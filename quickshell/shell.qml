//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    AppearanceState { id: appearance }
    Theme { id: theme; darkMode: appearance.darkMode }
    DesktopServices {
        id: desktop
        controlsVisible: launcher.open
        terminalCommand: desktopSearch.terminalCommand
        onFeedback: (key, summary, body, critical) =>
            notifications.notifyLocal(key, {summary: summary, body: body, critical: critical})
    }
    DesktopSearch { id: desktopSearch; query: launcher.query; actions: shellActions }
    Notifications { id: notifications }
    PanelState {
        id: panelState
        onFeedback: (key, summary, body, critical) =>
            notifications.notifyLocal(key, {summary: summary, body: body, critical: critical})
    }
    BatteryAlerts { battery: desktop.battery; notifications: notifications }
    ScreenKeyboard {
        id: keyboard
        style: theme
        panelOpen: launcher.open
        onFeedback: (key, summary, body, critical) =>
            notifications.notifyLocal(key, {summary: summary, body: body, critical: critical})
    }
    WorkspaceLayoutState { id: workspaceLayouts }
    HyprlandControls {
        id: hyprControls
        layoutState: workspaceLayouts
        onFeedback: (key, summary, body, critical) =>
            notifications.notifyLocal(key, {summary: summary, body: body, critical: critical})
    }
    ShellActions {
        id: shellActions
        services: desktop
        appearance: appearance
        keyboard: keyboard
        hyprControls: hyprControls
        onNavigateRequested: section => {
            if (section === "desktop" || section === "controls") launcher.selectHome(section);
            else launcher.showDetails(section);
        }
    }

    Connections {
        target: desktop.controls
        function onFeedback(key, summary, body, critical) {
            notifications.notifyLocal(key, {summary: summary, body: body, critical: critical});
        }
    }

    // Darkman owns the appearance preference; the shell mirrors it locally.
    // Pages size to their content under one height limit; details own their header.
    LauncherPanel {
        id: launcher
        services: desktop
        style: theme
        appearance: appearance
        searchModel: desktopSearch
        notifs: notifications
        keyboard: keyboard
        hyprControls: hyprControls
        actions: shellActions
        panelState: panelState
    }
    PanelHotCorners { panel: launcher; style: theme }
    NotificationBanner { notifs: notifications; style: theme }
    OsdOverlay { shell: desktop; style: theme; searchModel: desktopSearch; layoutState: workspaceLayouts }

    IpcHandler {
        target: "appearance"
        function setMode(mode: string): void {
            if (mode === "dark" || mode === "light") appearance.setTheme(mode === "dark");
        }
        function status(): string {
            return JSON.stringify({mode: appearance.darkMode ? "dark" : "light",
                ready: appearance.appearanceKnown, available: appearance.appearanceAvailable,
                error: appearance.appearanceError});
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle(); }
        function close(): void { launcher.dismiss(); }
    }
}
