// Exercise the real action directory and dispatch with inert service adapters.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../ShellActions.qml'), 'utf8');

function fixture() {
    const calls = [];
    const accepted = name => (...args) => { calls.push([name, ...args]); return true; };
    const context = {
        services: {
            sink: {audio: {muted: false}}, source: {audio: {muted: false}}, keepAwake: false,
            toggleOutputMute: accepted('output'), toggleMicMute: accepted('mic'),
            toggleKeepAwake: accepted('awake'),
            controls: {
                wifiAvailable: true, wifiEnabled: true, wifiBusy: false,
                bluetoothAvailable: true, bluetoothEnabled: true, bluetoothBusy: false,
                powerProfiles: ['balanced'], powerAvailable: true,
                toggleWifi: accepted('wifi'), toggleBluetooth: accepted('bluetooth'),
                setPowerProfile: accepted('power')
            }
        },
        appearance: {appearanceAvailable: true, appearanceKnown: true, setTheme: accepted('theme')},
        keyboard: {available: true, pending: false, shown: false, toggle: accepted('keyboard')},
        hyprControls: {available: true, busy: false, lock: accepted('lock')},
        navigateRequested: accepted('navigate')
    };
    vm.createContext(context);
    // Keep the catalogue reactive as QML does: getters re-evaluate against live mocks.
    const entries = source.split('readonly property var entries: ')[1].split('\n\n    // Shared')[0];
    const functions = source.slice(source.indexOf('    function available'), source.lastIndexOf('}'));
    vm.runInContext('function readEntries() { return ' + entries + '; }\n' + functions, context);
    Object.defineProperty(context, 'entries', {get: () => context.readEntries()});
    return {context, calls};
}

test('navigation actions choose destinations without touching services', () => {
    const {context, calls} = fixture();
    for (const id of ['desktop', 'controls', 'wifi', 'bluetooth', 'audio', 'notifications', 'brightness'])
        assert.equal(context.execute(id), true);
    assert.deepEqual(calls, ['desktop', 'controls', 'wifi', 'bluetooth', 'audio', 'notifications', 'controls']
        .map(id => ['navigate', id]));
});

test('radio availability is independent and rechecked at dispatch', () => {
    const {context, calls} = fixture();
    assert.equal(context.available('wifi-toggle'), true);
    context.services.controls.wifiBusy = true;
    assert.equal(context.execute('wifi-toggle'), false);
    assert.equal(context.execute('bluetooth-toggle'), true);
    context.services.controls.bluetoothAvailable = false;
    assert.equal(context.execute('bluetooth-toggle'), false);
    assert.deepEqual(calls, [['bluetooth']]);
});

test('all controls use the same service dispatch and acceptance result', () => {
    const {context, calls} = fixture();
    for (const id of ['output-mute', 'mic-mute', 'keep-awake', 'light', 'dark', 'keyboard', 'lock', 'power:balanced'])
        assert.equal(context.execute(id), true, id);
    assert.deepEqual(calls, [['output'], ['mic'], ['awake'], ['theme', false], ['theme', true],
        ['keyboard'], ['lock'], ['power', 'balanced']]);
    context.hyprControls.lock = () => false;
    assert.equal(context.execute('lock'), false);
});

test('unavailable devices, pending keyboard, unknown actions and profiles cannot run', () => {
    const {context, calls} = fixture();
    context.services.sink = null;
    context.services.source = null;
    context.keyboard.pending = true;
    context.appearance.appearanceAvailable = false;
    context.hyprControls.busy = true;
    context.services.controls.powerAvailable = false;
    for (const id of ['output-mute', 'mic-mute', 'keyboard', 'light', 'dark', 'lock', 'power:balanced', 'power:unknown', 'unknown'])
        assert.equal(context.execute(id), false, id);
    assert.deepEqual(calls, []);
});
