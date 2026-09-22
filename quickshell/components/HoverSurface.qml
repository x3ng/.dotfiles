pragma ComponentBehavior: Bound

import QtQuick

// Shared, deliberately quiet hover treatment for flat top-level controls.
Rectangle {
    required property var style
    required property bool hovered

    anchors.fill: parent
    color: hovered ? style.surfaceHover : "transparent"

    Behavior on color {
        ColorAnimation { duration: 120 }
    }
}
