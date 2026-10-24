pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

Rectangle {
    id: detail
    required property Theme style
    required property var services
    required property var actions
    required property var notifs
    readonly property var system: services.controls
    required property string section
    property bool audioInput: false
    property bool showHistory: false
    readonly property var notificationEntries: showHistory ? notifs.history : notifs.current
    property bool panelOpen: visible
    signal dismissRequested()
    signal closePanelRequested()
    readonly property bool isNotifs: section === "notifications"
    readonly property string title: section === "wifi" ? "Wi-Fi"
        : section === "bluetooth" ? "Bluetooth"
        : detail.isNotifs ? "Notifications"
        : "Audio devices"
    readonly property string subtitle: section === "wifi" ? "Nearby networks · connect & manage"
        : section === "bluetooth" ? "Devices · discover, pair & connect"
        : detail.isNotifs ? (detail.showHistory ? "Saved notifications · clearing history also dismisses pending entries"
            : "Pending notifications · cleared entries remain in history")
        : "Choose your default device"
    readonly property bool radioEnabled: section === "wifi" ? system.wifiEnabled : system.bluetoothEnabled
    readonly property var rows: audioInput ? services.audioInputs : services.audioOutputs
    onSectionChanged: { audioInput = false; showHistory = false; viewport.contentY = 0; }
    readonly property real naturalHeight: detailHeader.implicitHeight + style.spaceLg + content.implicitHeight
        + (isNotifs ? notificationToolbar.implicitHeight + style.spaceLg : 0)
    implicitWidth: 380
    color: "transparent"
    focus: visible
    Keys.onEscapePressed: dismissRequested()
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        spacing: detail.style.spaceLg
        DetailHeader {
            id: detailHeader
            style: detail.style
            title: detail.title
            subtitle: detail.subtitle
            onBackRequested: detail.dismissRequested()
        }
        RowLayout {
            id: notificationToolbar
            Layout.fillWidth: true
            visible: detail.isNotifs
            spacing: detail.style.spaceSm
            ChoiceButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 36
                filled: true
                style: detail.style
                label: "Pending · " + detail.notifs.current.length
                selected: !detail.showHistory
                onTriggered: { detail.showHistory = false; viewport.contentY = 0; }
            }
            ChoiceButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 36
                filled: true
                style: detail.style
                label: "History · " + detail.notifs.history.length
                selected: detail.showHistory
                onTriggered: { detail.showHistory = true; viewport.contentY = 0; }
            }
            ChoiceButton {
                objectName: "notification-clear-all"
                Layout.preferredWidth: 112
                Layout.preferredHeight: 36
                filled: true
                style: detail.style
                label: detail.showHistory ? "Clear history" : "Clear all"
                available: detail.notificationEntries.length > 0
                onTriggered: {
                    if (detail.showHistory) detail.notifs.clearHistory();
                    else detail.notifs.clearCurrent();
                }
            }
        }
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            implicitHeight: content.implicitHeight
            radius: detail.style.radiusCard
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
                    spacing: detail.style.spaceLg
                    RowLayout {
                        Layout.fillWidth: true
                        visible: detail.section === "wifi" || detail.section === "bluetooth"
                        Text {
                            Layout.fillWidth: true
                            text: detail.radioEnabled ? "Enabled" : "Disabled"
                            color: detail.style.textSecondary
                            font.family: detail.style.fontFamily
                            font.pixelSize: detail.style.fontSizeBody
                        }
                        ChoiceButton {
                            Layout.preferredWidth: 80
                            style: detail.style
                            label: detail.radioEnabled ? "On" : "Off"
                            filled: true
                            selected: detail.radioEnabled
                            available: detail.actions.available(detail.section + "-toggle")
                            onTriggered: detail.actions.execute(detail.section + "-toggle")
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: detail.section === "audio"
                        spacing: detail.style.spaceSm
                        ChoiceButton {
                            Layout.fillWidth: true
                            style: detail.style
                            label: "Output"
                            selected: !detail.audioInput
                            onTriggered: { detail.audioInput = false; viewport.contentY = 0; }
                        }
                        ChoiceButton {
                            Layout.fillWidth: true
                            style: detail.style
                            label: "Microphone"
                            selected: detail.audioInput
                            onTriggered: { detail.audioInput = true; viewport.contentY = 0; }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: detail.style.separator
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: detail.section === "audio"
                        spacing: detail.style.spaceXs
                        Repeater {
                            model: detail.rows
                            delegate: DeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                style: detail.style
                                title: modelData.description || modelData.name
                                selected: modelData === (detail.audioInput ? detail.services.source : detail.services.sink)
                                subtitle: selected ? "Current device" : ""
                                onTriggered: detail.services.selectAudioDevice(modelData, detail.audioInput)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: detail.rows.length === 0
                            text: "No audio devices available"
                            color: detail.style.textMuted
                            font.family: detail.style.fontFamily
                            font.pixelSize: detail.style.fontSizeBody
                        }
                    }
                    ConnectivityPane {
                        Layout.fillWidth: true
                        visible: detail.section === "wifi" || detail.section === "bluetooth"
                        active: detail.panelOpen && visible
                        section: detail.section
                        style: detail.style
                        services: detail.services
                        onRevealRequested: viewport.contentY = 0
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: detail.isNotifs
                        spacing: detail.style.spaceXs
                        Repeater {
                            model: detail.notificationEntries
                            delegate: NotificationRow {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                style: detail.style
                                entry: modelData
                                compact: false
                                actions: detail.notifs.entryActions(entry)
                                activationLabel: detail.notifs.activationLabel(entry)
                                onActivated: { if (detail.notifs.activateEntry(entry)) detail.closePanelRequested(); }
                                onActionRequested: action => { if (detail.notifs.invokeEntryAction(entry, action)) detail.closePanelRequested(); }
                                onTriggered: {
                                    if (detail.showHistory) detail.notifs.removeHistory(index);
                                    else detail.notifs.removeCurrent(index);
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: detail.notificationEntries.length === 0
                            text: detail.showHistory ? "No saved notifications" : "No pending notifications"
                            color: detail.style.textMuted
                            font.family: detail.style.fontFamily
                            font.pixelSize: detail.style.fontSizeBody
                        }
                    }

                }
            }
        }
    }
}
