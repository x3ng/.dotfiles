pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: state
    property var layouts: ({})
    property bool pending: false

    function label(workspaceId) {
        const layout = layouts[String(workspaceId)];
        return layout ? layout.toUpperCase() : "—";
    }

    function marker(workspaceId) {
        const layout = layouts[String(workspaceId)];
        return ({dwindle: "D", master: "M", scrolling: "S", monocle: "O"})[layout]
            ?? (layout ? layout.slice(0, 1).toUpperCase() : "—");
    }

    function refresh() {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return;
        if (read.running) { pending = true; return; }
        read.running = true;
    }

    function scheduleRefresh() {
        // A queued IPC read may already describe the state before this event.
        if (read.running) pending = true;
        refreshDelay.restart();
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Quickshell 0.3 does not refresh monitor.specialWorkspace on this
            // event; its focusedWorkspace continues to name the regular one.
            if (event.name === "activespecialv2") Hyprland.refreshMonitors();
            if (event.name === "configreloaded" || event.name === "workspacev2"
                || event.name === "activespecialv2" || event.name === "createworkspacev2"
                || event.name === "destroyworkspacev2" || event.name === "renameworkspace")
                state.scheduleRefresh();
        }
    }

    Timer { id: refreshDelay; interval: 40; onTriggered: state.refresh() }
    // Hyprland 0.56 exposes layout snapshots but no tiled-layout change event.
    // Refresh on native lifecycle events and explicit UI requests; do not poll.

    Process {
        id: read
        command: ["hyprctl", "-j", "workspaces"]
        property string output: ""
        stdout: StdioCollector { onStreamFinished: read.output = text }
        onExited: (code, status) => {
            if (code === 0 && status === 0 && !state.pending) {
                try {
                    const rows = JSON.parse(output);
                    if (!Array.isArray(rows)) throw new Error("Expected workspace array");
                    const next = {};
                    for (const workspace of rows) {
                        if (typeof workspace.tiledLayout !== "string") continue;
                        const key = String(workspace.id);
                        next[key] = workspace.tiledLayout;
                    }
                    if (JSON.stringify(state.layouts) !== JSON.stringify(next))
                        state.layouts = next;
                } catch (error) {
                    console.warn("Workspace layouts:", error);
                }
            }
            output = "";
            if (state.pending) {
                state.pending = false;
                refreshDelay.restart();
            }
        }
    }
}
