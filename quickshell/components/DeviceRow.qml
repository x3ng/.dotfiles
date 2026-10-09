pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: row
    required property Theme style
    required property string title
    property string subtitle: ""
    property bool selected: false
    property bool available: true
    signal triggered()
    implicitHeight: subtitle ? 58 : 48
    radius: style.radiusControl
    color: selected ? style.surfaceSelected : mouse.containsMouse ? style.surfaceHover : "transparent"
    opacity: available ? 1 : 0.5
    RowLayout {
        anchors.fill: parent
        anchors.margins: row.style.spaceMd
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: row.style.spaceXs
            Text {
                Layout.fillWidth: true
                text: row.title
                elide: Text.ElideRight
                color: row.selected ? row.style.textSelected : row.style.textPrimary
                font.family: row.style.fontFamily
                font.pixelSize: row.style.fontSizeBody
                font.weight: row.selected ? Font.Medium : Font.Normal
            }
            Text {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                elide: Text.ElideRight
                color: row.style.textMuted
                font.family: row.style.fontFamily
                font.pixelSize: row.style.fontSizeCaption
            }
        }
        StatusIcon {
            kind: row.selected ? "check" : "chevron"
            width: 16
            height: 16
            ink: row.selected ? row.style.accent : row.style.textMuted
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: row.available
        hoverEnabled: true
        onClicked: row.triggered()
    }
}
