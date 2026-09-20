pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
    id: popup

    required property var style
    required property var shell
    required property var barWindow
    required property real anchorRight
    required property var sink
    required property var battery
    required property bool hasBattery
    required property color batteryColor
    property bool open: false
    property string focus: "volume"

    function showSection(section, wasOpen) {
        focus = section;
        open = !wasOpen;
    }

    function dismiss() {
        open = false;
    }

    parentWindow: barWindow
    visible: open && barWindow.isVisible
    implicitWidth: 300
    implicitHeight: hasBattery ? 214 : 158
    relativeX: Math.round(anchorRight - width)
    relativeY: style.barHeight + 6
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (!visible && open) open = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: popup.style.surface
        border.width: 1
        border.color: popup.style.outline

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            anchors.leftMargin: 12
            text: "SYSTEM STATUS"
            color: popup.style.textMuted
            font.pixelSize: 9
            font.weight: Font.DemiBold
        }

        Item {
            id: volumeControl
            anchors.top: title.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 52

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: popup.focus === "volume"
                    ? popup.style.surfaceRaised
                    : "transparent"
            }

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.topMargin: 4
                text: "VOL"
                color: popup.focus === "volume"
                    ? popup.style.textPrimary
                    : popup.style.textSecondary
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                anchors.top: parent.top
                anchors.right: volumeMute.left
                anchors.rightMargin: 8
                anchors.topMargin: 4
                text: popup.sink?.audio
                    ? Math.round(popup.sink.audio.volume * 100) + "%"
                    : "—"
                color: popup.style.textPrimary
                font.pixelSize: 10
            }

            Rectangle {
                id: volumeMute
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 6
                width: 48
                height: 18
                radius: 6
                color: popup.sink?.audio?.muted
                    ? popup.style.surfaceHover
                    : "transparent"
                border.width: popup.sink?.audio?.muted ? 1 : 0
                border.color: popup.style.warning

                Text {
                    anchors.centerIn: parent
                    text: popup.sink?.audio?.muted ? "MUTED" : "MUTE"
                    color: popup.sink?.audio?.muted
                        ? popup.style.warning
                        : popup.style.textMuted
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: popup.sink?.audio ?? false
                    onClicked: popup.sink.audio.muted = !popup.sink.audio.muted
                }
            }

            ValueSlider {
                style: popup.style
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                value: popup.sink?.audio?.volume ?? 0
                available: popup.sink?.audio ?? false
                onEdited: function(newValue) { popup.shell.setVolume(newValue); }
            }
        }

        Item {
            id: brightnessControl
            anchors.top: volumeControl.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 52

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: popup.focus === "brightness"
                    ? popup.style.surfaceRaised
                    : "transparent"
            }

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.topMargin: 4
                text: "BRI"
                color: popup.focus === "brightness"
                    ? popup.style.textPrimary
                    : popup.style.textSecondary
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.topMargin: 4
                text: popup.shell.brightness >= 0
                    ? Math.round(popup.shell.brightness * 100) + "%"
                    : "—"
                color: popup.style.textPrimary
                font.pixelSize: 10
            }

            ValueSlider {
                style: popup.style
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                value: Math.max(0, popup.shell.brightness)
                fillColor: popup.style.accentWarm
                available: popup.shell.brightness >= 0
                onEdited: function(newValue) { popup.shell.setBrightness(newValue); }
            }
        }

        Item {
            visible: popup.hasBattery
            anchors.top: brightnessControl.bottom
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 44

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: popup.focus === "battery"
                    ? popup.style.surfaceRaised
                    : "transparent"
            }

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.topMargin: 5
                text: "BAT"
                color: popup.focus === "battery"
                    ? popup.style.textPrimary
                    : popup.style.textSecondary
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.topMargin: 5
                text: popup.battery
                    ? Math.round(popup.battery.percentage * 100) + "%"
                    : "—"
                color: popup.batteryColor
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                text: popup.shell.batteryDetail(popup.battery)
                elide: Text.ElideRight
                color: popup.style.textMuted
                font.pixelSize: 8
            }
        }
    }
}
