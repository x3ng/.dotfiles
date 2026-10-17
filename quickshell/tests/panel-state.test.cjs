const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../PanelState.qml'), 'utf8');
function state() {
    const writes = [], notices = [];
    const context = vm.createContext({selectedHomeTab: 'desktop', loadedOnce: false,
        persistenceAllowed: false, persistenceError: '', revision: 0, writingRevision: 0,
        dirty: false, writeInFlight: false, persistedTab: '', writingTab: '', savedState: {setText: text => writes.push(JSON.parse(text))},
        feedback: (...args) => notices.push(args)});
    for (const name of ['reportError', 'setLastHomeTab', 'applyLoaded', 'finishLoad', 'flush', 'saved', 'saveFailed']) {
        const start = source.indexOf(`function ${name}(`);
        let end = source.indexOf('{', start) + 1;
        for (let depth = 1; depth; end++) {
            if (source[end] === '{') depth++;
            if (source[end] === '}') depth--;
        }
        vm.runInContext(source.slice(start, end), context);
    }
    return {context, writes, notices};
}
const stored = tab => JSON.stringify({version: 1, lastHomeTab: tab});
test('fresh panel defaults to desktop and missing state does not write until selection', () => {
    const {context: s, writes} = state();
    s.finishLoad(true, '');
    assert.equal(s.selectedHomeTab, 'desktop'); assert.equal(s.loadedOnce, true);
    assert.deepEqual(writes, []);
    assert.equal(s.setLastHomeTab('controls'), true);
    assert.deepEqual(writes, [{version: 1, lastHomeTab: 'controls'}]);
});
test('valid state restores only supported tab; invalid selection is inert', () => {
    const {context: s, writes} = state();
    s.applyLoaded(stored('controls'));
    assert.equal(s.selectedHomeTab, 'controls');
    for (const tab of ['windows', '', null, true, 0]) assert.equal(s.setLastHomeTab(tab), false);
    assert.equal(s.revision, 0); assert.deepEqual(writes, []);
});
test('explicit selection including default wins over late initial read', () => {
    for (const tab of ['desktop', 'controls']) {
        const {context: s, writes} = state();
        s.setLastHomeTab(tab); assert.deepEqual(writes, []);
        s.applyLoaded(stored(tab === 'desktop' ? 'controls' : 'desktop'));
        assert.equal(s.selectedHomeTab, tab);
        assert.deepEqual(writes, [{version: 1, lastHomeTab: tab}]);
        s.applyLoaded(stored('controls')); assert.equal(s.selectedHomeTab, tab);
    }
});
test('malformed or unsupported data preserves original file and keeps memory usable', () => {
    for (const contents of ['', '{', 'null', '[]', '{}', '{"version":2,"lastHomeTab":"controls"}', stored('windows')]) {
        const {context: s, writes, notices} = state();
        s.applyLoaded(contents);
        assert.equal(s.loadedOnce, true); assert.equal(s.selectedHomeTab, 'desktop');
        assert.equal(s.persistenceAllowed, false); assert.ok(s.persistenceError);
        assert.equal(s.setLastHomeTab('controls'), true);
        assert.equal(s.selectedHomeTab, 'controls'); assert.deepEqual(writes, []);
        assert.equal(notices.length, 1);
    }
});
test('unreadable state never gets overwritten, including pre-load user choice', () => {
    const {context: s, writes, notices} = state();
    s.setLastHomeTab('controls'); s.finishLoad(false, 'unreadable');
    assert.equal(s.selectedHomeTab, 'controls'); assert.equal(s.loadedOnce, true);
    s.setLastHomeTab('desktop'); assert.deepEqual(writes, []);
    assert.equal(notices[0][0], 'panel-state');
});
test('asynchronous saves serialize and coalesce to latest selection', () => {
    const {context: s, writes} = state();
    s.finishLoad(true, ''); s.setLastHomeTab('controls');
    s.setLastHomeTab('controls'); s.setLastHomeTab('desktop');
    assert.equal(writes.length, 1); s.saved();
    assert.deepEqual(writes, [{version: 1, lastHomeTab: 'controls'}, {version: 1, lastHomeTab: 'desktop'}]);
    assert.equal(s.writeInFlight, true); s.saved();
    assert.equal(s.dirty, false); assert.equal(s.writeInFlight, false);
});
test('write failure retains newer memory and disables unsafe cached retries', () => {
    const {context: s, writes, notices} = state();
    s.finishLoad(true, ''); s.setLastHomeTab('controls'); s.setLastHomeTab('desktop');
    s.saveFailed(); assert.equal(s.selectedHomeTab, 'desktop');
    assert.equal(s.dirty, true); assert.equal(s.writeInFlight, false);
    assert.equal(writes.length, 1); assert.equal(notices.length, 1);
    s.setLastHomeTab('desktop'); assert.equal(writes.length, 1);
    assert.ok(s.persistenceError); assert.equal(s.persistenceAllowed, false);
});
test('production FileView explicitly uses asynchronous atomic writes and XDG state directory', () => {
    for (const fragment of ['atomicWrites: true', 'blockWrites: false', 'preload: true',
        'FileViewError.FileNotFound', 'Quickshell.env("XDG_STATE_HOME")', '/quickshell/panel-state.json'])
        assert.ok(source.includes(fragment), fragment);
});

test('selecting the persisted tab does not wait for a nonexistent FileView saved event', () => {
    const {context: s, writes} = state();
    s.applyLoaded(stored('desktop')); s.setLastHomeTab('desktop');
    assert.equal(s.writeInFlight, false); assert.deepEqual(writes, []);
    s.setLastHomeTab('controls'); s.setLastHomeTab('controls'); s.saved();
    assert.equal(writes.length, 1); assert.equal(s.writeInFlight, false);
    s.setLastHomeTab('desktop'); assert.equal(writes.length, 2);
});
