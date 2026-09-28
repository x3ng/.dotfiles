pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

PopupWindow {
    id: drawer
    required property var style
    required property var barWindow
    required property bool expanded
    required property bool hasTrayItems
    required property real inputX
    required property real triggerX
    required property real triggerWidth
    required property var openMenu
    signal requestCollapse()
    parentWindow: drawer.barWindow
    visible: drawer.expanded && drawer.hasTrayItems && drawer.barWindow.isVisible
    implicitWidth: Math.min(320, Math.max(76, trayRow.implicitWidth + 24))
    // Keep the drawer close to the icon row; extra vertical
    // padding makes a following context menu feel detached.
    implicitHeight: 44
    // Center the tray popup on the trigger instead of
    // pinning it to the far-right edge of the bar.
    relativeX: Math.round(Math.max(
        drawer.style.barOuterMarginX,
        Math.min(
            drawer.barWindow.width - drawer.style.barOuterMarginX - width,
            drawer.inputX + drawer.triggerX
                + (drawer.triggerWidth - width) / 2
        )
    ))
    relativeY: drawer.style.barHeight + 6
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: drawer.style.radiusPopup
        color: drawer.style.surface
        border.width: 1
        border.color: drawer.style.outline
    }

    Row {
        id: trayRow
        spacing: 4
        anchors.centerIn: parent

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            Item {
                id: trayItem
                required property SystemTrayItem modelData
                width: 28; height: 28

                function displayMenu() {
                    // Never fall back to SystemTrayItem.display():
                    // that opens Qt's platform-themed white menu.
                    // A menu handle may arrive one event-loop turn
                    // after hasMenu, so retry once instead.
                    var right = drawer.relativeX + trayRow.x
                        + trayItem.x + trayItem.width;
                    if (!drawer.openMenu(trayItem.modelData, right))
                        Qt.callLater(() => drawer.openMenu(trayItem.modelData, right));
                }

                function fallbackLabel() {
                    var key = (
                        (trayItem.modelData.icon ?? "") + " " +
                        (trayItem.modelData.id ?? "") + " " +
                        (trayItem.modelData.title ?? "")
                    ).toLowerCase();

                    if (key.indexOf("keyboard") >= 0 || key.indexOf("fcitx") >= 0)
                        return "K";
                    if (key.indexOf("bluetooth") >= 0 || key.indexOf("blue") >= 0)
                        return "B";
                    return "·";
                }

                Rectangle {
                    anchors.fill: parent; radius: drawer.style.radiusSmall
                    color: trayMouse.containsMouse ? drawer.style.surfaceHover : "transparent"
                }

                IconImage {
                    id: trayIcon
                    anchors.centerIn: parent
                    implicitSize: drawer.style.iconSizeSmall
                    source: trayItem.modelData.icon
                    visible: status !== Image.Error && source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: trayItem.fallbackLabel()
                    visible: !trayIcon.visible
                    color: drawer.style.textSecondary
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: function(event) {
                        if (event.button === Qt.RightButton
                            && trayItem.modelData.hasMenu) {
                            event.accepted = true;
                            trayItem.displayMenu();
                        }
                    }
                    onClicked: function(event) {
                        if (event.button === Qt.LeftButton) {
                            if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                trayItem.displayMenu();
                            else {
                                drawer.requestCollapse();
                                trayItem.modelData.activate();
                            }
                        }
                    }
                }
            }
    }
}
}
