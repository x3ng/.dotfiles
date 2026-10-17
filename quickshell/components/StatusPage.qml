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
                spacing: page.style.spaceLg

                StatusNotices {
                    actions: page.actions
                    Layout.fillWidth: true
                    style: page.style
                    services: page.services
                }

                // Quick-settings style: one shared column grid, everything
                // snapped to the same half/quarter divisions as the tiles above,
                // so vertical edges stay in one straight line. No section
                // titles, no category cards — one button per function.
                DesktopControls {
                    actions: page.actions
                    Layout.fillWidth: true
                    style: page.style
                    services: page.services
                }

                // Sliders sit on the same center split as the tiles (12px gap
                // matches DesktopControls), so the middle seam stays continuous.
                // Volume carries its device picker inline, Android-style.
                GridLayout {
                    Layout.fillWidth: true
                    columns: viewport.width >= 520 ? 2 : 1
                    columnSpacing: 12
                    GroupCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: viewport.width >= 520
                            ? Math.floor((content.width - 12) / 2) : content.width
                        style: page.style
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: page.style.spaceSm
                            FilledSlider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                style: page.style
                                label: "Volume"
                                value: page.sink?.audio?.volume ?? 0
                                available: !!page.sink?.audio
                                onEdited: value => page.services.setVolume(value)
                            }
                            ChoiceButton {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                style: page.style
                                filled: true
                                filledColor: page.style.surfaceHover
                                label: ""
                                iconKind: "headphones"
                                iconSize: 20
                                onTriggered: page.actions.execute("audio")
                            }
                        }
                    }
                    GroupCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: viewport.width >= 520
                            ? Math.floor((content.width - 12) / 2) : content.width
                        style: page.style
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
                }

                // Uniform quarter-grid of single-function toggles: even number
                // of columns keeps the center seam aligned with the rows above.
                GroupCard {
                    Layout.fillWidth: true
                    style: page.style
                    GridLayout {
                        Layout.fillWidth: true
                        columns: viewport.width >= 520 ? 4 : 2
                        columnSpacing: page.style.spaceSm
                        rowSpacing: page.style.spaceSm

                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            filledColor: page.style.surfaceHover
                            label: "Mute output"
                            iconKind: "volume"
                            selected: page.sink?.audio?.muted ?? false
                            available: page.actions.available("output-mute")
                            onTriggered: page.actions.execute("output-mute")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            filledColor: page.style.surfaceHover
                            label: "Mute mic"
                            iconKind: "mic"
                            selected: page.services.source?.audio?.muted ?? false
                            available: page.actions.available("mic-mute")
                            onTriggered: page.actions.execute("mic-mute")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            filledColor: page.style.surfaceHover
                            label: "Light"
                            iconKind: "brightness"
                            selected: page.appearance.appearanceKnown && !page.appearance.darkMode
                            available: page.actions.available("light")
                            onTriggered: page.actions.execute("light")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            filledColor: page.style.surfaceHover
                            label: "Dark"
                            iconKind: "moon"
                            selected: page.appearance.appearanceKnown && page.appearance.darkMode
                            available: page.actions.available("dark")
                            onTriggered: page.actions.execute("dark")
                        }

                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            filledColor: page.style.surfaceHover
                            label: "Keep awake"
                            iconKind: "eye"
                            selected: page.services.keepAwake
                            available: page.actions.available("keep-awake")
                            onTriggered: page.actions.execute("keep-awake")
                        }
                        Repeater {
                            model: page.system.powerProfiles
                            ChoiceButton {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                style: page.style
                                filled: true
                                filledColor: page.style.surfaceHover
                                label: modelData === "power-saver" ? "Saver"
                                    : modelData === "performance" ? "Performance"
                                    : "Balanced"
                                iconKind: modelData === "power-saver" ? "leaf"
                                    : modelData === "performance" ? "gauge"
                                    : "balance"
                                selected: page.system.powerProfile === modelData
                                available: page.actions.available("power:" + modelData)
                                onTriggered: page.actions.execute("power:" + modelData)
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: page.system.busy || page.system.error !== ""
                        text: page.system.busy ? "Applying…" : page.system.error
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: page.style.accentWarm
                        font.family: page.style.fontFamily
                        font.pixelSize: page.style.fontSizeCaption
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
                            visible: page.notifs.current.length > 0
                            text: page.notifs.current.length + " pending"
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
                    }

                    Repeater {
                        model: Math.min(page.notifs.current.length, page.notifs.previewCount)
                        delegate: NotificationRow {
                            required property int index
                            Layout.fillWidth: true
                            style: page.style
                            entry: page.notifs.current[index]
                            onActivated: page.actions.execute("notifications")
                            onTriggered: page.notifs.removeCurrent(index)
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: page.notifs.current.length === 0
                        text: page.notifs.history.length > 0
                            ? "No unread notifications" : "No notifications"
                        color: page.style.textMuted
                        font.family: page.style.fontFamily
                        font.pixelSize: page.style.fontSizeSmall
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        Text {
                            Layout.fillWidth: true
                            text: page.notifs.current.length > page.notifs.previewCount
                                ? (page.notifs.current.length - page.notifs.previewCount) + " more pending"
                                : "Notification history"
                            color: page.style.accent
                            elide: Text.ElideRight
                            font.family: page.style.fontFamily
                            font.pixelSize: page.style.fontSizeSmall
                        }
                        Text {
                            text: page.notifs.history.length + " saved"
                            color: page.style.textMuted
                            font.family: page.style.fontFamily
                            font.pixelSize: page.style.fontSizeCaption
                        }
                        StatusIcon {
                            kind: "chevron"
                            Layout.preferredWidth: 14
                            Layout.preferredHeight: 14
                            ink: page.style.accent
                        }
                    }
                }
            }
        }
    }
}
