pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets

Item {
    id: wsContainer
    required property var shell
    required property real regionWidth
    required property real leftEdge
    required property real rightEdge
    signal requestDismissMenus()
    property var workspaceList: []
    // Refresh title/icon bindings for title, focus and
    // toplevel lifecycle events without polling.
    property int windowRevision: 0

    // Stay on the physical screen midpoint. The shorter of
    // the two distances to the anchored side regions decides
    // the available width, so unequal side widths cannot push
    // this item off-centre.
    readonly property real collisionWidth: {
        var centre = wsContainer.regionWidth / 2;
        var leftEdge = wsContainer.leftEdge + wsContainer.shell.barSectionGap;
        var rightStart = wsContainer.rightEdge;
        var rightEdge = rightStart - wsContainer.shell.barSectionGap;
        return Math.max(0, Math.floor(2 * Math.min(
            centre - leftEdge,
            rightEdge - centre
        )));
    }
    readonly property var responsiveLayout: {
        wsContainer.windowRevision;
        wsContainer.workspaceList;
        workspaceTitleMetrics.height;
        return wsContainer.layoutForWidth(wsContainer.collisionWidth);
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(wsRow.implicitWidth, collisionWidth)
    height: 28
    // Only an irreducible number/icon strip can reach this
    // fallback. wsRow remains centred, so clipping is even.
    clip: wsRow.implicitWidth > width

    FontMetrics {
        id: workspaceTitleMetrics
        font.pixelSize: 12
    }

    function refreshWorkspaces() {
        var list = Hyprland.workspaces?.values ?? [];
        var fid = Hyprland.focusedWorkspace?.id ?? 1;
        var out = [];
        var hasFocused = false;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id > 0) {
                out.push(list[i]);
                if (list[i].id === fid) hasFocused = true;
            }
        }
        if (!hasFocused && Hyprland.focusedWorkspace)
            out.push(Hyprland.focusedWorkspace);
        out.sort(function(a, b) { return a.id - b.id; });
        workspaceList = out;
    }

    function windowsFor(workspaceId) {
        var windows = Hyprland.toplevels?.values ?? [];
        var result = [];
        for (var i = 0; i < windows.length; i++) {
            if (windows[i].workspace?.id === workspaceId)
                result.push(windows[i]);
        }
        return result;
    }

    function measuredTitleWidth(title) {
        var value = title ?? "";
        return Math.ceil(Math.max(
            workspaceTitleMetrics.advanceWidth(value),
            workspaceTitleMetrics.boundingRect(value).width
        )) + 1;
    }

    function estimatedWidth(titleCap, showInactiveTitles, showActiveTitles) {
        var focusedId = Hyprland.focusedWorkspace?.id ?? -1;
        var total = 0;
        for (var i = 0; i < workspaceList.length; i++) {
            var workspace = workspaceList[i];
            var active = workspace.id === focusedId;
            var showTitles = active ? showActiveTitles : showInactiveTitles;
            var windows = windowsFor(workspace.id);
            // 20 px number badge, followed by one stable 16 px
            // application icon slot for every toplevel.
            var contents = 20;
            for (var j = 0; j < windows.length; j++) {
                contents += 5 + 16;
                var title = windows[j].title ?? "";
                if (showTitles && title !== "") {
                    var natural = measuredTitleWidth(title);
                    contents += 4 + (titleCap < 0 ? natural : Math.min(titleCap, natural));
                }
            }
            total += Math.max(23, contents + 14);
            if (i > 0) total += 3;
        }
        return total;
    }

    function largestTitleWidth(showInactiveTitles, showActiveTitles) {
        var focusedId = Hyprland.focusedWorkspace?.id ?? -1;
        var largest = 0;
        for (var i = 0; i < workspaceList.length; i++) {
            var active = workspaceList[i].id === focusedId;
            if (!(active ? showActiveTitles : showInactiveTitles)) continue;
            var windows = windowsFor(workspaceList[i].id);
            for (var j = 0; j < windows.length; j++)
                largest = Math.max(largest, measuredTitleWidth(windows[j].title));
        }
        return largest;
    }

    function fittedTitleCap(available, minimum, showInactiveTitles, showActiveTitles) {
        var high = largestTitleWidth(showInactiveTitles, showActiveTitles);
        if (high <= minimum) return high;
        var low = minimum;
        // Short labels are unaffected by a uniform cap, so
        // longer labels naturally elide before shorter ones.
        for (var i = 0; i < 12; i++) {
            var mid = (low + high) / 2;
            if (estimatedWidth(mid, showInactiveTitles, showActiveTitles) <= available)
                low = mid;
            else
                high = mid;
        }
        return Math.floor(low);
    }

    function layoutForWidth(available) {
        if (estimatedWidth(-1, true, true) <= available)
            return { titleCap: -1, showInactiveTitles: true, showActiveTitles: true };

        // First keep all titles and progressively shorten only
        // those that exceed the calculated common cap.
        var allTitleFloor = 34;
        if (estimatedWidth(allTitleFloor, true, true) <= available) {
            return {
                titleCap: fittedTitleCap(available, allTitleFloor, true, true),
                showInactiveTitles: true,
                showActiveTitles: true
            };
        }

        // Then drop inactive titles. Preserve the active title
        // at natural width when possible, and elide it further
        // only when that is required to avoid a collision.
        if (estimatedWidth(-1, false, true) <= available)
            return { titleCap: -1, showInactiveTitles: false, showActiveTitles: true };

        var activeTitleFloor = 24;
        if (estimatedWidth(activeTitleFloor, false, true) <= available) {
            return {
                titleCap: fittedTitleCap(available, activeTitleFloor, false, true),
                showInactiveTitles: false,
                showActiveTitles: true
            };
        }

        // Workspace numbers and app icons are the final layer
        // retained on very narrow screens.
        return { titleCap: 0, showInactiveTitles: false, showActiveTitles: false };
    }

    Component.onCompleted: refreshWorkspaces()

    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() { wsContainer.refreshWorkspaces(); }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { wsContainer.refreshWorkspaces(); }
        function onRawEvent() {
            wsContainer.windowRevision += 1;
        }
    }
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { wsContainer.windowRevision += 1; }
    }

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: wsContainer.workspaceList

            Rectangle {
                id: workspaceDelegate
                required property var modelData
                property bool isActive: Hyprland.focusedWorkspace?.id === modelData.id
                property var workspaceWindows: {
                    wsContainer.windowRevision;
                    return wsContainer.windowsFor(modelData.id);
                }
                readonly property bool hasWindows: workspaceWindows.length > 0

                implicitWidth: workspaceContents.implicitWidth + 14
                width: Math.max(23, implicitWidth)
                height: 26
                // Keep workspaces flat: state is communicated
                // by text and the active underline below.
                color: "transparent"

                HoverSurface {
                    style: wsContainer.shell
                    hovered: wsMouse.containsMouse
                    radius: wsContainer.shell.radiusSmall
                }

                scale: wsMouse.pressed ? 0.97 : 1
                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 10
                    height: 2
                    radius: 1
                    color: wsContainer.shell.accent
                    visible: workspaceDelegate.isActive
                }

                Row {
                    id: workspaceContents
                    anchors.centerIn: parent
                    spacing: 5

                    Item {
                        width: 20; height: 20

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: workspaceDelegate.modelData.id
                            color: workspaceDelegate.isActive
                                ? wsContainer.shell.accent
                                : (wsMouse.containsMouse ? wsContainer.shell.textPrimary : wsContainer.shell.textSecondary)
                            font.pixelSize: 13
                            font.weight: Font.Bold

                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }

                    Repeater {
                        model: workspaceDelegate.workspaceWindows

                        Row {
                            id: windowEntry
                            required property var modelData
                            property var desktopEntry: wsContainer.shell.desktopEntryFor(modelData)
                            spacing: 4

                            // Reserve the icon cell while the
                            // desktop icon resolves, keeping
                            // measurements and layout stable.
                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 16
                                    source: wsContainer.shell.desktopIconSource(windowEntry.desktopEntry)
                                    visible: source !== "" && status !== Image.Error
                                }
                            }

                            Text {
                                // Every open toplevel gets its own compact
                                // identifier, rather than representing an
                                // entire workspace with its focused window.
                                text: windowEntry.modelData.title
                                visible: text !== "" && (workspaceDelegate.isActive
                                    ? wsContainer.responsiveLayout.showActiveTitles
                                    : wsContainer.responsiveLayout.showInactiveTitles)
                                width: wsContainer.responsiveLayout.titleCap < 0
                                    ? implicitWidth
                                    : Math.min(wsContainer.responsiveLayout.titleCap, implicitWidth)
                                elide: Text.ElideRight
                                color: workspaceDelegate.isActive ? wsContainer.shell.textPrimary : wsContainer.shell.textSecondary
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                MouseArea {
                    id: wsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wsContainer.requestDismissMenus();
                        if (Hyprland.usingLua)
                            Hyprland.dispatch("hl.dsp.focus({workspace = " + workspaceDelegate.modelData.id + "})");
                        else
                            Hyprland.dispatch("workspace " + workspaceDelegate.modelData.id);
                    }
                }
            }
        }

    } // wsRow
} // workspace Item
