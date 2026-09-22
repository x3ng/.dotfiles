pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PopupWindow {
    id: popup

    required property var style
    required property var shell
    required property var barWindow
    property bool open: false

    function dismiss() {
        open = false;
    }

    parentWindow: barWindow
    visible: open && barWindow.isVisible
    implicitWidth: 284
    implicitHeight: 174
    relativeX: Math.round(barWindow.width
        - style.barOuterMarginX
        - style.barBackgroundPaddingX
        - width)
    relativeY: style.barHeight + 6
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (!visible && open) open = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: popup.style.radiusPopup
        color: popup.style.surface
        border.width: 1
        border.color: popup.style.outline

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 12
            text: "QUICK TOOLS"
            color: popup.style.textMuted
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        Grid {
            anchors.top: title.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 2
            spacing: 8

            QuickToolTile {
                style: popup.style
                label: "AWAKE"
                detail: popup.shell.keepAwake ? "ON" : "OFF"
                active: popup.shell.keepAwake
                onTriggered: popup.shell.keepAwake = !popup.shell.keepAwake
            }

            QuickToolTile {
                style: popup.style
                label: "THEME"
                detail: popup.shell.modeLabel
                active: !popup.shell.darkMode
                onTriggered: popup.shell.toggleTheme()
            }

            QuickToolTile {
                property var source: Pipewire.defaultAudioSource
                style: popup.style
                label: "MIC"
                detail: !source?.audio ? "UNAVAILABLE"
                    : (source.audio.muted ? "MUTED" : "LIVE")
                active: source?.audio?.muted ?? false
                available: source?.audio ?? false
                onTriggered: popup.shell.toggleMicMute()
            }

            QuickToolTile {
                style: popup.style
                label: "POWER"
                detail: popup.shell.powerProfileLabel()
                active: PowerProfiles.profile !== PowerProfile.Balanced
                onTriggered: popup.shell.cyclePowerProfile()
            }
        }
    }
}
