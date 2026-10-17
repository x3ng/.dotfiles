const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
function fixture() {
    const api = vm.createContext({});
    vm.runInContext(fs.readFileSync(path.join(__dirname, '../components/ConnectionFeedback.js'), 'utf8'), api);
    const tracker = api.create();
    return {api, tracker, observe: (rows, time) => JSON.parse(JSON.stringify(api.observe(tracker, rows, time)))};
}
const wifi = (name, connected, device = 'wlan0', extra = {}) =>
    ({key: `wifi:${device}:${name}`, name, kind: 'wifi', device, connected, ...extra});
const bluetooth = connected => ({key: 'bluetooth:aa', name: 'Headset', kind: 'bluetooth', connected});
function stable(f, rows) { assert.deepEqual(f.observe(rows, 0), []); assert.deepEqual(f.observe(rows, 3000), []); }

test('discovery is quiet; brief loss recovers; persistent loss is emitted only once', () => {
    const f = fixture(); stable(f, [wifi('A', true)]);
    assert.deepEqual(f.observe([wifi('A', false)], 4000), []);
    assert.deepEqual(f.observe([wifi('A', true)], 5000), []);
    assert.deepEqual(f.observe([wifi('A', false)], 6000), []);
    assert.equal(f.observe([wifi('A', false)], 10000)[0].result, 'lost');
    assert.deepEqual(f.observe([wifi('A', false)], 15000), []);
});

test('failed Wi-Fi switch restores old connection monitoring regardless of row order', () => {
    for (const reverse of [false, true]) {
        const f = fixture();
        const rows = [wifi('A', true), wifi('B', false)]; if (reverse) rows.reverse();
        stable(f, rows);
        f.api.request(f.tracker, wifi('B').key, 4000);
        f.api.failure(f.tracker, wifi('B').key, 'Bad password');
        assert.equal(f.observe(rows, 5000)[0].result, 'failed');
        f.observe([wifi('A', false), wifi('B', false)], 6000);
        const lost = f.observe([wifi('A', false), wifi('B', false)], 10000);
        assert.equal(lost.length, 1); assert.equal(lost[0].key, wifi('A').key);
    }
});

test('a Wi-Fi switch never silences another device', () => {
    const f = fixture(); stable(f, [wifi('A', true), wifi('B', false), wifi('C', true, 'usb0')]);
    f.api.request(f.tracker, wifi('B').key, 4000);
    const rows = [wifi('A', true), wifi('B', false, 'wlan0', {connecting: true}), wifi('C', false, 'usb0')];
    f.observe(rows, 4500);
    const lost = f.observe(rows, 8500); assert.equal(lost[0].key, wifi('C', false, 'usb0').key);
});

test('switch timeout restores still-connected old link and has finite pending state', () => {
    const f = fixture(); const rows = [wifi('A', true), wifi('B', false)]; stable(f, rows);
    f.api.request(f.tracker, wifi('B').key, 4000);
    assert.equal(f.observe(rows, 49000)[0].result, 'failed');
    f.observe(rows, 50000); assert.equal(f.tracker.pending, false);
    f.observe([wifi('A', false), wifi('B', false)], 51000);
    assert.equal(f.observe([wifi('A', false), wifi('B', false)], 55000)[0].result, 'lost');
});

test('intentional switching emits success but not old network loss', () => {
    const f = fixture(); stable(f, [wifi('A', true), wifi('B', false)]);
    f.api.request(f.tracker, wifi('B').key, 4000);
    f.observe([wifi('A', false), wifi('B', false, 'wlan0', {connecting: true})], 4500);
    assert.equal(f.observe([wifi('A', false), wifi('B', true)], 5000)[0].result, 'connected');
    assert.deepEqual(f.observe([wifi('A', false), wifi('B', true)], 10000), []);
});

test('radio off cancels requests; a failed disconnect suppression expires', () => {
    const f = fixture(); stable(f, [bluetooth(true)]);
    f.api.silence(f.tracker, 'bluetooth:', false, 4000);
    assert.deepEqual(f.observe([bluetooth(true)], 5000), []);
    assert.deepEqual(f.observe([bluetooth(true)], 9000), []);
    f.observe([bluetooth(false)], 10000);
    assert.equal(f.observe([bluetooth(false)], 14000)[0].result, 'lost');
    const g = fixture(); stable(g, [wifi('A', true), wifi('B', false)]);
    g.api.request(g.tracker, wifi('B').key, 4000);
    g.api.silence(g.tracker, 'wifi:', false, 4500);
    assert.deepEqual(g.observe([], 5000), []); assert.deepEqual(g.observe([], 50000), []);
    assert.equal(g.tracker.pending, false);
});

test('native failures are deduplicated; explicit retry still receives a result', () => {
    const f = fixture(), rows = [wifi('A', false)]; f.observe(rows, 0);
    f.api.failure(f.tracker, rows[0].key, 'Authentication failed');
    assert.equal(f.observe(rows, 1)[0].result, 'failed');
    f.api.failure(f.tracker, rows[0].key, 'Authentication failed');
    assert.deepEqual(f.observe(rows, 100), []);
    f.api.request(f.tracker, rows[0].key, 200);
    f.api.failure(f.tracker, rows[0].key, 'Authentication failed');
    assert.equal(f.observe(rows, 300)[0].result, 'failed');
});

test('Bluetooth connection failure is debounced and has a timeout fallback', () => {
    const f = fixture(), row = bluetooth(false); f.observe([row], 0);
    f.api.request(f.tracker, row.key, 1); f.observe([{...row, connecting: true}], 2);
    assert.deepEqual(f.observe([row], 100), []);
    assert.equal(f.observe([row], 1100)[0].result, 'failed');
    const g = fixture(); g.observe([row], 0); g.api.request(g.tracker, row.key, 1);
    assert.equal(g.observe([row], 25001)[0].result, 'failed');
});
