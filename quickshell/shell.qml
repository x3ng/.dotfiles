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

ShellRoot {
    id: root

    // Visual system: a quiet, high-contrast floating surface instead of a
    // collection of independent black boxes.
    readonly property int barHeight: 40
    // Keep the transparent tail outside the reserved zone. This offsets
    // Hyprland's global outer gap without letting a visible control overlap
    // the window below.
    readonly property int barReservedHeight: 36
    readonly property int barOuterMarginX: 8
    readonly property int barBackgroundPaddingX: 12
    readonly property int barBackgroundHeight: 34
    readonly property int barSectionGap: 14
    readonly property real barBackgroundOpacity: 0.97
    readonly property color surface: "#171a22"
    readonly property color surfaceRaised: "#232936"
    readonly property color surfaceHover: "#303847"
    // QML uses #AARRGGBB for 8-digit colours. Keep these as translucent
    // white; #ffffff18 would instead render as an opaque yellow.
    readonly property color outline: "#20ffffff"
    readonly property color separator: "#18ffffff"
    readonly property color textPrimary: "#f3f5fa"
    readonly property color textSecondary: "#c7cddd"
    readonly property color textMuted: "#949db0"
    readonly property color accent: "#72b7e8"
    readonly property color accentWarm: "#e8b86a"
    readonly property color positive: "#7bc89c"
    readonly property color accentInk: "#0c202d"
    readonly property color warning: "#e0aa62"
    readonly property color critical: "#ec8796"

    // Quick tools are global even though each monitor owns its own menu.
    // Keep-awake intentionally resets with Quickshell to avoid an inhibitor
    // being forgotten across sessions.
    property bool keepAwake: false

    function toggleMicMute() {
        var audio = Pipewire.defaultAudioSource?.audio;
        if (audio) audio.muted = !audio.muted;
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

    component QuickToolTile: Rectangle {
        id: quickToolTile
        required property string label
        required property string detail
        property bool active: false
        property bool available: true
        signal triggered()

        width: 126
        height: 58
        radius: 10
        color: active
            ? root.surfaceHover
            : (toolMouse.containsMouse && available ? root.surfaceRaised : "transparent")
        border.width: active ? 1 : 0
        border.color: root.accent
        opacity: available ? 1 : 0.52

        Behavior on color { ColorAnimation { duration: 120 } }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                text: quickToolTile.label
                color: quickToolTile.active ? root.textPrimary : root.textSecondary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: quickToolTile.detail
                color: quickToolTile.active ? root.accent : root.textMuted
                font.pixelSize: 9
            }
        }

        MouseArea {
            id: toolMouse
            anchors.fill: parent
            enabled: quickToolTile.available
            hoverEnabled: true
            onClicked: quickToolTile.triggered()
        }
    }

    component StatusMeter: Item {
        id: statusMeter
        required property real level
        property color fillColor: root.accent
        property bool dimmed: false
        property bool adjustable: false
        property bool overflow: false
        property bool groupOpen: false
        signal activated(bool wasOpen)
        signal stepped(real amount)

        width: 12
        height: 24

        Rectangle {
            id: meterTrack
            width: 4
            height: 18
            radius: 2
            color: root.separator
            anchors.centerIn: parent

            Rectangle {
                width: parent.width
                height: statusMeter.dimmed
                    ? 0
                    : Math.round(parent.height * Math.max(0, Math.min(1, statusMeter.level)))
                radius: 2
                color: statusMeter.fillColor
                anchors.bottom: parent.bottom

                Behavior on height {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            Rectangle {
                visible: statusMeter.overflow && !statusMeter.dimmed
                width: 4
                height: 2
                radius: 1
                color: statusMeter.fillColor
                anchors.bottom: parent.top
                anchors.bottomMargin: 2
            }
        }

        MouseArea {
            property bool wasOpenOnPress: false
            anchors.fill: parent
            hoverEnabled: true
            onPressed: wasOpenOnPress = statusMeter.groupOpen
            onClicked: statusMeter.activated(wasOpenOnPress)
            onWheel: function(wheel) {
                if (!statusMeter.adjustable) return;
                statusMeter.stepped(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                wheel.accepted = true;
            }
        }
    }

    component ValueSlider: Item {
        id: valueSlider
        required property real value
        property color fillColor: root.accent
        property bool available: true
        signal edited(real newValue)

        width: 258
        height: 20
        opacity: available ? 1 : 0.5

        function valueAt(mouseX) {
            return Math.max(0, Math.min(1, mouseX / width));
        }

        Rectangle {
            height: 4
            radius: 2
            color: root.separator
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, valueSlider.value))
                height: parent.height
                radius: 2
                color: valueSlider.fillColor
            }
        }

        Rectangle {
            x: Math.max(0, Math.min(parent.width - width,
                parent.width * Math.max(0, Math.min(1, valueSlider.value)) - width / 2))
            width: 10
            height: 10
            radius: 5
            color: valueSlider.fillColor
            anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
            anchors.fill: parent
            enabled: valueSlider.available
            onPressed: function(mouse) { valueSlider.edited(valueSlider.valueAt(mouse.x)); }
            onPositionChanged: function(mouse) {
                if (pressed) valueSlider.edited(valueSlider.valueAt(mouse.x));
            }
        }
    }

    // ── Font sizes ─────────────────────────────────────────────────
    readonly property int fontSizeSmall: 13    // workspace numbers
    readonly property int fontSizeMedium: 13   // volume, brightness, battery
    readonly property int fontSizeLarge: 16    // clock
    readonly property int iconSizeSmall: 20    // tray icons
    readonly property int separatorHeight: 18

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
            property bool trayMenuOpen: false
            property var trayMenuOwner: null
            property var trayMenuCurrent: null
            property var trayMenuStack: []
            property real trayMenuAnchorRight: 0
            property bool calendarOpen: false
            property date calendarMonth: new Date()
            property string calendarTodayKey: ""
            property string calendarTodayLabel: ""
            property bool toolsOpen: false
            property bool statusOpen: false
            property string statusFocus: "volume"
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
                    closeTrayMenu();
                }
            }

            onTrayItemsChanged: {
                if (!trayMenuOwner) return;
                var ownerStillPresent = false;
                for (var i = 0; i < trayItems.length; i++) {
                    if (trayItems[i] === trayMenuOwner) {
                        ownerStillPresent = true;
                        break;
                    }
                }
                if (!ownerStillPresent) closeTrayMenu();
            }

            function openTrayMenu(owner, anchorItem) {
                // QsMenuOpener expects the handle exported by the tray item.
                // It resolves the DBusMenu root and owns its open/close
                // lifecycle internally.
                var menuHandle = owner?.menu;
                if (!menuHandle) return false;

                closeTrayMenu();
                var pos = anchorItem.mapToItem(null, 0, 0);
                trayMenuAnchorRight = pos.x + anchorItem.width;
                trayMenuOwner = owner;
                trayMenuStack = [menuHandle];
                trayMenuCurrent = menuHandle;
                trayMenuOpen = true;
                calendarOpen = false;
                toolsOpen = false;
                statusOpen = false;
                return true;
            }

            function enterTraySubmenu(entry) {
                if (!entry?.hasChildren) return;
                trayMenuStack = trayMenuStack.concat([entry]);
                trayMenuCurrent = entry;
            }

            function leaveTraySubmenu() {
                if (trayMenuStack.length <= 1) return;
                trayMenuStack = trayMenuStack.slice(0, trayMenuStack.length - 1);
                trayMenuCurrent = trayMenuStack[trayMenuStack.length - 1];
            }

            function closeTrayMenu() {
                // Clearing the QsMenuOpener binding releases the active
                // entry, which emits the matching DBusMenu close event.
                trayMenuCurrent = null;
                trayMenuOpen = false;
                trayMenuStack = [];
                trayMenuOwner = null;
            }

            function triggerTrayMenuEntry(entry) {
                // QsMenuEntry's generic signal is bridged to DBusMenu's
                // Event("clicked") call by the concrete tray entry.
                entry.triggered();
                closeTrayMenu();
            }

            function trayMenuHeading() {
                if (trayMenuStack.length > 1 && trayMenuCurrent?.text)
                    return trayMenuCurrent.text.toUpperCase();
                var title = trayMenuOwner?.title || trayMenuOwner?.id || "APPLICATION";
                return title.toUpperCase();
            }

            function resetCalendarMonth() {
                var now = new Date();
                calendarMonth = new Date(now.getFullYear(), now.getMonth(), 1);
            }

            function shiftCalendarMonth(offset) {
                calendarMonth = new Date(
                    calendarMonth.getFullYear(),
                    calendarMonth.getMonth() + offset,
                    1
                );
            }

            function calendarTitle() {
                return Qt.formatDateTime(calendarMonth, "MMMM yyyy").toUpperCase();
            }

            function calendarCells() {
                // Keep the model reactive when midnight updates the key.
                calendarTodayKey;
                var year = calendarMonth.getFullYear();
                var month = calendarMonth.getMonth();
                var first = new Date(year, month, 1);
                var mondayOffset = (first.getDay() + 6) % 7;
                var cells = [];

                for (var i = 0; i < 42; i++) {
                    var date = new Date(year, month, 1 - mondayOffset + i);
                    cells.push({
                        day: date.getDate(),
                        inMonth: date.getMonth() === month,
                        today: Qt.formatDateTime(date, "yyyy-MM-dd") === calendarTodayKey
                    });
                }
                return cells;
            }

            onIsVisibleChanged: {
                visibilityAnimation.stop();
                if (isVisible) {
                    surfaceVisible = true;
                    visibilityAnimation.to = 1;
                } else {
                    trayExpanded = false;
                    closeTrayMenu();
                    calendarOpen = false;
                    toolsOpen = false;
                    statusOpen = false;
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
                    radius: 15
                    color: root.surface
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
                        var rightStart = trayDrawer.width > 0
                            ? trayDrawer.x
                            : (trayToggle.visible ? trayToggle.x : statusGroup.x);
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
                            // 16 px number badge, followed by one stable 16 px
                            // application icon slot for every toplevel.
                            var contents = 16;
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

                                implicitWidth: workspaceContents.implicitWidth + 14
                                width: Math.max(23, implicitWidth)
                                height: 24
                                radius: 7
                                color: isActive ? root.surfaceRaised : (wsMouse.containsMouse ? root.surfaceHover : "transparent")
                                border.width: 0
                                border.color: root.outline

                                Behavior on color { ColorAnimation { duration: 130 } }

                                Row {
                                    id: workspaceContents
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Item {
                                        width: 16; height: 16

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 5
                                            visible: workspaceDelegate.isActive
                                            color: root.accent
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            text: workspaceDelegate.modelData.id
                                            color: workspaceDelegate.isActive ? root.accentInk : root.textSecondary
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
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
                                    onClicked: {
                                        bar.trayExpanded = false;
                                        bar.closeTrayMenu();
                                        bar.calendarOpen = false;
                                        bar.toolsOpen = false;
                                        bar.statusOpen = false;
                                        root.dispatch("workspace " + workspaceDelegate.modelData.id);
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

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: bar.calendarOpen
                            ? root.surfaceRaised
                            : (clockMouse.containsMouse ? root.surfaceHover : "transparent")

                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    Row {
                        id: clockRow
                        spacing: 7
                        anchors.centerIn: parent

                        Text {
                            id: clockDate
                            color: root.textSecondary
                            font.pixelSize: root.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: clockTime
                            color: root.textPrimary
                            font.pixelSize: root.fontSizeMedium
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    function refresh() {
                        var now = new Date();
                        clockTime.text = Qt.formatDateTime(now, "HH:mm");
                        clockDate.text = Qt.formatDateTime(now, "MM/dd · ddd");
                        var todayKey = Qt.formatDateTime(now, "yyyy-MM-dd");
                        if (bar.calendarTodayKey !== todayKey) {
                            bar.calendarTodayKey = todayKey;
                            bar.calendarTodayLabel = Qt.formatDateTime(now, "dddd · MMMM d").toUpperCase();
                        }
                    }
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.refresh() }
                    Component.onCompleted: refresh()

                    MouseArea {
                        id: clockMouse
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: wasOpenOnPress = bar.calendarOpen
                        onClicked: {
                            if (wasOpenOnPress) {
                                bar.calendarOpen = false;
                            } else {
                                bar.resetCalendarMonth();
                                bar.trayExpanded = false;
                                bar.closeTrayMenu();
                                bar.toolsOpen = false;
                                bar.statusOpen = false;
                                bar.calendarOpen = true;
                            }
                        }
                    }
                }

                PopupWindow {
                    id: calendarPopup
                    parentWindow: bar
                    visible: bar.calendarOpen && bar.isVisible
                    implicitWidth: 280
                    implicitHeight: 294
                    relativeX: Math.round(Math.max(
                        root.barOuterMarginX,
                        Math.min(
                            bar.width - root.barOuterMarginX - width,
                            inputRegion.x + clock.x
                        )
                    ))
                    relativeY: root.barHeight + 6
                    color: "transparent"
                    grabFocus: true

                    onVisibleChanged: {
                        if (!visible && bar.calendarOpen) bar.calendarOpen = false;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.outline

                        Item {
                            id: calendarHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 44

                            Item {
                                width: 30
                                height: 30
                                anchors.left: parent.left
                                anchors.leftMargin: 9
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: previousMonthMouse.containsMouse
                                        ? root.surfaceHover
                                        : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: root.textSecondary
                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: previousMonthMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: bar.shiftCalendarMonth(-1)
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: bar.calendarTitle()
                                color: root.textPrimary
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }

                            Item {
                                width: 30
                                height: 30
                                anchors.right: parent.right
                                anchors.rightMargin: 9
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: nextMonthMouse.containsMouse
                                        ? root.surfaceHover
                                        : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    color: root.textSecondary
                                    font.pixelSize: 20
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: nextMonthMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: bar.shiftCalendarMonth(1)
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: calendarHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            height: 1
                            color: root.separator
                        }

                        Row {
                            id: weekdayRow
                            anchors.top: calendarHeader.bottom
                            anchors.topMargin: 5
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                                Item {
                                    required property string modelData
                                    width: 36
                                    height: 22

                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        color: root.textMuted
                                        font.pixelSize: 8
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        Grid {
                            id: calendarGrid
                            anchors.top: weekdayRow.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 7

                            Repeater {
                                model: bar.calendarCells()

                                Item {
                                    id: calendarDay
                                    required property var modelData
                                    width: 36
                                    height: 32

                                    Rectangle {
                                        width: 28
                                        height: 26
                                        radius: 8
                                        anchors.centerIn: parent
                                        color: calendarDay.modelData.today
                                            ? root.accent
                                            : "transparent"
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: calendarDay.modelData.day
                                        color: calendarDay.modelData.today
                                            ? root.accentInk
                                            : (calendarDay.modelData.inMonth
                                                ? root.textPrimary
                                                : root.textMuted)
                                        opacity: calendarDay.modelData.inMonth || calendarDay.modelData.today
                                            ? 1
                                            : 0.45
                                        font.pixelSize: 11
                                        font.weight: calendarDay.modelData.today
                                            ? Font.DemiBold
                                            : Font.Normal
                                    }
                                }
                            }
                        }

                        Item {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 27

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                height: 1
                                color: root.separator
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                text: bar.calendarTodayLabel
                                color: todayMouse.containsMouse ? root.accent : root.textSecondary
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: bar.resetCalendarMonth()
                            }
                        }
                    }
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
                        bar.statusFocus = section;
                        bar.trayExpanded = false;
                        bar.closeTrayMenu();
                        bar.calendarOpen = false;
                        bar.toolsOpen = false;
                        bar.statusOpen = !wasOpen;
                    }

                    implicitWidth: statusRow.implicitWidth + 12
                    implicitHeight: 28
                    width: implicitWidth
                    height: implicitHeight
                    anchors.right: quickToolsButton.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: bar.statusOpen ? root.surfaceRaised : "transparent"

                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    MouseArea {
                        property bool wasOpenOnPress: false
                        anchors.fill: parent
                        onPressed: wasOpenOnPress = bar.statusOpen
                        onClicked: statusGroup.open(bar.statusFocus, wasOpenOnPress)
                    }

                    Row {
                        id: statusRow
                        spacing: 4
                        anchors.centerIn: parent

                        StatusMeter {
                            level: statusGroup.sink?.audio?.volume ?? 0
                            fillColor: root.accent
                            dimmed: statusGroup.sink?.audio?.muted ?? true
                            adjustable: statusGroup.sink?.audio ?? false
                            overflow: (statusGroup.sink?.audio?.volume ?? 0) > 1
                            groupOpen: bar.statusOpen
                            onActivated: function(wasOpen) { statusGroup.open("volume", wasOpen); }
                            onStepped: function(amount) {
                                root.setVolume((statusGroup.sink?.audio?.volume ?? 0) + amount);
                            }
                        }

                        StatusMeter {
                            level: Math.max(0, root.brightness)
                            fillColor: root.accentWarm
                            dimmed: root.brightness < 0
                            adjustable: root.brightness >= 0
                            groupOpen: bar.statusOpen
                            onActivated: function(wasOpen) { statusGroup.open("brightness", wasOpen); }
                            onStepped: function(amount) {
                                root.setBrightness(Math.max(0, root.brightness) + amount);
                            }
                        }

                        StatusMeter {
                            visible: statusGroup.hasBattery
                            level: statusGroup.battery?.percentage ?? 0
                            fillColor: statusGroup.batteryColor
                            groupOpen: bar.statusOpen
                            onActivated: function(wasOpen) { statusGroup.open("battery", wasOpen); }
                        }
                    }
                }

                PopupWindow {
                    id: statusPopup
                    parentWindow: bar
                    visible: bar.statusOpen && bar.isVisible
                    implicitWidth: 300
                    implicitHeight: statusGroup.hasBattery ? 214 : 158
                    relativeX: Math.round(inputRegion.x
                        + statusGroup.x
                        + statusGroup.width
                        - width)
                    relativeY: root.barHeight + 6
                    color: "transparent"
                    grabFocus: true

                    onVisibleChanged: {
                        if (!visible && bar.statusOpen) bar.statusOpen = false;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.outline

                        Text {
                            id: statusPopupTitle
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: 12
                            anchors.leftMargin: 12
                            text: "SYSTEM STATUS"
                            color: root.textMuted
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        Item {
                            id: volumeControl
                            anchors.top: statusPopupTitle.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: 52

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: bar.statusFocus === "volume"
                                    ? root.surfaceRaised
                                    : "transparent"
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.topMargin: 4
                                text: "VOL"
                                color: bar.statusFocus === "volume" ? root.textPrimary : root.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: volumeMute.left
                                anchors.rightMargin: 8
                                anchors.topMargin: 4
                                text: statusGroup.sink?.audio
                                    ? Math.round(statusGroup.sink.audio.volume * 100) + "%"
                                    : "—"
                                color: root.textPrimary
                                font.pixelSize: 10
                            }

                            Rectangle {
                                id: volumeMute
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                width: 48
                                height: 18
                                radius: 6
                                color: statusGroup.sink?.audio?.muted
                                    ? root.surfaceHover
                                    : "transparent"
                                border.width: statusGroup.sink?.audio?.muted ? 1 : 0
                                border.color: root.warning

                                Text {
                                    anchors.centerIn: parent
                                    text: statusGroup.sink?.audio?.muted ? "MUTED" : "MUTE"
                                    color: statusGroup.sink?.audio?.muted ? root.warning : root.textMuted
                                    font.pixelSize: 8
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: statusGroup.sink?.audio ?? false
                                    onClicked: {
                                        statusGroup.sink.audio.muted = !statusGroup.sink.audio.muted;
                                    }
                                }
                            }

                            ValueSlider {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                value: statusGroup.sink?.audio?.volume ?? 0
                                available: statusGroup.sink?.audio ?? false
                                onEdited: function(newValue) { root.setVolume(newValue); }
                            }
                        }

                        Item {
                            id: brightnessControl
                            anchors.top: volumeControl.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: 52

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: bar.statusFocus === "brightness"
                                    ? root.surfaceRaised
                                    : "transparent"
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.topMargin: 4
                                text: "BRI"
                                color: bar.statusFocus === "brightness" ? root.textPrimary : root.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.topMargin: 4
                                text: root.brightness >= 0
                                    ? Math.round(root.brightness * 100) + "%"
                                    : "—"
                                color: root.textPrimary
                                font.pixelSize: 10
                            }

                            ValueSlider {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                value: Math.max(0, root.brightness)
                                fillColor: root.accentWarm
                                available: root.brightness >= 0
                                onEdited: function(newValue) { root.setBrightness(newValue); }
                            }
                        }

                        Item {
                            id: batteryControl
                            visible: statusGroup.hasBattery
                            anchors.top: brightnessControl.bottom
                            anchors.topMargin: 8
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: bar.statusFocus === "battery"
                                    ? root.surfaceRaised
                                    : "transparent"
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.topMargin: 5
                                text: "BAT"
                                color: bar.statusFocus === "battery" ? root.textPrimary : root.textSecondary
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.topMargin: 5
                                text: statusGroup.battery
                                    ? Math.round(statusGroup.battery.percentage * 100) + "%"
                                    : "—"
                                color: statusGroup.batteryColor
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 5
                                text: root.batteryDetail(statusGroup.battery)
                                elide: Text.ElideRight
                                color: root.textMuted
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                // ── Far right: quick tools ──────────────────────────
                Item {
                    id: quickToolsButton
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.rightMargin: root.barBackgroundPaddingX
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: bar.toolsOpen
                            ? root.surfaceRaised
                            : (quickToolsMouse.containsMouse ? root.surfaceHover : "transparent")
                        border.width: root.keepAwake ? 1 : 0
                        border.color: root.accent

                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: "…"
                        color: root.keepAwake ? root.accent : root.textSecondary
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
                        onPressed: wasOpenOnPress = bar.toolsOpen
                        onClicked: {
                            bar.trayExpanded = false;
                            bar.closeTrayMenu();
                            bar.calendarOpen = false;
                            bar.statusOpen = false;
                            bar.toolsOpen = !wasOpenOnPress;
                        }
                    }
                }

                PopupWindow {
                    id: quickToolsPopup
                    parentWindow: bar
                    visible: bar.toolsOpen && bar.isVisible
                    implicitWidth: 284
                    implicitHeight: 174
                    relativeX: Math.round(bar.width
                        - root.barOuterMarginX
                        - root.barBackgroundPaddingX
                        - width)
                    relativeY: root.barHeight + 6
                    color: "transparent"
                    grabFocus: true

                    onVisibleChanged: {
                        if (!visible && bar.toolsOpen) bar.toolsOpen = false;
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.surface
                        border.width: 1
                        border.color: root.outline

                        Text {
                            id: quickToolsTitle
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: 12
                            anchors.leftMargin: 12
                            text: "QUICK TOOLS"
                            color: root.textMuted
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }

                        Grid {
                            anchors.top: quickToolsTitle.bottom
                            anchors.topMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 2
                            spacing: 8

                            QuickToolTile {
                                label: "AWAKE"
                                detail: root.keepAwake ? "ON" : "OFF"
                                active: root.keepAwake
                                onTriggered: root.keepAwake = !root.keepAwake
                            }

                            QuickToolTile {
                                label: "NIGHT"
                                detail: "UNAVAILABLE"
                                available: false
                            }

                            QuickToolTile {
                                property var source: Pipewire.defaultAudioSource
                                label: "MIC"
                                detail: !source?.audio ? "UNAVAILABLE"
                                    : (source.audio.muted ? "MUTED" : "LIVE")
                                active: source?.audio?.muted ?? false
                                available: source?.audio ?? false
                                onTriggered: root.toggleMicMute()
                            }

                            QuickToolTile {
                                label: "POWER"
                                detail: root.powerProfileLabel()
                                active: PowerProfiles.profile !== PowerProfile.Balanced
                                onTriggered: root.cyclePowerProfile()
                            }
                        }
                    }
                }

                // ── Separator ─────────────────────────────────────
                Rectangle {
                    id: traySeparator
                    visible: bar.hasTrayItems
                    width: 1
                    height: root.separatorHeight
                    color: root.separator
                    anchors.right: statusGroup.left
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: trayToggle
                    visible: bar.hasTrayItems
                    width: visible ? 22 : 0
                    height: 22
                    anchors.right: traySeparator.left
                    anchors.rightMargin: visible ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: bar.trayExpanded
                            ? root.surfaceRaised
                            : (trayToggleMouse.containsMouse ? root.surfaceHover : "transparent")

                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        // Point towards the action: expand left, then fold the
                        // drawer back towards the fixed status block.
                        text: bar.trayExpanded ? "›" : "‹"
                        color: bar.trayNeedsAttention ? root.warning : root.textSecondary
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
                            bar.calendarOpen = false;
                            bar.toolsOpen = false;
                            bar.statusOpen = false;
                            bar.trayExpanded = !bar.trayExpanded;
                        }
                    }
                }

                // ── System tray ───────────────────────────────────
                Item {
                    id: trayDrawer
                    width: bar.trayExpanded && bar.hasTrayItems ? trayRow.implicitWidth : 0
                    height: 28
                    clip: true
                    anchors.right: trayToggle.left
                    anchors.rightMargin: bar.hasTrayItems ? 6 : 0
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width {
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    Row {
                        id: trayRow
                        spacing: 4
                        width: implicitWidth
                        height: implicitHeight
                        enabled: trayDrawer.width > 0
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

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
                                if (!bar.openTrayMenu(trayItem.modelData, trayItem))
                                    Qt.callLater(() => bar.openTrayMenu(trayItem.modelData, trayItem));
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
                                anchors.fill: parent; radius: 4
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
                                onClicked: function(event) {
                                    if (event.button === Qt.LeftButton) {
                                        if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                                            trayItem.displayMenu();
                                        else {
                                            bar.closeTrayMenu();
                                            trayItem.modelData.activate();
                                        }
                                    } else if (event.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                                        trayItem.displayMenu();
                                    }
                                }
                            }
                        }
                    }
                }

                PopupWindow {
                    id: trayMenuPopup
                    parentWindow: bar
                    visible: bar.trayMenuOpen && bar.isVisible
                    implicitWidth: 260
                    implicitHeight: Math.min(
                        420,
                        Math.max(62, bar.screen.height - root.barHeight - 18),
                        Math.max(62, trayMenuList.contentHeight + 50)
                    )
                    relativeX: Math.round(Math.max(
                        root.barOuterMarginX,
                        Math.min(
                            bar.width - root.barOuterMarginX - width,
                            bar.trayMenuAnchorRight - width
                        )
                    ))
                    relativeY: root.barHeight + 6
                    color: "transparent"
                    grabFocus: true

                    onVisibleChanged: {
                        if (!visible && bar.trayMenuOpen) bar.closeTrayMenu();
                    }

                    QsMenuOpener {
                        id: trayMenuOpener
                        menu: bar.trayMenuCurrent
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: root.surface
                        border.width: 1
                        border.color: root.outline

                        Item {
                            id: trayMenuHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 42

                            Item {
                                id: trayMenuBack
                                visible: bar.trayMenuStack.length > 1
                                width: visible ? 28 : 0
                                height: 28
                                anchors.left: parent.left
                                anchors.leftMargin: 7
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: trayMenuBackMouse.containsMouse
                                        ? root.surfaceHover
                                        : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    color: root.textSecondary
                                    font.pixelSize: 19
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: trayMenuBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: bar.leaveTraySubmenu()
                                }
                            }

                            Text {
                                anchors.left: trayMenuBack.right
                                anchors.right: trayMenuClose.left
                                anchors.leftMargin: trayMenuBack.visible ? 4 : 12
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: bar.trayMenuHeading()
                                elide: Text.ElideRight
                                color: root.textMuted
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                            }

                            Item {
                                id: trayMenuClose
                                width: 28
                                height: 28
                                anchors.right: parent.right
                                anchors.rightMargin: 7
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 7
                                    color: trayMenuCloseMouse.containsMouse
                                        ? root.surfaceHover
                                        : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: root.textMuted
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: trayMenuCloseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: bar.closeTrayMenu()
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: trayMenuHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            height: 1
                            color: root.separator
                        }

                        ListView {
                            id: trayMenuList
                            anchors.top: trayMenuHeader.bottom
                            anchors.topMargin: 5
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: trayMenuOpener.children
                                ? [...trayMenuOpener.children.values]
                                : []

                            delegate: Item {
                                id: menuEntry
                                required property QsMenuEntry modelData
                                readonly property bool checked: modelData.checkState !== Qt.Unchecked
                                width: trayMenuList.width
                                height: modelData.isSeparator ? 9 : 34
                                opacity: modelData.enabled ? 1 : 0.52

                                Rectangle {
                                    visible: menuEntry.modelData.isSeparator
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 1
                                    color: root.separator
                                }

                                Rectangle {
                                    visible: !menuEntry.modelData.isSeparator
                                    anchors.fill: parent
                                    radius: 7
                                    color: menuEntryMouse.containsMouse && menuEntry.modelData.enabled
                                        ? root.surfaceHover
                                        : "transparent"

                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                Item {
                                    visible: !menuEntry.modelData.isSeparator
                                    width: 18
                                    height: 18
                                    anchors.left: parent.left
                                    anchors.leftMargin: 9
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 16
                                        source: menuEntry.modelData.icon
                                        visible: menuEntry.modelData.buttonType === QsMenuButtonType.None
                                            && source !== ""
                                            && status !== Image.Error
                                    }

                                    Rectangle {
                                        visible: menuEntry.modelData.buttonType !== QsMenuButtonType.None
                                        width: 13
                                        height: 13
                                        anchors.centerIn: parent
                                        radius: menuEntry.modelData.buttonType === QsMenuButtonType.RadioButton
                                            ? 7
                                            : 3
                                        color: menuEntry.checked ? root.accent : "transparent"
                                        border.width: 1
                                        border.color: menuEntry.checked ? root.accent : root.textMuted

                                        Rectangle {
                                            visible: menuEntry.checked
                                                && menuEntry.modelData.buttonType === QsMenuButtonType.RadioButton
                                            width: 5
                                            height: 5
                                            radius: 3
                                            anchors.centerIn: parent
                                            color: root.accentInk
                                        }

                                        Text {
                                            visible: menuEntry.checked
                                                && menuEntry.modelData.buttonType === QsMenuButtonType.CheckBox
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -1
                                            text: menuEntry.modelData.checkState === Qt.PartiallyChecked ? "−" : "✓"
                                            color: root.accentInk
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                Text {
                                    visible: !menuEntry.modelData.isSeparator
                                    anchors.left: parent.left
                                    anchors.leftMargin: 36
                                    anchors.right: menuEntryArrow.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: menuEntry.modelData.text
                                    elide: Text.ElideRight
                                    color: root.textPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                Text {
                                    id: menuEntryArrow
                                    visible: !menuEntry.modelData.isSeparator
                                        && menuEntry.modelData.hasChildren
                                    width: visible ? 18 : 0
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    color: root.textMuted
                                    font.pixelSize: 17
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                MouseArea {
                                    id: menuEntryMouse
                                    anchors.fill: parent
                                    enabled: !menuEntry.modelData.isSeparator
                                        && menuEntry.modelData.enabled
                                    hoverEnabled: true
                                    onClicked: {
                                        if (menuEntry.modelData.hasChildren)
                                            bar.enterTraySubmenu(menuEntry.modelData);
                                        else
                                            bar.triggerTrayMenuEntry(menuEntry.modelData);
                                    }
                                }
                            }

                            Text {
                                visible: trayMenuList.count === 0
                                anchors.centerIn: parent
                                text: "NO ACTIONS"
                                color: root.textMuted
                                font.pixelSize: 9
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
}
