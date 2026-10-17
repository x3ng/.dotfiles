pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import ".."

PanelWindow {
    id: panel
    required property var services
    required property Theme style
    required property var appearance
    required property var searchModel
    required property var hyprControls
    required property var notifs
    required property var keyboard
    required property var actions
    required property var panelState
    property bool open: false
    property string homeTab: "desktop"
    readonly property var homeTabDefinitions: [
        {key: "desktop", label: "Desktop"},
        {key: "controls", label: "System controls"}
    ]
    readonly property var detailSections: ["wifi", "bluetooth", "audio", "notifications"]
    // Read actual StackLayout indices so adding/reordering a page cannot change
    // the meaning of navigation or page-specific lifecycle bindings.
    readonly property var pageIndexes: ({
        search: searchResultsPage.StackLayout.index,
        controls: statusPage.StackLayout.index,
        details: controlDetails.StackLayout.index,
        desktop: desktopPage.StackLayout.index
    })
    property string controlSection: ""
    readonly property bool searching: query.trim().length > 0
    readonly property bool showingDetails: controlSection !== ""
    readonly property int activePage: showingDetails ? pageIndexes.details
        : searching ? pageIndexes.search : pageIndexes[homeTab]
    property string query: ""
    property int selectedIndex: 0
    property var selectedKey: null
    property string selectionQuery: ""
    property int selectionRevision: 0
    readonly property var sink: services.sink
    readonly property var player: services.player
    readonly property var results: searchModel.results

    function handleKey(event) {
        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                && open && !searching && !showingDetails && !search.inputMethodComposing) {
            const tabs = homeTabDefinitions.map(tab => tab.key);
            const direction = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
            selectHome(tabs[(tabs.indexOf(homeTab) + direction + tabs.length) % tabs.length]);
            event.accepted = true;
            return;
        }
        if (!(event.modifiers & Qt.ControlModifier)) return;
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if (!searching) return;
            const index = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1;
            activate(index);
            event.accepted = true;
            return;
        }
        switch (event.key) {
        case Qt.Key_N: panel.moveSelection(1); break;
        case Qt.Key_P: panel.moveSelection(-1); break;
        case Qt.Key_G: panel.dismiss(); break;
        default: return;
        }
        event.accepted = true;
    }

    function toggle() {
        if (open) { dismiss(); return; }
        const name = Hyprland.focusedMonitor?.name;
        openOnScreen(Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0]);
    }
    function openOnScreen(targetScreen) {
        if (open || !targetScreen) return;
        screen = targetScreen;
        trayMenu.dismiss();
        controlSection = "";
        query = "";
        selectedIndex = 0;
        // Read the panel state only when opening. A late disk load must not
        // navigate away from the page the user is already interacting with.
        const savedTab = panelState.lastHomeTab;
        homeTab = homeTabDefinitions.some(tab => tab.key === savedTab) ? savedTab : "desktop";
        open = true;
        Qt.callLater(() => { if (panel.open && !panel.showingDetails) search.forceActiveFocus(); });
    }
    function dismiss() { trayMenu.dismiss(); controlSection = ""; open = false; }
    function selectHome(tab) {
        if (!homeTabDefinitions.some(definition => definition.key === tab)) return;
        trayMenu.dismiss();
        homeTab = tab;
        panelState.setLastHomeTab(tab);
        returnToHome();
    }
    function returnToHome() {
        query = "";
        controlSection = "";
        Qt.callLater(() => { if (panel.open && !panel.showingDetails) search.forceActiveFocus(); });
    }
    function showDetails(section) {
        if (!detailSections.includes(section)) return false;
        trayMenu.dismiss();
        query = "";
        homeTab = "controls";
        panelState.setLastHomeTab("controls");
        controlSection = section;
        Qt.callLater(() => { if (panel.open && panel.showingDetails) controlDetails.forceActiveFocus(); });
        return true;
    }
    function handleEscape() {
        if (showingDetails || searching) returnToHome();
        else dismiss();
    }
    function moveSelection(delta) {
        if (!searching || !results.length) return;
        selectionRevision++;
        selectedIndex = (selectedIndex + delta + results.length) % results.length;
        selectedKey = results[selectedIndex].key;
        searchResultsPage.showSelection(selectedIndex);
    }
    function syncSelection(reset = false) {
        const sameQuery = !reset && selectionQuery === query;
        const previous = sameQuery ? results.findIndex(result => result.key === selectedKey) : -1;
        selectedIndex = previous >= 0 ? previous : sameQuery
            ? Math.min(selectedIndex, Math.max(0, results.length - 1)) : 0;
        selectedKey = results[selectedIndex]?.key ?? null;
        selectionQuery = query;
        // A retained result may move outside the old viewport after re-ranking.
        Qt.callLater(() => {
            if (panel.open && panel.searching) searchResultsPage.showSelection(selectedIndex);
        });
    }
    function resetSelection() {
        const revision = ++selectionRevision;
        selectedIndex = 0;
        selectedKey = null;
        selectionQuery = query;
        // query and the derived results can notify in either order. Do not
        // retain an identity from the old query while bindings are settling.
        Qt.callLater(() => {
            if (revision === selectionRevision) syncSelection(true);
        });
    }
    function activate(index, forceTerminal = false) {
        const result = results[index];
        if (!searching || !result || result.enabled === false) return;
        if (result.kind === "ACTION") {
            // Keep the row before clearing the query reshuffles the model.
            const previousQuery = query;
            query = "";
            const outcome = searchModel.activateResult(result, forceTerminal);
            if (!outcome.accepted) query = previousQuery;
        } else {
            const outcome = searchModel.activateResult(result, forceTerminal);
            if (outcome.accepted && outcome.closePanel) dismiss();
        }
    }
    onQueryChanged: {
        trayMenu.dismiss();
        controlSection = "";
        resetSelection();
        searchResultsPage.resetScroll();
    }
    onResultsChanged: syncSelection()

    visible: open || card.opacity > 0
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    // Respect the screen keyboard's exclusive zone so the backdrop never
    // covers its keys, even when this overlay is mapped after the keyboard.
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-launcher"

    TrayMenuPopup { id: trayMenu; style: panel.style; panelWindow: panel }
    readonly property var trayItems: SystemTray.items.values
    onTrayItemsChanged: {
        if (trayMenu.owner && !trayItems.includes(trayMenu.owner)) trayMenu.dismiss();
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        id: backdropRect
        anchors.fill: parent
        color: panel.style.backdrop
        opacity: panel.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: panel.dismiss() }
    }

    Rectangle {
        id: card
        opacity: panel.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // Keep the search field stationary as status/search content changes height.
        anchors.topMargin: Math.max(16, Math.round((parent.height - panel.style.maximumPanelHeight) / 2))
        width: Math.min(panel.style.maximumPanelWidth, parent.width - 32)
        readonly property real contentHeight: panel.showingDetails ? controlDetails.naturalHeight
            : panel.searching ? searchResultsPage.naturalHeight
            : panel.homeTab === "desktop" ? desktopPage.naturalHeight : statusPage.naturalHeight
        readonly property real chromeHeight: panel.showingDetails ? 0
            : panel.style.stripHeight + footer.implicitHeight + panel.style.panelGap * 2
                + (homeTabs.visible ? homeTabs.implicitHeight + panel.style.panelGap : 0)
        // Each page sizes to its own content, subject to one shared ceiling.
        height: Math.min(panel.style.maximumPanelHeight, parent.height - anchors.topMargin - 16,
            contentHeight + chromeHeight + panel.style.panelPadding * 2)
        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        radius: panel.style.radiusPanel
        color: panel.style.panelSurface
        border.color: panel.style.outline
        border.width: 1
        // Stop clicks in blank areas reaching the outside-dismiss handler.
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: panel.handleEscape()
        Keys.onPressed: event => panel.handleKey(event)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: panel.style.panelPadding
            spacing: panel.style.panelGap

            Rectangle {
                id: searchStrip
                visible: !panel.showingDetails
                Layout.fillWidth: true
                Layout.preferredHeight: panel.style.stripHeight
                Layout.minimumHeight: panel.style.stripHeight
                Layout.maximumHeight: panel.style.stripHeight
                radius: panel.style.radiusInput
                color: panel.style.surfaceRaised
                border.color: search.activeFocus ? panel.style.accent : panel.style.outline
                border.width: 1
                EmacsInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: panel.style.spaceMd
                    anchors.rightMargin: keyboardButton.width + panel.style.spaceSm * 2
                    anchors.topMargin: panel.style.spaceSm
                    anchors.bottomMargin: panel.style.spaceSm
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: panel.style.fontFamily
                    font.pixelSize: panel.style.fontSizeControl
                    color: panel.style.textPrimary
                    selectionColor: panel.style.surfaceSelected
                    selectedTextColor: panel.style.textSelected
                    clip: true
                    text: panel.query
                    onTextChanged: panel.query = text
                    onShortcut: event => panel.handleKey(event)
                    Keys.onDownPressed: panel.moveSelection(1)
                    Keys.onUpPressed: panel.moveSelection(-1)
                    Keys.onReturnPressed: event => panel.activate(panel.selectedIndex, !!(event.modifiers & Qt.ShiftModifier))
                    Keys.onEnterPressed: event => panel.activate(panel.selectedIndex, !!(event.modifiers & Qt.ShiftModifier))
                    Keys.onEscapePressed: panel.handleEscape()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search apps, windows and actions…"
                        color: panel.style.textMuted
                        font: search.font
                    }
                }
                ChoiceButton {
                    id: keyboardButton
                    anchors.right: parent.right
                    anchors.rightMargin: panel.style.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 32
                    style: panel.style
                    label: ""
                    iconKind: "keyboard"
                    iconSize: 20
                    selected: panel.keyboard.shown
                    available: panel.keyboard.available && !panel.keyboard.pending
                    ToolTip.visible: keyboardHover.hovered
                    ToolTip.delay: 500
                    ToolTip.text: panel.keyboard.error || (!panel.keyboard.available
                        ? "Screen keyboard unavailable" : panel.keyboard.shown
                            ? "Hide screen keyboard" : "Show screen keyboard")
                    HoverHandler { id: keyboardHover }
                    onTriggered: {
                        search.forceActiveFocus();
                        panel.actions.execute("keyboard");
                    }
                }
            }

            RowLayout {
                id: homeTabs
                visible: !panel.showingDetails && !panel.searching
                Layout.fillWidth: true
                spacing: panel.style.spaceSm
                Repeater {
                    model: panel.homeTabDefinitions
                    ChoiceButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        style: panel.style
                        label: modelData.label
                        selected: panel.homeTab === modelData.key
                        filled: true
                        filledColor: panel.style.surfaceRaised
                        onTriggered: panel.selectHome(modelData.key)
                    }
                }
            }

            StackLayout {
                id: pages
                Layout.minimumHeight: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                currentIndex: panel.activePage
                SearchResultsPage {
                    id: searchResultsPage
                    style: panel.style
                    results: panel.results
                    searchModel: panel.searchModel
                    selectedIndex: panel.selectedIndex
                    active: panel.searching && !panel.showingDetails
                    onActivateRequested: index => panel.activate(index)
                }
                StatusPage {
                    id: statusPage
                    Layout.minimumHeight: 0
                    services: panel.services
                    actions: panel.actions
                    style: panel.style
                    appearance: panel.appearance
                    notifs: panel.notifs
                    sink: panel.sink
                    player: panel.player
                    panelOpen: panel.open && panel.activePage === panel.pageIndexes.controls
                }
                ControlDetails {
                    id: controlDetails
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    style: panel.style
                    services: panel.services
                    actions: panel.actions
                    notifs: panel.notifs
                    section: panel.controlSection
                    onDismissRequested: panel.returnToHome()
                    Keys.onPressed: event => panel.handleKey(event)
                }
                DesktopPage {
                    id: desktopPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    style: panel.style
                    searchModel: panel.searchModel
                    controls: panel.hyprControls
                    actions: panel.actions
                    panelOpen: panel.open && panel.activePage === panel.pageIndexes.desktop
                    onDismissRequested: panel.dismiss()
                }
            }
            PanelFooter {
                id: footer
                visible: !panel.showingDetails
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.minimumHeight: implicitHeight
                Layout.maximumHeight: implicitHeight
                style: panel.style
                services: panel.services
                appearance: panel.appearance
                trayItems: panel.trayItems
                date: clock.date
                onMenuRequested: (owner, right, top) => {
                    const pos = footer.mapToItem(panel.contentItem, right, top);
                    const showMenu = () => trayMenu.openFor(owner, pos.x, pos.y);
                    if (!showMenu()) Qt.callLater(showMenu);
                }
            }
        }
    }
}
