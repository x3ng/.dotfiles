pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: tile
    required property var style
    required property string icon
    required property string title
    required property string detail
    property bool available: true
    property bool toggleable: false
    property bool toggleAvailable: true
    property bool active: false
    signal triggered()
    signal toggled()
    implicitHeight: 76
    implicitWidth: 240
    radius: style.radiusCard
    color: mouse.containsMouse ? style.surfaceHover : style.surfaceRaised
    border.width: 1
    border.color: style.separator
    opacity: available ? 1 : 0.5
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 12
            color: tile.active ? tile.style.surfaceSelected : tile.style.surfaceHover
            StatusIcon {
                anchors.centerIn: parent
                width: 20; height: 20
                kind: tile.icon
                ink: tile.active ? tile.style.accent : tile.style.textSecondary
            }
            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                enabled: tile.toggleable && tile.available && tile.toggleAvailable
                hoverEnabled: true
                onClicked: tile.toggled()
            }
            ToolTip.visible: toggleMouse.containsMouse
            ToolTip.delay: 500
            ToolTip.text: tile.active ? "Turn off " + tile.title : "Turn on " + tile.title
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: tile.title
                color: tile.style.textPrimary
                font.family: tile.style.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                text: tile.available ? tile.detail : "Unavailable"
                elide: Text.ElideRight
                color: tile.style.textMuted
                font.family: tile.style.fontFamily
                font.pixelSize: 12
            }
        }
        Text {
            text: "›"
            color: tile.style.textMuted
            font.pixelSize: 18
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.leftMargin: tile.toggleable ? 60 : 0
        enabled: tile.available
        hoverEnabled: true
        onClicked: tile.triggered()
    }
}
