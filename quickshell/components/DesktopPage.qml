pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

ColumnLayout {
    id: page
    required property Theme style
    required property var searchModel
    required property var controls
    required property var actions
    required property bool panelOpen
    // The layout picker has an explicit target; the overview always shows every workspace.
    property int selectedWorkspaceId: 0
    property string expandedAddress: ""
    // Keep inline actions with their window address, not with a disposable delegate.
    property string windowActionMode: ""
    property int pendingDismissRequestId: 0
    property string pendingDismissAddress: ""
    property bool choosingWorkspace: false
    property bool choosingLayout: false
    property int pendingWorkspaceId: 0
    property int pendingWorkspaceRequestId: 0
    readonly property var selectedWorkspace: controls.workspaces.find(w => w.id === selectedWorkspaceId) ?? null
    readonly property real naturalHeight: content.implicitHeight
    signal dismissRequested()

    function ensureSelection(reset) {
        // panelOpen can be assigned before required services during construction.
        if (!controls) return;
        if (!reset && selectedWorkspace) return;
        const workspace = controls.workspaces.find(w => w.id === controls.focusedWorkspaceId)
            ?? controls.workspaces.find(w => w.active && w.special)
            ?? controls.workspaces.find(w => w.active) ?? controls.workspaces[0];
        selectedWorkspaceId = workspace?.id ?? 0;
    }

    function focusWindow(address) {
        if (!controls.busy && controls.focusWindow(address)) {
            pendingDismissRequestId = controls.lastRequestId;
            pendingDismissAddress = address;
        }
    }

    function openWorkspace(id) {
        if (controls.focusWorkspace(id)) {
            pendingWorkspaceId = id;
            pendingWorkspaceRequestId = controls.lastRequestId;
            choosingWorkspace = false;
        }
    }

    Component.onCompleted: ensureSelection(true)
    onExpandedAddressChanged: windowActionMode = ""
    onSelectedWorkspaceIdChanged: choosingLayout = false
    onPanelOpenChanged: {
        pendingDismissRequestId = 0;
        pendingDismissAddress = "";
        pendingWorkspaceId = 0;
        pendingWorkspaceRequestId = 0;
        choosingWorkspace = false;
        choosingLayout = false;
        expandedAddress = "";
        if (panelOpen) { ensureSelection(true); viewport.contentY = 0; }
    }
    Connections {
        target: page.controls
        function onWorkspacesChanged() { page.ensureSelection(false); }
        function onWindowsChanged() {
            if (!page.controls.windows.some(w => w.address === page.expandedAddress)) page.expandedAddress = "";
            if (page.pendingDismissAddress && !page.controls.windows.some(w => w.address === page.pendingDismissAddress)) {
                page.pendingDismissRequestId = 0;
                page.pendingDismissAddress = "";
            }
        }
        function onOperationFinished(success, operation, target, requestId, message) {
            if (page.pendingWorkspaceRequestId && requestId === page.pendingWorkspaceRequestId) {
                page.pendingWorkspaceId = 0;
                page.pendingWorkspaceRequestId = 0;
                if (success && page.panelOpen) page.dismissRequested();
            }
            if (!page.pendingDismissRequestId || requestId !== page.pendingDismissRequestId) return;
            page.pendingDismissRequestId = 0;
            page.pendingDismissAddress = "";
            if (success && page.panelOpen) page.dismissRequested();
        }
    }

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        implicitHeight: content.implicitHeight
        radius: page.style.radiusCard
        color: "transparent"
        Flickable {
            id: viewport
            anchors.fill: parent
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: content
                width: viewport.width
                spacing: page.style.spaceMd

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Workspaces"
                        color: page.style.textPrimary
                        font.family: page.style.fontFamily
                        font.pixelSize: page.style.fontSizeBody
                        font.weight: Font.DemiBold
                    }
                    ChoiceButton {
                        Layout.preferredWidth: 136
                        visible: page.controls.workspaceTargets.some(w => !w.exists)
                        style: page.style
                        label: "＋ New workspace"
                        selected: page.choosingWorkspace
                        available: page.controls.available && !page.controls.busy
                        onTriggered: page.choosingWorkspace = !page.choosingWorkspace
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    visible: page.choosingWorkspace
                    spacing: page.style.spaceXs
                    Repeater {
                        model: page.controls.workspaceTargets.filter(w => !w.exists)
                        ChoiceButton {
                            required property var modelData
                            width: 44
                            style: page.style
                            label: modelData.name
                            filled: true
                            available: !page.controls.busy
                            onTriggered: page.openWorkspace(modelData.id)
                        }
                    }
                }
                Text {
                    visible: page.controls.error !== ""
                    Layout.fillWidth: true
                    text: page.controls.error
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: page.style.accentWarm
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeBody
                }
                RowLayout {
                    id: workspaceGrid
                    Layout.fillWidth: true
                    readonly property int columns: width >= 560 ? 2 : 1
                    spacing: page.style.spaceMd
                    Repeater {
                        model: workspaceGrid.columns
                        ColumnLayout {
                            id: workspaceColumn
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignTop
                            spacing: page.style.spaceMd
                            // Stable source order, independent column heights: expanding a
                            // window's actions never shifts cards into another column.
                            Repeater {
                                model: page.controls.workspaces.filter((workspace, i) => i % workspaceGrid.columns === workspaceColumn.index)
                                GroupCard {
                                    id: workspaceCard
                                    required property var modelData
                                    readonly property var windows: page.controls.windows.filter(w => w.workspaceId === modelData.id)
                                    objectName: "workspace-" + modelData.id
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.alignment: Qt.AlignTop
                                    style: page.style
                                    color: page.style.panelSurface
                                    border.color: modelData.active ? page.style.accent : page.style.separator
                                    pad: page.style.spaceSm
                                    contentSpacing: page.style.spaceXs

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: page.style.spaceXs
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 32
                                            implicitHeight: 34
                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: (workspaceCard.modelData.active ? "● " : "") + workspaceCard.modelData.name
                                                textFormat: Text.PlainText
                                                elide: Text.ElideRight
                                                color: workspaceCard.modelData.active ? page.style.accent : page.style.textPrimary
                                                font.family: page.style.fontFamily
                                                font.pixelSize: page.style.fontSizeBody
                                                font.weight: Font.DemiBold
                                            }
                                            MouseArea {
                                                objectName: "focus-workspace-" + workspaceCard.modelData.id
                                                anchors.fill: parent
                                                enabled: page.controls.available && !page.controls.busy
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: page.openWorkspace(workspaceCard.modelData.id)
                                            }
                                        }
                                        ChoiceButton {
                                            Layout.preferredWidth: Math.min(116, workspaceCard.width * 0.48)
                                            style: page.style
                                            objectName: "layout-workspace-" + workspaceCard.modelData.id
                                            label: (workspaceCard.modelData.layout ?? "—") + "  ▾"
                                            selected: page.choosingLayout && page.selectedWorkspaceId === workspaceCard.modelData.id
                                            available: page.controls.available && !page.controls.busy && !!workspaceCard.modelData.exists
                                            onTriggered: {
                                                const wasOpen = page.choosingLayout && page.selectedWorkspaceId === workspaceCard.modelData.id;
                                                page.selectedWorkspaceId = workspaceCard.modelData.id;
                                                page.choosingLayout = !wasOpen;
                                            }
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: (workspaceCard.modelData.monitor ? workspaceCard.modelData.monitor + " · " : "")
                                            + workspaceCard.windows.length + (workspaceCard.windows.length === 1 ? " window" : " windows")
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: page.style.textMuted
                                        font.family: page.style.fontFamily
                                        font.pixelSize: page.style.fontSizeSmall
                                    }
                                    GridLayout {
                                        visible: page.choosingLayout && page.selectedWorkspaceId === workspaceCard.modelData.id
                                        Layout.fillWidth: true
                                        columns: 2
                                        columnSpacing: page.style.spaceXs
                                        rowSpacing: page.style.spaceXs
                                        Repeater {
                                            model: ["dwindle", "master", "scrolling", "monocle"]
                                            ChoiceButton {
                                                required property string modelData
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: 1
                                                style: page.style
                                                label: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                                selected: workspaceCard.modelData.layout === modelData
                                                available: page.controls.available && !page.controls.busy
                                                onTriggered: {
                                                    if (page.controls.setLayout(workspaceCard.modelData.id, modelData)) page.choosingLayout = false;
                                                }
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: workspaceCard.windows
                                        DesktopWindowCard {
                                            required property var modelData
                                            objectName: "window-" + modelData.address
                                            Layout.fillWidth: true
                                            style: page.style
                                            windowData: modelData
                                            controls: page.controls
                                            searchModel: page.searchModel
                                            expanded: page.expandedAddress === modelData.address
                                            actionMode: expanded ? page.windowActionMode : ""
                                            onExpandRequested: page.expandedAddress = expanded ? "" : modelData.address
                                            onModeRequested: mode => {
                                                if (page.expandedAddress === modelData.address) page.windowActionMode = mode;
                                            }
                                            onFocusRequested: address => page.focusWindow(address)
                                        }
                                    }
                                    Item {
                                        visible: workspaceCard.windows.length === 0
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Empty workspace"
                                            color: page.style.textMuted
                                            font.family: page.style.fontFamily
                                            font.pixelSize: page.style.fontSizeSmall
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: page.controls.available && !page.controls.busy
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: page.openWorkspace(workspaceCard.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: page.controls.workspaces.length === 0
                    Layout.fillWidth: true
                    text: "No workspaces available."
                    color: page.style.textSecondary
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeBody
                }
                ChoiceButton {
                    Layout.fillWidth: true
                    style: page.style
                    label: "Lock screen"
                    filled: true
                    available: page.actions.available("lock")
                    onTriggered: {
                        if (page.actions.execute("lock")) {
                            page.pendingDismissRequestId = page.controls.lastRequestId;
                            page.pendingDismissAddress = "";
                        }
                    }
                }
            }
        }
    }
}
