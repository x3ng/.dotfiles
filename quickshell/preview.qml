import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell

ShellRoot {
    Theme { id: loginTheme; darkMode: Quickshell.env("QS_PREVIEW_LOCK") === "1" || Quickshell.env("QS_PREVIEW_LIGHT") !== "1" }
    WallpaperState { id: wallpaperState }
    SessionCatalog { id: catalog }

    Window {
        id: window
        visible: true
        width: 1100
        height: 720
        title: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            ? "Quickshell · Lock screen preview" : "Quickshell · Greeter preview"
        color: loginTheme.panelSurface
        onVisibleChanged: if (visible) Qt.callLater(loginView.focusInput)

        WallpaperImage {
            anchors.fill: parent
            layer.enabled: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 48
            }
            visible: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            source: wallpaperState.urlFor(wallpaperState.entryFor(Quickshell.screens[0]?.name || "").path)
            fit: wallpaperState.entryFor(Quickshell.screens[0]?.name || "").fit
        }
        Rectangle {
            anchors.fill: parent
            visible: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            color: "#55000000"
        }
        LoginView {
            id: loginView
            anchors.fill: parent
            theme: loginTheme
            transparentBackground: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            cardOpacity: Quickshell.env("QS_PREVIEW_LOCK") === "1" ? 0.55 : 1
            frosted: Quickshell.env("QS_PREVIEW_LOCK") === "1"
            userName: Quickshell.env("USER")
            editableUser: Quickshell.env("QS_PREVIEW_LOCK") !== "1"
            sessions: Quickshell.env("QS_PREVIEW_LOCK") === "1" ? [] : catalog.sessions
            selectedSessionId: catalog.selectedId
            showPowerActions: Quickshell.env("QS_PREVIEW_LOCK") !== "1"
            powerMenuOpen: Quickshell.env("QS_PREVIEW_POWER_OPEN") === "1"
            onSelectSession: id => catalog.choose(id)
            onPowerRequested: action => Qt.quit()
            onSubmit: (userName, secret) => Qt.quit()
        }
    }
}
