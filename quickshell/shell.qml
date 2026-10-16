//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    AppearanceState { id: appearance }
    Theme { id: theme; darkMode: appearance.darkMode }
    DesktopServices { id: desktop; controlsVisible: launcher.open; terminalCommand: desktopSearch.terminalCommand }
    DesktopSearch { id: desktopSearch; query: launcher.query }
    Notifications { id: notifications }
    WorkspaceLayoutState { id: workspaceLayouts }

    // The shell owns appearance state and publishes the application preference.
    // Pages size to their content under one height limit; details own their header.
    LauncherPanel {
        id: launcher
        services: desktop
        style: theme
        appearance: appearance
        searchModel: desktopSearch
        notifs: notifications
        layoutState: workspaceLayouts
    }
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
