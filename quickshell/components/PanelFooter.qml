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
    required property date date
    signal menuRequested(var owner, real right, real top)

    implicitHeight: style.stripHeight
    radius: style.radiusInput
    color: style.surfaceRaised
    border.width: 1
    border.color: style.outline

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: footer.style.spaceMd
        anchors.rightMargin: footer.style.spaceMd
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 14

        Row {
            spacing: footer.style.spaceSm
            StatusIcon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "calendar"
                ink: footer.style.textSecondary
                width: 20; height: 20
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
                text: Qt.formatDateTime(footer.date, "MM-dd · ddd")
                color: footer.style.textSecondary
                font.family: footer.style.fontFamily
                font.pixelSize: footer.style.fontSizeSmall
            }
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: [
                {kind: "battery", shown: footer.services.battery?.isPresent ?? false,
                    value: Math.round((footer.services.battery?.percentage ?? 0) * 100) + "%",
                    level: footer.services.battery?.percentage ?? 0,
                    hint: footer.services.batteryDetail(footer.services.battery)},
                {kind: "volume", shown: true,
                    value: footer.services.sink?.audio ? Math.round(footer.services.sink.audio.volume * 100) + "%" : "—",
                    muted: footer.services.sink?.audio?.muted ?? false,
                    hint: footer.services.sink?.audio?.muted ? "Volume · Muted" : "Volume"},
                {kind: "brightness", shown: footer.services.brightness >= 0,
                    value: Math.round(footer.services.brightness * 100) + "%", hint: "Brightness"},
                {kind: "appearance", shown: true, level: footer.appearance.darkMode ? 1 : 0,
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
                        width: 20; height: 20
                        kind: indicator.modelData.kind
                        ink: indicator.modelData.kind === "battery" && indicator.modelData.level < 0.2
                            ? footer.style.accentWarm : footer.style.textPrimary
                        level: indicator.modelData.level ?? 1
                        muted: indicator.modelData.muted ?? false
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: indicator.modelData.value
                        color: footer.style.textPrimary
                        font.family: footer.style.fontFamily
                        font.pixelSize: footer.style.fontSizeSmall
                        font.weight: Font.Medium
                    }
                }
                HoverHandler { id: hover }
                ToolTip.visible: hover.hovered
                ToolTip.delay: 500
                ToolTip.text: indicator.modelData.hint
            }
        }

        Rectangle {
            visible: footer.trayItems.length > 0
            width: 1; height: 24
            color: footer.style.separator
        }
        Row {
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
                }
            }
        }
    }
}
