pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    required property var style
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
        anchors.margins: 12
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: row.title
                elide: Text.ElideRight
                color: row.selected ? row.style.textSelected : row.style.textPrimary
                font.family: row.style.fontFamily
                font.pixelSize: 13
                font.weight: row.selected ? Font.Medium : Font.Normal
            }
            Text {
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                elide: Text.ElideRight
                color: row.style.textMuted
                font.family: row.style.fontFamily
                font.pixelSize: 11
            }
        }
        Text {
            text: row.selected ? "✓" : "›"
            color: row.selected ? row.style.accent : row.style.textMuted
            font.pixelSize: 16
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
