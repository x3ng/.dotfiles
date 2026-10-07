pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Scope {
    required property bool darkMode
    readonly property int radiusPanel: 16
    readonly property int radiusInput: 10
    readonly property int radiusPopup: 8
    readonly property int radiusCard: 10
    readonly property int radiusControl: 4
    readonly property int radiusSmall: 3
    // Semantic colours. The panel is 85% opaque; internal cards stay opaque.
    // QML uses #AARRGGBB.
    readonly property color backdrop: darkMode ? "#38000000" : "#18000000"
    readonly property color panelSurface: darkMode ? "#d91b1d20" : "#d9f0f1f3"
    readonly property color surface: darkMode ? "#f21b1d20" : "#faf0f1f3"
    readonly property color surfaceRaised: darkMode ? "#292c30" : "#f8f9fa"
    readonly property color surfaceHover: darkMode ? "#34383d" : "#e2e5e9"
    readonly property color surfaceSelected: darkMode ? "#263a35" : "#bcded2"
    readonly property color textSelected: darkMode ? "#93c0b1" : "#205e51"
    readonly property color outline: darkMode ? "#485058" : "#c9ced5"
    readonly property color separator: darkMode ? "#383e45" : "#d5dbe1"
    readonly property color textPrimary: darkMode ? "#edf0f3" : "#20262d"
    readonly property color textSecondary: darkMode ? "#c0c7d0" : "#47515d"
    readonly property color textMuted: darkMode ? "#9ea8b4" : "#606b78"
    readonly property color accent: darkMode ? "#79ad9d" : "#1c7057"
    readonly property color accentInk: darkMode ? "#132a23" : "#ffffff"
    readonly property color accentWarm: darkMode ? "#e4bb80" : "#805313"

    readonly property int fontSizeSmall: 13
    readonly property string fontFamily: "Inter"
}
