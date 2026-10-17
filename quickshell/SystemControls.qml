pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "components/ConnectionFeedback.js" as ConnectionFeedback

// Native service objects own D-Bus calls and signal subscriptions. Views use
// this adapter for display state and actions, without commands or text parsing.
Scope {
    id: root
    property bool active: false
    property string error: ""
    signal feedback(string key, string summary, string body, bool critical)
    property var connectionTracker: ConnectionFeedback.create()

    function wifiKey(network) { return "wifi:" + network.device.name + ":" + network.name; }
    function bluetoothKey(device) { return "bluetooth:" + device.address; }

    function observeConnections() {
        const rows = wifiEnabled ? wifiNetworks.map(network => ({
            key: wifiKey(network), name: network.name, kind: "wifi", device: network.device.name, connected: network.connected,
            connecting: network.state === ConnectionState.Connecting
        })) : [];
        if (bluetoothEnabled) {
            for (const device of bluetoothDevices) rows.push({
                key: bluetoothKey(device), name: device.name || device.address, kind: "bluetooth",
                connected: device.state === BluetoothDeviceState.Connected,
                connecting: device.state === BluetoothDeviceState.Connecting
            });
        }
        for (const event of ConnectionFeedback.observe(connectionTracker, rows, Date.now())) {
            const kind = event.kind === "wifi" ? "Wi-Fi" : "Bluetooth";
            const summary = kind + (event.result === "connected" ? " connected"
                : event.result === "failed" ? " connection failed" : " disconnected");
            const body = event.name + (event.reason ? ": " + event.reason : "");
            if (event.result === "failed") error = body;
            feedback(event.key, summary, body, false);
        }
        connectionDeadline.running = connectionTracker.pending;
    }
    function scheduleConnectionObservation() { Qt.callLater(observeConnections); }
    onWifiNetworksChanged: scheduleConnectionObservation()
    onBluetoothDevicesChanged: scheduleConnectionObservation()
    onWifiEnabledChanged: {
        if (!wifiEnabled) ConnectionFeedback.silence(connectionTracker, "wifi:");
        scheduleConnectionObservation();
    }
    onBluetoothEnabledChanged: {
        if (!bluetoothEnabled) ConnectionFeedback.silence(connectionTracker, "bluetooth:");
        scheduleConnectionObservation();
    }
    Component.onCompleted: {
        scheduleConnectionObservation();
        refreshPowerAvailability();
    }
    onActiveChanged: { if (active) refreshPowerAvailability(); }

    // Quickshell 0.3.2 exposes no PowerProfiles availability/ready property.
    // Probe its actual D-Bus endpoint at startup and when opening the panel.
    property bool powerServiceAvailable: false
    function refreshPowerAvailability() {
        if (powerProbe.running) return;
        powerProbe.output = "";
        powerProbe.hasStarted = false;
        powerProbe.running = true;
        powerStartupCheck.restart();
    }
    Process {
        id: powerProbe
        property bool hasStarted: false
        property string output: ""
        command: ["busctl", "--system", "--timeout=2", "--json=short", "get-property",
            "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        stdout: StdioCollector { onStreamFinished: powerProbe.output = text }
        onStarted: hasStarted = true
        onExited: (code, status) => {
            let available = false;
            if (code === 0 && status === 0) {
                try {
                    const result = JSON.parse(output);
                    available = result.type === "s" && ["power-saver", "balanced", "performance"].includes(result.data);
                } catch (_) {}
            }
            root.powerServiceAvailable = available;
        }
    }
    Timer {
        id: powerStartupCheck
        interval: 1000
        onTriggered: {
            if (!powerProbe.hasStarted && !powerProbe.running) root.powerServiceAvailable = false;
        }
    }
    Timer {
        id: connectionDeadline
        interval: 1000
        repeat: true
        onTriggered: root.observeConnections()
    }
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
    readonly property var powerProfiles: powerAvailable
        ? ["power-saver", "balanced"].concat(PowerProfiles.hasPerformanceProfile ? ["performance"] : []) : []
    readonly property bool powerAvailable: powerServiceAvailable
    readonly property string powerProfile: powerAvailable ? profileSlug(PowerProfiles.profile) : ""
    readonly property bool wifiBusy: wifiNetworks.some(network => network.stateChanging)
    readonly property bool bluetoothBusy: bluetoothDevices.some(device => device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting)
        || bluetoothAdapter?.state === BluetoothAdapterState.Enabling
        || bluetoothAdapter?.state === BluetoothAdapterState.Disabling

    readonly property bool busy: wifiBusy || bluetoothBusy

    function bluetoothDeviceBusy(device) {
        return device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting;
    }
    function bluetoothDeviceLabel(device) {
        if (device.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        const state = device.connected ? "Connected · Click to disconnect" : "Click to connect";
        return state + (device.batteryAvailable ? " · " + Math.round(device.battery * 100) + "%" : "");
    }

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
            function onConnectedChanged() { root.scheduleConnectionObservation(); }
            function onStateChanged() { root.scheduleConnectionObservation(); }
            function onRequestDisconnect() {
                ConnectionFeedback.silence(root.connectionTracker, root.wifiKey(modelData), true);
                root.scheduleConnectionObservation();
            }
            function onConnectionFailed(reason) {
                root.error = modelData.name + ": " + ConnectionFailReason.toString(reason);
                ConnectionFeedback.failure(root.connectionTracker, root.wifiKey(modelData), ConnectionFailReason.toString(reason));
                root.scheduleConnectionObservation();
            }
        }
    }
    Instantiator {
        model: root.bluetoothDevices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { root.scheduleConnectionObservation(); }
            function onStateChanged() { root.scheduleConnectionObservation(); }
        }
    }
    function toggleWifi() {
        if (!wifiAvailable || wifiBusy) return false;
        error = "";
        if (wifiEnabled) ConnectionFeedback.silence(connectionTracker, "wifi:");
        Networking.wifiEnabled = !Networking.wifiEnabled;
        scheduleConnectionObservation();
        return true;
    }
    function toggleBluetooth() {
        if (!bluetoothAdapter || bluetoothBusy) return false;
        error = "";
        if (bluetoothEnabled) ConnectionFeedback.silence(connectionTracker, "bluetooth:");
        bluetoothAdapter.enabled = !bluetoothAdapter.enabled;
        scheduleConnectionObservation();
        return true;
    }
    function connectWifi(network) {
        if (!wifiEnabled || wifiBusy || !wifiProfiles.includes(network) || network.connected) return false;
        error = "";
        observeConnections();
        // The tracker scopes switch suppression to this network's device.
        ConnectionFeedback.request(connectionTracker, wifiKey(network), Date.now());
        network.connect();
        scheduleConnectionObservation();
        return true;
    }
    function toggleBluetoothDevice(device) {
        if (!bluetoothEnabled || bluetoothDeviceBusy(device) || !bluetoothDevices.includes(device)) return false;
        error = "";
        observeConnections();
        if (device.connected) ConnectionFeedback.silence(connectionTracker, bluetoothKey(device), true);
        else ConnectionFeedback.request(connectionTracker, bluetoothKey(device), Date.now());
        device.connected = !device.connected;
        scheduleConnectionObservation();
        return true;
    }
    function profileSlug(profile) {
        if (profile === PowerProfile.PowerSaver) return "power-saver";
        if (profile === PowerProfile.Performance) return "performance";
        return "balanced";
    }
    function setPowerProfile(profile) {
        if (!powerAvailable || !powerProfiles.includes(profile)) return false;
        error = "";
        PowerProfiles.profile = profile === "power-saver" ? PowerProfile.PowerSaver
            : profile === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
        return true;
    }
}
