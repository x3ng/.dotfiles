pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

// Search presentation only. Navigation and activation remain in LauncherPanel.
ColumnLayout {
    id: page
    required property Theme style
    required property var results
    required property var searchModel
    required property int selectedIndex
    required property bool active
    signal activateRequested(int index)

    function showSelection(index) { resultList.positionViewAtIndex(index, ListView.Contain); }
    function resetScroll() { resultList.positionViewAtBeginning(); }

    readonly property real naturalHeight: resultHeading.implicitHeight + spacing
        + Math.max(80, page.results.length * 40
            + Math.max(0, page.results.length - 1) * resultList.spacing)
    Layout.minimumHeight: 0
    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: page.style.spaceSm
    Text {
        id: resultHeading
        text: "RESULTS · " + page.results.length
        color: page.style.textMuted
        font.family: page.style.fontFamily
        font.pixelSize: page.style.fontSizeCaption
        font.letterSpacing: page.style.sectionLetterSpacing
    }
    ListView {
        id: resultList
        Layout.minimumHeight: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: page.active ? page.results : []
        spacing: 2
        delegate: Rectangle {
            id: resultRow
            required property var modelData
            required property int index
            width: resultList.width
            height: 40
            opacity: modelData.enabled === false ? 0.45 : 1
            radius: page.style.radiusControl
            color: index === page.selectedIndex ? page.style.surfaceSelected
                : rowMouse.containsMouse ? page.style.surfaceHover : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.margins: page.style.spaceSm
                spacing: 10
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    IconImage {
                        id: resultIcon
                        anchors.fill: parent
                        implicitSize: 24
                        source: page.searchModel.desktopIconSource(resultRow.modelData.entry)
                        visible: source !== "" && status !== Image.Error
                    }
                    StatusIcon {
                        anchors.centerIn: parent
                        visible: !resultIcon.visible
                        kind: resultRow.modelData.kind === "ACTION" ? resultRow.modelData.icon
                            : resultRow.modelData.kind === "WINDOW" ? "window" : "app"
                        width: 20
                        height: 20
                        ink: page.style.textSecondary
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: resultRow.modelData.title
                    textFormat: Text.PlainText
                    color: resultRow.index === page.selectedIndex
                        ? page.style.textSelected : page.style.textPrimary
                    elide: Text.ElideRight
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeBody
                }
                Text {
                    text: resultRow.modelData.kind
                    color: page.style.textMuted
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeMicro
                }
                Text {
                    visible: resultRow.index < 10
                    text: "Ctrl+" + (resultRow.index === 9 ? "0" : String(resultRow.index + 1))
                    color: resultRow.index === page.selectedIndex
                        ? page.style.textSelected : page.style.textMuted
                    font.family: page.style.fontFamily
                    font.pixelSize: page.style.fontSizeCaption
                }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: resultRow.modelData.enabled !== false
                onClicked: page.activateRequested(resultRow.index)
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !page.results.length
            text: "No matching apps, windows or actions"
            color: page.style.textMuted
            font.pixelSize: page.style.fontSizeBody
        }
    }
}
