pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

ColumnLayout {
    id: page
    required property var services
    readonly property var system: services.controls
    required property Theme style
    required property var searchModel
    required property var appearance
    required property var notifs
    required property var sink
    required property var player
    required property bool panelOpen
    signal detailsRequested(string section)
    readonly property real naturalHeight: content.implicitHeight + spacing
        + workspaces.implicitHeight
    spacing: page.style.spaceLg

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
            spacing: page.style.spaceLg

            // Quick-settings style: one shared column grid, everything
            // snapped to the same half/quarter divisions as the tiles above,
            // so vertical edges stay in one straight line. No section
            // titles, no category cards — one button per function.
            DesktopControls {
                Layout.fillWidth: true
                style: page.style
                services: page.services
                onDetailsRequested: section => page.detailsRequested(section)
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
                            onTriggered: page.detailsRequested("audio")
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
                        available: !!page.sink?.audio
                        onTriggered: page.services.toggleOutputMute()
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
                        available: !!page.services.source?.audio
                        onTriggered: page.services.toggleMicMute()
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
                        available: page.appearance.appearanceAvailable && page.appearance.appearanceKnown
                        onTriggered: page.appearance.setTheme(false)
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
                        available: page.appearance.appearanceAvailable && page.appearance.appearanceKnown
                        onTriggered: page.appearance.setTheme(true)
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
                        onTriggered: page.services.toggleKeepAwake()
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
                            available: page.system.powerAvailable && !page.system.busy
                            onTriggered: page.system.setPowerProfile(modelData)
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
                    font.pixelSize: page.style.fontSizeCaption
                }
            }

            // Notification center entry: always present, so the panel does not
            // reflow when the pending list empties. It previews the newest few
            // pending entries (or an empty state); tapping the card - including
            // the "in history" line - opens the history detail page. Clear
            // empties the pending list only, so history keeps every entry.
            GroupCard {
                Layout.fillWidth: true
                style: page.style
                onActivated: page.detailsRequested("notifications")

                RowLayout {
                    Layout.fillWidth: true
                    spacing: page.style.spaceSm
                    Text {
                        text: page.notifs.current.length > 0
                            ? "NOTIFICATIONS · " + page.notifs.current.length
                            : "NOTIFICATIONS"
                        color: page.style.textMuted
                        font.family: page.style.fontFamily
                        font.pixelSize: page.style.fontSizeCaption
                        font.letterSpacing: page.style.sectionLetterSpacing
                    }
                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                    Text {
                        visible: page.notifs.current.length > 0
                        text: "Clear"
                        color: clearMouse.containsMouse ? page.style.accent : page.style.textMuted
                        font.family: page.style.fontFamily
                        font.pixelSize: page.style.fontSizeCaption
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: page.notifs.clearCurrent()
                        }
                    }
                    StatusIcon {
                        kind: "chevron"
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
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
                Text {
                    Layout.fillWidth: true
                    visible: page.notifs.history.length > 0
                    text: page.notifs.current.length > page.notifs.previewCount
                        ? (page.notifs.current.length - page.notifs.previewCount)
                            + " more · " + page.notifs.history.length + " in history"
                        : page.notifs.history.length + " in history"
                    color: page.style.accent
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeCaption
                }
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
