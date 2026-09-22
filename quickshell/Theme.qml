pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    // One switch drives every Quickshell surface. Keep the palette values
    // below semantic so components never need to know about light/dark hexes.
    property bool darkMode: true

    function toggle() {
        darkMode = !darkMode;
    }

    readonly property string modeLabel: darkMode ? "DARK" : "LIGHT"

    readonly property int barHeight: 40
    readonly property int barReservedHeight: 36
    readonly property int barOuterMarginX: 4
    readonly property int barBackgroundPaddingX: 12
    readonly property int barBackgroundHeight: 34
    readonly property int barSectionGap: 14
    readonly property int radiusBar: 8
    readonly property int radiusPopup: 8
    readonly property int radiusCard: 5
    readonly property int radiusControl: 4
    readonly property int radiusSmall: 3
    // Keep the alpha in the surface colours. Applying another opacity to the
    // whole rectangle would multiply the alpha and make dark mode muddy.
    readonly property real barBackgroundOpacity: 1.0

    // Neutral surfaces carry most of the UI; accents are reserved for focus
    // and status, so the palette stays calm without becoming monochrome.
    // QML uses #AARRGGBB for 8-digit colours.
    // Dark mode uses translucent charcoal instead of pure black/white.
    // The first byte is alpha: QML colours are #AARRGGBB.
    readonly property color surface: darkMode ? "#b8141416" : "#cfeef2f2"
    // A lighter backing for the bar itself; popups keep the stronger surface.
    readonly property color barSurface: darkMode ? "#70141618" : "#90eef2f2"
    readonly property color surfaceRaised: darkMode ? "#c91f2022" : "#dffbfbfb"
    readonly property color surfaceHover: darkMode ? "#d02b2c30" : "#d9e7e9eb"
    readonly property color outline: darkMode ? "#35ffffff" : "#24000000"
    readonly property color separator: darkMode ? "#22ffffff" : "#18000000"
    readonly property color textPrimary: darkMode ? "#e6e6e6" : "#151515"
    readonly property color textSecondary: darkMode ? "#b8b8b8" : "#4f4f4f"
    readonly property color textMuted: darkMode ? "#858585" : "#818181"
    readonly property color accent: darkMode ? "#84b8b0" : "#2f7770"
    readonly property color accentWarm: darkMode ? "#d8ad72" : "#9a691f"
    readonly property color positive: darkMode ? "#86bb98" : "#32734a"
    readonly property color accentInk: darkMode ? "#14201e" : "#f7f7f7"
    readonly property color warning: darkMode ? "#d4a96f" : "#9a691f"
    readonly property color critical: darkMode ? "#d17f88" : "#a5434e"

    readonly property int fontSizeSmall: 13
    readonly property int fontSizeMedium: 13
    readonly property int fontSizeLarge: 16
    readonly property string fontFamily: "Inter"
    readonly property int iconSizeSmall: 20
    readonly property int separatorHeight: 18
}
