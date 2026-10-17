pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "components/HyprlandControlCommands.js" as Commands

// Views select explicit workspace IDs and window addresses. Opening the panel
// must never redirect an operation to whichever window happens to be focused.
Scope {
    id: root
    required property var layoutState
    readonly property bool available: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property var pendingOperation: null
    readonly property bool busy: pendingOperation !== null
    property int requestSequence: 0
    readonly property int lastRequestId: requestSequence
    property string error: ""
    signal feedback(string key, string summary, string body, bool critical)
    signal operationFinished(bool success, string operation, string target, int requestId, string message)
    readonly property int focusedWorkspaceId: Hyprland.focusedMonitor?.lastIpcObject.specialWorkspace?.id
        || Hyprland.focusedWorkspace?.id || 0
    readonly property var workspaces: {
        const rows = Hyprland.workspaces.values.map(workspace => ({
            id: workspace.id,
            name: workspace.name,
            configName: workspace.name.startsWith("special:") ? workspace.name
                : workspace.name === String(workspace.id) ? String(workspace.id) : "name:" + workspace.name,
            monitor: workspace.monitor?.name ?? "",
            active: workspace.active || workspace.id === root.focusedWorkspaceId,
            special: workspace.name.startsWith("special:"),
            exists: true,
            layout: root.layoutState.layouts[String(workspace.id)] ?? "—",
            windowCount: workspace.toplevels.values.length
        }));
        return rows.sort((a, b) => Number(a.special) - Number(b.special) || a.id - b.id);
    }
    readonly property var workspaceTargets: {
        const rows = workspaces.slice();
        if (root.available) {
            for (let id = 1; id <= 10; id++) {
                if (rows.some(row => row.id === id)) continue;
                rows.push({id: id, name: String(id), configName: String(id), monitor: "",
                    active: false, special: false, exists: false, layout: "—", windowCount: 0});
            }
        }
        return rows.sort((a, b) => Number(a.special) - Number(b.special) || a.id - b.id);
    }
    readonly property var windows: Hyprland.toplevels.values
        .filter(window => window.lastIpcObject.mapped !== false && Commands.address(window.address))
        .map(window => ({
            address: Commands.address(window.address),
            title: window.title || window.lastIpcObject.title || "Untitled window",
            appId: window.wayland?.appId || window.lastIpcObject.class || window.lastIpcObject.initialClass || "",
            workspaceId: window.workspace?.id ?? window.lastIpcObject.workspace?.id ?? 0,
            workspaceName: window.workspace?.name ?? window.lastIpcObject.workspace?.name ?? "",
            monitor: window.monitor?.name ?? "",
            floating: !!window.lastIpcObject.floating,
            fullscreen: Number(window.lastIpcObject.fullscreen ?? 0) !== 0,
            focused: window.activated
        })).sort((a, b) => a.workspaceId - b.workspaceId || a.title.localeCompare(b.title) || a.address.localeCompare(b.address))

    function reject(message) {
        error = message;
        feedback("desktop-operation", "Desktop operation", message, false);
        return false;
    }
    function run(request, operation, target) {
        if (busy) return reject("Another desktop operation is still running");
        if (!available) return reject("Hyprland is not available");
        if (request.error) return reject(request.error);
        error = "";
        requestSequence++;
        const context = {id: requestSequence, operation: operation, target: String(target)};
        pendingOperation = context;
        const process = actionFactory.createObject(root, {context: context, code: request.code});
        if (!process) {
            finish(context, false, "Could not start desktop operation");
            return false;
        }
        process.running = true;
        return true;
    }
    function workspaceRow(id) { return workspaceTargets.find(row => row.id === id); }
    function windowRequest(operation, address, id) {
        const target = Commands.address(address);
        const window = target ? windows.find(row => row.address === target) : null;
        const names = {focus: "focusWindow", float: "toggleFloat", fullscreen: "toggleFullscreen",
            move: "moveWindow", close: "closeWindow"};
        return run(Commands.windowAction(operation, window, workspaceRow(id)), names[operation], target);
    }
    function focusWorkspace(id) { return run(Commands.workspaceAction("focus", workspaceRow(id)), "focusWorkspace", id); }
    function setLayout(id, layout) { return run(Commands.workspaceAction("layout", workspaceRow(id), layout), "setLayout", id); }
    function focusWindow(address) { return windowRequest("focus", address); }
    function toggleFloat(address) { return windowRequest("float", address); }
    function toggleFullscreen(address) { return windowRequest("fullscreen", address); }
    function moveWindow(address, id) { return windowRequest("move", address, id); }
    function closeWindow(address) { return windowRequest("close", address); }
    function lock() {
        // Acknowledge the launch request; hyprlock owns authentication and lock state.
        return run({code: Commands.result("hl.dsp.exec_cmd('pidof hyprlock || hyprlock')")}, "lock", "session");
    }
    function refresh() {
        if (!available) return;
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshMonitors();
        layoutState.refresh();
    }
    function finish(context, success, message) {
        // A timed-out old process can exit after a newer request was accepted.
        if (!pendingOperation || pendingOperation.id !== context.id) return;
        pendingOperation = null;
        error = success ? "" : message || "Desktop operation failed";
        if (!success) feedback("desktop-operation", "Desktop operation", error, false);
        refresh();
        operationFinished(success, context.operation, context.target, context.id, success ? "" : error);
    }
    Component {
        id: actionFactory
        Process {
            id: action
            required property var context
            required property string code
            property bool hasStarted: false
            property bool settled: false
            property string output: ""
            property string failure: ""
            // eval discards Lua return values; repl preserves our explicit result.
            command: ["hyprctl", "repl", code]
            stdout: StdioCollector { onStreamFinished: action.output = text.trim() }
            stderr: StdioCollector { onStreamFinished: action.failure = text.trim() }
            function settle(success, message) {
                if (settled) return;
                settled = true;
                root.finish(context, success, message);
                running = false;
                destroy();
            }
            onStarted: hasStarted = true
            onExited: (exitCode, status) => {
                const success = exitCode === 0 && status === 0 && output === "OK";
                settle(success, output.startsWith("ERROR: ") ? output.slice(7)
                    : failure || output || "Desktop operation failed (" + exitCode + ")");
            }
            // Quickshell 0.3.2 does not emit exited when executable startup fails.
            property Timer startupCheck: Timer {
                interval: 1000
                running: true
                onTriggered: {
                    if (!action.hasStarted && !action.running)
                        action.settle(false, "Could not start hyprctl");
                }
            }
            property Timer deadline: Timer {
                interval: 8000
                running: true
                onTriggered: action.settle(false, "Desktop operation timed out")
            }
        }
    }
}
