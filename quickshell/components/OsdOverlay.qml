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
    required property var layoutState

    property bool shown: false
    property string monitorName: ""
    property string kind: "volume"
    property real lastBrightness: -1
    property real lastVolume: -1
    property bool lastMuted: false
    property bool workspaceReady: false
    property var lastWorkspaceId: null
    property string layoutLabel: ""
    property string layoutWorkspaceLabel: ""
    property bool lastMicMuted: false
    property bool microphoneMuted: false
    property string lastOutputKey: ""
    property string outputLabel: ""
    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property int layoutWorkspaceId: Hyprland.focusedMonitor?.lastIpcObject.specialWorkspace?.id
        || workspace?.id || 0
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink?.ready ? sink.audio : null
    readonly property var sourceAudio: source?.ready ? source.audio : null
    readonly property string outputKey: sink?.ready ? (sink.name || String(sink.id)) : ""
    readonly property string feedbackTitle: kind === "layout" ? layoutWorkspaceLabel
        : kind === "microphone" ? "MICROPHONE" : "AUDIO OUTPUT"
    readonly property string feedbackValue: kind === "layout" ? layoutLabel
        : kind === "microphone" ? (microphoneMuted ? "MUTED" : "UNMUTED") : outputLabel
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

    onSourceAudioChanged: lastMicMuted = sourceAudio?.muted ?? false

    onOutputKeyChanged: {
        // Retain the last stable identity across temporary nulls and node rebuilds.
        if (outputKey) outputDelay.restart();
        else outputDelay.stop();
    }

    function reconcileOutput() {
        if (!outputKey) return;
        const changed = lastOutputKey !== "" && lastOutputKey !== outputKey;
        lastOutputKey = outputKey;
        if (changed) {
            outputLabel = sink.description || sink.nickname || sink.name || "Audio output";
            reveal("output");
        }
    }

    Timer {
        id: outputDelay
        interval: 180
        onTriggered: osd.reconcileOutput()
    }

    Connections {
        target: osd.sourceAudio
        function onMutedChanged() {
            if (!osd.sourceAudio) return;
            const muted = osd.sourceAudio.muted;
            if (muted !== osd.lastMicMuted) {
                osd.microphoneMuted = muted;
                osd.reveal("microphone");
            }
            osd.lastMicMuted = muted;
        }
    }

    Connections {
        target: osd.layoutState
        function onLayoutChanged(workspaceId) {
            if (workspaceId !== osd.layoutWorkspaceId) return;
            const workspace = Hyprland.workspaces.values.find(w => w.id === workspaceId);
            osd.layoutLabel = osd.layoutState.label(workspaceId);
            osd.layoutWorkspaceLabel = workspaceId < 0
                ? (workspace?.name ?? "SPECIAL WORKSPACE") : "WORKSPACE " + (workspace?.name ?? workspaceId);
            osd.reveal("layout");
        }
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
            readonly property bool active: modelData !== null && osd.shown && osd.monitorName === modelData.name
            visible: active || content.opacity > 0
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:osd"
            anchors { bottom: true }
            margins { bottom: 56 }
            implicitWidth: Math.min((osd.kind === "workspace"
                ? Math.max(card.implicitWidth, workspaceSummary.implicitWidth + 2 * osd.style.spaceLg)
                : card.implicitWidth) + 26, Math.max(1, (modelData?.width ?? 1920) - 64))
            implicitHeight: card.implicitHeight + 14
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

                OsdCard {
                    id: card
                    anchors.centerIn: parent
                    width: window.width - 26
                    height: implicitHeight
                    style: osd.style
                    label: osd.kind === "workspace" ? "WORKSPACES"
                        : osd.kind === "volume" ? "VOLUME"
                        : osd.kind === "brightness" ? "BRIGHTNESS" : osd.feedbackTitle
                    value: showProgress
                        ? (osd.muted ? "MUTED · " : "") + Math.round(Math.max(0, osd.level) * 100) + "%"
                        : osd.feedbackValue
                    caution: osd.muted || (osd.kind === "microphone" && osd.microphoneMuted)
                    showProgress: osd.kind === "volume" || osd.kind === "brightness"
                    progress: osd.level
                    customContent: osd.kind === "workspace"

                    WorkspaceSummary {
                        id: workspaceSummary
                        width: parent.width
                        height: implicitHeight
                        style: osd.style
                        searchModel: osd.searchModel
                        layoutState: osd.layoutState
                        interactive: false
                        padding: 0
                        color: "transparent"
                    }
                }
            }
        }
    }
}
