pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Widgets
import ".."

Rectangle {
    id: summary
    required property Theme style
    required property var searchModel
    required property var layoutState
    required property var controls
    property bool interactive: true
    property int padding: 9
    property int highlightedWorkspaceId: 0
    // Focus/title updates must not reset the nested Repeaters and reload all
    // icons during a workspace animation. Publish only structural icon data;
    // active styling and layout labels retain their own live bindings.
    property var workspaces: []
    readonly property var structureSnapshot: controls.workspaces
        .filter(w => (w.id > 0 && (w.windowCount > 0
            || w.id === controls.focusedWorkspaceId)) || w.id === highlightedWorkspaceId)
        .map(w => ({id: w.id, name: w.name, windows: controls.windows
            .filter(window => window.workspaceId === w.id)
            .map(window => ({address: window.address, appId: window.appId}))
            .sort((a, b) => a.address.localeCompare(b.address))}))
        .sort((a, b) => a.id - b.id)
    onStructureSnapshotChanged: structureDelay.restart()
    Component.onCompleted: structureDelay.restart()
    Timer {
        id: structureDelay
        interval: 0
        onTriggered: {
            if (JSON.stringify(summary.workspaces) !== JSON.stringify(summary.structureSnapshot))
                summary.workspaces = summary.structureSnapshot;
        }
    }

    function workspaceLabel(workspace) {
        const name = workspace.id > 0 ? workspace.id : workspace.name.replace(/^special:/, "");
        return name + "·" + layoutState.marker(workspace.id);
    }

    function workspaceWidth(workspace) {
        return Math.ceil(labelMetrics.advanceWidth(workspaceLabel(workspace)))
            + 12 + workspace.windows.length * 24;
    }

    FontMetrics {
        id: labelMetrics
        font.family: summary.style.fontFamily
        font.pixelSize: summary.style.fontSizeControl
        font.weight: Font.DemiBold
    }

    implicitWidth: workspaceFlow.naturalWidth + 2 * padding
    implicitHeight: workspaceFlow.implicitHeight + 2 * padding
    radius: style.radiusCard
    color: style.surfaceRaised

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: summary.padding
        height: workspaceFlow.implicitHeight

        Flow {
            id: workspaceFlow
            readonly property real naturalWidth: summary.workspaces.reduce(
                (total, w) => total + summary.workspaceWidth(w), 0)
                + Math.max(0, summary.workspaces.length - 1) * spacing
            width: Math.min(parent.width, naturalWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Repeater {
                model: summary.workspaces
                Rectangle {
                    id: workspace
                    required property var modelData
                    readonly property bool active: modelData.id === summary.controls.focusedWorkspaceId
                    width: Math.min(summary.workspaceWidth(modelData), workspaceFlow.width)
                    height: Math.max(30, icons.implicitHeight)
                    radius: summary.style.radiusControl
                    border.width: modelData.id === summary.highlightedWorkspaceId ? 1 : 0
                    border.color: summary.style.accent
                    color: active ? summary.style.surfaceSelected
                        : workspaceMouse.containsMouse ? summary.style.surfaceHover : "transparent"
                    ShellToolTip {
                        style: summary.style
                        visible: summary.interactive && workspaceMouse.containsMouse
                        text: summary.layoutState.label(workspace.modelData.id)
                    }
                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Flow {
                        id: icons
                        width: parent.width - 12
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            width: Math.ceil(implicitWidth)
                            height: 30
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: summary.workspaceLabel(workspace.modelData)
                            textFormat: Text.PlainText
                            color: workspace.active ? summary.style.textSelected : summary.style.textPrimary
                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                            font.family: summary.style.fontFamily
                            font.pixelSize: summary.style.fontSizeControl
                            font.weight: Font.DemiBold
                        }
                        Repeater {
                            model: workspace.modelData.windows
                            Item {
                                id: app
                                required property var modelData
                                readonly property var entry: summary.searchModel.desktopEntryFor({appId: modelData.appId})
                                width: 20
                                height: 30
                                IconImage {
                                    id: icon
                                    anchors.centerIn: parent
                                    implicitSize: 20
                                    source: summary.searchModel.desktopIconSource(app.entry)
                                    visible: source !== "" && status !== Image.Error
                                }
                                StatusIcon {
                                    anchors.centerIn: parent
                                    visible: !icon.visible
                                    kind: "window"
                                    width: 18
                                    height: 18
                                    ink: summary.style.textSecondary
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: workspaceMouse
                        enabled: summary.interactive
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: summary.controls.focusWorkspace(workspace.modelData.id)
                    }
                }
            }
        }
    }
}
