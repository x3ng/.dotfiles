pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

GridLayout {
    id: controls
    required property Theme style
    required property var services
    readonly property var system: services.controls
    signal detailsRequested(string section)
    columns: width >= 480 ? 2 : 1
    columnSpacing: 12
    rowSpacing: 12

    ControlTile {
        Layout.fillWidth: true
        style: controls.style
        icon: "wifi"
        title: "Wi-Fi"
        detail: controls.system.wifiEnabled ? controls.system.wifiConnection : "Off"
        available: controls.system.wifiAvailable
        active: controls.system.wifiEnabled
        toggleable: true
        toggleAvailable: !controls.system.busy
        onTriggered: controls.detailsRequested("wifi")
        onToggled: controls.system.toggleWifi()
    }
    ControlTile {
        Layout.fillWidth: true
        style: controls.style
        icon: "bluetooth"
        title: "Bluetooth"
        detail: !controls.system.bluetoothEnabled ? "Off"
            : controls.system.bluetoothConnected.length
                ? controls.system.bluetoothConnected.length + " connected"
                : "No devices connected"
        available: controls.system.bluetoothAvailable
        active: controls.system.bluetoothEnabled
        toggleable: true
        toggleAvailable: !controls.system.busy
        onTriggered: controls.detailsRequested("bluetooth")
        onToggled: controls.system.toggleBluetooth()
    }
}
