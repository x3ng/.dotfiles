pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Scroll only when the available height is too small; cards keep their geometry.
ColumnLayout {
    id: page
    required property var services
    required property var style
    required property var searchModel
    required property var appearance
    required property var sink
    required property var player
    required property bool panelOpen
    readonly property real naturalHeight: content.implicitHeight + workspaces.implicitHeight + spacing
    spacing: 12

    Flickable {
        id: controls
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        implicitHeight: content.implicitHeight
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
                FilledSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    style: page.style
                    label: "Volume"
                    value: page.sink?.audio?.volume ?? 0
                    available: !!page.sink?.audio
                    onEdited: value => page.services.setVolume(value)
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
            }

            GridLayout {
                Layout.fillWidth: true
                columns: controls.width >= 480 ? 2 : 1
                columnSpacing: 20
                rowSpacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            style: page.style
                            label: "Mute output"
                            selected: page.sink?.audio?.muted ?? false
                            available: !!page.sink?.audio
                            onTriggered: page.sink.audio.muted = !page.sink.audio.muted
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            style: page.style
                            label: "Mute mic"
                            selected: Pipewire.defaultAudioSource?.audio?.muted ?? false
                            available: !!Pipewire.defaultAudioSource?.audio
                            onTriggered: page.services.toggleMicMute()
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            style: page.style
                            label: "Dark"
                            selected: page.appearance.appearanceKnown && page.appearance.darkMode
                            available: page.appearance.appearanceAvailable
                            onTriggered: page.appearance.setTheme(true)
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            style: page.style
                            label: "Light"
                            selected: page.appearance.appearanceKnown && !page.appearance.darkMode
                            available: page.appearance.appearanceAvailable
                            onTriggered: page.appearance.setTheme(false)
                        }
                    }
                }
            }

            MediaCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 128
                radius: page.style.radiusCard
                border.width: 0
                style: page.style
                player: page.player
                panelOpen: page.panelOpen
            }
        }
    }

    WorkspaceSummary {
        id: workspaces
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        style: page.style
        searchModel: page.searchModel
    }
}
