pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell owns the choice. System settings only publish it to applications.
Scope {
    id: theme
    property bool darkMode: true
    property bool appearanceKnown: false
    readonly property bool appearanceAvailable: appearanceKnown
    readonly property string appearanceError: persistenceError || desktopAppearance.error
    property string persistenceError: ""
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/quickshell/appearance-mode"

    Appearance {
        id: desktopAppearance
        mode: theme.appearanceKnown ? (theme.darkMode ? "dark" : "light") : ""
    }

    function setTheme(dark) {
        if (!appearanceKnown) return;
        darkMode = dark;
        savedMode.setText(dark ? "dark\n" : "light\n");
        // Reapply even when selecting the current mode (e.g. after a failure).
        Qt.callLater(desktopAppearance.apply);
    }

    FileView {
        id: savedMode
        path: theme.statePath
        printErrors: false
        onLoaded: {
            const mode = text().trim();
            theme.darkMode = mode !== "light";
            theme.appearanceKnown = true;
        }
        onLoadFailed: error => {
            theme.appearanceKnown = true;
            if (error === 2) savedMode.setText("dark\n");
            else theme.persistenceError = "Could not read saved appearance";
        }
        onSaved: theme.persistenceError = ""
        onSaveFailed: error => theme.persistenceError = "Could not save appearance"
    }
}
