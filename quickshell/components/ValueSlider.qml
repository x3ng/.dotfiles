pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: slider

    required property var style
    required property real value
    property color fillColor: style.accent
    property bool available: true
    signal edited(real newValue)

    width: 258
    height: 20
    opacity: available ? 1 : 0.5

    function valueAt(mouseX) {
        return Math.max(0, Math.min(1, mouseX / width));
    }

    Rectangle {
        height: 4
        radius: 2
        color: slider.style.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, slider.value))
            height: parent.height
            radius: 2
            color: slider.fillColor
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(parent.width - width,
            parent.width * Math.max(0, Math.min(1, slider.value)) - width / 2))
        width: 10
        height: 10
        radius: 5
        color: slider.fillColor
        anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
        anchors.fill: parent
        enabled: slider.available
        onPressed: function(mouse) { slider.edited(slider.valueAt(mouse.x)); }
        onPositionChanged: function(mouse) {
            if (pressed) slider.edited(slider.valueAt(mouse.x));
        }
    }
}
