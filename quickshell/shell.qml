//@ pragma UseQApplication
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
// Reusable visual components live beside the deployed entry point.
import "components"

ShellRoot {
    id: root

    Theme { id: theme }

    // Compatibility aliases keep the bar logic concise while Theme.qml owns
    // the visual system in one place.
    readonly property alias barHeight: theme.barHeight
    readonly property alias barReservedHeight: theme.barReservedHeight
    readonly property alias barOuterMarginX: theme.barOuterMarginX
    readonly property alias barBackgroundPaddingX: theme.barBackgroundPaddingX
    readonly property alias barBackgroundHeight: theme.barBackgroundHeight
    readonly property alias barSectionGap: theme.barSectionGap
    readonly property alias radiusBar: theme.radiusBar
    readonly property alias radiusPopup: theme.radiusPopup
    readonly property alias radiusCard: theme.radiusCard
    readonly property alias radiusControl: theme.radiusControl
    readonly property alias radiusSmall: theme.radiusSmall
    readonly property alias barBackgroundOpacity: theme.barBackgroundOpacity
    readonly property alias darkMode: theme.darkMode
    readonly property alias modeLabel: theme.modeLabel
    readonly property alias surface: theme.surface
    readonly property alias barSurface: theme.barSurface
    readonly property alias surfaceRaised: theme.surfaceRaised
    readonly property alias surfaceHover: theme.surfaceHover
    readonly property alias outline: theme.outline
    readonly property alias separator: theme.separator
    readonly property alias textPrimary: theme.textPrimary
    readonly property alias textSecondary: theme.textSecondary
    readonly property alias textMuted: theme.textMuted
    readonly property alias accent: theme.accent
    readonly property alias accentWarm: theme.accentWarm
    readonly property alias positive: theme.positive
    readonly property alias accentInk: theme.accentInk
    readonly property alias warning: theme.warning
    readonly property alias critical: theme.critical
    readonly property alias fontSizeSmall: theme.fontSizeSmall
    readonly property alias fontSizeMedium: theme.fontSizeMedium
    readonly property alias fontSizeLarge: theme.fontSizeLarge
    readonly property alias fontFamily: theme.fontFamily
    readonly property alias iconSizeSmall: theme.iconSizeSmall
    readonly property alias separatorHeight: theme.separatorHeight

    // Quick tools are global even though each monitor owns its own menu.
    // Keep-awake intentionally resets with Quickshell to avoid an inhibitor
    // being forgotten across sessions.
    property bool keepAwake: false

    function toggleMicMute() {
        var audio = Pipewire.defaultAudioSource?.audio;
        if (audio) audio.muted = !audio.muted;
    }

    function toggleTheme() {
        theme.toggle();
    }

    function cyclePowerProfile() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver) {
            PowerProfiles.profile = PowerProfile.Balanced;
        } else if (PowerProfiles.profile === PowerProfile.Balanced
                   && PowerProfiles.hasPerformanceProfile) {
            PowerProfiles.profile = PowerProfile.Performance;
        } else {
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }

    function powerProfileLabel() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver) return "SAVER";
        if (PowerProfiles.profile === PowerProfile.Performance) return "PERFORMANCE";
        return "BALANCED";
    }

    function setVolume(value) {
        var audio = Pipewire.defaultAudioSink?.audio;
        if (audio) audio.volume = Math.max(0, Math.min(1, value));
    }

    function durationLabel(seconds) {
        if (!seconds || seconds <= 0) return "";
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        if (hours > 0) return hours + "H " + minutes + "M";
        return Math.max(1, minutes) + "M";
    }

    function batteryDetail(device) {
        if (!device) return "UNAVAILABLE";
        if (device.state === UPowerDeviceState.Charging) {
            var untilFull = durationLabel(device.timeToFull);
            return untilFull ? "CHARGING · " + untilFull + " TO FULL" : "CHARGING";
        }
        if (device.state === UPowerDeviceState.Discharging) {
            var remaining = durationLabel(device.timeToEmpty);
            return remaining ? "DISCHARGING · " + remaining + " LEFT" : "DISCHARGING";
        }
        if (device.state === UPowerDeviceState.FullyCharged) return "FULLY CHARGED";
        return "BATTERY";
    }

    // ── Bar visibility per monitor ──────────────────────────────────
    property var monitorBarState: ({})

    function getBarVisible(monitorName) {
        if (!monitorName) return true;
        return root.monitorBarState[monitorName] ?? true;
    }

    function setBarVisible(monitorName, visible) {
        if (!monitorName) return;
        var s = Object.assign({}, root.monitorBarState);
        s[monitorName] = visible;
        root.monitorBarState = s;
    }

    function toggleBarVisible(monitorName) {
        if (!monitorName) return;
        setBarVisible(monitorName, !getBarVisible(monitorName));
    }

    function dispatch(command) {
        // Quickshell handles both Hyprland IPC transports itself. Passing a
        // JSON-encoded string to the new Lua transport makes it evaluate the
        // quoted text as Lua instead of treating it as a dispatcher request.
        Hyprland.dispatch(command);
    }

    function normalizedDesktopId(value) {
        return (value ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function desktopEntryFor(toplevel) {
        var ipc = toplevel?.lastIpcObject ?? toplevel ?? {};
        var candidates = [toplevel?.wayland?.appId, ipc.initialClass, ipc.class];
        for (var i = 0; i < candidates.length; i++) {
            if (!candidates[i]) continue;
            var exact = DesktopEntries.heuristicLookup(candidates[i]);
            if (exact) return exact;
        }

        var wanted = root.normalizedDesktopId(candidates[0] || candidates[1]);
        if (!wanted) return null;
        var entries = DesktopEntries.applications?.values ?? [];
        for (var j = 0; j < entries.length; j++) {
            var entry = entries[j];
            if (root.normalizedDesktopId(entry.id) === wanted
                || root.normalizedDesktopId(entry.startupClass) === wanted)
                return entry;
        }
        return null;
    }

    function desktopIconSource(entry) {
        var icon = entry?.icon ?? "";
        if (!icon) return "";
        return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon;
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            if (Hyprland.focusedMonitor)
                root.toggleBarVisible(Hyprland.focusedMonitor.name);
        }
    }

    // ── Brightness — event-driven via kernel uevent ─────────────────
    property real brightness: -1   // 0.0~1.0, -1 = not initialized
    property int brightnessMax: 0
    property bool brightnessSetting: false

    Process {
        id: brightnessReadProc
        command: ["sh", "-c", "echo \"$(brightnessctl g) $(brightnessctl m)\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(/\s+/);
                if (p.length >= 2) {
                    root.brightnessMax = parseInt(p[1]);
                    if (root.brightnessMax > 0)
                        root.brightness = parseInt(p[0]) / root.brightnessMax;
                }
            }
        }
    }

    Process {
        id: brightnessWatcher
        command: ["udevadm", "monitor", "--subsystem-match=backlight", "--kernel"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (!root.brightnessSetting) brightnessDebounce.restart();
            }
        }
        onExited: (code, status) => {
            // Restart if it exits unexpectedly (e.g. udev restart)
            if (code !== 0) {
                watcherRestart.restart();
            }
        }
    }
    Timer {
        id: watcherRestart
        interval: 2000
        onTriggered: brightnessWatcher.running = true
    }

    Timer {
        id: brightnessDebounce
        interval: 50
        onTriggered: brightnessReadProc.running = true
    }

    function setBrightness(value) {
        value = Math.max(0, Math.min(1, value));
        var pct = Math.max(1, Math.round(value * 100));
        root.brightnessSetting = true;
        root.brightness = value;
        Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s", pct + "%", "--quiet"]);
        // Clear guard after a short delay (no Process reuse needed)
        brightnessGuardReset.restart();
    }

    Timer {
        id: brightnessGuardReset
        interval: 200
        onTriggered: root.brightnessSetting = false
    }

    // ── Bar per monitor ─────────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property ShellScreen modelData
            screen: modelData

            property bool isVisible: root.getBarVisible(modelData.name)
            // Keep the layer surface alive until its contents have faded out.
            // Collapsing its geometry while still visible makes the compositor
            // animate a final frame whose children have converged at x = 0.
            property bool surfaceVisible: true
            property real visibilityProgress: 1
            property bool trayExpanded: false
            readonly property var trayItems: SystemTray.items?.values ?? []
            readonly property bool hasTrayItems: trayItems.length > 0
            readonly property bool trayNeedsAttention: {
                for (var i = 0; i < trayItems.length; i++) {
                    if (trayItems[i].status === Status.NeedsAttention)
                        return true;
                }
                return false;
            }

            onHasTrayItemsChanged: {
                if (!hasTrayItems) {
                    trayExpanded = false;
                    trayMenuPopup.dismiss();
                }
            }

            onTrayItemsChanged: {
                if (!trayMenuPopup.owner) return;
                var ownerStillPresent = false;
                for (var i = 0; i < trayItems.length; i++) {
                    if (trayItems[i] === trayMenuPopup.owner) {
                        ownerStillPresent = true;
                        break;
                    }
                }
                if (!ownerStillPresent) trayMenuPopup.dismiss();
            }

            function openTrayMenu(owner, anchorRight) {
                var opened = trayMenuPopup.openFor(owner, anchorRight);
                if (opened) {
                    calendarPopup.dismiss();
                    quickToolsPopup.dismiss();
                    statusPopup.dismiss();
                }
                return opened;
            }

            function closeTrayMenu() {
                trayMenuPopup.dismiss();
            }

            onIsVisibleChanged: {
                visibilityAnimation.stop();
                if (isVisible) {
                    surfaceVisible = true;
                    visibilityAnimation.to = 1;
                } else {
                    trayExpanded = false;
                    closeTrayMenu();
                    calendarPopup.dismiss();
                    quickToolsPopup.dismiss();
                    statusPopup.dismiss();
                    visibilityAnimation.to = 0;
                }
                visibilityAnimation.start();
            }

            Component.onCompleted: {
                surfaceVisible = isVisible;
                visibilityProgress = isVisible ? 1 : 0;
            }

            NumberAnimation {
                id: visibilityAnimation
                target: bar
                property: "visibilityProgress"
                duration: 150
                easing.type: Easing.OutCubic
                onFinished: {
                    if (!bar.isVisible && bar.visibilityProgress <= 0)
                        bar.surfaceVisible = false;
                }
            }

            IdleInhibitor {
                window: bar
                enabled: root.keepAwake
            }

            surfaceFormat.opaque: false
            // Reserve space while the bar is shown so maximized windows and
            // readers never sit underneath it. `bar toggle` releases the
            // reservation again on the focused monitor.
            exclusiveZone: isVisible ? root.barReservedHeight : 0
            aboveWindows: true
            focusable: true
            anchors { top: true; left: true; right: true }
            implicitHeight: surfaceVisible ? root.barHeight : 0
            color: "transparent"

            // Match pointer input to the floating surface, leaving the outer
            // screen margins transparent and click-through.
            mask: Region { item: bar.isVisible ? inputRegion : null }

            Item {
                id: inputRegion
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -6 * (1 - bar.visibilityProgress)
                width: bar.surfaceVisible ? Math.max(0, bar.width - root.barOuterMarginX * 2) : 0
                height: bar.surfaceVisible ? root.barBackgroundHeight : 0
                opacity: bar.visibilityProgress

                Rectangle {
                    id: bgRect
                    anchors.fill: parent
                    radius: root.radiusBar
                    color: root.barSurface
                    opacity: root.barBackgroundOpacity
                    border.width: 1
                    border.color: root.outline
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: bar.trayExpanded
                    acceptedButtons: Qt.LeftButton
                    onClicked: bar.trayExpanded = false
                }

                // ── Workspaces ────────────────────────────────────
                Item {
                    id: wsContainer
                    property var workspaceList: []
                    // Refresh title/icon bindings for title, focus and
                    // toplevel lifecycle events without polling.
                    property int windowRevision: 0

                    // Stay on the physical screen midpoint. The shorter of
                    // the two distances to the anchored side regions decides
                    // the available width, so unequal side widths cannot push
                    // this item off-centre.
                    readonly property real collisionWidth: {
                        var centre = inputRegion.width / 2;
                        var leftEdge = clock.x + clock.width + root.barSectionGap;
                        var rightStart = trayToggle.visible ? trayToggle.x : statusGroup.x;
                        var rightEdge = rightStart - root.barSectionGap;
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
                                    style: root
                                    hovered: wsMouse.containsMouse
                                    radius: root.radiusSmall
                                }

                                scale: wsMouse.pressed ? 0.97 : 1
                                Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 10
                                    height: 2
                                    radius: 1
                                    color: root.accent
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
                                                ? root.accent
                                                : (wsMouse.containsMouse ? root.textPrimary : root.textSecondary)
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
                                            property var desktopEntry: root.desktopEntryFor(modelData)
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
                                                    source: root.desktopIconSource(windowEntry.desktopEntry)
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
                                                color: workspaceDelegate.isActive ? root.textPrimary : root.textSecondary
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
                                        bar.trayExpanded = false;
                                        bar.closeTrayMenu();
                                        calendarPopup.dismiss();
                                        quickToolsPopup.dismiss();
                                        statusPopup.dismiss();
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

                // ── Left: date and time ─────────────────────────────
                Item {
                    id: clock
                    implicitWidth: clockRow.implicitWidth + 14
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight
                    anchors.left: parent.left
                    anchors.leftMargin: root.barBackgroundPaddingX
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: root
                        hovered: clockMouse.containsMouse
                        radius: root.radiusSmall
                    }

                    Row {
                        id: clockRow
                        spacing: 7
                        anchors.centerIn: parent

                        Text {
                            id: clockDate
                            color: root.textPrimary
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: clockTime
                            color: root.textPrimary
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    function refresh() {
                        var now = new Date();
                        clockTime.text = Qt.formatDateTime(now, "HH:mm");
                        clockDate.text = Qt.formatDateTime(now, "MM/dd · ddd");
                    }
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.refresh() }
                    Component.onCompleted: refresh()

                    MouseArea {
                        id: clockMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = calendarPopup.open
                        onClicked: {
                            if (wasOpenOnPress) {
                                calendarPopup.dismiss();
                            } else {
                                bar.trayExpanded = false;
                                bar.closeTrayMenu();
                                quickToolsPopup.dismiss();
                                statusPopup.dismiss();
                                calendarPopup.showCalendar();
                            }
                        }
                    }
                }

                CalendarPopup {
                    id: calendarPopup
                    style: root
                    barWindow: bar
                    anchorX: inputRegion.x + clock.x
                }

                // ── Right: fixed system status ──────────────────────
                // A single readable overview keeps every value visible
                // without forcing three tiny rows into a short bar.
                Item {
                    id: statusGroup
                    property var sink: Pipewire.defaultAudioSink
                    property var battery: UPower.displayDevice
                    property bool hasBattery: battery?.isLaptopBattery ?? false
                    property color batteryColor: {
                        if (!battery) return root.textMuted;
                        var pct = (battery.percentage ?? 0) * 100;
                        if (battery.state === UPowerDeviceState.Charging) return root.positive;
                        if (pct <= 15) return root.critical;
                        if (pct <= 40) return root.warning;
                        return root.positive;
                    }

                    function open(section, wasOpen) {
                        bar.trayExpanded = false;
                        bar.closeTrayMenu();
                        calendarPopup.dismiss();
                        quickToolsPopup.dismiss();
                        statusPopup.showSection(section, wasOpen);
                    }

                    implicitWidth: statusRow.implicitWidth + 12
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight
                    anchors.right: quickToolsButton.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: root
                        // The meters are one control: the outer MouseArea
                        // owns hover and click handling for the whole group.
                        hovered: statusMouse.containsMouse
                        radius: root.radiusSmall
                    }

                    MouseArea {
                        id: statusMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = statusPopup.open
                        onClicked: statusGroup.open(statusPopup.focus, wasOpenOnPress)
                    }

                    Row {
                        id: statusRow
                        spacing: 2
                        anchors.centerIn: parent

                        StatusMeter {
                            id: volumeMeter
                            style: root
                            level: statusGroup.sink?.audio?.volume ?? 0
                            fillColor: root.accent
                            dimmed: statusGroup.sink?.audio?.muted ?? true
                            overflow: (statusGroup.sink?.audio?.volume ?? 0) > 1
                        }

                        StatusMeter {
                            id: brightnessMeter
                            style: root
                            level: Math.max(0, root.brightness)
                            fillColor: root.accentWarm
                            dimmed: root.brightness < 0
                        }

                        StatusMeter {
                            id: batteryMeter
                            style: root
                            visible: statusGroup.hasBattery
                            level: statusGroup.battery?.percentage ?? 0
                            fillColor: statusGroup.batteryColor
                        }
                    }
                }

                SystemStatusPopup {
                    id: statusPopup
                    style: root
                    shell: root
                    barWindow: bar
                    anchorRight: inputRegion.x + statusGroup.x + statusGroup.width
                    sink: statusGroup.sink
                    battery: statusGroup.battery
                    hasBattery: statusGroup.hasBattery
                    batteryColor: statusGroup.batteryColor
                }

                // ── Far right: quick tools ──────────────────────────
                Item {
                    id: quickToolsButton
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: root.barBackgroundPaddingX
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: root
                        hovered: quickToolsMouse.containsMouse
                        radius: root.radiusSmall
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: "…"
                        color: root.keepAwake || quickToolsPopup.open
                            ? root.accent
                            : root.textSecondary
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        visible: root.keepAwake
                        width: 5
                        height: 5
                        radius: 3
                        color: root.accent
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }

                    MouseArea {
                        id: quickToolsMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = quickToolsPopup.open
                        onClicked: {
                            bar.trayExpanded = false;
                            bar.closeTrayMenu();
                            calendarPopup.dismiss();
                            statusPopup.dismiss();
                            quickToolsPopup.open = !wasOpenOnPress;
                        }
                    }
                }

                QuickToolsPopup {
                    id: quickToolsPopup
                    style: root
                    shell: root
                    barWindow: bar
                }

                Item {
                    id: trayToggle
                    visible: bar.hasTrayItems
                    width: visible ? 22 : 0
                    height: 22
                    anchors.right: statusGroup.left
                    anchors.rightMargin: visible ? 9 : 0
                    anchors.verticalCenter: parent.verticalCenter

                    HoverSurface {
                        style: root
                        hovered: trayToggleMouse.containsMouse
                        radius: root.radiusSmall
                    }

                    Text {
                        anchors.centerIn: parent
                        // Point towards the action: expand left, then fold the
                        // drawer back towards the fixed status block.
                        text: bar.trayExpanded ? "⌃" : "⌄"
                        color: bar.trayNeedsAttention
                            ? root.warning
                            : (bar.trayExpanded ? root.accent : root.textSecondary)
                        font.pixelSize: 18
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        visible: bar.trayNeedsAttention && !bar.trayExpanded
                        width: 5
                        height: 5
                        radius: 3
                        color: root.warning
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }

                    MouseArea {
                        id: trayToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            bar.closeTrayMenu();
                            calendarPopup.dismiss();
                            quickToolsPopup.dismiss();
                            statusPopup.dismiss();
                            bar.trayExpanded = !bar.trayExpanded;
                        }
                    }
                }

                // ── System tray ───────────────────────────────────
                PopupWindow {
                    id: trayDrawer
                    parentWindow: bar
                    visible: bar.trayExpanded && bar.hasTrayItems && bar.isVisible
                    implicitWidth: Math.min(320, Math.max(76, trayRow.implicitWidth + 24))
                    // Keep the drawer close to the icon row; extra vertical
                    // padding makes a following context menu feel detached.
                    implicitHeight: 44
                    // Center the tray popup on the trigger instead of
                    // pinning it to the far-right edge of the bar.
                    relativeX: Math.round(Math.max(
                        root.barOuterMarginX,
                        Math.min(
                            bar.width - root.barOuterMarginX - width,
                            inputRegion.x + trayToggle.x
                                + (trayToggle.width - width) / 2
                        )
                    ))
                    relativeY: root.barHeight + 6
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        radius: root.radiusPopup
                        color: root.surface
                        border.width: 1
                        border.color: root.outline
                    }

                    Row {
                        id: trayRow
                        spacing: 4
                        anchors.centerIn: parent

                        Repeater {
                            id: trayRepeater
                            model: SystemTray.items

                        Item {
                            id: trayItem
                            required property SystemTrayItem modelData
                            width: 28; height: 28

                            function displayMenu() {
                                // Never fall back to SystemTrayItem.display():
                                // that opens Qt's platform-themed white menu.
                                // A menu handle may arrive one event-loop turn
                                // after hasMenu, so retry once instead.
                                var right = trayDrawer.relativeX + trayRow.x
                                    + trayItem.x + trayItem.width;
                                if (!bar.openTrayMenu(trayItem.modelData, right))
                                    Qt.callLater(() => bar.openTrayMenu(trayItem.modelData, right));
                            }

                            function fallbackLabel() {
                                var key = (
                                    (trayItem.modelData.icon ?? "") + " " +
                                    (trayItem.modelData.id ?? "") + " " +
                                    (trayItem.modelData.title ?? "")
                                ).toLowerCase();

                                if (key.indexOf("keyboard") >= 0 || key.indexOf("fcitx") >= 0)
                                    return "K";
                                if (key.indexOf("bluetooth") >= 0 || key.indexOf("blue") >= 0)
                                    return "B";
                                return "·";
                            }

                            Rectangle {
                                anchors.fill: parent; radius: root.radiusSmall
                                color: trayMouse.containsMouse ? root.surfaceHover : "transparent"
                            }

                            IconImage {
                                id: trayIcon
                                anchors.centerIn: parent
                                implicitSize: root.iconSizeSmall
                                source: trayItem.modelData.icon
                                visible: status !== Image.Error && source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: trayItem.fallbackLabel()
                                visible: !trayIcon.visible
                                color: root.textSecondary
                                font.pixelSize: 13
                                font.bold: true
                            }

                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: function(event) {
                                    if (event.button === Qt.RightButton
                                        && trayItem.modelData.hasMenu) {
                                        event.accepted = true;
                                        trayItem.displayMenu();
                                    }
                                }
                                onClicked: function(event) {
                                    if (event.button === Qt.LeftButton) {
                                        if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                            trayItem.displayMenu();
                                        else {
                                            bar.trayExpanded = false;
                                            bar.closeTrayMenu();
                                            trayItem.modelData.activate();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                TrayMenuPopup {
                    id: trayMenuPopup
                    style: root
                    barWindow: bar
                    trayPanelOffset: trayDrawer.height + 2
                }
            }
        }
    }
}
}
