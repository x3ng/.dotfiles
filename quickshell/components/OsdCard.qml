pragma ComponentBehavior: Bound

import QtQuick
import ".."

Rectangle {
    id: card
    required property Theme style
    property string label: ""
    property string value: ""
    property bool caution: false
    property bool showProgress: false
    property real progress: 0
    property bool customContent: false
    default property alias content: customSlot.data

    implicitWidth: 320
    implicitHeight: body.implicitHeight + 2 * style.spaceMd
    radius: style.radiusPopup
    color: style.surface
    border.color: style.outline
    border.width: 1

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: card.style.spaceLg
        anchors.rightMargin: card.style.spaceLg
        anchors.topMargin: card.style.spaceMd
        spacing: card.style.spaceXs

        Text {
            width: parent.width
            text: card.label
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: card.style.textSecondary
            font.family: card.style.fontFamily
            font.pixelSize: card.style.fontSizeBody
        }

        Text {
            visible: !card.customContent
            width: parent.width
            text: card.value
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: card.caution ? card.style.accentWarm : card.style.textPrimary
            font.family: card.style.fontFamily
            font.pixelSize: card.style.fontSizeControl
            font.weight: Font.DemiBold
        }

        Item {
            id: customSlot
            visible: card.customContent
            width: parent.width
            height: childrenRect.height
        }

        Item {
            visible: card.showProgress
            width: parent.width
            height: card.style.spaceSm + 5

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 5
                radius: 3
                color: card.style.separator

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, card.progress))
                    height: parent.height
                    radius: parent.radius
                    color: card.caution ? card.style.accentWarm : card.style.accent
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
