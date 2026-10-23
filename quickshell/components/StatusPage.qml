pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

ColumnLayout {
    id: page
    required property var actions
    required property var services
    readonly property var system: services.controls
    required property Theme style
    required property var appearance
    required property var notifs
    required property var sink
    required property var player
    required property bool panelOpen
    signal dismissRequested()
    readonly property real naturalHeight: content.implicitHeight
    onPanelOpenChanged: { if (panelOpen) viewport.contentY = 0; }
    spacing: page.style.spaceLg

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        implicitHeight: content.implicitHeight
        radius: page.style.radiusCard
        color: "transparent"
        Flickable {
            id: viewport
            anchors.fill: parent
            implicitHeight: content.implicitHeight
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: content
                width: viewport.width
                spacing: page.style.spaceMd

                StatusNotices {
                    actions: page.actions
                    Layout.fillWidth: true
                    style: page.style
                    services: page.services
                }

                DesktopControls {
                    actions: page.actions
                    Layout.fillWidth: true
                    style: page.style
                    services: page.services
                }

                GroupCard {
                    Layout.fillWidth: true
                    style: page.style
                    title: "Sound & display"
                    iconKind: "volume"
                    contentSpacing: page.style.spaceSm
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        ChoiceButton {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            style: page.style
                            label: ""
                            iconKind: "volume"
                            tooltip: page.sink?.audio?.muted ? "Unmute output" : "Mute output"
                            selected: page.sink?.audio?.muted ?? false
                            available: page.actions.available("output-mute")
                            onTriggered: page.actions.execute("output-mute")
                        }
                        FilledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            label: page.sink?.audio?.muted ? "Muted" : "Volume"
                            value: page.sink?.audio?.volume ?? 0
                            available: !!page.sink?.audio
                            onEdited: value => page.services.setVolume(value)
                        }
                        ChoiceButton {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            style: page.style
                            label: ""
                            iconKind: "mic"
                            tooltip: page.services.source?.audio?.muted ? "Unmute microphone" : "Mute microphone"
                            selected: page.services.source?.audio?.muted ?? false
                            available: page.actions.available("mic-mute")
                            onTriggered: page.actions.execute("mic-mute")
                        }
                        ChoiceButton {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            style: page.style
                            label: ""
                            iconKind: "headphones"
                            tooltip: "Choose audio devices"
                            onTriggered: page.actions.execute("audio")
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        Item {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            StatusIcon {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                kind: "brightness"
                                ink: page.style.textMuted
                            }
                        }
                        FilledSlider {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            label: "Brightness"
                            value: Math.max(0, page.services.brightness)
                            available: page.services.brightness >= 0
                            onEdited: value => page.services.setBrightness(value)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.style.spaceMd
                    ChoiceButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 42
                        style: page.style
                        filled: true
                        label: "Dark mode"
                        iconKind: "moon"
                        selected: page.appearance.appearanceKnown && page.appearance.darkMode
                        available: page.actions.available("dark") && page.actions.available("light")
                        onTriggered: page.actions.execute(page.appearance.darkMode ? "light" : "dark")
                    }
                    ChoiceButton {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 42
                        style: page.style
                        filled: true
                        label: "Keep awake"
                        iconKind: "eye"
                        tooltip: "Prevent automatic lock and screen sleep"
                        selected: page.services.keepAwake
                        available: page.actions.available("keep-awake")
                        onTriggered: page.actions.execute("keep-awake")
                    }
                }

                GroupCard {
                    Layout.fillWidth: true
                    visible: page.system.powerProfiles.length > 0
                    style: page.style
                    title: "Power profile"
                    iconKind: "gauge"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceXs
                        Repeater {
                            model: page.system.powerProfiles
                            ChoiceButton {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 36
                                style: page.style
                                filled: true
                                filledColor: page.style.surfaceHover
                                label: modelData === "power-saver" ? "Saver" : modelData === "performance" ? "Performance" : "Balanced"
                                iconKind: modelData === "power-saver" ? "leaf" : modelData === "performance" ? "gauge" : "balance"
                                selected: page.system.powerProfile === modelData
                                available: page.actions.available("power:" + modelData)
                                onTriggered: page.actions.execute("power:" + modelData)
                            }
                        }
                    }
                }

                // Current playback comes before the growing notification list.
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

                // A short inbox preview; full content stays in notification history.
                // Keep its entry visible even when there are no pending messages.
                GroupCard {
                    Layout.fillWidth: true
                    style: page.style
                    onActivated: page.actions.execute("notifications")
                    contentSpacing: page.style.spaceMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        Text {
                            Layout.fillWidth: true
                            text: "Notifications"
                            color: page.style.textPrimary
                            elide: Text.ElideRight
                            font.family: page.style.fontFamily
                            font.pixelSize: page.style.fontSizeControl
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: page.notifs.current.length > 0 ? page.notifs.current.length + " pending"
                                : page.notifs.history.length + " saved"
                            color: page.style.textMuted
                            font.family: page.style.fontFamily
                            font.pixelSize: page.style.fontSizeCaption
                        }
                        ChoiceButton {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 28
                            visible: page.notifs.current.length > 0
                            style: page.style
                            label: "Clear"
                            onTriggered: page.notifs.clearCurrent()
                        }
                        StatusIcon {
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            kind: "chevron"
                            ink: page.style.textMuted
                        }
                    }

                    Repeater {
                        model: Math.min(page.notifs.current.length, page.notifs.previewCount)
                        delegate: NotificationRow {
                            required property int index
                            Layout.fillWidth: true
                            style: page.style
                            entry: page.notifs.current[index]
                            actions: page.notifs.entryActions(entry)
                            activationLabel: page.notifs.activationLabel(entry)
                            onActivated: { if (page.notifs.activateEntry(entry)) page.dismissRequested(); }
                            onActionRequested: action => { if (page.notifs.invokeEntryAction(entry, action)) page.dismissRequested(); }
                            onTriggered: page.notifs.removeCurrent(index)
                        }
                    }

                }
            }
        }
    }
}
