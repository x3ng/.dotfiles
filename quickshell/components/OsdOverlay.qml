pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland

Scope {
    id: osd

    required property var shell
    required property var style

    property bool shown: false
    property string monitorName: ""
    property string kind: "volume"
    property real lastBrightness: -1
    property real lastVolume: -1
    property bool lastMuted: false
    readonly property var sinkAudio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property real level: kind === "brightness"
        ? shell.brightness : (sinkAudio?.volume ?? 0)
    readonly property bool muted: kind === "volume" && (sinkAudio?.muted ?? false)

    function reveal(nextKind) {
        if (nextKind === "brightness" && shell.brightness < 0) return;
        kind = nextKind;
        monitorName = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        shown = monitorName !== "";
        if (shown) hideTimer.restart();
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
            visible: osd.shown && osd.monitorName === modelData.name
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:osd"
            anchors { bottom: true }
            margins { bottom: 56 }
            implicitWidth: 250
            implicitHeight: 76
            color: "transparent"
            mask: Region {}

            Rectangle {
                anchors.centerIn: parent
                width: 224
                height: 62
                radius: osd.style.radiusPopup
                color: osd.style.surface
                border.color: osd.style.outline
                border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 11
                    text: osd.kind === "brightness" ? "BRIGHTNESS"
                        : (osd.muted ? "MUTED" : "VOLUME")
                    color: osd.style.textSecondary
                    font.family: osd.style.fontFamily
                    font.pixelSize: osd.style.fontSizeSmall
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 11
                    text: osd.muted ? "0%" : Math.round(Math.max(0, osd.level) * 100) + "%"
                    color: osd.style.textPrimary
                    font.family: osd.style.fontFamily
                    font.pixelSize: osd.style.fontSizeSmall
                }

                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    height: 5
                    radius: 3
                    color: osd.style.separator

                    Rectangle {
                        width: osd.muted ? 0 : track.width * Math.max(0, Math.min(1, osd.level))
                        height: parent.height
                        radius: parent.radius
                        color: osd.kind === "brightness" ? osd.style.accentWarm : osd.style.accent

                        Behavior on width {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
