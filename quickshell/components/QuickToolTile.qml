pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: tile

    required property var style
    required property string label
    required property string detail
    property bool active: false
    property bool available: true
    signal triggered()

    width: 126
    height: 62
    radius: style.radiusCard
    color: active
        ? style.surfaceHover
        : (mouseArea.containsMouse && available ? style.surfaceRaised : "transparent")
    border.width: active ? 1 : 0
    border.color: style.accent
    opacity: available ? 1 : 0.52

    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: tile.label
            color: tile.active ? tile.style.textPrimary : tile.style.textSecondary
            font.family: tile.style.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Text {
            text: tile.detail
            color: tile.active ? tile.style.accent : tile.style.textMuted
            font.family: tile.style.fontFamily
            font.pixelSize: 11
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: tile.available
        hoverEnabled: true
        onClicked: tile.triggered()
    }
}
