pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import ".."

// Top-center notification banners: one card per live popup, stacked
// downward from the top edge, click to dismiss, action buttons when the
// app provides them.
PanelWindow {
    id: banner

    required property var notifs
    required property Theme style

    readonly property int cardWidth: 360

    visible: notifs.popups.length > 0
    color: "transparent"
    // Full-width strip so the stack can sit centered under the top edge.
    anchors { top: true; left: true; right: true }
    margins { top: 10 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-notifications"
    implicitWidth: 1
    implicitHeight: stack.implicitHeight + 1

    mask: Region {
        item: stack
    }

    ColumnLayout {
        id: stack
        anchors.horizontalCenter: parent.horizontalCenter
        width: banner.cardWidth
        spacing: banner.style.spaceSm

        Repeater {
            model: banner.notifs.popups

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var wrapper: modelData

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + banner.style.spaceMd * 2
                radius: banner.style.radiusCard
                color: banner.style.surfaceRaised
                border.width: 1
                border.color: card.wrapper.critical
                    ? banner.style.accentWarm : banner.style.separator
                // Cards fade in as they arrive. Removal stays instant: the
                // stack reflows and the window hides as soon as it empties.
                opacity: 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Component.onCompleted: card.opacity = 1

                // Under the content: buttons get the click, everything
                // else falls through to dismiss.
                MouseArea {
                    anchors.fill: parent
                    onClicked: banner.notifs.dismiss(card.wrapper)
                }

                ColumnLayout {
                    id: body
                    anchors.fill: parent
                    anchors.margins: banner.style.spaceMd
                    spacing: banner.style.spaceXs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: banner.style.spaceSm

                        Item {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            IconImage {
                                id: notifIcon
                                anchors.fill: parent
                                implicitSize: 20
                                source: card.wrapper.image !== ""
                                    ? (card.wrapper.image.startsWith("/")
                                        ? "file://" + card.wrapper.image
                                        : "image://icon/" + card.wrapper.image)
                                    : ""
                                visible: source !== "" && status === Image.Ready
                            }
                            StatusIcon {
                                anchors.centerIn: parent
                                visible: !notifIcon.visible && !card.wrapper.critical
                                kind: "app"
                                width: 16
                                height: 16
                                ink: banner.style.textSecondary
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !notifIcon.visible && card.wrapper.critical
                                text: "!"
                                color: banner.style.accentWarm
                                font.family: banner.style.fontFamily
                                font.pixelSize: banner.style.fontSizeBody
                                font.weight: Font.Bold
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.wrapper.appName
                            color: banner.style.textMuted
                            elide: Text.ElideRight
                            font.family: banner.style.fontFamily
                            font.pixelSize: banner.style.fontSizeCaption
                        }
                        Text {
                            text: Qt.formatTime(new Date(), "hh:mm")
                            color: banner.style.textMuted
                            font.family: banner.style.fontFamily
                            font.pixelSize: banner.style.fontSizeMicro
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.wrapper.summary !== ""
                        text: card.wrapper.summary
                        color: banner.style.textPrimary
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: banner.style.fontFamily
                        font.pixelSize: banner.style.fontSizeBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: card.wrapper.body !== ""
                        text: card.wrapper.body
                        color: banner.style.textSecondary
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.family: banner.style.fontFamily
                        font.pixelSize: banner.style.fontSizeSmall
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: card.wrapper.actions.length > 0
                        spacing: banner.style.spaceSm
                        Repeater {
                            model: card.wrapper.actions
                            ChoiceButton {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                style: banner.style
                                filled: true
                                filledColor: banner.style.surfaceHover
                                textSize: banner.style.fontSizeCaption
                                label: modelData.text
                                onTriggered: banner.notifs.invokeAction(card.wrapper, modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
