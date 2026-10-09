pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Scope {
    required property bool darkMode
    // Palette sync: the values below are mirrored in hypr/appearance.lua
    // (borders, groupbar). Keep both files in step when changing a colour;
    // accent is intentionally darker in Hyprland borders than in the shell.
    readonly property int panelPadding: 24
    readonly property int panelGap: 10
    // Shared spacing scale; one-off optical adjustments stay literal.
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int maximumPanelHeight: 700
    readonly property int maximumPanelWidth: 680
    readonly property int stripHeight: 40
    readonly property int radiusPanel: 16
    readonly property int radiusInput: 10
    readonly property int radiusPopup: 8
    readonly property int radiusCard: 10
    readonly property int radiusControl: 8
    readonly property int radiusSmall: 3
    // Opaque surfaces keep background windows from competing with controls.
    // QML uses #AARRGGBB.
    readonly property color backdrop: darkMode ? "#38000000" : "#18000000"
    readonly property color panelSurface: darkMode ? "#1b1d20" : "#f0f1f3"
    readonly property color surface: darkMode ? "#f21b1d20" : "#faf0f1f3"
    // Cards sit visibly above the panel: white-on-grey in light mode keeps
    // the light theme from reading as one flat sheet.
    readonly property color surfaceRaised: darkMode ? "#2e3238" : "#ffffff"
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

    // Typography scale; every text size in the shell maps to one of these.
    readonly property int fontSizeMicro: 10
    readonly property int fontSizeCaption: 11
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeBody: 13
    readonly property int fontSizeControl: 14
    readonly property int fontSizeHeading: 21
    readonly property string fontFamily: "Inter"
    readonly property real sectionLetterSpacing: 1.2
}
