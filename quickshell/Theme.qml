pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: theme

    // Darkman owns the mode and sunrise/sunset schedule.
    property bool darkMode: true
    property bool appearanceKnown: false
    readonly property bool appearanceAvailable: modeWatch.connected && modeControl.connected
    readonly property alias appearanceError: desktopAppearance.error

    Appearance {
        id: desktopAppearance
        mode: theme.appearanceKnown ? (theme.darkMode ? "dark" : "light") : ""
    }

    function setTheme(dark) {
        if (!appearanceAvailable) return;
        modeControl.write("set " + (dark ? "dark" : "light") + "\n");
        modeControl.flush();
    }

    Socket {
        id: modeWatch
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/darkman/control.sock"
        connected: true
        onConnectionStateChanged: {
            if (connected) {
                write("watch\n");
                flush();
            }
        }
        parser: SplitParser {
            onRead: data => {
                const mode = data.trim();
                theme.appearanceKnown = mode === "dark" || mode === "light";
                if (theme.appearanceKnown) {
                    theme.darkMode = mode === "dark";
                    // Also synchronize after reconnect, even if the mode is unchanged.
                    Qt.callLater(desktopAppearance.apply);
                }
            }
        }
    }

    Socket {
        id: modeControl
        path: modeWatch.path
        connected: true
    }

    Timer {
        interval: 2000
        repeat: true
        running: !modeWatch.connected || !modeControl.connected
        onTriggered: {
            if (!modeWatch.connected) modeWatch.connected = true;
            if (!modeControl.connected) modeControl.connected = true;
        }
    }

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
    // Semantic colours; light surfaces stay nearly opaque to preserve contrast
    // over dark or colourful wallpapers. QML uses #AARRGGBB.
    readonly property color surface: darkMode ? "#f21b1d20" : "#faf0f1f3"
    readonly property color barSurface: darkMode ? "#eb1b1d20" : "#f5eceef1"
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
    readonly property color accentWarm: darkMode ? "#e4bb80" : "#805313"
    readonly property color positive: darkMode ? "#96cda5" : "#28683f"
    readonly property color accentInk: darkMode ? "#132a23" : "#ffffff"
    readonly property color warning: darkMode ? "#e4bb80" : "#805313"
    readonly property color critical: darkMode ? "#e99da6" : "#a33345"

    readonly property int fontSizeSmall: 13
    readonly property int fontSizeMedium: 13
    readonly property int fontSizeLarge: 16
    readonly property string fontFamily: "Inter"
    readonly property int iconSizeSmall: 20
    readonly property int separatorHeight: 18
}
