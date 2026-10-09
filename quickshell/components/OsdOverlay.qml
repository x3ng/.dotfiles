pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import ".."

Scope {
    id: osd

    required property var shell
    required property Theme style
    required property var searchModel

    property bool shown: false
    property string monitorName: ""
    property string kind: "volume"
    property real lastBrightness: -1
    property real lastVolume: -1
    property bool lastMuted: false
    property bool workspaceReady: false
    property var lastWorkspaceId: null
    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property var sinkAudio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property real level: kind === "brightness"
        ? shell.brightness : (sinkAudio?.volume ?? 0)
    readonly property bool muted: kind === "volume" && (sinkAudio?.muted ?? false)

    Component.onCompleted: {
        lastWorkspaceId = workspace?.id ?? null;
        workspaceReady = true;
    }

    onWorkspaceChanged: {
        const nextId = workspace?.id ?? null;
        // Initial discovery and losing focus are not workspace switches.
        if (workspaceReady && lastWorkspaceId !== null && nextId !== null
                && nextId !== lastWorkspaceId)
            reveal("workspace");
        lastWorkspaceId = nextId;
    }

    function reveal(nextKind) {
        if (nextKind === "brightness" && shell.brightness < 0) return;
        kind = nextKind;
        monitorName = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        shown = monitorName !== "";
        if (shown) {
            hideTimer.interval = nextKind === "workspace" ? 1000 : 1500;
            hideTimer.restart();
        }
    }

    onSinkAudioChanged: {
        // Changing output devices is not a volume key press.
        lastVolume = sinkAudio?.volume ?? -1;
        lastMuted = sinkAudio?.muted ?? false;
    }

    Connections {
        target: osd.sinkAudio

        function onVolumeChanged() {
            const volume = osd.sinkAudio?.volume ?? -1;
            if (osd.lastVolume >= 0 && volume !== osd.lastVolume)
                osd.reveal("volume");
            osd.lastVolume = volume;
        }

        function onMutedChanged() {
            const muted = osd.sinkAudio?.muted ?? false;
            if (muted !== osd.lastMuted) osd.reveal("volume");
            osd.lastMuted = muted;
        }
    }

    Connections {
        target: osd.shell

        function onBrightnessChanged() {
            const brightness = osd.shell.brightness;
            if (osd.lastBrightness >= 0 && brightness >= 0
                    && brightness !== osd.lastBrightness)
                osd.reveal("brightness");
            osd.lastBrightness = brightness;
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.shown = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData
            screen: modelData
            readonly property bool active: osd.shown && osd.monitorName === modelData.name
            visible: active || content.opacity > 0
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:osd"
            anchors { bottom: true }
            margins { bottom: 56 }
            implicitWidth: osd.kind === "workspace"
                ? Math.min(workspaceSummary.implicitWidth + 26, 586, modelData.width - 32) : 250
            implicitHeight: osd.kind === "workspace" ? workspaceSummary.implicitHeight + 14 : 76
            color: "transparent"
            mask: Region {}

            Item {
                id: content
                anchors.fill: parent
                opacity: window.active ? 1 : 0
                transform: Translate { y: (1 - content.opacity) * 8 }
                Behavior on opacity {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                WorkspaceSummary {
                    id: workspaceSummary
                    anchors.centerIn: parent
                    width: window.width - 26
                    height: implicitHeight
                    visible: osd.kind === "workspace"
                    style: osd.style
                    searchModel: osd.searchModel
                    interactive: false
                    radius: osd.style.radiusPopup
                    color: osd.style.surface
                    border.color: osd.style.outline
                    border.width: 1
                }

                Rectangle {
                    visible: osd.kind !== "workspace"
                    anchors.centerIn: parent
                    width: 224
                    height: 62
                    radius: osd.style.radiusPopup
                    color: osd.style.surface
                    border.color: osd.style.outline
                    border.width: 1

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: osd.style.spaceLg
                        anchors.top: parent.top
                        anchors.topMargin: 11
                        text: osd.kind === "brightness" ? "BRIGHTNESS"
                            : (osd.muted ? "MUTED" : "VOLUME")
                        color: osd.style.textSecondary
                        font.family: osd.style.fontFamily
                        font.pixelSize: osd.style.fontSizeBody
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: osd.style.spaceLg
                        anchors.top: parent.top
                        anchors.topMargin: 11
                        text: Math.round(Math.max(0, osd.level) * 100) + "%"
                        color: osd.style.textPrimary
                        font.family: osd.style.fontFamily
                        font.pixelSize: osd.style.fontSizeBody
                    }

                    Rectangle {
                        id: track
                        anchors.left: parent.left
                        anchors.leftMargin: osd.style.spaceLg
                        anchors.right: parent.right
                        anchors.rightMargin: osd.style.spaceLg
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 14
                        height: 5
                        radius: 3
                        color: osd.style.separator

                        Rectangle {
                            width: track.width * Math.max(0, Math.min(1, osd.level))
                            height: parent.height
                            radius: parent.radius
                            color: osd.kind === "brightness" ? osd.style.accentWarm
                                : osd.muted ? osd.style.textSecondary : osd.style.accent

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                }
            }
        }
    }
}
