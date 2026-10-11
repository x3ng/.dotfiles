pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Publish the shell choice to the compositor and the GTK Settings portal.
Scope {
    id: root
    property string mode: ""
    property string compositorError: ""
    property string settingsError: ""
    readonly property string error: compositorError || settingsError
    property string applyingMode: ""

    onModeChanged: Qt.callLater(apply)

    function apply() {
        if (mode !== "dark" && mode !== "light") return;
        if (!settingsUpdate.running) {
            settingsMode = mode;
            settingsUpdate.command = ["gsettings", "set", "org.gnome.desktop.interface",
                "color-scheme", mode === "dark" ? "prefer-dark" : "prefer-light"];
            settingsUpdate.running = true;
        }
        if (update.running || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            || (mode !== "dark" && mode !== "light")) return;
        applyingMode = mode;
        compositorError = "";
        update.command = ["hyprctl", "eval",
            "require('appearance').apply('" + applyingMode + "')"];
        update.running = true;
    }

    Process {
        id: update
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) console.warn("Hyprland appearance:", text.trim()); }
        }
        onExited: (code, status) => {
            if (code !== 0 || status !== 0) {
                root.compositorError = "Hyprland colour update failed (" + code + ")";
                console.error(root.compositorError);
            }
            // Coalesce rapid changes, then apply the newest shell mode.
            if (root.mode !== root.applyingMode) Qt.callLater(root.apply);
        }
    }
    property string settingsMode: ""
    Process {
        id: settingsUpdate
        stderr: StdioCollector {
            onStreamFinished: { if (text.trim()) console.warn("Application appearance:", text.trim()); }
        }
        onExited: (code, status) => {
            root.settingsError = code !== 0 || status !== 0
                ? "Application theme preference update failed (" + code + ")" : "";
            if (root.mode !== root.settingsMode) Qt.callLater(root.apply);
        }
    }

}
