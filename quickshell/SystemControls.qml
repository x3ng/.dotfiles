pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// Native service objects own D-Bus calls and signal subscriptions. Views use
// this adapter for display state and actions, without commands or text parsing.
Scope {
    id: root
    property bool active: false
    property string error: ""
    readonly property var wifiDevices: Networking.devices.values.filter(device => device.type === DeviceType.Wifi)
    readonly property var wifiNetworks: wifiDevices.reduce((networks, device) => networks.concat(device.networks.values), [])
    readonly property var wifiProfiles: wifiNetworks.filter(network => network.known)
        .sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
    readonly property bool wifiAvailable: wifiDevices.length > 0
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string wifiConnection: wifiNetworks.find(network => network.connected)?.name ?? "Not connected"
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: bluetoothAdapter !== null
    readonly property bool bluetoothEnabled: bluetoothAdapter?.enabled ?? false
    readonly property var bluetoothDevices: bluetoothAdapter?.devices.values.filter(device => device.paired) ?? []
    readonly property var bluetoothConnected: bluetoothDevices.filter(device => device.connected).map(device => device.address)
    readonly property var powerProfiles: ["power-saver", "balanced"].concat(PowerProfiles.hasPerformanceProfile ? ["performance"] : [])
    readonly property bool powerAvailable: powerProfiles.length > 0
    readonly property string powerProfile: profileSlug(PowerProfiles.profile)
    readonly property bool busy: wifiNetworks.some(network => network.stateChanging)
        || bluetoothDevices.some(device => device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting)
        || bluetoothAdapter?.state === BluetoothAdapterState.Enabling
        || bluetoothAdapter?.state === BluetoothAdapterState.Disabling

    Instantiator {
        model: root.wifiDevices
        delegate: Binding {
            required property var modelData
            target: modelData
            property: "scannerEnabled"
            value: root.active
            restoreMode: Binding.RestoreNone
        }
    }
    Instantiator {
        model: root.wifiNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root.error = modelData.name + ": " + ConnectionFailReason.toString(reason);
            }
        }
    }
    function toggleWifi() {
        if (!wifiAvailable || busy) return;
        error = "";
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
    function toggleBluetooth() {
        if (!bluetoothAdapter || busy) return;
        error = "";
        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
    }
    function connectWifi(network) {
        if (!wifiEnabled || busy || !wifiProfiles.includes(network) || network.connected) return;
        error = "";
        network.connect();
    }
    function toggleBluetoothDevice(device) {
        if (!bluetoothEnabled || busy || !bluetoothDevices.includes(device)) return;
        error = "";
        device.connected = !device.connected;
    }
    function profileSlug(profile) {
        if (profile === PowerProfile.PowerSaver) return "power-saver";
        if (profile === PowerProfile.Performance) return "performance";
        return "balanced";
    }
    function setPowerProfile(profile) {
        if (!powerProfiles.includes(profile)) return;
        error = "";
        PowerProfiles.profile = profile === "power-saver" ? PowerProfile.PowerSaver
            : profile === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
