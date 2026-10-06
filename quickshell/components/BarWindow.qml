pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

Scope {
    id: barScope
    required property var shell

    // ── Bar per monitor ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData

            property bool isVisible: barScope.shell.getBarVisible(modelData.name)
            // Progress drives the slide and layer size. Send the final reserved
            // area once so Hyprland can animate window reflow independently.
            // Unmap at the end; never request a zero-sized mapped layer.
            property bool surfaceVisible: true
            property real visibilityProgress: 1
            property bool trayExpanded: false
            readonly property var trayItems: SystemTray.items?.values ?? []
            readonly property bool hasTrayItems: trayItems.length > 0
            readonly property bool trayNeedsAttention: {
                for (var i = 0; i < trayItems.length; i++) {
                    if (trayItems[i].status === Status.NeedsAttention)
                        return true;
                }
                return false;
            }

            onHasTrayItemsChanged: {
                if (!hasTrayItems) {
                    trayExpanded = false;
                    trayMenuPopup.dismiss();
                }
            }

            onTrayItemsChanged: {
                if (!trayMenuPopup.owner) return;
                var ownerStillPresent = false;
                for (var i = 0; i < trayItems.length; i++) {
                    if (trayItems[i] === trayMenuPopup.owner) {
                        ownerStillPresent = true;
                        break;
                    }
                }
                if (!ownerStillPresent) trayMenuPopup.dismiss();
            }

            function openTrayMenu(owner, anchorRight) {
                var opened = trayMenuPopup.openFor(owner, anchorRight);
                if (opened) {
                    calendarPopup.dismiss();
                    quickToolsPopup.dismiss();
                    statusPopup.dismiss();
                }
                return opened;
            }

            function closeTrayMenu() {
                trayMenuPopup.dismiss();
            }

            onIsVisibleChanged: {
                visibilityAnimation.stop();
                if (isVisible) {
                    surfaceVisible = true;
                    visibilityAnimation.to = 1;
                } else {
                    trayExpanded = false;
                    closeTrayMenu();
                    calendarPopup.dismiss();
                    quickToolsPopup.dismiss();
                    statusPopup.dismiss();
                    visibilityAnimation.to = 0;
                }
                visibilityAnimation.start();
            }

            Component.onCompleted: {
                surfaceVisible = isVisible;
                visibilityProgress = isVisible ? 1 : 0;
            }

            NumberAnimation {
                id: visibilityAnimation
                target: bar
                property: "visibilityProgress"
                // Match hypr/compositor.lua: windows, 4.79, easeOutQuint.
                duration: 479
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
                onFinished: {
                    if (!bar.isVisible && bar.visibilityProgress <= 0)
                        bar.surfaceVisible = false;
                }
            }

            IdleInhibitor {
                window: bar
                enabled: barScope.shell.keepAwake
            }

            surfaceFormat.opaque: false
            // Updating this every frame repeatedly retargets Hyprland's
            // window animation and makes windows trail behind the bar.
            exclusiveZone: isVisible ? barScope.shell.barReservedHeight : 0
            visible: surfaceVisible
            WlrLayershell.namespace: "quickshell:bar"
            aboveWindows: true
            focusable: true
            anchors { top: true; left: true; right: true }
            implicitHeight: Math.max(1, Math.round(barScope.shell.barHeight * visibilityProgress))
            contentItem.clip: true
            color: "transparent"

            // Match pointer input to the floating surface, leaving the outer
            // screen margins transparent and click-through.
            mask: Region { item: bar.isVisible ? inputRegion : null }

            Item {
                id: inputRegion
                anchors.horizontalCenter: parent.horizontalCenter
                // Keep the original content height: slide it through the
                // shrinking viewport instead of squeezing or fading it.
                y: (barScope.shell.barHeight - height) / 2
                    - barScope.shell.barHeight * (1 - bar.visibilityProgress)
                width: Math.max(0, bar.width - barScope.shell.barOuterMarginX * 2)
                height: barScope.shell.barBackgroundHeight

                // Three macro surfaces keep the wallpaper visible in the
                // empty space while preserving a clear left/center/right
                // grouping for the bar contents.
                ContentSurface {
                    id: leftContentSurface
                    style: barScope.shell
                    // Match the bar's outer edge; the clock keeps its own
                    // internal padding from this surface.
                    x: clock.x - barScope.shell.barBackgroundPaddingX
                    width: clock.width + barScope.shell.barBackgroundPaddingX * 2
                    height: barScope.shell.barBackgroundHeight
                    anchors.verticalCenter: parent.verticalCenter
                }

                ContentSurface {
                    id: centerContentSurface
                    style: barScope.shell
                    x: wsContainer.x - 6
                    width: wsContainer.width + 12
                    height: barScope.shell.barBackgroundHeight
                    anchors.verticalCenter: parent.verticalCenter
                }

                ContentSurface {
                    id: rightContentSurface
                    style: barScope.shell
                    x: (trayToggle.visible ? trayToggle.x : statusGroup.x) - 6
                    // Extend through the quick-tools side padding so the
                    // outer margin matches the left side.
                    width: quickToolsButton.x + quickToolsButton.width - x
                        + barScope.shell.barBackgroundPaddingX
                    height: barScope.shell.barBackgroundHeight
                    anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: bar.trayExpanded
                    acceptedButtons: Qt.LeftButton
                    onClicked: bar.trayExpanded = false
                }

                // Keep workspace contents in their own component; the bar
                // supplies only the available geometry and menu dismissal.
                WorkspaceStrip {
                    id: wsContainer
                    shell: barScope.shell
                    regionWidth: inputRegion.width
                    leftEdge: clock.x + clock.width
                    rightEdge: trayToggle.visible ? trayToggle.x : statusGroup.x
                    onRequestDismissMenus: {
                        bar.trayExpanded = false;
                        bar.closeTrayMenu();
                        calendarPopup.dismiss();
                        quickToolsPopup.dismiss();
                        statusPopup.dismiss();
                    }
                }

                // ── Left: date and time ─────────────────────────────
                Item {
                    id: clock
                    implicitWidth: clockRow.implicitWidth + 14
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: barScope.shell.barBackgroundPaddingX
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: barScope.shell
                        hovered: clockMouse.containsMouse
                        radius: barScope.shell.radiusSmall
                    }

                    Row {
                        id: clockRow
                        spacing: 7
                        anchors.centerIn: parent

                        Text {
                            id: clockDate
                            color: barScope.shell.textPrimary
                            font.family: barScope.shell.fontFamily
                            font.pixelSize: barScope.shell.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: clockTime
                            color: barScope.shell.textPrimary
                            font.family: barScope.shell.fontFamily
                            font.pixelSize: barScope.shell.fontSizeMedium
                            font.weight: Font.Medium
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

                    MouseArea {
                        id: clockMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = calendarPopup.open
                        onClicked: {
                            if (wasOpenOnPress) {
                                calendarPopup.dismiss();
                            } else {
                                bar.trayExpanded = false;
                                bar.closeTrayMenu();
                                quickToolsPopup.dismiss();
                                statusPopup.dismiss();
                                calendarPopup.showCalendar();
                            }
                        }
                    }
                }

                CalendarPopup {
                    id: calendarPopup
                    style: barScope.shell
                    barWindow: bar
                    anchorX: inputRegion.x + clock.x
                }

                // ── Right: fixed system status ──────────────────────
                // A single readable overview keeps every value visible
                // without forcing three tiny rows into a short bar.
                Item {
                    id: statusGroup
                    property var sink: Pipewire.defaultAudioSink
                    property var battery: UPower.displayDevice
                    property bool hasBattery: battery?.isLaptopBattery ?? false
                    property color batteryColor: {
                        if (!battery) return barScope.shell.textMuted;
                        var pct = (battery.percentage ?? 0) * 100;
                        if (battery.state === UPowerDeviceState.Charging) return barScope.shell.positive;
                        if (pct <= 15) return barScope.shell.critical;
                        if (pct <= 40) return barScope.shell.warning;
                        return barScope.shell.positive;
                    }

                    function open(section, wasOpen) {
                        bar.trayExpanded = false;
                        bar.closeTrayMenu();
                        calendarPopup.dismiss();
                        quickToolsPopup.dismiss();
                        statusPopup.showSection(section, wasOpen);
                    }

                    implicitWidth: statusRow.implicitWidth + 12
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight
                    anchors.right: quickToolsButton.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: barScope.shell
                        // The meters are one control: the outer MouseArea
                        // owns hover and click handling for the whole group.
                        hovered: statusMouse.containsMouse
                        radius: barScope.shell.radiusSmall
                    }

                    MouseArea {
                        id: statusMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = statusPopup.open
                        onClicked: statusGroup.open(statusPopup.focus, wasOpenOnPress)
                    }

                    Row {
                        id: statusRow
                        spacing: 2
                        anchors.centerIn: parent

                        StatusMeter {
                            id: volumeMeter
                            style: barScope.shell
                            level: statusGroup.sink?.audio?.volume ?? 0
                            fillColor: barScope.shell.accent
                            dimmed: statusGroup.sink?.audio?.muted ?? true
                            overflow: (statusGroup.sink?.audio?.volume ?? 0) > 1
                        }

                        StatusMeter {
                            id: brightnessMeter
                            style: barScope.shell
                            level: Math.max(0, barScope.shell.brightness)
                            fillColor: barScope.shell.accentWarm
                            dimmed: barScope.shell.brightness < 0
                        }

                        StatusMeter {
                            id: batteryMeter
                            style: barScope.shell
                            visible: statusGroup.hasBattery
                            level: statusGroup.battery?.percentage ?? 0
                            fillColor: statusGroup.batteryColor
                        }
                    }
                }

                SystemStatusPopup {
                    id: statusPopup
                    style: barScope.shell
                    shell: barScope.shell
                    barWindow: bar
                    anchorRight: inputRegion.x + statusGroup.x + statusGroup.width
                    sink: statusGroup.sink
                    battery: statusGroup.battery
                    hasBattery: statusGroup.hasBattery
                    batteryColor: statusGroup.batteryColor
                }

                // ── Far right: quick tools ──────────────────────────
                Item {
                    id: quickToolsButton
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: barScope.shell.barBackgroundPaddingX
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: barScope.shell
                        hovered: quickToolsMouse.containsMouse
                        radius: barScope.shell.radiusSmall
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: "…"
                        color: barScope.shell.keepAwake || quickToolsPopup.open
                            ? barScope.shell.accent
                            : barScope.shell.textSecondary
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: barScope.shell.keepAwake
                        width: 5
                        height: 5
                        radius: 3
                        color: barScope.shell.accent
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }

                    MouseArea {
                        id: quickToolsMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = quickToolsPopup.open
                        onClicked: {
                            bar.trayExpanded = false;
                            bar.closeTrayMenu();
                            calendarPopup.dismiss();
                            statusPopup.dismiss();
                            quickToolsPopup.open = !wasOpenOnPress;
                        }
                    }
                }

                QuickToolsPopup {
                    id: quickToolsPopup
                    style: barScope.shell
                    shell: barScope.shell
                    barWindow: bar
                }

                Item {
                    id: trayToggle
                    visible: bar.hasTrayItems
                    width: visible ? 22 : 0
                    height: 22
                    anchors.right: statusGroup.left
                    anchors.rightMargin: visible ? 9 : 0
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: barScope.shell
                        hovered: trayToggleMouse.containsMouse
                        radius: barScope.shell.radiusSmall
                    }

                    Text {
                        anchors.centerIn: parent
                        // Point towards the action: expand left, then fold the
                        // drawer back towards the fixed status block.
                        text: bar.trayExpanded ? "⌃" : "⌄"
                        color: bar.trayNeedsAttention
                            ? barScope.shell.warning
                            : (bar.trayExpanded ? barScope.shell.accent : barScope.shell.textSecondary)
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        visible: bar.trayNeedsAttention && !bar.trayExpanded
                        width: 5
                        height: 5
                        radius: 3
                        color: barScope.shell.warning
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }

                    MouseArea {
                        id: trayToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            bar.closeTrayMenu();
                            calendarPopup.dismiss();
                            quickToolsPopup.dismiss();
                            statusPopup.dismiss();
                            bar.trayExpanded = !bar.trayExpanded;
                        }
                    }
                }

                TrayDrawer {
                    id: trayDrawer
                    style: barScope.shell
                    barWindow: bar
                    expanded: bar.trayExpanded
                    hasTrayItems: bar.hasTrayItems
                    inputX: inputRegion.x
                    triggerX: trayToggle.x
                    triggerWidth: trayToggle.width
                    openMenu: (owner, right) => bar.openTrayMenu(owner, right)
                    onRequestCollapse: {
                        bar.trayExpanded = false;
                        bar.closeTrayMenu();
                    }
                }

                TrayMenuPopup {
                    id: trayMenuPopup
                    style: barScope.shell
                    barWindow: bar
                    trayPanelOffset: trayDrawer.height + 2
                }
            }
        }
    }
}
