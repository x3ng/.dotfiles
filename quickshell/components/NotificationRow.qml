pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

// One notification in a history list: app icon (with a generic fallback
// for tools like notify-send that send none), app name, merged summary
// and body, timestamp. Click dismisses the entry.
Rectangle {
    id: row
    required property Theme style
    required property var entry
    // Summary and body on one line: notify-send often puts the whole message
    // in one of them, and app bodies carry newlines.
    readonly property string mergedText: ((entry.summary || "")
        + (entry.body ? ((entry.summary ? " — " : "") + entry.body) : ""))
        .replace(/\s+/g, " ")
    signal triggered()

    implicitHeight: 40
    radius: style.radiusControl
    color: mouse.containsMouse ? style.surfaceHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: row.style.spaceSm
        anchors.rightMargin: row.style.spaceSm
        spacing: row.style.spaceSm

        Item {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            IconImage {
                id: rowIcon
                anchors.fill: parent
                implicitSize: 18
                source: row.entry.image
                    ? ((("" + row.entry.image).startsWith("/"))
                        ? "file://" + row.entry.image
                        : "image://icon/" + row.entry.image)
                    : ""
                visible: source !== "" && status === Image.Ready
            }
            StatusIcon {
                anchors.fill: parent
                visible: !rowIcon.visible
                kind: "app"
                ink: row.style.textMuted
            }
        }
        Text {
            Layout.preferredWidth: 76
            text: row.entry.appName
            color: row.style.textMuted
            elide: Text.ElideRight
            font.family: row.style.fontFamily
            font.pixelSize: row.style.fontSizeCaption
        }
        Text {
            Layout.fillWidth: true
            text: row.mergedText
            color: row.style.textPrimary
            elide: Text.ElideRight
            font.family: row.style.fontFamily
            font.pixelSize: row.style.fontSizeBody
        }
        Text {
            text: Qt.formatTime(new Date(row.entry.time), "hh:mm")
            color: row.style.textMuted
            font.family: row.style.fontFamily
            font.pixelSize: row.style.fontSizeMicro
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.triggered()
    }
}
