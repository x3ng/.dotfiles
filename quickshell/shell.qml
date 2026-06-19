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

    readonly property int barHeight: 30
    readonly property int barBackgroundPaddingX: 10
    readonly property int barBackgroundHeight: 26
    readonly property real barBackgroundOpacity: 0.58

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
        Hyprland.dispatch(Hyprland.usingLua ? JSON.stringify(command) : command);
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
            exclusiveZone: isVisible ? root.barHeight : 0
            anchors { top: true; left: true; right: true }
            implicitHeight: isVisible ? root.barHeight : 0
            color: "transparent"

            Rectangle {
                anchors.centerIn: contentRow
                width: contentRow.implicitWidth + root.barBackgroundPaddingX * 2
                height: root.barBackgroundHeight
                radius: 6
                color: "black"
                opacity: root.barBackgroundOpacity
                visible: bar.isVisible
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 10
                visible: bar.isVisible

                // ── Workspaces ────────────────────────────────────
                Item {
                    id: wsContainer
                    property var workspaceList: []

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
                    }

                    implicitWidth: wsRow.implicitWidth
                    implicitHeight: wsRow.implicitHeight
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: wsRow
                        spacing: 4

                        Repeater {
                            model: wsContainer.workspaceList

                            Rectangle {
                                required property var modelData
                                property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id

                                width: 24; height: 20; radius: 4
                                color: isActive ? "#ffffff" : "#333333"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.id
                                    color: isActive ? "#000000" : "#cccccc"
                                    font.pixelSize: 11; font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.dispatch("workspace " + modelData.id)
                                }
                            }
                        }

                        // Special workspace
                        Rectangle {
                            property bool isSpecial: (Hyprland.focusedWorkspace?.id ?? 0) < 0
                            width: 24; height: 20; radius: 4
                            color: isSpecial ? "#ff5555" : "#333333"
                            visible: isSpecial

                            Text {
                                anchors.centerIn: parent
                                text: "S"
                                color: "#000000"
                                font.pixelSize: 11; font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.dispatch("togglespecialworkspace magic")
                            }
                        }
                    } // wsRow
                } // workspace Item

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: 16; color: "#333333"; anchors.verticalCenter: parent.verticalCenter }

                // ── Clock ─────────────────────────────────────────
                Text {
                    id: clock
                    color: "#cccccc"; font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm  MM-dd ddd") }
                    Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "HH:mm  MM-dd ddd")
                }

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: 16; color: "#333333"; anchors.verticalCenter: parent.verticalCenter }

                // ── Volume ────────────────────────────────────────
                Text {
                    property var sink: Pipewire.defaultAudioSink
                    text: {
                        if (!sink?.audio) return "🔇 0%";
                        if (sink.audio.muted) return "🔇 0%";
                        var v = Math.round(sink.audio.volume * 100);
                        return (v < 50 ? "🔉 " : "🔊 ") + v + "%";
                    }
                    color: "#cccccc"; font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Brightness ────────────────────────────────────
                Text {
                    text: root.brightness >= 0 ? "☀ " + Math.round(root.brightness * 100) + "%" : "☀ ..."
                    color: "#cccccc"; font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Battery ───────────────────────────────────────
                Text {
                    property var dev: UPower.displayDevice
                    visible: dev?.isLaptopBattery ?? false
                    text: {
                        if (!dev) return "🔋 ...";
                        var pct = (dev.percentage ?? 0) * 100;
                        if (pct <= 0) return "🔋 ...";
                        var icon = dev.state === UPowerDeviceState.Charging ? "⚡" : "🔋";
                        return icon + " " + Math.round(pct) + "%";
                    }
                    color: {
                        if (!dev) return "#cccccc";
                        var pct = (dev.percentage ?? 0) * 100;
                        if (pct <= 15 && dev.state !== UPowerDeviceState.Charging) return "#ff5555";
                        if (pct <= 40) return "#ffaa55";
                        return "#cccccc";
                    }
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }

                // ── Separator ─────────────────────────────────────
                Rectangle { width: 1; height: 16; color: "#333333"; anchors.verticalCenter: parent.verticalCenter }

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
                            width: 22; height: 22

                            Rectangle {
                                anchors.fill: parent; radius: 4
                                color: trayMouse.containsMouse ? "#444444" : "transparent"
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 18
                                source: trayItem.modelData.icon
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(event) {
                                    if (event.button === Qt.LeftButton) {
                                        trayItem.modelData.activate();
                                    } else if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                                        // Use native platform menu with correct coordinates
                                        var pos = trayItem.mapToItem(null, 0, 0);
                                        trayItem.modelData.display(
                                            trayItem.QsWindow.window,
                                            pos.x,
                                            pos.y + trayItem.height
                                        );
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
