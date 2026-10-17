const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../SystemControls.qml'), 'utf8');
function bodyAt(start) {
    const begin = source.indexOf('{', start); let end = begin + 1;
    for (let depth = 1; depth; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    return source.slice(begin, end);
}
function loadFunction(name, context) {
    const start = source.indexOf(`function ${name}(`);
    vm.runInContext(source.slice(start, source.indexOf('{', start)) + bodyAt(start), context);
}

test('power availability requires a successful actual service property read', () => {
    const context = vm.createContext({root: {powerServiceAvailable: true}, output: ''});
    vm.runInContext('function exited(code, status) ' + bodyAt(source.indexOf('onExited:', source.indexOf('id: powerProbe'))), context);
    for (const value of ['', '{}', '{"type":"b","data":true}', '{"type":"s","data":"unknown"}']) {
        context.output = value; context.exited(0, 0); assert.equal(context.root.powerServiceAvailable, false);
    }
    context.output = '{"type":"s","data":"balanced"}'; context.exited(0, 0);
    assert.equal(context.root.powerServiceAvailable, true);
    context.exited(1, 0); assert.equal(context.root.powerServiceAvailable, false);
});

test('power probe handles executable startup failure without exited', () => {
    const context = vm.createContext({root: {powerServiceAvailable: true}, powerProbe: {hasStarted: false, running: false}});
    vm.runInContext('function timeout() ' + bodyAt(source.indexOf('onTriggered:', source.indexOf('id: powerStartupCheck'))), context);
    context.timeout(); assert.equal(context.root.powerServiceAvailable, false);
});

test('system actions return accepted status and refuse missing service or busy radio', () => {
    const context = vm.createContext({wifiAvailable: true, wifiBusy: true, wifiEnabled: true,
        Networking: {wifiEnabled: true}, scheduleConnectionObservation() {}, ConnectionFeedback: {silence() {}}, connectionTracker: {}, error: '',
        powerAvailable: false, powerProfiles: ['balanced'], PowerProfiles: {profile: 123}, PowerProfile: {Balanced: 1, Performance: 2, PowerSaver: 0}});
    loadFunction('toggleWifi', context); loadFunction('setPowerProfile', context);
    assert.equal(context.toggleWifi(), false); assert.equal(context.Networking.wifiEnabled, true);
    context.wifiBusy = false; assert.equal(context.toggleWifi(), true); assert.equal(context.Networking.wifiEnabled, false);
    assert.equal(context.setPowerProfile('balanced'), false); assert.equal(context.PowerProfiles.profile, 123);
    context.powerAvailable = true; assert.equal(context.setPowerProfile('balanced'), true); assert.equal(context.PowerProfiles.profile, 1);
});

for (const action of ['toggleWifi', 'toggleBluetooth', 'onRequestDisconnect']) {
    test(`${action}: rejected backend request without native signals still expires suppression`, () => {
        let now = 0;
        const clock = {now: () => now};
        const trackerApi = vm.createContext({Date: clock});
        vm.runInContext(fs.readFileSync(path.join(__dirname, '../components/ConnectionFeedback.js'), 'utf8'), trackerApi);
        const isBluetooth = action === 'toggleBluetooth';
        const network = {name: 'Home', device: {name: 'wlan0'}, connected: true, state: 1};
        const device = {name: 'Headset', address: 'aa', state: 1};
        const callbacks = [], feedback = [];
        const networking = {}, adapter = {};
        // Emulate a D-Bus request rejected without changing the native property.
        Object.defineProperty(networking, 'wifiEnabled', {get: () => true, set() {}});
        Object.defineProperty(adapter, 'enabled', {get: () => true, set() {}});
        const context = vm.createContext({
            Date: clock, ConnectionFeedback: trackerApi, connectionTracker: trackerApi.create(),
            ConnectionState: {Connecting: 2}, BluetoothDeviceState: {Connected: 1, Connecting: 2},
            wifiAvailable: true, wifiBusy: false, wifiEnabled: !isBluetooth,
            wifiNetworks: isBluetooth ? [] : [network], Networking: networking,
            bluetoothEnabled: isBluetooth, bluetoothBusy: false, bluetoothAdapter: adapter,
            bluetoothDevices: isBluetooth ? [device] : [], modelData: network,
            connectionDeadline: {running: false}, error: '',
            Qt: {callLater: callback => callbacks.push(callback)},
            feedback: (...args) => feedback.push(args)
        });
        context.root = context;
        for (const name of ['wifiKey', 'bluetoothKey', 'observeConnections', 'scheduleConnectionObservation', action])
            loadFunction(name, context);
        context.observeConnections();
        now = 3000; context.observeConnections();
        assert.equal(context.connectionDeadline.running, false);

        now = 4000; context[action]();
        assert.ok(callbacks.length > 0, 'intent must schedule observation even without a native state signal');
        for (const callback of callbacks.splice(0)) callback();
        assert.equal(context.connectionDeadline.running, true, 'suppression deadline must be serviced');
        now = 9000; context.observeConnections();
        assert.equal(context.connectionDeadline.running, false);
        assert.equal(feedback.length, 0);

        now = 20000; network.connected = false; device.state = 0;
        context.observeConnections();
        now = 24000; context.observeConnections();
        assert.equal(feedback.length, 1, 'the first later genuine disconnect must still notify');
        assert.match(feedback[0][1], /disconnected$/);
    });
}
