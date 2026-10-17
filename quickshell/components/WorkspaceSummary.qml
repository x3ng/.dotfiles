pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import Quickshell.Widgets
import ".."

Rectangle {
    id: summary
    required property Theme style
    required property var searchModel
    required property var layoutState
    property bool interactive: true
    property int padding: 9
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.toplevels.values.length > 0
            || w.id === Hyprland.focusedWorkspace?.id))
        .sort((a, b) => a.id - b.id)

    function workspaceLabel(workspace) {
        return workspace.id + "·" + layoutState.marker(workspace.id);
    }

    function workspaceWidth(workspace) {
        return Math.ceil(labelMetrics.advanceWidth(workspaceLabel(workspace)))
            + 12 + workspace.toplevels.values.length * 24;
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
                    readonly property bool active: modelData.id === Hyprland.focusedWorkspace?.id
                    width: Math.min(summary.workspaceWidth(modelData), workspaceFlow.width)
                    height: Math.max(30, icons.implicitHeight)
                    radius: summary.style.radiusControl
                    color: active ? summary.style.surfaceSelected
                        : workspaceMouse.containsMouse ? summary.style.surfaceHover : "transparent"
                    ToolTip.visible: summary.interactive && workspaceMouse.containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: summary.layoutState.label(modelData.id)
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
                            model: workspace.modelData.toplevels.values
                            Item {
                                id: app
                                required property var modelData
                                readonly property var entry: summary.searchModel.desktopEntryFor(
                                    modelData.wayland ?? {appId: modelData.lastIpcObject.initialClass
                                        || modelData.lastIpcObject.class})
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
                        onClicked: Hyprland.dispatch("hl.dsp.focus({workspace = " + workspace.modelData.id + "})")
                    }
                }
            }
        }
    }
}
