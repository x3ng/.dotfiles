const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../DesktopServices.qml'), 'utf8');

function load(name, context) {
    const start = source.indexOf(`    function ${name}(`);
    assert.notEqual(start, -1);
    // Functions under test contain no brace characters in string literals.
    let end = source.indexOf('{', start) + 1;
    for (let depth = 1; depth && end < source.length; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    vm.createContext(context);
    vm.runInContext(source.slice(start, end), context);
}

test('network editor is rejected without a terminal and launched outside the shell service', () => {
    const calls = [];
    const context = {terminalCommand: [], Quickshell: {execDetached: argv => calls.push(Array.from(argv))}};
    load('openNetworkEditor', context);
    assert.equal(context.openNetworkEditor(), false);
    assert.equal(calls.length, 0);
    context.terminalCommand = ['kitty', '--title', 'Network $EDITOR', '--'];
    assert.equal(context.openNetworkEditor(), true);
    assert.deepEqual(calls[0], ['systemd-run', '--user', '--scope', '--collect', '--quiet',
        '--slice=app.slice', '--expand-environment=no', '--', 'kitty', '--title', 'Network $EDITOR', '--', 'nmtui', 'connect']);
});

test('audio actions reject missing devices and mutate only the selected default', () => {
    const context = {sink: null, Pipewire: {defaultAudioSource: null}};
    load('toggleOutputMute', context);
    load('toggleMicMute', context);
    assert.equal(context.toggleOutputMute(), false);
    assert.equal(context.toggleMicMute(), false);
    context.sink = {audio: {muted: false}};
    context.Pipewire.defaultAudioSource = {audio: {muted: true}};
    assert.equal(context.toggleOutputMute(), true);
    assert.equal(context.sink.audio.muted, true);
    assert.equal(context.Pipewire.defaultAudioSource.audio.muted, true);
    assert.equal(context.toggleMicMute(), true);
    assert.equal(context.Pipewire.defaultAudioSource.audio.muted, false);
});

function processFixture(id) {
    const start = source.indexOf(`id: ${id}`);
    const block = source.slice(start, source.indexOf('\n    }', start));
    const feedback = [];
    const context = {
        running: false, awaitingStart: false, startFailed: false, failure: '',
        root: {feedback: (...args) => feedback.push(args), flushBrightness() {}},
        Qt: {callLater() {}}, brightnessDebounce: {restart() {}}, feedback
    };
    vm.createContext(context);
    for (const name of ['RunningChanged', 'Exited']) {
        const handler = block.indexOf(`on${name}:`);
        const body = block.indexOf('{', handler);
        let end = body + 1;
        for (let depth = 1; depth && end < block.length; end++) {
            if (block[end] === '{') depth++;
            if (block[end] === '}') depth--;
        }
        vm.runInContext(`function on${name}(code, status) ` + block.slice(body, end), context);
    }
    const started = block.match(/onStarted: ([^\n]+)/)[1];
    vm.runInContext('function onStarted() { ' + started + '; }', context);
    return context;
}

for (const id of ['idleInhibitor', 'brightnessWriteProc']) {
    test(`${id}: startup is silent; FailedToStart reports once without exited`, () => {
        const process = processFixture(id);
        process.onRunningChanged();
        assert.equal(process.feedback.length, 0);
        process.awaitingStart = true;
        process.onRunningChanged();
        assert.equal(process.feedback.length, 1);
        assert.equal(process.startFailed, true);
        process.onRunningChanged();
        process.onExited(-1, 1);
        assert.equal(process.feedback.length, 1, 'do not duplicate a failed-start report');
    });

    test(`${id}: successful start clears the guard; runtime failure reports once`, () => {
        const process = processFixture(id);
        process.awaitingStart = true;
        process.running = true;
        process.onRunningChanged();
        process.onStarted();
        assert.equal(process.awaitingStart, false);
        process.running = false;
        process.onRunningChanged();
        process.onExited(1, 0);
        assert.equal(process.feedback.length, 1);
        process.feedback.length = 0;
        process.onExited(0, 0);
        assert.equal(process.feedback.length, 0, 'normal inhibitor release/brightness completion is silent');
    });
}

test('each service launch arms failure tracking and clears prior failure', () => {
    const inhibitor = {running: false, awaitingStart: false, startFailed: true, failure: 'old'};
    const context = {idleInhibitor: inhibitor};
    load('toggleKeepAwake', context);
    assert.equal(context.toggleKeepAwake(), true);
    assert.equal(inhibitor.awaitingStart, true);
    assert.equal(inhibitor.startFailed, false);
    assert.equal(inhibitor.failure, '');
    const writer = {running: false, awaitingStart: false, startFailed: true, failure: 'old'};
    const brightness = {brightnessWriteProc: writer, pendingBrightness: 45};
    load('flushBrightness', brightness);
    brightness.flushBrightness();
    assert.equal(writer.awaitingStart, true);
    assert.equal(writer.startFailed, false);
    assert.equal(writer.failure, '');
    assert.equal(writer.running, true);
    assert.equal(brightness.pendingBrightness, -1);
});

test('volume rejects invalid values and clamps finite requests to the supported range', () => {
    const audio = {volume: 0.5};
    const context = {Pipewire: {defaultAudioSink: {audio}}};
    load('setVolume', context);
    for (const invalid of [NaN, Infinity, -Infinity, '0.5', undefined]) {
        assert.equal(context.setVolume(invalid), false);
        assert.equal(audio.volume, 0.5);
    }
    assert.equal(context.setVolume(2), true);
    assert.equal(audio.volume, 1);
    assert.equal(context.setVolume(-1), true);
    assert.equal(audio.volume, 0);
});
