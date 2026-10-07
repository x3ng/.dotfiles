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

}
