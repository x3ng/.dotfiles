pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// Grouped container in the iOS/Android settings style: the card border
// itself says "these controls belong together", so sections need no
// text titles. Content declared inside flows into a padded column.
Rectangle {
    id: card
    required property Theme style
    default property alias content: inner.data
    readonly property int pad: card.style.spaceMd
    // Emitted when the card body is tapped; per-control MouseAreas
    // declared inside take precedence over this.
    signal activated()

    color: card.style.surfaceRaised
    border.width: 1
    border.color: card.style.separator
    radius: card.style.radiusCard
    implicitWidth: inner.implicitWidth + card.pad * 2
    implicitHeight: inner.implicitHeight + card.pad * 2

    MouseArea {
        anchors.fill: parent
        onClicked: card.activated()
    }

    ColumnLayout {
        id: inner
        x: card.pad
        y: card.pad
        width: card.width - card.pad * 2
        spacing: card.style.spaceSm
    }
}
