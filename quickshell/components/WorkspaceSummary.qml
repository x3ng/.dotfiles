pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Widgets

Rectangle {
    id: summary
    required property var style
    required property var searchModel
    property bool interactive: true
    readonly property var workspaces: Hyprland.workspaces.values
        .filter(w => w.id > 0 && (w.toplevels.values.length > 0
            || w.id === Hyprland.focusedWorkspace?.id))
        .sort((a, b) => a.id - b.id)

    implicitWidth: workspaceFlow.naturalWidth + 18
    implicitHeight: workspaceFlow.implicitHeight + 18
    radius: style.radiusCard
    color: style.surfaceRaised

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 9
        height: workspaceFlow.implicitHeight

        Flow {
            id: workspaceFlow
            readonly property real naturalWidth: summary.workspaces.reduce(
                (total, w) => total + 34 + w.toplevels.values.length * 26, 0)
                + Math.max(0, summary.workspaces.length - 1) * spacing
            width: Math.min(parent.width, naturalWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: summary.workspaces
                Rectangle {
                    id: workspace
                    required property var modelData
                    readonly property bool active: modelData.id === Hyprland.focusedWorkspace?.id
                    width: Math.min(34 + modelData.toplevels.values.length * 26, workspaceFlow.width)
                    height: Math.max(30, icons.implicitHeight)
                    radius: summary.style.radiusControl
                    color: active ? summary.style.surfaceSelected
                        : workspaceMouse.containsMouse ? summary.style.surfaceHover : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }

                    Flow {
                        id: icons
                        width: parent.width - 16
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            width: 18
                            height: 30
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: workspace.modelData.id
                            color: workspace.active ? summary.style.textSelected : summary.style.textSecondary
                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                            font.family: summary.style.fontFamily
                            font.pixelSize: 13
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
                                Text {
                                    anchors.centerIn: parent
                                    visible: !icon.visible
                                    text: "▣"
                                    color: summary.style.textSecondary
                                    font.pixelSize: 18
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
