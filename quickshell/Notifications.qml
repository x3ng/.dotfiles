pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

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
    readonly property int previewCount: 3
    readonly property int maxCurrent: 20
    // History is re-read on every start, so it has to stay bounded (entry
    // bodies are arbitrary application text).
    readonly property int maxHistory: 50

    // Popup lifetime: app-provided timeout when set, else mako's default
    // of 5s. Critical notifications stay until dismissed.
    readonly property int defaultTimeout: 5000

    readonly property string historyFile: Quickshell.cacheDir + "/notification_history.json"

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
        // Snapshots so the banner keeps rendering if the app closes the
        // notification underneath us.
        required property string appName
        required property string summary
        required property string body
        required property string image
        required property int urgency
        readonly property bool critical: urgency === NotificationUrgency.Critical
        readonly property var actions: notification.actions
        readonly property int timeout: {
            if (wrapper.critical) return 0;
            const t = wrapper.notification.expireTimeout;
            return t >= 0 ? t : root.defaultTimeout;
        }
        readonly property Timer timer: Timer {
            interval: Math.max(1, wrapper.timeout)
            running: wrapper.timeout > 0
            onTriggered: root.expire(wrapper)
        }
        // Apps may close their own notification (e.g. after a reply);
        // drop the popup so nothing lingers on screen.
        readonly property Connections closedWatch: Connections {
            target: wrapper.notification
            ignoreUnknownSignals: true
            function onClosed() { root.remove(wrapper); }
        }
    }

    function track(notif) {
        notif.tracked = true;
        const appName = notif.appName || "Application";
        const image = notif.appIcon || notif.image;
        const wrapper = notifWrapperComponent.createObject(root, {
            notification: notif,
            appName: appName,
            summary: notif.summary,
            body: notif.body,
            image: image,
            urgency: notif.urgency
        });
        if (!wrapper) return;
        // Transient notifications are toast-only: they never reach the
        // notification center, matching Noctalia's treatment of them.
        if (!notif.transient) {
            const record = {
                appName: appName,
                summary: notif.summary,
                body: notif.body,
                image: image,
                urgency: notif.urgency,
                time: Date.now()
            };
            // The same record object backs both lists this session, so the
            // detail page and the card never disagree about an entry.
            current = [record, ...current].slice(0, maxCurrent);
            history = [record, ...history].slice(0, maxHistory);
            persistHistory();
        }
        popups = [...popups, wrapper];
        // Evict from the front; expire() may fire onClosed -> remove()
        // re-entrantly, so remove() is idempotent and this is a no-op after.
        while (popups.length > maxVisible) {
            const evicted = popups[0];
            try { evicted.notification.expire(); } catch (e) {}
            remove(evicted);
        }
    }

    function remove(wrapper) {
        const i = popups.indexOf(wrapper);
        if (i < 0) return;
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
        try { action.invoke(); } catch (e) {}
        dismiss(wrapper);
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
