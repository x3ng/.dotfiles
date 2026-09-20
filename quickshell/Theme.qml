pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property int barHeight: 40
    readonly property int barReservedHeight: 36
    readonly property int barOuterMarginX: 8
    readonly property int barBackgroundPaddingX: 12
    readonly property int barBackgroundHeight: 34
    readonly property int barSectionGap: 14
    readonly property real barBackgroundOpacity: 0.97

    readonly property color surface: "#171a22"
    readonly property color surfaceRaised: "#232936"
    readonly property color surfaceHover: "#303847"
    // QML uses #AARRGGBB for 8-digit colours.
    readonly property color outline: "#20ffffff"
    readonly property color separator: "#18ffffff"
    readonly property color textPrimary: "#f3f5fa"
    readonly property color textSecondary: "#c7cddd"
    readonly property color textMuted: "#949db0"
    readonly property color accent: "#72b7e8"
    readonly property color accentWarm: "#e8b86a"
    readonly property color positive: "#7bc89c"
    readonly property color accentInk: "#0c202d"
    readonly property color warning: "#e0aa62"
    readonly property color critical: "#ec8796"

    readonly property int fontSizeSmall: 13
    readonly property int fontSizeMedium: 13
    readonly property int fontSizeLarge: 16
    readonly property int iconSizeSmall: 20
    readonly property int separatorHeight: 18
}
