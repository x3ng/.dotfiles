//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
// Reusable visual components live beside the deployed entry point.
import "components"

ShellRoot {
    id: root

    Theme { id: theme }

    // Compatibility aliases keep the bar logic concise while Theme.qml owns
    // the visual system in one place.
    readonly property alias barHeight: theme.barHeight
    readonly property alias barReservedHeight: theme.barReservedHeight
    readonly property alias barOuterMarginX: theme.barOuterMarginX
    readonly property alias barBackgroundPaddingX: theme.barBackgroundPaddingX
    readonly property alias barBackgroundHeight: theme.barBackgroundHeight
    readonly property alias barSectionGap: theme.barSectionGap
    readonly property alias radiusBar: theme.radiusBar
    readonly property alias radiusPopup: theme.radiusPopup
    readonly property alias radiusCard: theme.radiusCard
    readonly property alias radiusControl: theme.radiusControl
    readonly property alias radiusSmall: theme.radiusSmall
    readonly property alias appearanceKnown: theme.appearanceKnown
    readonly property alias appearanceAvailable: theme.appearanceAvailable
    readonly property alias appearanceError: theme.appearanceError
    readonly property alias darkMode: theme.darkMode
    readonly property alias surface: theme.surface
    readonly property alias barSurface: theme.barSurface
    readonly property alias surfaceRaised: theme.surfaceRaised
    readonly property alias surfaceHover: theme.surfaceHover
    readonly property alias surfaceSelected: theme.surfaceSelected
    readonly property alias textSelected: theme.textSelected
    readonly property alias outline: theme.outline
    readonly property alias separator: theme.separator
    readonly property alias textPrimary: theme.textPrimary
    readonly property alias textSecondary: theme.textSecondary
    readonly property alias textMuted: theme.textMuted
    readonly property alias accent: theme.accent
    readonly property alias accentWarm: theme.accentWarm
    readonly property alias positive: theme.positive
    readonly property alias accentInk: theme.accentInk
    readonly property alias warning: theme.warning
    readonly property alias critical: theme.critical
    readonly property alias fontSizeSmall: theme.fontSizeSmall
    readonly property alias fontSizeMedium: theme.fontSizeMedium
    readonly property alias fontSizeLarge: theme.fontSizeLarge
    readonly property alias fontFamily: theme.fontFamily
    readonly property alias iconSizeSmall: theme.iconSizeSmall
    readonly property alias separatorHeight: theme.separatorHeight

    // Quick tools are global even though each monitor owns its own menu.
    // Keep-awake intentionally resets with Quickshell to avoid an inhibitor
    // being forgotten across sessions.
    property bool keepAwake: false

    function toggleMicMute() {
        var audio = Pipewire.defaultAudioSource?.audio;
        if (audio) audio.muted = !audio.muted;
    }

    function setTheme(dark) {
        theme.setTheme(dark);
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

    // ── Bar visibility per monitor ──────────────────────────────────
    property var monitorBarState: ({})

    function getBarVisible(monitorName) {
        if (!monitorName) return true;
        return root.monitorBarState[monitorName] ?? true;
    }

    function setBarVisible(monitorName, visible) {
        if (!monitorName) return;
        var s = Object.assign({}, root.monitorBarState);
        s[monitorName] = visible;
        root.monitorBarState = s;
    }

    function toggleBarVisible(monitorName) {
        if (!monitorName) return;
        setBarVisible(monitorName, !getBarVisible(monitorName));
    }

    function dispatch(command) {
        // Quickshell handles both Hyprland IPC transports itself. Passing a
        // JSON-encoded string to the new Lua transport makes it evaluate the
        // quoted text as Lua instead of treating it as a dispatcher request.
        Hyprland.dispatch(command);
    }

    function normalizedDesktopId(value) {
        return (value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function desktopEntryFor(toplevel) {
        var ipc = toplevel?.lastIpcObject ?? toplevel ?? {};
        var candidates = [toplevel?.wayland?.appId, ipc.initialClass, ipc.class];
        for (var i = 0; i < candidates.length; i++) {
            if (!candidates[i]) continue;
            var exact = DesktopEntries.heuristicLookup(candidates[i]);
            if (exact) return exact;
        }

        var wanted = root.normalizedDesktopId(candidates[0] || candidates[1]);
        if (!wanted) return null;
        var entries = DesktopEntries.applications?.values ?? [];
        for (var j = 0; j < entries.length; j++) {
            var entry = entries[j];
            if (root.normalizedDesktopId(entry.id) === wanted
                || root.normalizedDesktopId(entry.startupClass) === wanted)
                return entry;
        }
        return null;
    }

    function desktopIconSource(entry) {
        var icon = entry?.icon ?? "";
        if (!icon) return "";
        return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    OsdOverlay {
        shell: root
        style: root
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            if (Hyprland.focusedMonitor)
                root.toggleBarVisible(Hyprland.focusedMonitor.name);
        }
    }

    // ── Brightness — event-driven via kernel uevent ─────────────────
    property real brightness: -1   // 0.0~1.0, -1 = not initialized
    property int brightnessMax: 0
    property bool brightnessSetting: false

    Process {
        id: brightnessReadProc
        command: ["sh", "-c", "echo \"$(brightnessctl g) $(brightnessctl m)\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(/\s+/);
                if (p.length >= 2) {
                    root.brightnessMax = parseInt(p[1]);
                    if (root.brightnessMax > 0)
                        root.brightness = parseInt(p[0]) / root.brightnessMax;
                }
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
        onTriggered: root.brightnessSetting = false
    }

    BarWindow { shell: root }
}
