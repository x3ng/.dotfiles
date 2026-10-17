pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Panel preferences belong to the panel; other modules own their own state files.
Scope {
    id: root
    readonly property string lastHomeTab: selectedHomeTab
    readonly property bool ready: loadedOnce
    readonly property string error: persistenceError
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
        || Quickshell.env("HOME") + "/.local/state") + "/quickshell/panel-state.json"
    signal feedback(string key, string summary, string body, bool critical)

    property string selectedHomeTab: "desktop"
    property bool loadedOnce: false
    property bool persistenceAllowed: false
    property string persistenceError: ""
    property int revision: 0
    property int writingRevision: 0
    property bool dirty: false
    property bool writeInFlight: false
    property string persistedTab: ""
    property string writingTab: ""

    function reportError(message) {
        persistenceError = message;
        feedback("panel-state", "Panel preferences not saved", message, false);
    }

    function setLastHomeTab(tab) {
        if (tab !== "desktop" && tab !== "controls") return false;
        // Even selecting the default before loading expresses newer user intent.
        selectedHomeTab = tab;
        revision++;
        dirty = true;
        flush();
        return true;
    }

    function applyLoaded(contents) {
        if (loadedOnce) return;
        let data;
        try {
            data = JSON.parse(contents);
        } catch (_) {
            finishLoad(false, "Could not parse panel preferences. The original file is preserved; changes are temporary.");
            return;
        }
        if (!data || data.version !== 1
                || (data.lastHomeTab !== "desktop" && data.lastHomeTab !== "controls")) {
            finishLoad(false, "Unsupported panel preferences format. The original file is preserved; changes are temporary.");
            return;
        }
        persistedTab = data.lastHomeTab;
        if (revision === 0) selectedHomeTab = data.lastHomeTab;
        finishLoad(true, "");
    }

    function finishLoad(writable, message) {
        if (loadedOnce) return;
        persistenceAllowed = writable;
        loadedOnce = true;
        if (message) reportError(message);
        flush();
    }

    function flush() {
        if (!loadedOnce || !persistenceAllowed || !dirty || writeInFlight) return;
        if (selectedHomeTab === persistedTab) {
            dirty = false;
            return;
        }
        writingRevision = revision;
        writingTab = selectedHomeTab;
        writeInFlight = true;
        savedState.setText(JSON.stringify({version: 1, lastHomeTab: selectedHomeTab}) + "\n");
    }

    function saved() {
        if (!writeInFlight) return;
        writeInFlight = false;
        persistenceError = "";
        persistedTab = writingTab;
        dirty = revision !== writingRevision;
        flush();
    }

    function saveFailed() {
        writeInFlight = false;
        // FileView caches failed text, so identical retries can silently do nothing.
        // Preserve usable memory and leave recovery to the next shell startup.
        persistenceAllowed = false;
        reportError("Could not save panel preferences. Changes remain temporary until the shell restarts.");
    }

    FileView {
        id: savedState
        path: root.statePath
        preload: true
        blockLoading: false
        blockWrites: false
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.applyLoaded(text())
        onLoadFailed: error => root.finishLoad(error === FileViewError.FileNotFound,
            error === FileViewError.FileNotFound ? ""
                : "Could not read panel preferences. The original file is preserved; changes are temporary.")
        onSaved: root.saved()
        onSaveFailed: root.saveFailed()
    }
}
