pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

// One stable desktop summary. Complete lists remain in the existing pages;
// opening a device editor never copies its state into this view.
ColumnLayout {
    id: page
    required property Theme style
    required property var services
    required property var actions
    required property var appearance
    required property var notifs
    required property var searchModel
    required property var controls
    required property bool panelOpen
    // Retain the last page snapshot while closed; background focus changes
    // must not rebuild invisible workspace and window delegates.
    property var displayedWorkspaces: []
    property var displayedWindows: []
    Binding {
        target: page; property: "displayedWorkspaces"
        value: page.controls.workspaces
        when: page.panelOpen
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: page; property: "displayedWindows"
        value: page.controls.windows
        when: page.panelOpen
        restoreMode: Binding.RestoreNone
    }
    signal dismissRequested
    readonly property real naturalHeight: content.implicitHeight
    readonly property var system: services.controls
    readonly property var player: services.player
    readonly property var sink: services.sink
    property bool choosingPower: false
    property int pendingWorkspaceRequestId: 0

    function profileLabel(profile) {
        return profile === "power-saver" ? "Saver" : profile === "performance" ? "Performance" : profile === "balanced" ? "Balanced" : profile || "Power";
    }
    function openWorkspace(id) {
        if (!controls.busy && controls.focusWorkspace(id))
            pendingWorkspaceRequestId = controls.lastRequestId;
    }
    onPanelOpenChanged: {
        pendingWorkspaceRequestId = 0;
        choosingPower = false;
        if (panelOpen)
            viewport.contentY = 0;
    }
    Connections {
        target: page.controls
        function onOperationFinished(success, operation, target, requestId, message) {
            if (!page.pendingWorkspaceRequestId || requestId !== page.pendingWorkspaceRequestId)
                return;
            page.pendingWorkspaceRequestId = 0;
            if (success && page.panelOpen)
                page.dismissRequested();
        }
    }

    // The scroll viewport is rectangular: only each control clips its own corners.
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        implicitHeight: page.naturalHeight
        Flickable {
            id: viewport
            objectName: "overview-scroll"
            anchors.fill: parent
            contentWidth: width
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: content
                width: viewport.width
                spacing: page.style.spaceSm

                ColumnLayout {
                    id: mainContent
                    Layout.fillWidth: true
                    spacing: page.style.spaceSm
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            spacing: page.style.spaceXs
                            Repeater {
                                model: page.displayedWorkspaces
                                ChoiceButton {
                                    id: workspaceChip
                                    required property var modelData
                                    readonly property var apps: [...new Set(page.displayedWindows.filter(w => w.workspaceAddress === modelData.address).map(w => w.appId))].slice(0, 2)
                                    objectName: "overview-workspace-" + modelData.address
                                    width: modelData.special ? 108 : (String(modelData.name || modelData.address).length > 1 ? 40 : 32) + apps.length * 18
                                    height: 36
                                    style: page.style
                                    label: ""
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: page.style.spaceSm
                                        spacing: page.style.spaceXs
                                        Text {
                                            Layout.fillWidth: true
                                            text: String(workspaceChip.modelData.name || workspaceChip.modelData.address).replace(/^special:/, "")
                                            elide: Text.ElideRight
                                            color: workspaceChip.selected ? page.style.textPrimary : page.style.textSecondary
                                            font.family: page.style.fontFamily
                                            font.pixelSize: page.style.fontSizeBody
                                            font.weight: workspaceChip.selected ? Font.DemiBold : Font.Normal
                                        }
                                        Repeater {
                                            model: workspaceChip.apps
                                            Item {
                                                required property string modelData
                                                Layout.preferredWidth: 17
                                                Layout.preferredHeight: 17
                                                IconImage {
                                                    id: appIcon
                                                    anchors.fill: parent
                                                    source: page.searchModel.desktopIconSource(page.searchModel.desktopEntryFor({
                                                        appId: parent.modelData
                                                    }))
                                                    visible: source !== "" && status !== Image.Error
                                                }
                                                StatusIcon {
                                                    anchors.fill: parent
                                                    visible: !appIcon.visible
                                                    kind: "window"
                                                    ink: page.style.textMuted
                                                }
                                            }
                                        }
                                    }
                                    tooltip: "Workspace " + (modelData.name || modelData.address) + " · " + (modelData.windowCount ?? 0) + " windows"
                                    selected: modelData.address === page.controls.focusedWorkspaceAddress
                                    filled: true
                                    available: page.controls.available && !page.controls.busy
                                    onTriggered: page.openWorkspace(modelData.address)
                                }
                            }
                        }
                        ChoiceButton {
                            objectName: "overview-windows"
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 36
                            style: page.style
                            label: ""
                            Accessible.name: "All windows"
                            iconKind: "window"
                            tooltip: "All windows · manage workspaces and layouts"
                            onTriggered: page.actions.execute("desktop")
                        }
                    }

                    DesktopControls {
                        Layout.fillWidth: true
                        style: page.style
                        actions: page.actions
                        services: page.services
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: page.style.spaceSm
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: page.style.spaceXs
                            ChoiceButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 36
                                style: page.style
                                label: ""
                                iconKind: "volume"
                                selected: page.sink?.audio?.muted ?? false
                                tooltip: selected ? "Unmute output" : "Mute output"
                                available: page.actions.available("output-mute")
                                onTriggered: page.actions.execute("output-mute")
                            }
                            FilledSlider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                style: page.style
                                label: page.sink?.audio?.muted ? "Muted" : "Volume"
                                value: page.sink?.audio?.volume ?? 0
                                available: !!page.sink?.audio
                                onEdited: value => page.services.setVolume(value)
                            }
                            ChoiceButton {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 36
                                style: page.style
                                label: ""
                                iconKind: "headphones"
                                tooltip: "Audio devices · " + (page.sink?.description || "Choose output or microphone")
                                onTriggered: page.actions.execute("audio")
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: page.style.spaceXs
                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 36
                                StatusIcon {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    kind: "brightness"
                                    ink: page.style.textMuted
                                }
                            }
                            FilledSlider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                style: page.style
                                label: "Brightness"
                                value: Math.max(0, page.services.brightness)
                                available: page.services.brightness >= 0
                                onEdited: value => page.services.setBrightness(value)
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 440 ? 4 : 2
                        columnSpacing: page.style.spaceXs
                        rowSpacing: page.style.spaceXs
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            iconKind: page.appearance.darkMode ? "moon" : "brightness"
                            label: !page.appearance.appearanceKnown ? "Appearance" : page.appearance.darkMode ? "Dark" : "Light"
                            tooltip: page.appearance.appearanceError || "Change appearance"
                            available: page.actions.available("dark") && page.actions.available("light")
                            onTriggered: page.actions.execute(page.appearance.darkMode ? "light" : "dark")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            iconKind: "eye"
                            label: page.services.keepAwake ? "Awake: on" : "Awake: off"
                            tone: "toggle"
                            selected: page.services.keepAwake
                            tooltip: page.services.keepAwake ? "Automatic locking and screen power-off are paused" : "Keep awake · prevent automatic locking and screen power-off"
                            available: page.actions.available("keep-awake")
                            onTriggered: page.actions.execute("keep-awake")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            iconKind: "mic"
                            label: !page.services.source?.audio ? "Mic: —" : page.services.source.audio.muted ? "Mic: muted" : "Mic: on"
                            selected: page.services.source?.audio?.muted ?? false
                            tooltip: selected ? "Unmute microphone" : "Mute microphone"
                            available: page.actions.available("mic-mute")
                            onTriggered: page.actions.execute("mic-mute")
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 36
                            style: page.style
                            filled: true
                            iconKind: "gauge"
                            label: page.profileLabel(page.system.powerProfile)
                            tooltip: "Power profile"
                            selected: page.choosingPower
                            available: page.system.powerAvailable && page.system.powerProfiles.length > 0
                            onTriggered: page.choosingPower = !page.choosingPower
                        }
                    }
                    RowLayout {
                        visible: page.choosingPower
                        Layout.fillWidth: true
                        spacing: page.style.spaceXs
                        Repeater {
                            model: page.system.powerProfiles
                            ChoiceButton {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 32
                                style: page.style
                                label: page.profileLabel(modelData)
                                selected: page.system.powerProfile === modelData
                                available: page.actions.available("power:" + modelData)
                                onTriggered: {
                                    if (page.actions.execute("power:" + modelData))
                                        page.choosingPower = false;
                                }
                            }
                        }
                    }

                    // Only real playback earns a content row. Its bounded height
                    // keeps title changes from shifting controls.
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        visible: !!page.player
                        radius: page.style.radiusCard
                        color: page.style.surfaceRaised
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: page.style.spaceSm
                            spacing: page.style.spaceSm
                            ClippingRectangle {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                radius: page.style.radiusControl
                                color: page.style.surfaceHover
                                Image {
                                    id: cover
                                    anchors.fill: parent
                                    source: page.player?.trackArtUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }
                                StatusIcon {
                                    anchors.centerIn: parent
                                    width: 22
                                    height: 22
                                    visible: !cover.visible
                                    kind: "music"
                                    ink: page.style.textMuted
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: page.style.spaceXs
                                Text {
                                    Layout.fillWidth: true
                                    text: page.player?.trackTitle || page.player?.identity || "No media playing"
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: page.style.textPrimary
                                    font.family: page.style.fontFamily
                                    font.pixelSize: page.style.fontSizeSmall
                                    font.weight: Font.Medium
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: page.player?.trackArtist || page.player?.identity || "Playback controls appear here"
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: page.style.textMuted
                                    font.family: page.style.fontFamily
                                    font.pixelSize: page.style.fontSizeCaption
                                }
                            }
                            Row {
                                visible: !!page.player
                                spacing: 2
                                ChoiceButton {
                                    width: 28
                                    height: 36
                                    style: page.style
                                    label: ""
                                    iconKind: "prev"
                                    tooltip: "Previous track"
                                    available: page.player?.canGoPrevious ?? false
                                    onTriggered: page.player?.previous()
                                }
                                ChoiceButton {
                                    width: 32
                                    height: 36
                                    style: page.style
                                    label: ""
                                    iconKind: page.player?.isPlaying ? "pause" : "play"
                                    tooltip: page.player?.isPlaying ? "Pause" : "Play"
                                    available: page.player?.canTogglePlaying ?? false
                                    onTriggered: page.player?.togglePlaying()
                                }
                                ChoiceButton {
                                    width: 28
                                    height: 36
                                    style: page.style
                                    label: ""
                                    iconKind: "next"
                                    tooltip: "Next track"
                                    available: page.player?.canGoNext ?? false
                                    onTriggered: page.player?.next()
                                }
                            }
                        }
                    }
                }


            }
        }
    }
}
