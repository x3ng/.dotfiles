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

ShellRoot {
    id: root

    // Visual system: a quiet, high-contrast floating surface instead of a
    // collection of independent black boxes.
    readonly property int barHeight: 40
    // Keep the transparent tail outside the reserved zone. This offsets
    // Hyprland's global outer gap without letting a visible control overlap
    // the window below.
    readonly property int barReservedHeight: 36
    readonly property int barBackgroundPaddingX: 12
    readonly property int barBackgroundHeight: 34
    readonly property real barBackgroundOpacity: 0.97
    readonly property color surface: "#11131a"
    readonly property color surfaceRaised: "#1b1e29"
    readonly property color surfaceHover: "#272b39"
    // QML uses #AARRGGBB for 8-digit colours. Keep these as translucent
    // white; #ffffff18 would instead render as an opaque yellow.
    readonly property color outline: "#0effffff"
    readonly property color separator: "#10ffffff"
    readonly property color textPrimary: "#e7e9f0"
    readonly property color textSecondary: "#b2b8c8"
    readonly property color textMuted: "#71798d"
    readonly property color accent: "#839fe5"
    readonly property color accentInk: "#121827"
    readonly property color warning: "#b8a1d9"
    readonly property color critical: "#d98ca7"

    // ── Font sizes ─────────────────────────────────────────────────
    readonly property int fontSizeSmall: 13    // workspace numbers
    readonly property int fontSizeMedium: 13   // volume, brightness, battery
    readonly property int fontSizeLarge: 16    // clock
    readonly property int iconSizeSmall: 20    // tray icons
    readonly property int separatorHeight: 18

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

    // ── Bar per monitor ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData

            property bool isVisible: root.getBarVisible(modelData.name)

            surfaceFormat.opaque: false
            // Reserve space while the bar is shown so maximized windows and
            // readers never sit underneath it. `bar toggle` releases the
            // reservation again on the focused monitor.
            exclusiveZone: isVisible ? root.barReservedHeight : 0
            aboveWindows: true
            focusable: true
            anchors { top: true; left: true; right: true }
            implicitHeight: isVisible ? root.barHeight : 0
            color: "transparent"

            // Keep the input region tied to the actual controls, not the full-width overlay.
            mask: Region { item: inputRegion }

            Item {
                id: inputRegion
                anchors.centerIn: parent
                width: bar.isVisible ? contentRow.implicitWidth + root.barBackgroundPaddingX * 2 : 0
                height: bar.isVisible ? root.barBackgroundHeight : 0

                Rectangle {
                    id: bgRect
                    anchors.fill: parent
                    radius: 15
                    color: root.surface
                    opacity: root.barBackgroundOpacity
                    border.width: 1
                    border.color: root.outline
                }

                Row {
                    id: contentRow
                    anchors.centerIn: parent
                    spacing: 8

                // ── Workspaces ────────────────────────────────────
                Item {
                    id: wsContainer
                    property var workspaceList: []
                    // Refresh title/icon bindings for title, focus and
                    // toplevel lifecycle events without polling.
                    property int windowRevision: 0

                    function refreshWorkspaces() {
                        var list = Hyprland.workspaces?.values ?? [];
                        var fid = Hyprland.focusedWorkspace?.id ?? 1;
                        var out = [];
                        var hasFocused = false;
                        for (var i = 0; i < list.length; i++) {
                            if (list[i].id > 0) {
                                out.push(list[i]);
                                if (list[i].id === fid) hasFocused = true;
                            }
                        }
                        if (!hasFocused && Hyprland.focusedWorkspace)
                            out.push(Hyprland.focusedWorkspace);
                        out.sort(function(a, b) { return a.id - b.id; });
                        workspaceList = out;
                    }

                    Component.onCompleted: refreshWorkspaces()

                    Connections {
                        target: Hyprland.workspaces
                        function onValuesChanged() { wsContainer.refreshWorkspaces(); }
                    }
                    Connections {
                        target: Hyprland
                        function onFocusedWorkspaceChanged() { wsContainer.refreshWorkspaces(); }
                        function onRawEvent() {
                            wsContainer.windowRevision += 1;
                        }
                    }
                    Connections {
                        target: Hyprland.toplevels
                        function onValuesChanged() { wsContainer.windowRevision += 1; }
                    }

                    implicitWidth: wsRow.implicitWidth
                    implicitHeight: wsRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: wsRow
                        spacing: 3

                        Repeater {
                            model: wsContainer.workspaceList

                            Rectangle {
                                required property var modelData
                                property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
                                property var workspaceWindows: {
                                    wsContainer.windowRevision;
                                    var windows = Hyprland.toplevels?.values ?? [];
                                    var result = [];
                                    for (var i = 0; i < windows.length; i++) {
                                        if (windows[i].workspace?.id === modelData.id)
                                            result.push(windows[i]);
                                    }
                                    return result;
                                }

                                implicitWidth: workspaceContents.implicitWidth + 14
                                width: Math.max(23, implicitWidth)
                                height: 24
                                radius: 7
                                color: isActive ? root.surfaceRaised : (wsMouse.containsMouse ? root.surfaceHover : "transparent")
                                border.width: 0
                                border.color: root.outline

                                Behavior on color { ColorAnimation { duration: 130 } }

                                Row {
                                    id: workspaceContents
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Item {
                                        width: 16; height: 16

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 5
                                            visible: isActive
                                            color: root.accent
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.id
                                            color: isActive ? root.accentInk : root.textSecondary
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    Repeater {
                                        model: workspaceWindows

                                        Row {
                                            required property var modelData
                                            property var desktopEntry: root.desktopEntryFor(modelData)
                                            spacing: 4

                                            IconImage {
                                                id: workspaceIcon
                                                implicitSize: 16
                                                source: root.desktopIconSource(parent.desktopEntry)
                                                visible: source !== "" && status !== Image.Error
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                // Every open toplevel gets its own compact
                                                // identifier, rather than representing an
                                                // entire workspace with its focused window.
                                                width: Math.min(86, implicitWidth)
                                                text: parent.modelData.title
                                                elide: Text.ElideRight
                                                color: isActive ? root.textPrimary : root.textSecondary
                                                font.pixelSize: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.dispatch("workspace " + modelData.id)
                                }
                            }
                        }

                    } // wsRow
                } // workspace Item

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: root.separatorHeight; color: root.separator; anchors.verticalCenter: parent.verticalCenter }

                // ── Clock ─────────────────────────────────────────
                Item {
                    id: clock
                    implicitWidth: clockRow.implicitWidth
                    implicitHeight: clockRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: clockRow
                        spacing: 7
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: clockTime
                            color: root.textPrimary
                            font.pixelSize: 14
                            font.weight: Font.Medium
                        }
                        Text {
                            id: clockDate
                            color: root.textSecondary
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    function refresh() {
                        var now = new Date();
                        clockTime.text = Qt.formatDateTime(now, "HH:mm");
                        clockDate.text = Qt.formatDateTime(now, "MM/dd · ddd");
                    }
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.refresh() }
                    Component.onCompleted: refresh()
                }

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: root.separatorHeight; color: root.separator; anchors.verticalCenter: parent.verticalCenter }

                // ── System status ──────────────────────────────────
                // A single readable overview keeps every value visible
                // without forcing three tiny rows into a short bar.
                Item {
                    id: statusGroup
                    implicitWidth: statusRow.implicitWidth
                    implicitHeight: statusRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: statusRow
                        spacing: 9
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: volumeStatus
                            property var sink: Pipewire.defaultAudioSink
                            spacing: 4
                            Rectangle { width: 4; height: 4; radius: 2; color: volumeStatus.sink?.audio?.muted ? root.textMuted : root.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "VOL"; color: root.textMuted; font.pixelSize: 9; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: volumeStatus.sink?.audio ? Math.round(volumeStatus.sink.audio.volume * 100) + "%" : "0%"; color: volumeStatus.sink?.audio?.muted ? root.textMuted : root.textPrimary; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            id: brightnessStatus
                            spacing: 4
                            Rectangle { width: 4; height: 4; radius: 2; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "BRI"; color: root.textMuted; font.pixelSize: 9; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: root.brightness >= 0 ? Math.round(root.brightness * 100) + "%" : "…"; color: root.textPrimary; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }

                        Row {
                            id: batteryStatus
                            property var dev: UPower.displayDevice
                            property color statusColor: {
                                if (!dev) return root.textMuted;
                                var pct = (dev.percentage ?? 0) * 100;
                                if (dev.state === UPowerDeviceState.Charging) return "#91b488";
                                if (pct <= 15) return root.critical;
                                if (pct <= 40) return root.warning;
                                return "#91b488";
                            }
                            visible: dev?.isLaptopBattery ?? false
                            spacing: 4
                            Rectangle { width: 4; height: 4; radius: 2; color: batteryStatus.statusColor; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: batteryStatus.dev?.state === UPowerDeviceState.Charging ? "CHG" : "BAT"; color: root.textMuted; font.pixelSize: 9; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: batteryStatus.dev && batteryStatus.dev.percentage > 0 ? Math.round(batteryStatus.dev.percentage * 100) + "%" : "…"; color: batteryStatus.statusColor; font.pixelSize: 11; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: root.separatorHeight; color: root.separator; anchors.verticalCenter: parent.verticalCenter }

                // ── System tray ───────────────────────────────────
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items

                        Item {
                            id: trayItem
                            required property SystemTrayItem modelData
                            width: 28; height: 28

                            function displayMenu() {
                                var pos = trayItem.mapToItem(null, 0, 0);
                                trayItem.modelData.display(
                                    trayItem.QsWindow.window,
                                    pos.x,
                                    pos.y + trayItem.height
                                );
                            }

                            function fallbackLabel() {
                                var key = (
                                    (trayItem.modelData.icon ?? "") + " " +
                                    (trayItem.modelData.id ?? "") + " " +
                                    (trayItem.modelData.title ?? "")
                                ).toLowerCase();

                                if (key.indexOf("keyboard") >= 0 || key.indexOf("fcitx") >= 0)
                                    return "K";
                                if (key.indexOf("bluetooth") >= 0 || key.indexOf("blue") >= 0)
                                    return "B";
                                return "·";
                            }

                            Rectangle {
                                anchors.fill: parent; radius: 4
                                color: trayMouse.containsMouse ? "#444444" : "transparent"
                            }

                            IconImage {
                                id: trayIcon
                                anchors.centerIn: parent
                                implicitSize: root.iconSizeSmall
                                source: trayItem.modelData.icon
                                visible: status !== Image.Error && source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: trayItem.fallbackLabel()
                                visible: !trayIcon.visible
                                color: "#9a9a9a"
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(event) {
                                    if (event.button === Qt.LeftButton) {
                                        if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                            trayItem.displayMenu();
                                        else
                                            trayItem.modelData.activate();
                                    } else if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                                        trayItem.displayMenu();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
}
