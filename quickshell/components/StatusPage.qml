pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    required property var services
    readonly property var system: services.controls
    required property var style
    required property var searchModel
    required property var appearance
    required property var sink
    required property var player
    required property bool panelOpen
    signal detailsRequested(string section)
    readonly property real naturalHeight: content.implicitHeight + workspaces.implicitHeight + spacing
    spacing: 16

    Flickable {
        id: viewport
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
            width: viewport.width
            spacing: 14
            Text {
                text: "CONNECTIVITY"
                color: page.style.textMuted
                font.family: page.style.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1.2
            }
            DesktopControls {
                Layout.fillWidth: true
                style: page.style
                services: page.services
                onDetailsRequested: section => page.detailsRequested(section)
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "SOUND & DISPLAY"
                    color: page.style.textMuted
                    font.family: page.style.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                }
                ChoiceButton {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 28
                    style: page.style
                    label: "Audio devices  ›"
                    available: page.services.audioOutputs.length > 0 || page.services.audioInputs.length > 0
                    onTriggered: page.detailsRequested("audio")
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: viewport.width >= 480 ? 2 : 1
                columnSpacing: 12
                rowSpacing: 12
                FilledSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    style: page.style
                    label: "Volume"
                    value: page.sink?.audio?.volume ?? 0
                    available: !!page.sink?.audio
                    onEdited: value => page.services.setVolume(value)
                }
                FilledSlider {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    style: page.style
                    label: "Brightness"
                    value: Math.max(0, page.services.brightness)
                    available: page.services.brightness >= 0
                    onEdited: value => page.services.setBrightness(value)
                }
            }
            GridLayout {
                Layout.fillWidth: true
                columns: viewport.width >= 480 ? 4 : 2
                columnSpacing: 8
                rowSpacing: 8
                ChoiceButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    style: page.style
                    filled: true
                    label: "Mute output"
                    selected: page.sink?.audio?.muted ?? false
                    available: !!page.sink?.audio
                    onTriggered: page.services.toggleOutputMute()
                }
                ChoiceButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    style: page.style
                    filled: true
                    label: "Mute mic"
                    selected: page.services.source?.audio?.muted ?? false
                    available: !!page.services.source?.audio
                    onTriggered: page.services.toggleMicMute()
                }
                ChoiceButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    style: page.style
                    filled: true
                    label: "Keep awake"
                    selected: page.services.keepAwake
                    onTriggered: page.services.toggleKeepAwake()
                }
                ChoiceButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    style: page.style
                    filled: true
                    label: page.appearance.darkMode ? "Dark mode" : "Light mode"
                    available: page.appearance.appearanceAvailable && page.appearance.appearanceKnown
                    onTriggered: page.appearance.setTheme(!page.appearance.darkMode)
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 60
                radius: page.style.radiusCard
                color: page.style.surfaceRaised
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    StatusIcon {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        kind: "power"
                        ink: page.style.textSecondary
                    }
                    Text {
                        text: "Power"
                        color: page.style.textSecondary
                        font.family: page.style.fontFamily
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: page.system.powerProfiles
                        ChoiceButton {
                            required property string modelData
                            Layout.preferredWidth: viewport.width >= 480 ? 100 : 72
                            Layout.preferredHeight: 34
                            style: page.style
                            label: modelData === "power-saver" ? "Saver" : modelData === "performance" ? "Performance" : "Balanced"
                            selected: page.system.powerProfile === modelData
                            available: page.system.powerAvailable && !page.system.busy
                            onTriggered: page.system.setPowerProfile(modelData)
                        }
                    }
                    Text {
                        visible: !page.system.powerAvailable
                        text: "Unavailable"
                        color: page.style.textMuted
                        font.pixelSize: 12
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: page.system.busy || page.system.error !== ""
                text: page.system.busy ? "Applying…" : page.system.error
                wrapMode: Text.Wrap
                color: page.style.accentWarm
                font.family: page.style.fontFamily
                font.pixelSize: 11
            }
            MediaCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 128
                visible: !!page.player
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
