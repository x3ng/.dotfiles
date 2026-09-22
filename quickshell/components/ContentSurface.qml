pragma ComponentBehavior: Bound

import QtQuick

// Shared backing for the three macro groups in the bar.
Rectangle {
    required property var style

    radius: style.radiusBar
    color: style.barSurface
    border.width: 1
    border.color: style.outline
}
