pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: meter

    required property var style
    required property real level
    property color fillColor: style.accent
    property bool dimmed: false
    property bool overflow: false

    width: 8
    height: 24

    Rectangle {
        width: 4
        height: 18
        radius: 2
        color: meter.style.separator
        anchors.centerIn: parent

        Rectangle {
            width: parent.width
            height: meter.dimmed
                ? 0
                : Math.round(parent.height * Math.max(0, Math.min(1, meter.level)))
            radius: 2
            color: meter.fillColor
            anchors.bottom: parent.bottom

            Behavior on height {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            visible: meter.overflow && !meter.dimmed
            width: 4
            height: 2
            radius: 1
            color: meter.fillColor
            anchors.bottom: parent.top
            anchors.bottomMargin: 2
        }
    }

}
