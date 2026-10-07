pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets

ClippingRectangle {
    id: slider
    required property var style
    required property real value
    required property string label
    property bool available: true
    signal edited(real newValue)

    implicitWidth: 240
    implicitHeight: 48
    radius: style.radiusCard
    color: style.surfaceHover
    opacity: available ? 1 : 0.5

    Rectangle {
        width: slider.width * Math.max(0, Math.min(1, slider.value))
        height: slider.height
        radius: 0
        color: slider.style.surfaceSelected
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: slider.label
        color: slider.style.textPrimary
        font.family: slider.style.fontFamily
        font.pixelSize: 14
        font.weight: Font.Medium
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: slider.available ? Math.round(slider.value * 100) + "%" : "Unavailable"
        color: slider.style.textPrimary
        font.family: slider.style.fontFamily
        font.pixelSize: 14
    }
    MouseArea {
        anchors.fill: parent
        enabled: slider.available
        function update(x) { slider.edited(Math.max(0, Math.min(1, x / width))); }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
        onWheel: event => {
            slider.edited(Math.max(0, Math.min(1, slider.value + (event.angleDelta.y > 0 ? 0.02 : -0.02))));
            event.accepted = true;
        }
    }
}
