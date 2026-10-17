// Exercise actual battery decisions without UPower, live notifications or disk IO.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../BatteryAlerts.qml'), 'utf8');

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
    const writes = [], alerts = [], closed = [];
    const state = vm.createContext({
        stateLoaded: false, persistenceAllowed: false, announcedThreshold: 100,
        batteryReady: true, onBattery: true, percentage: 0.15, batteryState: 2,
        alertKey: 'battery-low', FileViewError: {FileNotFound: 2},
        UPowerDeviceState: {Charging: 1, Discharging: 2, FullyCharged: 4},
        stateFile: {setText: text => writes.push(JSON.parse(text))},
        notifications: {
            historyLoaded: true,
            closeLocal: key => closed.push(key),
            notifyLocal: (key, details) => { alerts.push({key, ...details}); return true; }
        },
        console: {warn() {}}
    });
    vm.runInContext(['applyLoaded', 'loadFailed', 'saveFailed', 'persist', 'evaluate'].map(extract).join('\n'), state);
    return {state, writes, alerts, closed};
}

test('missing battery state allows persisting new alerts and charge-cycle reset', () => {
    const {state, writes, alerts, closed} = fixture();
    state.evaluate();
    assert.equal(alerts.length, 0, 'must wait for initial state');
    state.loadFailed(2);
    state.evaluate();
    state.evaluate();
    assert.equal(alerts.length, 1, 'same threshold is announced once');
    assert.deepEqual(writes, [{version: 1, threshold: 20}]);
    state.batteryState = 1;
    state.evaluate();
    assert.equal(state.announcedThreshold, 100);
    assert.equal(writes.at(-1).threshold, 100);
    assert.ok(closed.length);
});

test('valid battery state restores deduplication and permits a lower threshold', () => {
    const {state, writes, alerts} = fixture();
    state.applyLoaded('{"version":1,"threshold":20}');
    state.evaluate();
    assert.equal(alerts.length, 0);
    state.percentage = 0.09;
    state.evaluate();
    assert.equal(alerts.length, 1);
    assert.equal(alerts[0].critical, true);
    assert.equal(writes[0].threshold, 10);
});

test('invalid and future battery state stays untouched while session alerts work', () => {
    for (const contents of ['{bad', 'null', '{}', '{"version":2,"threshold":20}',
            '{"version":1,"threshold":12}', '{"version":1,"threshold":"20"}']) {
        const {state, writes, alerts} = fixture();
        state.applyLoaded(contents);
        assert.equal(state.stateLoaded, true);
        assert.equal(state.persistenceAllowed, false);
        state.evaluate();
        state.evaluate();
        assert.equal(alerts.length, 1, contents);
        assert.equal(state.announcedThreshold, 20);
        state.batteryState = 1;
        state.evaluate();
        assert.equal(state.announcedThreshold, 100, 'cycle reset remains available in memory');
        assert.equal(writes.length, 0, contents);
        state.loadFailed(2);
        assert.equal(state.persistenceAllowed, false, 'late callback cannot enable writes');
    }
});

test('non-missing battery read failures never enable disk writes', () => {
    for (const error of [1, 3, 13]) {
        const {state, writes, alerts} = fixture();
        state.loadFailed(error);
        state.evaluate();
        assert.equal(alerts.length, 1);
        assert.equal(writes.length, 0);
        state.applyLoaded('{"version":1,"threshold":5}');
        assert.equal(state.announcedThreshold, 20, 'late load must not overwrite newer session state');
        assert.equal(state.persistenceAllowed, false);
    }
});

test('battery save failure disables retries without blocking critical alerts', () => {
    const {state, writes, alerts} = fixture();
    state.loadFailed(2);
    state.evaluate();
    state.saveFailed();
    state.percentage = 0.04;
    state.evaluate();
    assert.equal(alerts.length, 2);
    assert.equal(alerts[1].critical, true);
    assert.equal(state.announcedThreshold, 5);
    assert.equal(writes.length, 1);
    state.persist();
    assert.equal(writes.length, 1);
});
