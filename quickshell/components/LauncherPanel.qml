pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray

PanelWindow {
    id: panel
    required property var services
    required property var style
    required property var appearance
    required property var searchModel
    property bool open: false
    property string controlSection: ""
    readonly property bool searching: query.trim().length > 0
    property string query: ""
    property int selectedIndex: 0
    readonly property var sink: services.sink
    readonly property var player: services.player
    readonly property var results: searchModel.results

    function handleKey(event) {
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
        screen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
        query = "";
        selectedIndex = 0;
        open = true;
        Qt.callLater(() => search.forceActiveFocus());
    }
    function dismiss() { trayMenu.dismiss(); controlSection = ""; open = false; }
    function returnToStatus() {
        controlSection = "";
        Qt.callLater(() => search.forceActiveFocus());
    }
    function moveSelection(delta) {
        if (!searching || !results.length) return;
        selectedIndex = (selectedIndex + delta + results.length) % results.length;
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function activate(index, forceTerminal = false) {
        const result = results[index];
        if (!searching || !result) return;
        if (searchModel.activate(index, forceTerminal)) dismiss();
    }
    onQueryChanged: { controlSection = ""; selectedIndex = 0; resultList.positionViewAtBeginning(); }
    onResultsChanged: selectedIndex = Math.min(selectedIndex, Math.max(0, results.length - 1))

    visible: open
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
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
        anchors.fill: parent
        color: panel.style.backdrop
        MouseArea { anchors.fill: parent; onClicked: panel.dismiss() }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // Keep the search field stationary as status/search content changes height.
        anchors.topMargin: Math.max(16, Math.round((parent.height - panel.style.maximumPanelHeight) / 2))
        width: Math.min(680, parent.width - 32)
        height: Math.min(panel.style.maximumPanelHeight, parent.height - anchors.topMargin - 16,
            (panel.controlSection !== "" ? panel.style.maximumPanelHeight
                : panel.searching ? searchResultsPage.naturalHeight : statusPage.naturalHeight)
                + panel.style.panelPadding * 2 + panel.style.stripHeight * 2 + panel.style.panelGap * 2)
        radius: panel.style.radiusPanel
        color: panel.style.panelSurface
        border.color: panel.style.outline
        border.width: 1
        // Stop clicks in blank areas reaching the outside-dismiss handler.
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: {
            if (panel.controlSection !== "") panel.returnToStatus();
            else panel.dismiss();
        }
        Keys.onPressed: event => panel.handleKey(event)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: panel.style.panelPadding
            spacing: panel.style.panelGap

            Rectangle {
                visible: panel.controlSection === ""
                Layout.fillWidth: true
                Layout.preferredHeight: panel.style.stripHeight
                radius: panel.style.radiusInput
                color: panel.style.surfaceRaised
                border.color: search.activeFocus ? panel.style.accent : panel.style.outline
                border.width: 1
                EmacsInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: panel.style.fontFamily
                    font.pixelSize: 14
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
                    Keys.onEscapePressed: panel.dismiss()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: "Search applications and windows…"
                        color: panel.style.textMuted
                        font: search.font
                    }
                }
            }

            StackLayout {
                Layout.minimumHeight: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: panel.controlSection !== "" ? 2 : panel.searching ? 0 : 1
                ColumnLayout {
                    id: searchResultsPage
                    readonly property real naturalHeight: resultHeading.implicitHeight + spacing
                        + Math.max(80, panel.results.length * 40
                            + Math.max(0, panel.results.length - 1) * resultList.spacing)
                    Layout.minimumHeight: 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    Text {
                        id: resultHeading
                        text: panel.query ? "RESULTS · " + panel.results.length : "WINDOWS & APPLICATIONS"
                        color: panel.style.textMuted
                        font.family: panel.style.fontFamily
                        font.pixelSize: 11
                    }
                    ListView {
                        id: resultList
                        Layout.minimumHeight: 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: panel.searching ? panel.results : []
                        spacing: 2
                        delegate: Rectangle {
                            id: resultRow
                            required property var modelData
                            required property int index
                            width: resultList.width
                            height: 40
                            radius: panel.style.radiusControl
                            color: index === panel.selectedIndex ? panel.style.surfaceSelected
                                : rowMouse.containsMouse ? panel.style.surfaceHover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10
                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    IconImage {
                                        id: resultIcon
                                        anchors.fill: parent
                                        implicitSize: 24
                                        source: panel.searchModel.desktopIconSource(resultRow.modelData.entry)
                                        visible: source !== "" && status !== Image.Error
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !resultIcon.visible
                                        text: resultRow.modelData.kind === "WINDOW" ? "▣" : "◇"
                                        color: panel.style.textSecondary
                                        font.pixelSize: 24
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: resultRow.modelData.title
                                    color: resultRow.index === panel.selectedIndex
                                        ? panel.style.textSelected : panel.style.textPrimary
                                    elide: Text.ElideRight
                                    font.family: panel.style.fontFamily
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: resultRow.modelData.kind
                                    color: panel.style.textMuted
                                    font.family: panel.style.fontFamily
                                    font.pixelSize: 10
                                }
                                Text {
                                    visible: resultRow.index < 10
                                    text: "Ctrl+" + (resultRow.index === 9 ? "0" : String(resultRow.index + 1))
                                    color: resultRow.index === panel.selectedIndex
                                        ? panel.style.textSelected : panel.style.textMuted
                                    font.family: panel.style.fontFamily
                                    font.pixelSize: 11
                                }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: panel.activate(resultRow.index)
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !panel.results.length
                            text: "No matching applications or windows"
                            color: panel.style.textMuted
                            font.pixelSize: 13
                        }
                    }
                }
                StatusPage {
                    id: statusPage
                    Layout.minimumHeight: 0
                    services: panel.services
                    searchModel: panel.searchModel
                    style: panel.style
                    appearance: panel.appearance
                    sink: panel.sink
                    player: panel.player
                    panelOpen: panel.open && !panel.searching && panel.controlSection === ""
                    onDetailsRequested: section => {
                        trayMenu.dismiss();
                        panel.controlSection = section;
                        Qt.callLater(() => controlDetails.forceActiveFocus());
                    }
                }
                ControlDetails {
                    id: controlDetails
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    style: panel.style
                    services: panel.services
                    section: panel.controlSection
                    onDismissRequested: panel.returnToStatus()
                    Keys.onPressed: event => panel.handleKey(event)
                }
            }
            PanelFooter {
                id: footer
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
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
