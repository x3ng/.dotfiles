pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: choice

    required property var style
    required property string label
    property bool selected: false
    property bool available: true
    property bool filled: false
    property int textSize: 12
    signal triggered()

    height: 34
    radius: style.radiusControl
    color: selected ? style.surfaceSelected
        : (mouse.containsMouse && available ? style.surfaceHover : filled ? style.surfaceRaised : "transparent")
    border.width: selected ? 1 : 0
    border.color: style.accent
    opacity: available ? 1 : 0.45

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: choice.label
        color: choice.selected ? choice.style.textSelected : choice.style.textSecondary
        font.family: choice.style.fontFamily
        font.pixelSize: choice.textSize
        font.weight: choice.selected ? Font.DemiBold : Font.Normal
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: choice.available
        hoverEnabled: true
        onClicked: choice.triggered()
    }
}
