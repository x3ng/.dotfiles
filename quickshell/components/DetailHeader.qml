import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: header
    required property Theme style
    required property string title
    property string subtitle: ""
    signal backRequested()
    implicitHeight: 48
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    Layout.minimumHeight: implicitHeight
    Text {
        id: heading
        anchors.left: backButton.right
        anchors.leftMargin: header.style.spaceMd
        anchors.top: parent.top
        anchors.right: parent.right
        elide: Text.ElideRight
        text: header.title
        color: header.style.textPrimary
        font.family: header.style.fontFamily
        font.pixelSize: header.style.fontSizeHeading
        font.weight: Font.DemiBold
    }
    Text {
        anchors.left: heading.left
        anchors.top: heading.bottom
        anchors.topMargin: 5
        anchors.right: parent.right
        elide: Text.ElideRight
        text: header.subtitle
        color: header.style.textMuted
        font.family: header.style.fontFamily
        font.pixelSize: header.style.fontSizeSmall
    }
    ChoiceButton {
        id: backButton
        anchors.left: parent.left
        anchors.top: parent.top
        width: 38
        height: 38
        style: header.style
        filled: true
        label: ""
        iconKind: "back"
        tooltip: "Back to overview"
        iconSize: 20
        onTriggered: header.backRequested()
    }
}
