pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

Scope {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var battery: UPower.displayDevice
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool keepAwake: idleInhibitor.running
    readonly property var source: Pipewire.defaultAudioSource
    property bool controlsVisible: false
    readonly property var controls: systemControls
    readonly property var audioOutputs: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink)
    readonly property var audioInputs: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !n.isSink)

    SystemControls { id: systemControls; active: root.controlsVisible }

    // A systemd idle inhibitor survives closing the panel. Closing stdin
    // releases it normally; shell shutdown also closes the pipe to cat.
    Process {
        id: idleInhibitor
        command: ["systemd-inhibit", "--what=idle", "--mode=block",
            "--who=Quickshell", "--why=Keep screen awake", "cat"]
        stdinEnabled: true
        stderr: SplitParser {
            onRead: data => console.warn("Keep awake: " + data.trim())
        }
    }

    function toggleKeepAwake() {
        if (idleInhibitor.running) {
            idleInhibitor.stdinEnabled = false;
        } else {
            idleInhibitor.stdinEnabled = true;
            idleInhibitor.running = true;
        }
    }

    PwObjectTracker {
        objects: root.audioOutputs.concat(root.audioInputs)
    }

    function toggleMicMute() {
        var audio = Pipewire.defaultAudioSource?.audio;
        if (audio) audio.muted = !audio.muted;
    }

    function toggleOutputMute() {
        if (sink?.audio) sink.audio.muted = !sink.audio.muted;
    }

    function selectAudioDevice(node, input) {
        const devices = input ? audioInputs : audioOutputs;
        if (!devices.includes(node)) return;
        if (input) Pipewire.preferredDefaultAudioSource = node;
        else Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolume(value) {
        var audio = Pipewire.defaultAudioSink?.audio;
        if (audio) audio.volume = Math.max(0, Math.min(1, value));
    }

    function durationLabel(seconds) {
        if (!seconds || seconds <= 0) return "";
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0) return hours + "H " + minutes + "M";
        return Math.max(1, minutes) + "M";
    }

    function batteryDetail(device) {
        if (!device) return "UNAVAILABLE";
        if (device.state === UPowerDeviceState.Charging) {
            var untilFull = durationLabel(device.timeToFull);
            return untilFull ? "CHARGING · " + untilFull + " TO FULL" : "CHARGING";
        }
        if (device.state === UPowerDeviceState.Discharging) {
            var remaining = durationLabel(device.timeToEmpty);
            return remaining ? "DISCHARGING · " + remaining + " LEFT" : "DISCHARGING";
        }
        if (device.state === UPowerDeviceState.FullyCharged) return "FULLY CHARGED";
        return "BATTERY";
    }

    // ── Brightness — event-driven via kernel uevent ─────────────────
    property real brightness: -1   // 0.0~1.0, -1 = not initialized
    property bool brightnessSetting: false

    Process {
        id: brightnessReadProc
        command: ["brightnessctl", "--class", "backlight", "--machine-readable"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                // brightnessctl's native CSV: device,class,current,percent,max.
                const fields = data.trim().split(",");
                const current = Number(fields[2]);
                const maximum = Number(fields[4]);
                if (fields.length >= 5 && Number.isFinite(current) && maximum > 0)
                    root.brightness = Math.max(0, Math.min(1, current / maximum));
            }
        }
    }

    Process {
        id: brightnessWatcher
        command: ["udevadm", "monitor", "--subsystem-match=backlight", "--kernel"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!root.brightnessSetting) brightnessDebounce.restart();
            }
        }
        onExited: (code, status) => {
            // Restart if it exits unexpectedly (e.g. udev restart)
            if (code !== 0) {
                watcherRestart.restart();
            }
        }
    }
    Timer {
        id: watcherRestart
        interval: 2000
        onTriggered: brightnessWatcher.running = true
    }

    Timer {
        id: brightnessDebounce
        interval: 50
        onTriggered: brightnessReadProc.running = true
    }

    function setBrightness(value) {
        value = Math.max(0, Math.min(1, value));
        var pct = Math.max(1, Math.round(value * 100));
        root.brightnessSetting = true;
        root.brightness = value;
        Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s", pct + "%", "--quiet"]);
        // Clear guard after a short delay (no Process reuse needed)
        brightnessGuardReset.restart();
    }

    Timer {
        id: brightnessGuardReset
        interval: 200
        onTriggered: {
            root.brightnessSetting = false;
            brightnessReadProc.running = true;
        }
    }

}
