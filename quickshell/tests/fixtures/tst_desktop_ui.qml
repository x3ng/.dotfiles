pragma ComponentBehavior: Bound

import QtQuick
import QtTest

Item {
    id: host
    width: 640
    height: 700
    property string screenshotPath: ""
    Theme { id: theme; darkMode: true }
    Rectangle { anchors.fill: parent; color: theme.panelSurface; z: -1 }
    QtObject {
        id: search
        function desktopEntryFor(window) { return null; }
        function desktopIconSource(entry) { return ""; }
    }
    QtObject {
        id: desktop
        property bool available: true
        property bool busy: false
        property string error: ""
        property int lastRequestId: 0
        property int focusedWorkspaceId: 1
        property var workspaces: []
        property var windows: []
        property var layoutCalls: []
        property var focusCalls: []
        property var moveCalls: []
        readonly property var workspaceTargets: workspaces.concat([{id: 3, name: "3", exists: false}])
        signal operationFinished(bool success, string operation, string target, int requestId, string message)
        function accept() { if (busy) return false; busy = true; lastRequestId++; return true; }
        function focusWindow(address) { if (!accept()) return false; focusCalls = focusCalls.concat([{address: address}]); return true; }
        function focusWorkspace(id) { if (!accept()) return false; focusCalls = focusCalls.concat([{workspace: id}]); return true; }
        function toggleFloat(address) { return accept(); }
        function toggleFullscreen(address) { return accept(); }
        function moveWindow(address, id) { if (!accept()) return false; moveCalls = moveCalls.concat([{address: address, workspace: id}]); return true; }
        function closeWindow(address) { return accept(); }
        function setLayout(id, layout) { if (!accept()) return false; layoutCalls = layoutCalls.concat([{id: id, layout: layout}]); return true; }
    }
    QtObject {
        id: actions
        property bool enabled: true
        property var calls: []
        function available(id) { return enabled; }
        function execute(id) { if (!available(id)) return false; calls = calls.concat([id]); return id === "lock" ? desktop.accept() : true; }
    }
    QtObject {
        id: system
        property bool wifiEnabled: true
        property bool bluetoothEnabled: false
        property bool wifiBusy: false
        property bool bluetoothBusy: false
        property var wifiProfiles: []
        property var bluetoothDevices: []
        property var bluetoothConnected: []
        property string error: ""
    }
    QtObject {
        id: services
        property var controls: system
        property var audioInputs: []
        property var audioOutputs: []
        property var source: null
        property var sink: null
        property var terminalCommand: ["kitty"]
        property bool editorAccepted: true
        property int editorCalls: 0
        function openNetworkEditor() { editorCalls++; return editorAccepted; }
    }
    QtObject { id: notifs; property var history: [] }
    Component {
        id: pageFactory
        DesktopPage {
            width: host.width
            height: host.height
            style: theme
            searchModel: search
            controls: desktop
            actions: actions
            panelOpen: true
        }
    }
    Component {
        id: choiceFactory
        ChoiceButton { style: theme; label: "An unusually long device label"; iconKind: "headphones"; width: 120 }
    }
    Component {
        id: deviceFactory
        DeviceRow { style: theme; title: "A very long <device> name that must elide"; subtitle: "An equally long connection status"; width: 180; height: implicitHeight }
    }
    Component {
        id: detailsFactory
        ControlDetails {
            width: host.width
            height: host.height
            style: theme
            services: services
            actions: actions
            notifs: notifs
            section: "wifi"
        }
    }
    SignalSpy { id: dismissSpy; signalName: "dismissRequested" }

    TestCase {
        name: "DesktopUi"
        when: windowShown

        function workspace(id) { return {id: id, name: String(id), active: id === 1, special: false, exists: true, layout: "dwindle", windowCount: id === 1 ? 1 : 0}; }
        function client(title) { return {address: "0x1", title: title, appId: "test", workspaceId: 1, floating: false, fullscreen: false, focused: true}; }
        function matching(item, predicate) {
            if (predicate(item)) return item;
            for (const child of item.children ?? []) {
                const result = matching(child, predicate);
                if (result) return result;
            }
            return null;
        }
        function card(page, address) { return matching(page, item => item.windowData?.address === (address ?? "0x1")); }
        function named(page, name) { return matching(page, item => item.objectName === name); }
        function button(root, label) { return matching(root, item => item.label === label && typeof item.triggered === "function"); }
        function init() {
            desktop.busy = false;
            desktop.lastRequestId = 0;
            desktop.workspaces = [workspace(1), workspace(2)];
            desktop.windows = [client("Original title")];
            desktop.layoutCalls = [];
            desktop.focusCalls = [];
            desktop.moveCalls = [];
            actions.enabled = true;
            actions.calls = [];
            services.editorAccepted = true;
            services.editorCalls = 0;
            dismissSpy.target = null;
            dismissSpy.clear();
        }
        function createPage() {
            const page = createTemporaryObject(pageFactory, host);
            verify(page !== null);
            tryCompare(page, "selectedWorkspaceId", 1);
            return page;
        }

        function test_optionalOverviewScreenshot() {
            if (!host.screenshotPath) return;
            desktop.workspaces = [workspace(1), workspace(2), workspace(3), workspace(4)];
            desktop.windows = [
                {address: "0x1", title: "Hyprland configuration — editor", appId: "code", workspaceId: 1, focused: true, floating: false, fullscreen: false},
                {address: "0x2", title: "Terminal · ~/dotfiles", appId: "kitty", workspaceId: 1, focused: false, floating: false, fullscreen: false},
                {address: "0x3", title: "Documentation — Firefox", appId: "firefox", workspaceId: 2, focused: false, floating: false, fullscreen: false},
                {address: "0x4", title: "Music library", appId: "music", workspaceId: 3, focused: false, floating: false, fullscreen: false}
            ];
            const page = createPage();
            wait(100);
            grabImage(host).save(host.screenshotPath);
        }

        function test_actionModeSurvivesDelegateRefresh() {
            const page = createPage();
            page.expandedAddress = "0x1";
            wait(0);
            button(card(page), "Move").triggered();
            compare(page.windowActionMode, "move");
            desktop.windows = [client("Changed title")];
            wait(0);
            compare(card(page).actionMode, "move");
            button(card(page), "Close").triggered();
            compare(page.windowActionMode, "close");
            desktop.windows = [client("Another update")];
            wait(0);
            compare(card(page).actionMode, "close");
            desktop.windows = [];
            compare(page.expandedAddress, "");
            compare(page.windowActionMode, "");
        }

        function test_layoutPickerIsContextual() {
            const page = createPage();
            const first = named(page, "workspace-1");
            const second = named(page, "workspace-2");
            compare(button(first, "Master").visible, false);
            named(page, "layout-workspace-1").triggered();
            compare(button(first, "Master").visible, true);
            named(page, "layout-workspace-2").triggered();
            compare(button(first, "Master").visible, false);
            compare(button(second, "Master").visible, true);
            compare(desktop.lastRequestId, 0, "Opening layout choices should not switch workspace");
            button(second, "Master").triggered();
            compare(desktop.layoutCalls.length, 1);
            compare(desktop.layoutCalls[0].id, 2);
            compare(desktop.layoutCalls[0].layout, "master");
            compare(page.choosingLayout, false);
            page.choosingLayout = true;
            page.panelOpen = false;
            page.panelOpen = true;
            compare(page.choosingLayout, false);
        }

        function test_workspaceCardsFitNarrowPage() {
            const page = createPage();
            page.width = 240;
            wait(0);
            assertWithin(named(page, "workspace-1"), page);
            assertWithin(named(page, "workspace-2"), page);
            assertWithin(named(page, "layout-workspace-1"), page);
            assertWithin(button(page, "＋ New workspace"), page);
            named(page, "layout-workspace-1").triggered();
            wait(0);
            for (const label of ["Dwindle", "Master", "Scrolling", "Monocle"])
                assertWithin(button(named(page, "workspace-1"), label), page);
        }

        function test_workspaceColumnsDoNotWaitForOppositeCard() {
            desktop.workspaces = [workspace(1), workspace(2), workspace(3), workspace(4)];
            desktop.windows = [1, 2, 3, 4].map(index => ({
                address: "0x" + index, title: "Window " + index, appId: "test",
                workspaceId: 1, focused: index === 1, floating: false, fullscreen: false
            }));
            const page = createPage();
            wait(0);
            const tall = named(page, "workspace-1");
            const short = named(page, "workspace-2");
            const next = named(page, "workspace-4");
            const tallPosition = tall.mapToItem(page, 0, 0);
            const shortPosition = short.mapToItem(page, 0, 0);
            const nextPosition = next.mapToItem(page, 0, 0);
            verify(nextPosition.x > tallPosition.x, "Fourth workspace should remain in the right column");
            verify(nextPosition.y >= shortPosition.y + short.height, "Right column cards overlap");
            verify(nextPosition.y < tallPosition.y + tall.height,
                "Short column must continue without waiting for the taller opposite workspace");
            verify(card(page).height <= 54, "Collapsed window row should stay compact");
        }

        function test_workspaceTitleAndLayoutShareHeader() {
            const page = createPage();
            for (const width of [640, 240]) {
                page.width = width;
                wait(0);
                const header = named(page, "focus-workspace-1");
                const layout = named(page, "layout-workspace-1");
                const headerPosition = header.mapToItem(page, 0, 0);
                const layoutPosition = layout.mapToItem(page, 0, 0);
                verify(layoutPosition.x >= headerPosition.x + header.width - 0.5,
                    "Layout selector should sit beside the title without overlapping its hit target");
                verify(layoutPosition.y < headerPosition.y + header.height
                    && layoutPosition.y + layout.height > headerPosition.y,
                    "Layout selector should share the workspace header row");
                assertWithin(header, page);
                assertWithin(layout, page);
            }
        }

        function test_workspaceHeaderFocusDismissesOnMatchingSuccess() {
            const page = createPage();
            dismissSpy.target = page;
            wait(0);
            const target = named(page, "focus-workspace-2");
            mouseClick(target, target.width / 2, target.height / 2);
            compare(desktop.focusCalls[0].workspace, 2);
            const request = desktop.lastRequestId;
            desktop.operationFinished(true, "focusWorkspace", "2", request + 1, "");
            compare(dismissSpy.count, 0);
            desktop.operationFinished(true, "focusWorkspace", "2", request, "");
            compare(dismissSpy.count, 1);
            desktop.operationFinished(true, "focusWorkspace", "2", request, "");
            compare(dismissSpy.count, 1);
        }

        function test_dismissMatchesRequest() {
            const page = createPage();
            dismissSpy.target = page;
            desktop.operationFinished(true, "lock", "session", 0, "");
            compare(dismissSpy.count, 0);
            page.focusWindow("0x1");
            const request = desktop.lastRequestId;
            desktop.operationFinished(true, "lock", "session", request + 1, "");
            compare(dismissSpy.count, 0);
            compare(page.pendingDismissRequestId, request);
            desktop.operationFinished(false, "focusWindow", "0x1", request, "gone");
            compare(dismissSpy.count, 0);
            compare(page.pendingDismissRequestId, 0);
            desktop.busy = false;
            page.focusWindow("0x1");
            desktop.operationFinished(true, "focusWindow", "0x1", desktop.lastRequestId, "");
            compare(dismissSpy.count, 1);
            desktop.operationFinished(true, "focusWindow", "0x1", desktop.lastRequestId, "");
            compare(dismissSpy.count, 1);
        }

        function test_closedPageIgnoresCompletion() {
            const page = createPage();
            dismissSpy.target = page;
            page.focusWindow("0x1");
            page.panelOpen = false;
            page.panelOpen = true;
            desktop.operationFinished(true, "focusWindow", "0x1", desktop.lastRequestId, "");
            compare(dismissSpy.count, 0);
        }

        function test_workspaceUpdatesDoNotCancelPendingFocus() {
            const page = createPage();
            dismissSpy.target = page;
            page.focusWindow("0x1");
            const request = desktop.lastRequestId;
            desktop.workspaces = desktop.workspaces.concat([workspace(3)]);
            compare(page.pendingDismissRequestId, request);
            desktop.operationFinished(true, "focusWindow", "0x1", request, "");
            compare(dismissSpy.count, 1);
        }

        function test_windowMoveKeepsActionsAttachedToAddress() {
            const page = createPage();
            page.expandedAddress = "0x1";
            page.windowActionMode = "close";
            const moved = client("Moved window");
            moved.workspaceId = 2;
            desktop.windows = [moved];
            wait(0);
            compare(page.expandedAddress, "0x1");
            compare(card(page).expanded, true);
            compare(card(page).actionMode, "close");
            desktop.windows = [];
            compare(page.expandedAddress, "");
            compare(page.windowActionMode, "");
        }

        function test_rightClickOpensActionsWithoutFocusing() {
            const page = createPage();
            wait(0);
            const target = named(page, "windowTarget_0x1");
            verify(target !== null);
            mouseClick(target, target.width / 2, target.height / 2, Qt.RightButton);
            compare(page.expandedAddress, "0x1");
            compare(desktop.focusCalls.length, 0);
            mouseClick(target, target.width / 2, target.height / 2, Qt.RightButton);
            compare(page.expandedAddress, "0x1", "Repeated right click must keep the menu open");
        }

        function test_overviewShowsWindowsAcrossWorkspaces() {
            const second = client("Other workspace window");
            second.address = "0x2";
            second.workspaceId = 2;
            second.focused = false;
            desktop.windows = [client("Original title"), second];
            const page = createPage();
            wait(0);
            verify(card(page, "0x1")?.visible);
            verify(card(page, "0x2")?.visible);
            const target = named(page, "windowTarget_0x2");
            mouseClick(target, target.width / 2, target.height / 2, Qt.LeftButton);
            compare(desktop.focusCalls.length, 1);
            compare(desktop.focusCalls[0].address, "0x2");
        }

        function test_moveMenuTargetsWindowFromAnotherWorkspace() {
            const second = client("Second window");
            second.address = "0x2";
            second.workspaceId = 2;
            desktop.windows = [client("First window"), second];
            const page = createPage();
            page.expandedAddress = "0x2";
            page.windowActionMode = "move";
            wait(0);
            button(card(page, "0x2"), "1").triggered();
            compare(desktop.moveCalls.length, 1);
            compare(desktop.moveCalls[0].address, "0x2");
            compare(desktop.moveCalls[0].workspace, 1);
            compare(page.windowActionMode, "");
        }

        function test_disappearedFocusTargetDoesNotDismiss() {
            const page = createPage();
            dismissSpy.target = page;
            page.focusWindow("0x1");
            const request = desktop.lastRequestId;
            desktop.windows = [];
            desktop.operationFinished(true, "focusWindow", "0x1", request, "");
            compare(dismissSpy.count, 0);
        }

        function assertWithin(item, boundary) {
            const origin = item.mapToItem(boundary, 0, 0);
            verify(origin.x >= -0.5, "left edge outside: " + origin.x);
            verify(origin.x + item.width <= boundary.width + 0.5,
                "right edge outside: " + (origin.x + item.width) + " > " + boundary.width);
        }

        function test_narrowIconButton() {
            const choice = createTemporaryObject(choiceFactory, host);
            wait(0);
            const text = matching(choice, item => item.text === choice.label && item.visible);
            verify(text !== null);
            assertWithin(text, choice);
            verify(text.truncated);
        }

        function test_narrowCloseConfirmation() {
            const page = createPage();
            page.width = 240;
            page.expandedAddress = "0x1";
            page.windowActionMode = "close";
            wait(0);
            const windowCard = card(page);
            verify(windowCard !== null);
            assertWithin(button(windowCard, "Cancel"), windowCard);
            assertWithin(button(windowCard, "Close window"), windowCard);
            const prompt = matching(windowCard, item => item.text === "Close this window?");
            verify(prompt.contentWidth <= prompt.width + 0.5, "Confirmation text overflows its allocated width");
        }

        function test_narrowDeviceRow() {
            const device = createTemporaryObject(deviceFactory, host);
            wait(0);
            const title = matching(device, item => item.text === device.title);
            verify(title !== null);
            assertWithin(title, device);
            verify(title.truncated);
        }

        function test_workspaceCreationIgnoresUnrelatedFailure() {
            const page = createPage();
            page.openWorkspace(3);
            const request = desktop.lastRequestId;
            desktop.operationFinished(false, "closeWindow", "0x2", request + 1, "gone");
            compare(page.pendingWorkspaceId, 3);
            desktop.workspaces = desktop.workspaces.concat([workspace(3)]);
            compare(page.pendingWorkspaceRequestId, request, "Model discovery is not operation completion");
            dismissSpy.target = page;
            desktop.operationFinished(false, "focusWorkspace", "3", request, "failed");
            compare(page.pendingWorkspaceRequestId, 0);
            compare(dismissSpy.count, 0);
        }

        function test_detailActionsShareAvailability() {
            const detail = createTemporaryObject(detailsFactory, host);
            verify(detail !== null);
            const radio = button(detail, "On");
            verify(radio !== null);
            actions.enabled = false;
            compare(radio.available, false);
            actions.enabled = true;
            radio.triggered();
            compare(actions.calls[0], "wifi-toggle");
            detail.section = "bluetooth";
            button(detail, "Off").triggered();
            compare(actions.calls[1], "bluetooth-toggle");
        }

        function test_networkEditorServiceOwnsLaunch() {
            const detail = createTemporaryObject(detailsFactory, host);
            dismissSpy.target = detail;
            services.editorAccepted = false;
            button(detail, "Find another network…").triggered();
            compare(services.editorCalls, 1);
            compare(dismissSpy.count, 0);
            services.editorAccepted = true;
            button(detail, "Find another network…").triggered();
            compare(services.editorCalls, 2);
            compare(dismissSpy.count, 1);
        }
    }
}
