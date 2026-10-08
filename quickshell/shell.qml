//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    AppearanceState { id: appearance }
    Theme { id: theme; darkMode: appearance.darkMode }
    DesktopServices { id: desktop; controlsVisible: launcher.open }
    DesktopSearch { id: desktopSearch; query: launcher.query }

    LauncherPanel {
        id: launcher
        services: desktop
        style: theme
        appearance: appearance
        searchModel: desktopSearch
    }
    OsdOverlay { shell: desktop; style: theme; searchModel: desktopSearch }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle(); }
        function close(): void { launcher.dismiss(); }
    }
}
