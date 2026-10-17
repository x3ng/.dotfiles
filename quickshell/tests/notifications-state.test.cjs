// No NotificationServer is instantiated: exercise the production state machine
// with inert FileViews, so tests cannot publish notifications or touch history.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../Notifications.qml'), 'utf8');

function extract(name) {
    const start = source.indexOf(`    function ${name}(`);
    assert.notEqual(start, -1);
    let end = source.indexOf('{', start) + 1;
    for (let depth = 1; depth && end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    return source.slice(start, end);
}

function fixture() {
    const writes = [];
    const context = {
        historyLoaded: false, legacyRequested: false, persistenceAllowed: false,
        persistenceError: '', historyDirty: false, historyRevision: 0,
        writingRevision: 0, writeInFlight: false, persistedContents: null, writingContents: '', closedLocalKeys: [],
        history: [], current: [], popups: [], maxHistory: 50, maxCurrent: 20,
        recordTransient: true, FileViewError: {FileNotFound: 2},
        saveTimer: {restart() {}}, historyFileView: {setText: text => writes.push(JSON.parse(text))},
        NotificationUtils: {savedImage: value => value}, console: {warn() {}}
    };
    vm.createContext(context);
    vm.runInContext(['persistHistory', 'loadHistory', 'finishLoad', 'applyLoaded', 'loadFailed',
        'flushHistory', 'historySaved', 'historySaveFailed', 'closeLocal', 'saveRecord']
        .map(extract).join('\n'), context);
    return {state: context, writes};
}

const record = (key, summary = key) => ({recordKey: key, time: 1, summary});
const snapshot = (notifications = [], current = []) => JSON.stringify({notifications, current});
const wrapper = (key, summary) => ({...record(key, summary), notification: {transient: false},
    appName: 'Mock', body: '', appIcon: '', contentImage: '', urgency: 1});

test('state path honors XDG_STATE_HOME and falls back to HOME, never cache', () => {
    const expression = source.split('readonly property string historyFile: ')[1]
        .split('\n    readonly property string legacyHistoryFile:')[0];
    const env = {HOME: '/mock/home', XDG_STATE_HOME: '/mock/state'};
    const context = vm.createContext({Quickshell: {env: name => env[name] || ''}});
    assert.equal(vm.runInContext(expression, context), '/mock/state/quickshell/notifications.json');
    env.XDG_STATE_HOME = '';
    assert.equal(vm.runInContext(expression, context), '/mock/home/.local/state/quickshell/notifications.json');
});

test('only a missing new file permits legacy migration', () => {
    const {state, writes} = fixture();
    state.loadFailed(2, false);
    assert.equal(state.legacyRequested, true);
    assert.equal(state.historyLoaded, false);
    state.applyLoaded(snapshot([record('old')], [record('old')]), true);
    state.flushHistory();
    assert.equal(state.historyLoaded, true);
    assert.equal(writes.length, 1);
    assert.equal(writes[0].version, 1);
    assert.equal(writes[0].notifications[0].recordKey, 'old');
    assert.equal(writes[0].current[0].recordKey, 'old');
    // A delayed stale cache signal cannot replace authoritative state.
    state.applyLoaded(snapshot([record('later')]), true);
    assert.equal(state.history[0].recordKey, 'old');
});

test('existing empty history stays empty and never consults or revives legacy data', () => {
    const {state, writes} = fixture();
    state.applyLoaded(snapshot(), false);
    assert.equal(state.legacyRequested, false);
    state.applyLoaded(snapshot([record('stale')], [record('stale')]), true);
    state.loadFailed(2, false);
    state.flushHistory();
    assert.equal(state.legacyRequested, false);
    assert.equal(state.history.length, 0);
    assert.equal(state.current.length, 0);
    assert.equal(writes.length, 0);
});

test('fresh installs create an empty authoritative snapshot after both files are absent', () => {
    const {state, writes} = fixture();
    state.loadFailed(2, false);
    state.loadFailed(2, true);
    state.flushHistory();
    assert.equal(writes.length, 1);
    assert.deepEqual(writes[0], {version: 1, notifications: [], current: []});
});

for (const legacy of [false, true]) {
    test(`${legacy ? 'legacy' : 'new'} corrupt JSON/invalid shape blocks persistence without losing live records`, () => {
        for (const text of ['', '{bad', '{}', '{"notifications":{}}', '{"notifications":[],"current":null}',
                '{"version":2,"notifications":[]}']) {
            const {state, writes} = fixture();
            state.saveRecord(wrapper('live', 'early arrival'));
            if (legacy) state.loadFailed(2, false);
            state.applyLoaded(text, legacy);
            assert.equal(state.historyLoaded, true);
            assert.equal(state.persistenceAllowed, false);
            assert.ok(state.persistenceError);
            state.saveRecord(wrapper('later', 'another arrival'));
            state.flushHistory();
            assert.equal(writes.length, 0);
            assert.equal(state.history.length, 2);
            if (!legacy) assert.equal(state.legacyRequested, false);
        }
    });

    test(`${legacy ? 'legacy' : 'new'} non-missing read errors preserve original data`, () => {
        const {state, writes} = fixture();
        if (legacy) state.loadFailed(2, false);
        state.loadFailed(13, legacy);
        state.saveRecord(wrapper('live', 'still usable'));
        state.flushHistory();
        assert.equal(state.persistenceAllowed, false);
        assert.equal(state.historyLoaded, true);
        assert.equal(writes.length, 0);
    });
}

test('early live records win over disk copies and closed local alerts cannot revive', () => {
    const {state, writes} = fixture();
    state.saveRecord(wrapper('same', 'live wins'));
    state.closeLocal('battery-low');
    state.flushHistory();
    assert.equal(writes.length, 0, 'cannot save before loading existing history');
    state.loadFailed(2, false);
    state.applyLoaded(snapshot([record('same', 'old'), record('local:battery-low')],
        [record('same', 'old'), record('local:battery-low')]), true);
    assert.equal(state.history.length, 2);
    assert.equal(state.history[0].summary, 'live wins');
    assert.equal(state.current.length, 1);
    state.flushHistory();
    assert.equal(writes[0].notifications[0].summary, 'live wins');
    assert.equal(writes[0].current.length, 1);
});

test('closing a local alert before loading persists removal even with no live current entries', () => {
    const {state, writes} = fixture();
    state.closeLocal('battery-low');
    state.applyLoaded(snapshot([record('local:battery-low')], [record('local:battery-low')]), false);
    state.flushHistory();
    assert.equal(writes.length, 1);
    assert.equal(writes[0].notifications.length, 1);
    assert.equal(writes[0].current.length, 0);
});

test('writes serialize and preserve changes received while a write is in flight', () => {
    const {state, writes} = fixture();
    state.applyLoaded(snapshot(), false);
    state.saveRecord(wrapper('first', 'first'));
    state.flushHistory();
    state.saveRecord(wrapper('second', 'second'));
    state.flushHistory();
    assert.equal(writes.length, 1);
    state.historySaved();
    assert.equal(state.historyDirty, true);
    state.flushHistory();
    assert.equal(writes.length, 2);
    assert.equal(writes[1].notifications.length, 2);
    state.historySaveFailed();
    assert.equal(state.writeInFlight, false);
    assert.equal(state.historyDirty, true);
    assert.ok(state.persistenceError);
    assert.equal(state.persistenceAllowed, false);
    state.saveRecord(wrapper('third', 'session only'));
    state.flushHistory();
    assert.equal(writes.length, 2);
    assert.equal(state.history.length, 3);
});

test('same-content saves skip FileView without waiting for a signal it will not emit', () => {
    const {state, writes} = fixture();
    const canonical = JSON.stringify({version: 1, notifications: [], current: []}) + '\n';
    state.applyLoaded(canonical, false);
    state.persistHistory();
    state.flushHistory();
    assert.equal(writes.length, 0);
    assert.equal(state.writeInFlight, false);
    assert.equal(state.historyDirty, false);
    state.saveRecord(wrapper('new', 'new'));
    state.flushHistory();
    assert.equal(writes.length, 1);
    state.historySaved();
    state.persistHistory();
    state.flushHistory();
    assert.equal(writes.length, 1);
    assert.equal(state.writeInFlight, false);
    assert.equal(state.historyDirty, false);
});
