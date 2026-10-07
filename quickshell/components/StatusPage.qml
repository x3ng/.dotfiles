pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Scroll only when the available height is too small; cards keep their geometry.
ColumnLayout {
    id: page
    required property var services
    required property var style
    required property var appearance
    required property var sink
    required property var battery
    required property var player
    required property bool panelOpen
    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: page.style.radiusCard
        color: page.style.surfaceRaised
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 16
            Text {
                text: page.battery?.isPresent
                    ? Math.round(page.battery.percentage * 100) + "%" : "—"
                color: page.style.textPrimary
                font.family: page.style.fontFamily
                font.pixelSize: 26
                font.weight: Font.Medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: "Battery"
                    color: page.style.textPrimary
                    font.family: page.style.fontFamily
                    font.pixelSize: 13
                }
                Text {
                    Layout.fillWidth: true
                    text: page.battery?.isPresent ? page.services.batteryDetail(page.battery) : "Battery unavailable"
                    color: page.style.textSecondary
                    font.family: page.style.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    Flickable {
        id: controls
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: content
            width: controls.width
            spacing: 12

            GridLayout {
                Layout.fillWidth: true
                columns: controls.width >= 480 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142
                    radius: page.style.radiusCard
                    color: page.style.surfaceRaised
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Text {
                            text: "Audio"
                            color: page.style.textMuted
                            font.family: page.style.fontFamily
                            font.pixelSize: 11
                        }
                        FilledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            style: page.style
                            label: page.sink?.audio?.muted ? "Muted" : "Volume"
                            value: page.sink?.audio?.volume ?? 0
                            available: !!page.sink?.audio
                            onEdited: value => page.services.setVolume(value)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            ChoiceButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                style: page.style
                                label: "MUTE"
                                selected: page.sink?.audio?.muted ?? false
                                available: !!page.sink?.audio
                                onTriggered: page.sink.audio.muted = !page.sink.audio.muted
                            }
                            ChoiceButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                style: page.style
                                label: "MIC MUTE"
                                selected: Pipewire.defaultAudioSource?.audio?.muted ?? false
                                available: !!Pipewire.defaultAudioSource?.audio
                                onTriggered: page.services.toggleMicMute()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142
                    radius: page.style.radiusCard
                    color: page.style.surfaceRaised
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        Text {
                            text: "Display"
                            color: page.style.textMuted
                            font.family: page.style.fontFamily
                            font.pixelSize: 11
                        }
                        FilledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            style: page.style
                            label: "Brightness"
                            value: Math.max(0, page.services.brightness)
                            available: page.services.brightness >= 0
                            onEdited: value => page.services.setBrightness(value)
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            ChoiceButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                style: page.style
                                label: "DARK"
                                selected: page.appearance.appearanceKnown && page.appearance.darkMode
                                available: page.appearance.appearanceAvailable
                                onTriggered: page.appearance.setTheme(true)
                            }
                            ChoiceButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                style: page.style
                                label: "LIGHT"
                                selected: page.appearance.appearanceKnown && !page.appearance.darkMode
                                available: page.appearance.appearanceAvailable
                                onTriggered: page.appearance.setTheme(false)
                            }
                        }
                    }
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 148
                radius: page.style.radiusCard
                border.width: 0
                style: page.style
                player: page.player
                panelOpen: page.panelOpen
            }
        }
    }
}
