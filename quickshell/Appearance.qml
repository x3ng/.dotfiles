pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Apply the observed Darkman mode to the compositor. Darkman owns the portal.
Scope {
    id: root
    property string mode: ""
    property string compositorError: ""
    readonly property string error: compositorError
    property string applyingMode: ""

    onModeChanged: Qt.callLater(apply)

    function apply() {
        if (mode !== "dark" && mode !== "light") return;
        if (update.running || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return;
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
}
