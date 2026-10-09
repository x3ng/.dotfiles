pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: choice

    required property Theme style
    required property string label
    property bool selected: false
    property bool available: true
    property bool filled: false
    // Background for filled buttons; override to surfaceHover inside cards.
    property color filledColor: style.surfaceRaised
    property int textSize: style.fontSizeSmall
    // Optional leading glyph. With a label it sits left of the text
    // (icon + description); alone it replaces the label (play/back/etc).
    property string iconKind: ""
    property int iconSize: 18
    signal triggered()

    height: 34
    radius: style.radiusControl
    color: selected ? style.surfaceSelected
        : (mouse.containsMouse && available ? style.surfaceHover : filled ? choice.filledColor : "transparent")
    border.width: selected ? 1 : 0
    border.color: style.accent
    opacity: available ? 1 : 0.45

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: choice.style.spaceSm
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: choice.label
        color: choice.selected ? choice.style.textSelected : choice.style.textSecondary
        font.family: choice.style.fontFamily
        font.pixelSize: choice.textSize
        font.weight: choice.selected ? Font.DemiBold : Font.Normal
        visible: choice.iconKind === "" && choice.label !== ""
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: choice.style.spaceXs
        visible: choice.iconKind !== "" && choice.label !== ""

        StatusIcon {
            kind: choice.iconKind
            width: choice.iconSize
            height: choice.iconSize
            ink: choice.selected ? choice.style.textSelected : choice.style.textSecondary
        }
        Text {
            text: choice.label
            color: choice.selected ? choice.style.textSelected : choice.style.textSecondary
            font.family: choice.style.fontFamily
            font.pixelSize: choice.textSize
            font.weight: choice.selected ? Font.DemiBold : Font.Normal
        }
    }

    StatusIcon {
        anchors.centerIn: parent
        visible: choice.iconKind !== "" && choice.label === ""
        kind: choice.iconKind
        width: choice.iconSize
        height: choice.iconSize
        ink: choice.selected ? choice.style.textSelected : choice.style.textSecondary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: choice.available
        hoverEnabled: true
        onClicked: choice.triggered()
    }
}
