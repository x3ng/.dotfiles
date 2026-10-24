pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import ".."

Rectangle {
    id: footer
    required property Theme style
    required property var services
    required property var appearance
    required property var trayItems
    property bool summaryOnly: false
    property bool centerActions: false
    property int notificationCount: 0
    property int notificationHistoryCount: 0
    property bool lockAvailable: false
    signal notificationsRequested()
    signal clearNotificationsRequested()
    signal settingsRequested()
    signal lockRequested()
    required property date date
    signal menuRequested(var owner, real right, real top)

    // Budget secondary status fields after the tray, not against the outer
    // panel width. The panel's normal content width is less than 580px.
    readonly property real statusWidth: width - trayRow.implicitWidth
        - (trayItems.length > 0 ? 21 : 0)
        - (centerActions ? actionRow.implicitWidth + 10 : 0)
    implicitHeight: 40
    color: "transparent"

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: footer.style.separator
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: footer.style.spaceXs
        anchors.rightMargin: footer.style.spaceXs
        anchors.topMargin: 9
        anchors.bottomMargin: 3
        spacing: 10

        Row {
            spacing: footer.style.spaceSm
            StatusIcon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "calendar"
                visible: !footer.centerActions || footer.statusWidth >= 160
                ink: footer.style.textSecondary
                width: 16; height: 16
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(footer.date, "HH:mm")
                color: footer.style.textPrimary
                font.family: footer.style.fontFamily
                font.pixelSize: footer.style.fontSizeControl
                font.weight: Font.Medium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: footer.statusWidth >= (footer.summaryOnly ? 320 : 410)
                text: Qt.formatDateTime(footer.date, "MM-dd · ddd")
                color: footer.style.textSecondary
                font.family: footer.style.fontFamily
                font.pixelSize: footer.style.fontSizeSmall
            }
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: [
                {kind: "battery", shown: (footer.services.battery?.isPresent ?? false) && (!footer.centerActions || footer.statusWidth >= 130),
                    value: Math.round((footer.services.battery?.percentage ?? 0) * 100) + "%",
                    level: footer.services.battery?.percentage ?? 0,
                    hint: footer.services.batteryDetail(footer.services.battery)},
                {kind: "volume", shown: !footer.summaryOnly && footer.statusWidth >= 340,
                    value: footer.services.sink?.audio ? Math.round(footer.services.sink.audio.volume * 100) + "%" : "—",
                    muted: footer.services.sink?.audio?.muted ?? false,
                    hint: footer.services.sink?.audio?.muted ? "Volume · Muted" : "Volume"},
                {kind: "brightness", shown: !footer.summaryOnly && footer.statusWidth >= 460 && footer.services.brightness >= 0,
                    value: Math.round(footer.services.brightness * 100) + "%", hint: "Brightness"},
                {kind: "appearance", shown: !footer.centerActions || footer.statusWidth >= 180, level: footer.appearance.darkMode ? 1 : 0,
                    value: !footer.appearance.appearanceAvailable ? "!" : !footer.appearance.appearanceKnown ? "?"
                        : footer.appearance.appearanceError ? "!" : "",
                    hint: !footer.appearance.appearanceAvailable ? "Appearance offline"
                        : !footer.appearance.appearanceKnown ? "Appearance unknown"
                        : footer.appearance.appearanceError ? "Appearance error"
                        : footer.appearance.darkMode ? "Dark mode" : "Light mode"}
            ]
            Item {
                id: indicator
                required property var modelData
                visible: modelData.shown
                implicitWidth: visible ? indicatorRow.width : 0
                implicitHeight: 28
                Row {
                    id: indicatorRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        kind: indicator.modelData.kind
                        ink: indicator.modelData.kind === "battery" && indicator.modelData.level < 0.2
                            ? footer.style.accentWarm : footer.style.textMuted
                        level: indicator.modelData.level ?? 1
                        muted: indicator.modelData.muted ?? false
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: indicator.modelData.value
                        color: footer.style.textSecondary
                        font.family: footer.style.fontFamily
                        font.pixelSize: footer.style.fontSizeSmall
                        font.weight: Font.Medium
                    }
                }
                HoverHandler { id: hover }
                ShellToolTip {
                    style: footer.style
                    visible: hover.hovered
                    text: indicator.modelData.hint
                }
            }
        }

        Row {
            id: actionRow
            visible: footer.centerActions
            spacing: 2
            ChoiceButton {
                objectName: "overview-notifications"
                width: 56; height: 28
                style: footer.style
                label: String(footer.notificationCount)
                iconKind: "bell"
                iconSize: 16
                Accessible.name: "Notifications"
                tooltip: footer.notificationCount + " pending notifications · "
                    + footer.notificationHistoryCount + " saved in history"
                onTriggered: footer.notificationsRequested()
            }
            ChoiceButton {
                objectName: "overview-clear-notifications"
                width: 28; height: 28
                style: footer.style
                label: ""
                iconKind: "trash"
                iconSize: 16
                available: footer.notificationCount > 0
                tooltip: "Clear pending notifications · keep history"
                onTriggered: footer.clearNotificationsRequested()
            }
            ChoiceButton {
                objectName: "overview-settings"
                width: 28; height: 28
                style: footer.style
                label: ""
                iconKind: "settings"
                iconSize: 16
                tooltip: "System controls"
                onTriggered: footer.settingsRequested()
            }
            ChoiceButton {
                width: 28; height: 28
                style: footer.style
                label: ""
                iconKind: "lock"
                iconSize: 16
                tooltip: "Lock screen"
                available: footer.lockAvailable
                onTriggered: footer.lockRequested()
            }
        }

        Rectangle {
            visible: footer.trayItems.length > 0
            width: 1; height: 24
            color: footer.style.separator
        }
        Row {
            id: trayRow
            spacing: footer.style.spaceXs
            Repeater {
                model: footer.trayItems
                Rectangle {
                    id: trayItem
                    required property var modelData
                    width: 28; height: 28
                    radius: footer.style.radiusControl
                    color: trayMouse.containsMouse ? footer.style.surfaceHover : "transparent"
                    IconImage {
                        id: trayIcon
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: trayItem.modelData.icon
                        visible: source !== "" && status !== Image.Error
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !trayIcon.visible
                        text: (trayItem.modelData.title || trayItem.modelData.id || "?").slice(0, 1)
                        color: footer.style.textSecondary
                        font.pixelSize: footer.style.fontSizeBody
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: event => {
                            if (event.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                const pos = trayItem.mapToItem(footer, trayItem.width, 0);
                                footer.menuRequested(trayItem.modelData, pos.x, pos.y);
                            } else trayItem.modelData.activate();
                        }
                    }
                    ShellToolTip {
                        style: footer.style
                        visible: trayMouse.containsMouse && text !== ""
                        text: [trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id || "",
                            trayItem.modelData.tooltipDescription || ""].filter(part => part !== "").join("\n")
                    }
                }
            }
        }
    }
}
