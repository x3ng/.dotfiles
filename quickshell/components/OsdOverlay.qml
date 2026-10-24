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
    required property var controls

    property bool shown: false
    property string monitorName: ""
    property string kind: "volume"
    property real lastBrightness: -1
    property real lastVolume: -1
    property bool lastMuted: false
    property bool workspaceReady: false
    property var lastWorkspaceId: null
    property bool lastMicMuted: false
    property bool microphoneMuted: false
    property string lastOutputKey: ""
    property string outputLabel: ""
    property var pendingMove: null
    property int moveWorkspaceId: 0
    property string moveWorkspaceLabel: ""
    property string movedWindowTitle: ""
    readonly property bool workspaceContent: kind === "workspace" || kind === "window-move"
    readonly property var workspace: Hyprland.focusedWorkspace
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink?.ready ? sink.audio : null
    readonly property var sourceAudio: source?.ready ? source.audio : null
    readonly property string outputKey: sink?.ready ? (sink.name || String(sink.id)) : ""
    readonly property string feedbackTitle: kind === "microphone" ? "MICROPHONE" : "AUDIO OUTPUT"
    readonly property string feedbackValue: kind === "microphone" ? (microphoneMuted ? "MUTED" : "UNMUTED") : outputLabel
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
                && nextId !== lastWorkspaceId
                && !(shown && kind === "window-move" && nextId === moveWorkspaceId))
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

    // Compositor events cover silent moves from keybindings and other clients,
    // as well as the overview. A rejected request never emits this event.
    function queueWindowMove(event) {
        if (event.name !== "movewindowv2") return false;
        const fields = event.data.split(",");
        const address = fields[0]?.replace(/^0x/i, "").toLowerCase();
        const id = Number(fields[1]);
        if (!/^[0-9a-f]+$/.test(address || "") || !Number.isSafeInteger(id) || id === 0) return false;
        pendingMove = {address: address, workspaceId: id, name: fields.slice(2).join(","), attempts: 0};
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        moveDelay.restart();
        return true;
    }
    function revealPendingMove() {
        const move = pendingMove;
        if (!move) return;
        const window = controls.windows.find(w => w.address.replace(/^0x/i, "").toLowerCase() === move.address);
        // Native models may update after rawEvent. Confirm the actual target
        // before showing success, with bounded retries and no IPC subprocess.
        if (!window || window.workspaceId !== move.workspaceId) {
            if (++move.attempts < 5) { moveDelay.restart(); return; }
            pendingMove = null;
            return;
        }
        const target = controls.workspaces.find(w => w.id === move.workspaceId);
        moveWorkspaceId = move.workspaceId;
        moveWorkspaceLabel = target?.name || move.name || String(move.workspaceId);
        movedWindowTitle = window.title || "Window";
        pendingMove = null;
        reveal("window-move");
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { osd.queueWindowMove(event); }
    }
    Timer { id: moveDelay; interval: 60; onTriggered: osd.revealPendingMove() }

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
            property bool surfaceReady: false
            visible: active || content.opacity > 0
            onVisibleChanged: { if (!visible) surfaceReady = false; }
            Connections {
                target: content.Window.window
                enabled: window.active && !window.surfaceReady
                function onFrameSwapped() { window.surfaceReady = true; }
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:osd"
            anchors { bottom: true }
            margins { bottom: 56 }
            implicitWidth: Math.min(card.implicitWidth + 26, Math.max(1, (modelData?.width ?? 1920) - 64))
            implicitHeight: card.implicitHeight + 14
            color: "transparent"
            mask: Region {}

            Item {
                id: content
                anchors.fill: parent
                opacity: window.active && window.surfaceReady ? 1 : 0
                transform: Translate { y: (1 - content.opacity) * 8 }
                Behavior on opacity {
                    NumberAnimation {
                        duration: window.active ? osd.style.motionHintEnter : osd.style.motionHintExit
                        easing.type: window.active ? Easing.OutCubic : Easing.InCubic
                    }
                }

                OsdCard {
                    id: card
                    anchors.centerIn: parent
                    width: window.width - 26
                    height: implicitHeight
                    implicitWidth: osd.workspaceContent ? Math.max(workspaceSummary.implicitWidth,
                        headingMetrics.advanceWidth(label), osd.kind === "window-move"
                            ? Math.min(titleMetrics.advanceWidth(osd.movedWindowTitle), 360) : 0)
                        + 2 * osd.style.spaceLg : 320
                    style: osd.style
                    label: osd.kind === "window-move" ? "MOVED TO " + osd.moveWorkspaceLabel
                        : osd.kind === "workspace" ? "WORKSPACES"
                        : osd.kind === "volume" ? "VOLUME"
                        : osd.kind === "brightness" ? "BRIGHTNESS" : osd.feedbackTitle
                    value: showProgress
                        ? (osd.muted ? "MUTED · " : "") + Math.round(Math.max(0, osd.level) * 100) + "%"
                        : osd.feedbackValue
                    caution: osd.muted || (osd.kind === "microphone" && osd.microphoneMuted)
                    showProgress: osd.kind === "volume" || osd.kind === "brightness"
                    progress: osd.level
                    customContent: osd.workspaceContent

                    FontMetrics {
                        id: headingMetrics
                        font.family: osd.style.fontFamily
                        font.pixelSize: osd.style.fontSizeBody
                    }
                    FontMetrics {
                        id: titleMetrics
                        font.family: osd.style.fontFamily
                        font.pixelSize: osd.style.fontSizeControl
                        font.weight: Font.DemiBold
                    }

                    Column {
                        width: parent.width
                        height: implicitHeight
                        spacing: osd.style.spaceXs
                        Text {
                            visible: osd.kind === "window-move"
                            width: parent.width
                            text: osd.movedWindowTitle
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: osd.style.textPrimary
                            font.family: osd.style.fontFamily
                            font.pixelSize: osd.style.fontSizeControl
                            font.weight: Font.DemiBold
                        }
                        WorkspaceSummary {
                            id: workspaceSummary
                            width: parent.width
                            height: implicitHeight
                            style: osd.style
                            searchModel: osd.searchModel
                            layoutState: osd.layoutState
                            controls: osd.controls
                            highlightedWorkspaceId: osd.kind === "window-move" ? osd.moveWorkspaceId : 0
                            interactive: false
                            padding: 0
                            color: "transparent"
                        }
                    }
                }
            }
        }
    }
}
