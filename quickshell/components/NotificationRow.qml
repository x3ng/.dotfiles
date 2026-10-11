pragma ComponentBehavior: Bound

import QtQuick

// Shared content layout; preview cards open history, history cards expand.
NotificationCard {
    compact: true
    expandable: !compact
    signal triggered()
    onDismissRequested: triggered()
}
