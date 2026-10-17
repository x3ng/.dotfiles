const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const fs = require('node:fs');
const {tmpdir} = require('node:os');
const {join, delimiter} = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const commands = vm.createContext({});
vm.runInContext(fs.readFileSync(join(__dirname, '../components/HyprlandControlCommands.js'), 'utf8'), commands);
const window = {address: '0xabc'};
const workspace = {id: -98, exists: true};
const empty = {id: 7, exists: false};

function scenarios() {
    const rows = [];
    for (const operation of ['focus', 'float', 'fullscreen', 'close', 'move']) {
        const code = commands.windowAction(operation, window, workspace).code;
        rows.push({code, mode: 'ok', expected: 'OK', window: true});
        rows.push({code, mode: 'missing-window', expected: 'ERROR: Window no longer exists', window: true});
        rows.push({code, mode: 'unmapped-window', expected: 'ERROR: Window no longer exists', window: true});
        rows.push({code, mode: 'dispatch-failure', expected: 'ERROR: refused', window: true});
        if (operation === 'move')
            rows.push({code, mode: 'missing-workspace', expected: 'ERROR: Workspace no longer exists', window: true});
    }
    rows.push({code: commands.windowAction('move', window, empty).code, mode: 'ok', expected: 'OK', window: true, empty: true});
    for (const operation of ['focus', 'layout']) {
        const code = commands.workspaceAction(operation, workspace, 'master').code;
        rows.push({code, mode: 'ok', expected: 'OK'});
        rows.push({code, mode: 'missing-workspace', expected: 'ERROR: Workspace no longer exists'});
    }
    rows.push({code: commands.workspaceAction('focus', empty).code, mode: 'ok', expected: 'OK', empty: true});
    return rows;
}

test('command validation rejects injection, invalid IDs and implicit targets', () => {
    for (const value of ['', '0x0', 'address:0xabc', "0xabc'); os.execute('bad')", '0x' + 'f'.repeat(17), null])
        assert.equal(commands.address(value), '');
    assert.equal(commands.address('ABC'), '0xabc');
    for (const id of [0, 1.1, NaN, Infinity, '1', '1;exit', 2147483648]) assert.equal(commands.validId(id), false);
    assert.ok(commands.windowAction('focus', null).error);
    assert.ok(commands.windowAction('move', window, {id: '7', exists: false}).error);
    assert.ok(commands.workspaceAction('layout', empty, 'master').error);
    assert.ok(commands.workspaceAction('layout', workspace, "dwindle'); os.execute('bad')").error);
    for (const row of scenarios()) assert.ok(row.code && !row.code.includes('get_active'));
});

function luaScenario(row) {
    return `do
    local calls = 0
    local win = {mapped = ${row.mode === 'unmapped-window' ? 'false' : 'true'}}
    local ws = {id = -98, config_name = "special:weird'quoted"}
    local function dispatch(args)
        return function()
            calls = calls + 1
            ${row.window ? 'assert(args.window == win, "must explicitly target checked window")' : ''}
            ${row.empty ? 'assert(args.workspace == 7, "empty target must use exact numeric ID")' : ''}
            return {ok = ${row.mode === 'dispatch-failure' ? 'false' : 'true'}, error = 'refused'}
        end
    end
    hl = {
        get_window = function(selector)
            assert(selector == 'address:0xabc')
            return ${row.mode === 'missing-window' ? 'nil' : 'win'}
        end,
        get_workspaces = function() return ${row.mode === 'missing-workspace' ? '{}' : '{ws}'} end,
        workspace_rule = function(rule)
            calls = calls + 1
            assert(rule.workspace == ws.config_name)
            assert(rule.layout == 'master')
        end,
        dispatch = function(fn) return fn() end,
        dsp = {
            focus = dispatch,
            window = {float = dispatch, fullscreen = dispatch, close = dispatch, move = dispatch},
            event = function(name)
                assert(name == 'workspace-layout')
                return function() return {ok = true} end
            end
        }
    }
    local fn, err = load([====[${row.code}]====])
    assert(fn, err)
    local result = fn()
    assert(result == ${JSON.stringify(row.expected)}, result)
    ${row.mode.startsWith('missing') || row.mode === 'unmapped-window'
        ? 'assert(calls == 0, "missing target dispatched action")' : 'assert(calls == 1)'}
end
`;
}
const interpreter = process.env.LUA || ['texlua', 'lua'].flatMap(name =>
    (process.env.PATH || '').split(delimiter).map(directory => join(directory, name)))
    .find(file => fs.existsSync(file));

test('27 Lua simulations preserve explicit targets and report dispatcher failures', {
    skip: !interpreter && 'No Lua interpreter: set LUA or provide lua/texlua'
}, () => {
    const directory = fs.mkdtempSync(join(tmpdir(), 'hyprland-controls-tests-'));
    try {
        const file = join(directory, 'dispatch.lua');
        fs.writeFileSync(file, scenarios().map(luaScenario).join('\n'));
        const result = spawnSync(interpreter, [file], {encoding: 'utf8', timeout: 5000});
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stdout + result.stderr);
    } finally {
        fs.rmSync(directory, {recursive: true, force: true});
    }
});
