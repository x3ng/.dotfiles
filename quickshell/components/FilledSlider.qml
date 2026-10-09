pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import ".."

ClippingRectangle {
    id: slider
    required property Theme style
    required property real value
    required property string label
    property bool available: true
    signal edited(real newValue)

    // Fill rule: bars with text on top (here) use surfaceSelected so the
    // label stays readable; bare progress bars (OSD, media timeline) use accent.
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
        font.pixelSize: slider.style.fontSizeControl
        font.weight: Font.Medium
    }
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: slider.available ? Math.round(slider.value * 100) + "%" : "Unavailable"
        color: slider.style.textPrimary
        font.family: slider.style.fontFamily
        font.pixelSize: slider.style.fontSizeControl
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
