pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Only compositor colours need adaptation. Application preferences use the portal.
Scope {
    id: root
    property string mode: ""
    property string error: ""
    property string applyingMode: ""

    onModeChanged: Qt.callLater(apply)

    function apply() {
        if (update.running || !Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            || (mode !== "dark" && mode !== "light")) return;
        applyingMode = mode;
        error = "";
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
                root.error = "Hyprland colour update failed (" + code + ")";
                console.error(root.error);
            }
            // Coalesce rapid changes, then apply the newest darkman mode.
            if (root.mode !== root.applyingMode) Qt.callLater(root.apply);
        }
    }
}
