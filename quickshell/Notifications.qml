pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "components/NotificationUtils.js" as NotificationUtils

// Freedesktop notification daemon (replaces mako). Three lists, matching how
// Noctalia and DankMaterialShell split the same problem:
//   - `popups`  live banners; short-lived and never persisted.
//   - `current` notifications the user has not dealt with yet. The status
//     page card shows these and its Clear empties only this list.
//   - `history` the saved log the detail page browses, kept across restarts.
// Dismissing a banner or letting it time out only hides the toast; the entry
// stays pending in `current` until it is cleared from the notification center.
Scope {
    id: root

    // Live popup wrappers, newest last. Capped; overflow evicts the oldest.
    property var popups: []
    // Pending entries, newest first, `time` is epoch ms.
    property var current: []
    // Saved log entries, newest first, `time` is epoch ms.
    property var history: []
    // Live banner stack.
    readonly property int maxVisible: 4
    // Active list shown by the status page card, and how much of it is
    // previewed before the "more" line hands the rest to the detail page.
    readonly property int previewCount: 2
    readonly property int maxCurrent: 20
    // History is re-read on every start, so it has to stay bounded (entry
    // bodies are arbitrary application text).
    readonly property int maxHistory: 50
    // Keep diagnostic tips (e.g. fcitx5's Wayland warnings) available after
    // their banners close. Set false to honor toast-only transient hints.
    property bool recordTransient: true

    // Popup lifetime: app-provided timeout when set, else mako's default
    // of 5s. Critical notifications stay until dismissed.
    readonly property int defaultTimeout: 5000

    readonly property string historyFile: Quickshell.cacheDir + "/notification_history.json"
    property int nextRecord: 0

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: false

        onNotification: notif => root.track(notif)
    }

    component NotifWrapper: QtObject {
        id: wrapper
        required property Notification notification
        required property string recordKey
        property double time: Date.now()
        readonly property string appName: notification.appName
            || DesktopEntries.heuristicLookup(notification.desktopEntry)?.name || "Application"
        readonly property string summary: notification.summary
        readonly property string body: notification.body
        readonly property string appIcon: notification.appIcon
            || DesktopEntries.heuristicLookup(notification.desktopEntry)?.icon || ""
        readonly property string contentImage: notification.image
        readonly property int urgency: notification.urgency
        readonly property bool critical: urgency === NotificationUrgency.Critical
        readonly property var actions: notification.actions
        property bool hovered: false
        property bool closing: false
        property double remaining: timeout
        property double deadline: 0
        readonly property int timeout: {
            if (wrapper.critical) return 0;
            const t = wrapper.notification.expireTimeout;
            return t >= 0 ? t : root.defaultTimeout;
        }
        readonly property Timer timer: Timer {
            interval: Math.max(1, wrapper.remaining)
            onTriggered: root.expire(wrapper)
        }
        function restartTimeout() {
            timer.stop();
            remaining = timeout;
            if (!hovered && timeout > 0) {
                deadline = Date.now() + remaining;
                timer.start();
            }
        }
        // Replaces-id updates modify the same Notification object. Coalesce
        // its property changes so the card and saved record update together.
        readonly property Timer updateTimer: Timer {
            interval: 0
            onTriggered: {
                if (!wrapper.closing) {
                    wrapper.time = Date.now();
                    root.saveRecord(wrapper);
                    wrapper.restartTimeout();
                }
            }
        }
        // Apps may close their own notification (e.g. after a reply);
        // drop the popup so nothing lingers on screen.
        readonly property Connections closedWatch: Connections {
            target: wrapper.notification
            function onClosed() { root.remove(wrapper); }
            function onSummaryChanged() { wrapper.updateTimer.restart(); }
            function onBodyChanged() { wrapper.updateTimer.restart(); }
            function onAppNameChanged() { wrapper.updateTimer.restart(); }
            function onAppIconChanged() { wrapper.updateTimer.restart(); }
            function onImageChanged() { wrapper.updateTimer.restart(); }
            function onUrgencyChanged() { wrapper.updateTimer.restart(); }
            function onActionsChanged() { wrapper.updateTimer.restart(); }
            function onExpireTimeoutChanged() { wrapper.updateTimer.restart(); }
            function onTransientChanged() { wrapper.updateTimer.restart(); }
        }
    }

    function track(notif) {
        notif.tracked = true;
        const existing = popups.find(w => w.notification === notif);
        if (existing) { existing.updateTimer.restart(); return; }
        const wrapper = notifWrapperComponent.createObject(root, {
            notification: notif,
            recordKey: Date.now() + ":" + (++nextRecord)
        });
        if (!wrapper) return;
        saveRecord(wrapper);
        popups = [...popups, wrapper];
        wrapper.restartTimeout();
        // Prefer evicting cards the user is not currently reading.
        while (popups.length > maxVisible) {
            const evicted = popups.find(w => !w.hovered) || popups[0];
            expire(evicted);
        }
    }

    function saveRecord(wrapper) {
        current = current.filter(e => e.recordKey !== wrapper.recordKey);
        history = history.filter(e => e.recordKey !== wrapper.recordKey);
        // Some apps mark useful warnings as transient, including fcitx5.
        if (recordTransient || !wrapper.notification.transient) {
            const record = {
                recordKey: wrapper.recordKey,
                appName: wrapper.appName,
                summary: wrapper.summary,
                body: wrapper.body,
                appIcon: NotificationUtils.savedImage(wrapper.appIcon),
                contentImage: NotificationUtils.savedImage(wrapper.contentImage),
                urgency: wrapper.urgency,
                time: wrapper.time
            };
            // The same record object backs both lists this session, so the
            // detail page and the card never disagree about an entry.
            current = [record, ...current].slice(0, maxCurrent);
            history = [record, ...history].slice(0, maxHistory);
        }
        persistHistory();
    }

    function setHovered(wrapper, hovered) {
        if (wrapper.closing || wrapper.hovered === hovered) return;
        wrapper.hovered = hovered;
        if (hovered) {
            if (wrapper.timer.running) {
                wrapper.timer.stop();
                wrapper.remaining = Math.max(1, wrapper.deadline - Date.now());
            }
        } else if (wrapper.timeout > 0) {
            wrapper.deadline = Date.now() + wrapper.remaining;
            wrapper.timer.start();
        }
    }

    function remove(wrapper) {
        const i = popups.indexOf(wrapper);
        if (i < 0) return;
        wrapper.closing = true;
        wrapper.timer.stop();
        wrapper.updateTimer.stop();
        popups = popups.filter(w => w !== wrapper);
        wrapper.destroy();
    }

    // Banner timer elapsed: hide the popup, close the notification. The
    // entry stays pending in `current`.
    function expire(wrapper) {
        try { wrapper.notification.expire(); } catch (e) {}
        remove(wrapper);
    }

    // User clicked the banner: dismiss instead of expire. Like Noctalia,
    // dismissing a toast only hides it - it still shows up in the card.
    function dismiss(wrapper) {
        try { wrapper.notification.dismiss(); } catch (e) {}
        remove(wrapper);
    }

    function invokeAction(wrapper, action) {
        if (wrapper.closing) return;
        const resident = wrapper.notification.resident;
        try { action.invoke(); } catch (e) {}
        // invoke() may synchronously emit closed; don't touch a removed card.
        if (!resident && popups.includes(wrapper)) dismiss(wrapper);
    }

    function activate(wrapper) {
        const action = Array.from(wrapper.actions).find(a => a.identifier === "default");
        if (action) invokeAction(wrapper, action);
    }

    // Status-page "Clear": empty the pending list only. History keeps every
    // entry, so nothing disappears from the detail page.
    function clearCurrent() {
        if (current.length === 0) return;
        current = [];
        persistHistory();
    }

    function removeCurrent(index) {
        current = current.filter((_, i) => i !== index);
        persistHistory();
    }

    function clearHistory() {
        if (history.length === 0) return;
        history = [];
        persistHistory();
    }

    function removeHistory(index) {
        history = history.filter((_, i) => i !== index);
        persistHistory();
    }

    // Disk-backed state: like mako's max-history, but it survives quickshell
    // restarts. Writes are debounced to avoid churn.
    function persistHistory() {
        saveTimer.restart();
    }

    function loadHistory() {
        const loadedHistory = (historyAdapter.notifications || [])
            .filter(e => e && typeof e.time === "number");
        const loadedCurrent = (historyAdapter.current || [])
            .filter(e => e && typeof e.time === "number");
        // Anything that arrived before the async load sits in front.
        history = [...history, ...loadedHistory].slice(0, maxHistory);
        current = [...current, ...loadedCurrent].slice(0, maxCurrent);
    }

    Timer {
        id: saveTimer
        interval: 200
        onTriggered: {
            historyAdapter.notifications = root.history;
            historyAdapter.current = root.current;
            historyFileView.writeAdapter();
        }
    }

    FileView {
        id: historyFileView
        path: root.historyFile
        printErrors: false
        onLoaded: root.loadHistory()
        onLoadFailed: error => {
            // Missing file on first run: create it so later saves succeed.
            if (error === 2)
                historyFileView.writeAdapter();
        }

        JsonAdapter {
            id: historyAdapter
            property var notifications: []
            property var current: []
        }
    }

    Component {
        id: notifWrapperComponent
        NotifWrapper {}
    }
}
