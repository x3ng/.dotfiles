const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../HyprlandControls.qml'), 'utf8');
function bodyAt(text, start) {
    const begin = text.indexOf('{', start);
    let end = begin + 1;
    for (let depth = 1; depth; end++) {
        if (text[end] === '{') depth++;
        if (text[end] === '}') depth--;
    }
    return text.slice(begin, end);
}
function loadFunction(name, context) {
    const start = source.indexOf(`function ${name}(`);
    const signature = source.slice(start, source.indexOf('{', start));
    vm.runInContext(signature + bodyAt(source, start), context);
}
function fixture() {
    const result = [], feedback = [], processes = [];
    const root = vm.createContext({pendingOperation: null, requestSequence: 0, error: '', available: true,
        feedback: (...args) => feedback.push(args), operationFinished: (...args) => result.push(args), refresh() {}});
    root.root = root;
    Object.defineProperty(root, 'busy', {get() { return this.pendingOperation !== null; }});
    for (const name of ['reject', 'run', 'finish']) loadFunction(name, root);
    root.actionFactory = {createObject: (_, properties) => {
        const action = vm.createContext({...properties, root, hasStarted: false, settled: false,
            running: false, output: '', failure: '', destroyed: 0, destroy() { this.destroyed++; }});
        action.action = action;
        loadFunction('settle', action);
        for (const timer of ['startupCheck', 'deadline']) {
            const at = source.indexOf('onTriggered:', source.indexOf('property Timer ' + timer));
            const text = timer === 'deadline'
                ? '{ ' + source.slice(at + 'onTriggered:'.length, source.indexOf('\n', at)) + '; }' : bodyAt(source, at);
            vm.runInContext('function ' + timer + '() ' + text, action);
        }
        processes.push(action); return action;
    }};
    return {root, result, feedback, processes};
}

test('accepted actions receive IDs; busy/validation rejection cannot consume the current operation', () => {
    const f = fixture(); assert.equal(f.root.run({code: 'return 1'}, 'focusWindow', '0xabc'), true);
    assert.equal(f.root.requestSequence, 1);
    assert.equal(f.root.run({code: 'return 2'}, 'lock', 'session'), false);
    assert.equal(f.root.pendingOperation.operation, 'focusWindow'); assert.equal(f.feedback.length, 1);
    f.processes[0].settle(true, '');
    assert.deepEqual(f.result[0], [true, 'focusWindow', '0xabc', 1, '']);
    assert.equal(f.root.busy, false); assert.equal(f.root.error, '');
});

test('FailedToStart without exited is detected and cannot leave busy set', () => {
    const f = fixture(); f.root.run({code: 'return 1'}, 'lock', 'session');
    const p = f.processes[0]; p.running = false; p.startupCheck();
    assert.equal(f.root.busy, false); assert.equal(f.result[0][0], false);
    assert.match(f.result[0][4], /start hyprctl/); assert.equal(f.feedback.length, 1);
    p.settle(false, 'duplicate late exit'); assert.equal(f.result.length, 1);
});

test('deadline handles a hung process; late completion cannot finish a newer request', () => {
    const f = fixture(); f.root.run({code: 'return 1'}, 'focusWindow', '0xabc');
    const old = f.processes[0]; old.hasStarted = true; old.deadline();
    assert.equal(f.root.busy, false); assert.match(f.result[0][4], /timed out/);
    f.root.run({code: 'return 2'}, 'closeWindow', '0xdef');
    old.settle(true, ''); f.root.finish(old.context, true, '');
    assert.equal(f.root.pendingOperation.id, 2); assert.equal(f.result.length, 1);
    f.processes[1].settle(true, ''); assert.equal(f.result[1][3], 2);
});

test('component allocation failure rejects synchronously; invalid requests never spawn', () => {
    const f = fixture(); f.root.actionFactory.createObject = () => null;
    assert.equal(f.root.run({code: 'return 1'}, 'lock', 'session'), false);
    assert.equal(f.root.busy, false);
    assert.equal(f.root.run({error: 'Window no longer exists'}, 'focusWindow', '0xabc'), false);
    assert.equal(f.root.requestSequence, 1);
});
