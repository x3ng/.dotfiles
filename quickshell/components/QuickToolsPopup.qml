pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PopupWindow {
    id: popup

    required property var style
    required property var shell
    required property var barWindow
    property bool open: false
    readonly property var player: {
        const players = Mpris.players?.values ?? [];
        for (const item of players) {
            if (item.isPlaying) return item;
        }
        return players.length > 0 ? players[0] : null;
    }

    function dismiss() {
        open = false;
    }

    parentWindow: barWindow
    visible: open && barWindow.isVisible
    implicitWidth: 316
    implicitHeight: player ? 430 : 272
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
            anchors.topMargin: 14
            anchors.leftMargin: 14
            text: "QUICK SETTINGS"
            color: popup.style.textMuted
            font.family: popup.style.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Row {
            id: toggles
            anchors.top: title.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            QuickToolTile {
                style: popup.style
                label: "KEEP AWAKE"
                detail: popup.shell.keepAwake ? "ON" : "OFF"
                active: popup.shell.keepAwake
                onTriggered: popup.shell.keepAwake = !popup.shell.keepAwake
            }

            QuickToolTile {
                property var source: Pipewire.defaultAudioSource
                style: popup.style
                label: "MICROPHONE"
                detail: !source?.audio ? "UNAVAILABLE"
                    : (source.audio.muted ? "MUTED" : "LIVE")
                active: source?.audio?.muted ?? false
                available: source?.audio ?? false
                onTriggered: popup.shell.toggleMicMute()
            }
        }

        Text {
            id: appearanceLabel
            anchors.top: toggles.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 14
            text: "APPEARANCE · " + (!popup.shell.appearanceAvailable ? "OFFLINE"
                : popup.shell.appearanceError ? "ERROR"
                : !popup.shell.appearanceKnown ? "UNSET"
                : (popup.shell.darkMode ? "DARK" : "LIGHT"))
            color: popup.style.textMuted
            font.family: popup.style.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Row {
            id: appearanceChoices
            anchors.top: appearanceLabel.bottom
            anchors.topMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            ChoiceButton {
                width: 135
                style: popup.style
                label: "DARK"
                selected: popup.shell.appearanceKnown && popup.shell.darkMode
                available: popup.shell.appearanceAvailable
                onTriggered: popup.shell.setTheme(true)
            }

            ChoiceButton {
                width: 135
                style: popup.style
                label: "LIGHT"
                selected: popup.shell.appearanceKnown && !popup.shell.darkMode
                available: popup.shell.appearanceAvailable
                onTriggered: popup.shell.setTheme(false)
            }
        }

        Text {
            id: powerLabel
            anchors.top: appearanceChoices.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 14
            text: "POWER PROFILE"
            color: popup.style.textMuted
            font.family: popup.style.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        Row {
            id: powerChoices
            anchors.top: powerLabel.bottom
            anchors.topMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            ChoiceButton {
                width: 88
                style: popup.style
                label: "SAVER"
                selected: PowerProfiles.profile === PowerProfile.PowerSaver
                onTriggered: PowerProfiles.profile = PowerProfile.PowerSaver
            }

            ChoiceButton {
                width: 88
                style: popup.style
                label: "BALANCED"
                selected: PowerProfiles.profile === PowerProfile.Balanced
                onTriggered: PowerProfiles.profile = PowerProfile.Balanced
            }

            ChoiceButton {
                width: 88
                style: popup.style
                label: "FAST"
                available: PowerProfiles.hasPerformanceProfile
                selected: PowerProfiles.profile === PowerProfile.Performance
                onTriggered: PowerProfiles.profile = PowerProfile.Performance
            }
        }

        MediaCard {
            visible: popup.player !== null
            anchors.top: powerChoices.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            style: popup.style
            player: popup.player
            panelOpen: popup.open
        }

    }
}
