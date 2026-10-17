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
    signal dismissRequested()
    readonly property bool isNotifs: section === "notifications"
    readonly property string title: section === "wifi" ? "Wi-Fi"
        : section === "bluetooth" ? "Bluetooth"
        : detail.isNotifs ? "Notifications"
        : "Audio devices"
    readonly property string subtitle: section === "wifi" ? "Saved networks nearby"
        : section === "bluetooth" ? "Paired devices"
        : detail.isNotifs ? (detail.notifs.history.length > 0
            ? detail.notifs.history.length + " saved · expand to read"
            : "Cleared notifications are kept here")
        : "Choose your default device"
    readonly property bool sectionBusy: section === "wifi" ? system.wifiBusy
        : section === "bluetooth" ? system.bluetoothBusy : false
    readonly property bool radioEnabled: section === "wifi" ? system.wifiEnabled : system.bluetoothEnabled
    readonly property var rows: section === "wifi" ? (radioEnabled ? system.wifiProfiles : [])
        : section === "bluetooth" ? (radioEnabled ? system.bluetoothDevices : [])
        : (audioInput ? services.audioInputs : services.audioOutputs)
    onSectionChanged: { audioInput = false; viewport.contentY = 0; }
    readonly property real naturalHeight: detailHeader.implicitHeight + style.spaceLg + content.implicitHeight
    implicitWidth: 380
    color: "transparent"
    focus: visible
    Keys.onEscapePressed: dismissRequested()
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        spacing: detail.style.spaceLg
        Item {
            id: detailHeader
            implicitHeight: 54
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            Layout.minimumHeight: implicitHeight
            Text {
                id: heading
                anchors.left: backButton.right
                anchors.leftMargin: detail.style.spaceMd
                anchors.top: parent.top
                anchors.right: parent.right
                elide: Text.ElideRight
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
                anchors.right: parent.right
                elide: Text.ElideRight
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
                        visible: !detail.isNotifs
                        spacing: detail.style.spaceXs
                        Repeater {
                            model: detail.rows
                            delegate: DeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                style: detail.style
                                title: detail.section === "audio" ? modelData.description || modelData.name : modelData.name
                                selected: detail.section === "wifi" ? (modelData.connected ?? false)
                                    : detail.section === "bluetooth" ? detail.system.bluetoothConnected.includes(modelData.address)
                                    : modelData === (detail.audioInput ? detail.services.source : detail.services.sink)
                                subtitle: detail.section === "wifi" ? (modelData.stateChanging ? "Connecting…" : selected ? "Connected" : "")
                                    : detail.section === "bluetooth" ? detail.system.bluetoothDeviceLabel(modelData)
                                    : selected ? "Current device" : ""
                                available: detail.section === "wifi" ? !detail.system.wifiBusy
                                    : detail.section === "bluetooth" ? !detail.system.bluetoothDeviceBusy(modelData) : true
                                onTriggered: {
                                    if (detail.section === "wifi") {
                                        detail.system.connectWifi(modelData);
                                    } else if (detail.section === "bluetooth") {
                                        detail.system.toggleBluetoothDevice(modelData);
                                    } else detail.services.selectAudioDevice(modelData, detail.audioInput);
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: detail.rows.length === 0
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
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: detail.isNotifs
                        spacing: detail.style.spaceXs
                        Repeater {
                            model: detail.notifs.history
                            delegate: NotificationRow {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                style: detail.style
                                entry: modelData
                                compact: false
                                onTriggered: detail.notifs.removeHistory(index)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            visible: detail.notifs.history.length === 0
                            text: "No saved notifications"
                            color: detail.style.textMuted
                            font.family: detail.style.fontFamily
                            font.pixelSize: detail.style.fontSizeBody
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: detail.sectionBusy || (detail.section === "wifi" && detail.system.error !== "")
                        text: detail.sectionBusy ? "Applying…" : detail.system.error
                        textFormat: Text.PlainText
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
                        available: detail.services.terminalCommand.length > 0
                        onTriggered: {
                            if (detail.services.openNetworkEditor()) detail.dismissRequested();
                        }
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
        }
    }
}
