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
    readonly property bool searching: query.trim().length > 0
    property string query: ""
    property int selectedIndex: 0
    readonly property var sink: services.sink
    readonly property var battery: services.battery
    readonly property var player: services.player
    readonly property var results: searchModel.results

    function handleKey(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return;
        switch (event.key) {
        case Qt.Key_N:
        case Qt.Key_J:
            panel.moveSelection(1); break;
        case Qt.Key_P:
        case Qt.Key_K:
            panel.moveSelection(-1); break;
        case Qt.Key_H:
            search.cursorPosition = Math.max(0, search.cursorPosition - 1); break;
        case Qt.Key_L:
            search.cursorPosition = Math.min(search.text.length, search.cursorPosition + 1); break;
        case Qt.Key_F:
            search.cursorPosition = Math.min(search.text.length, search.cursorPosition + 1); break;
        case Qt.Key_B:
            search.cursorPosition = Math.max(0, search.cursorPosition - 1); break;
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
    function dismiss() { trayMenu.dismiss(); open = false; }
    function moveSelection(delta) {
        if (!searching || !results.length) return;
        selectedIndex = (selectedIndex + delta + results.length) % results.length;
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }
    function activate(index) {
        const result = results[index];
        if (!searching || !result) return;
        if (searchModel.activate(index)) dismiss();
    }
    onQueryChanged: { selectedIndex = 0; resultList.positionViewAtBeginning(); }
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
        anchors.centerIn: parent
        width: Math.min(680, parent.width - 32)
        height: Math.min(560, parent.height - 32)
        radius: panel.style.radiusPanel
        color: panel.style.panelSurface
        border.color: panel.style.outline
        border.width: 1
        // Stop clicks in blank areas reaching the outside-dismiss handler.
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: panel.dismiss()
        Keys.onPressed: event => panel.handleKey(event)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: panel.style.radiusInput
                color: panel.style.surfaceRaised
                border.color: search.activeFocus ? panel.style.accent : panel.style.outline
                border.width: 1
                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.margins: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: panel.style.fontFamily
                    font.pixelSize: 16
                    color: panel.style.textPrimary
                    selectionColor: panel.style.surfaceSelected
                    selectedTextColor: panel.style.textSelected
                    clip: true
                    text: panel.query
                    onTextEdited: panel.query = text
                    Keys.onPressed: event => panel.handleKey(event)
                    Keys.onDownPressed: panel.moveSelection(1)
                    Keys.onUpPressed: panel.moveSelection(-1)
                    Keys.onReturnPressed: panel.activate(panel.selectedIndex)
                    Keys.onEnterPressed: panel.activate(panel.selectedIndex)
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
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: panel.searching ? 0 : 1
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    Text {
                        text: panel.query ? "RESULTS · " + panel.results.length : "WINDOWS & APPLICATIONS"
                        color: panel.style.textMuted
                        font.family: panel.style.fontFamily
                        font.pixelSize: 11
                    }
                    ListView {
                        id: resultList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: panel.searching ? panel.results : []
                        spacing: 4
                        delegate: Rectangle {
                            id: resultRow
                            required property var modelData
                            required property int index
                            width: resultList.width
                            height: 58
                            radius: panel.style.radiusControl
                            color: index === panel.selectedIndex ? panel.style.surfaceSelected
                                : rowMouse.containsMouse ? panel.style.surfaceHover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10
                                Item {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    IconImage {
                                        id: resultIcon
                                        anchors.fill: parent
                                        implicitSize: 28
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
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
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
                                        Layout.fillWidth: true
                                        text: resultRow.modelData.kind + " · " + resultRow.modelData.detail
                                        color: panel.style.textSecondary
                                        elide: Text.ElideRight
                                        font.family: panel.style.fontFamily
                                        font.pixelSize: 11
                                    }
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
                    services: panel.services
                    style: panel.style
                    appearance: panel.appearance
                    sink: panel.sink
                    battery: panel.battery
                    player: panel.player
                    panelOpen: panel.open && !panel.searching
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd ddd  HH:mm")
                        + (panel.battery?.isPresent ? "  ·  BAT " + Math.round(panel.battery.percentage * 100) + "%" : "")
                        + "  ·  VOL " + (panel.sink?.audio?.muted ? "MUTE" : panel.sink?.audio ? Math.round(panel.sink.audio.volume * 100) + "%" : "—")
                        + (panel.services.brightness >= 0 ? "  ·  BRI " + Math.round(panel.services.brightness * 100) + "%" : "")
                        + "  ·  " + (!panel.appearance.appearanceAvailable ? "OFFLINE" : !panel.appearance.appearanceKnown ? "UNSET" : panel.appearance.appearanceError ? "ERROR" : panel.appearance.darkMode ? "DARK" : "LIGHT")
                    color: panel.style.textPrimary
                    font.family: panel.style.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                Repeater {
                    model: panel.trayItems
                    Rectangle {
                        id: trayItem
                        required property var modelData
                        width: 28; height: 28
                        radius: panel.style.radiusSmall
                        color: trayMouse.containsMouse ? panel.style.surfaceHover : "transparent"
                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            source: trayItem.modelData.icon
                        }
                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: event => {
                                if (event.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                    const pos = trayItem.mapToItem(panel.contentItem, 0, trayItem.height);
                                    const showMenu = () => trayMenu.openFor(trayItem.modelData,
                                        pos.x + trayItem.width, pos.y - trayItem.height);
                                    if (!showMenu()) Qt.callLater(showMenu);
                                } else trayItem.modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
