pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import ".."

Rectangle {
    id: detail
    required property Theme style
    required property var services
    required property var notifs
    readonly property var system: services.controls
    required property string section
    property bool audioInput: false
    signal dismissRequested()
    readonly property bool isNotifs: section === "notifications"
    readonly property string title: section === "wifi" ? "Wi-Fi"
        : section === "bluetooth" ? "Bluetooth"
        : detail.isNotifs ? "Notifications"
        : "Audio devices"
    readonly property string subtitle: section === "wifi" ? "Saved networks nearby"
        : section === "bluetooth" ? "Paired devices"
        : detail.isNotifs ? (detail.notifs.history.length > 0
            ? detail.notifs.history.length + " saved · click a row to dismiss"
            : "Cleared notifications are kept here")
        : "Choose your default device"
    readonly property bool radioEnabled: section === "wifi" ? system.wifiEnabled : system.bluetoothEnabled
    readonly property var rows: section === "wifi" ? (radioEnabled ? system.wifiProfiles : [])
        : section === "bluetooth" ? (radioEnabled ? system.bluetoothDevices : [])
        : (audioInput ? services.audioInputs : services.audioOutputs)
    onSectionChanged: { audioInput = false; deviceList.positionViewAtBeginning(); notifList.positionViewAtBeginning(); }
    implicitWidth: 380
    implicitHeight: 520
    color: "transparent"
    focus: visible
    Keys.onEscapePressed: dismissRequested()
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        spacing: detail.style.spaceLg
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            Text {
                id: heading
                anchors.left: backButton.right
                anchors.leftMargin: detail.style.spaceMd
                anchors.top: parent.top
                text: detail.title
                color: detail.style.textPrimary
                font.family: detail.style.fontFamily
                font.pixelSize: detail.style.fontSizeHeading
                font.weight: Font.DemiBold
            }
            Text {
                anchors.left: heading.left
                anchors.top: heading.bottom
                anchors.topMargin: 5
                text: detail.subtitle
                color: detail.style.textMuted
                font.family: detail.style.fontFamily
                font.pixelSize: detail.style.fontSizeSmall
            }
            ChoiceButton {
                id: backButton
                anchors.left: parent.left
                anchors.top: parent.top
                width: 38
                height: 38
                style: detail.style
                filled: true
                label: ""
                iconKind: "back"
                iconSize: 20
                onTriggered: detail.dismissRequested()
            }
        }
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
                available: !detail.system.busy
                onTriggered: {
                    if (detail.section === "wifi")
                        detail.system.toggleWifi();
                    else
                        detail.system.toggleBluetooth();
                }
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
                onTriggered: { detail.audioInput = false; deviceList.positionViewAtBeginning(); }
            }
            ChoiceButton {
                Layout.fillWidth: true
                style: detail.style
                label: "Microphone"
                selected: detail.audioInput
                onTriggered: { detail.audioInput = true; deviceList.positionViewAtBeginning(); }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: detail.style.separator
        }
        ListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            visible: !detail.isNotifs
            clip: true
            spacing: detail.style.spaceXs
            model: detail.rows
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                id: scrollbar
                policy: ScrollBar.AsNeeded
                visible: size < 1
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: detail.style.textMuted
                    opacity: scrollbar.active ? 0.7 : 0.3
                }
            }
            delegate: DeviceRow {
                required property var modelData
                width: deviceList.width - 8
                style: detail.style
                title: detail.section === "audio" ? modelData.description || modelData.name : modelData.name
                selected: detail.section === "wifi" ? (modelData.connected ?? false)
                    : detail.section === "bluetooth" ? detail.system.bluetoothConnected.includes(modelData.address)
                    : modelData === (detail.audioInput ? detail.services.source : detail.services.sink)
                subtitle: detail.section === "wifi" ? (selected ? "Connected" : "")
                    : detail.section === "bluetooth" ? (selected ? "Connected · Click to disconnect" : "Click to connect")
                    : selected ? "Current device" : ""
                available: !detail.system.busy
                onTriggered: {
                    if (detail.section === "wifi") {
                        detail.system.connectWifi(modelData);
                    } else if (detail.section === "bluetooth") {
                        detail.system.toggleBluetoothDevice(modelData);
                    } else detail.services.selectAudioDevice(modelData, detail.audioInput);
                }
            }
            Text {
                anchors.centerIn: parent
                visible: deviceList.count === 0
                text: detail.section !== "audio" && !detail.radioEnabled
                    ? detail.title + " is turned off"
                    : detail.section === "wifi" ? "No saved networks nearby"
                    : detail.section === "bluetooth" ? "No paired devices"
                    : "No devices available"
                color: detail.style.textMuted
                font.family: detail.style.fontFamily
                font.pixelSize: detail.style.fontSizeBody
            }
        }
        ListView {
            id: notifList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            visible: detail.isNotifs
            clip: true
            spacing: detail.style.spaceXs
            boundsBehavior: Flickable.StopAtBounds
            model: detail.notifs.history
            ScrollBar.vertical: ScrollBar {
                id: notifScrollbar
                policy: ScrollBar.AsNeeded
                visible: size < 1
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: detail.style.textMuted
                    opacity: notifScrollbar.active ? 0.7 : 0.3
                }
            }
            delegate: NotificationRow {
                required property int index
                required property var modelData
                width: notifList.width - 8
                style: detail.style
                entry: modelData
                onTriggered: detail.notifs.removeHistory(index)
            }
            Text {
                anchors.centerIn: parent
                visible: notifList.count === 0
                text: "No saved notifications"
                color: detail.style.textMuted
                font.family: detail.style.fontFamily
                font.pixelSize: detail.style.fontSizeBody
            }
        }
        Text {
            Layout.fillWidth: true
            visible: detail.system.busy || (detail.section === "wifi" && detail.system.error !== "")
            text: detail.system.busy ? "Applying…" : detail.system.error
            wrapMode: Text.Wrap
            color: detail.style.accentWarm
            font.family: detail.style.fontFamily
            font.pixelSize: detail.style.fontSizeSmall
        }
        ChoiceButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: detail.section === "wifi"
            style: detail.style
            filled: true
            label: "Find another network…"
            onTriggered: { Quickshell.execDetached(["kitty", "--", "nmtui", "connect"]); detail.dismissRequested(); }
        }
        ChoiceButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            visible: detail.isNotifs && detail.notifs.history.length > 0
            style: detail.style
            filled: true
            label: "Clear all history"
            onTriggered: detail.notifs.clearHistory()
        }
    }
}
