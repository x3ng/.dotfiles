pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Persistent exceptions stay visible whenever the status page is opened.
GroupCard {
    id: notices
    required property var actions
    required property var services
    readonly property var entries: [
        {shown: services.keepAwake, icon: "eye", title: "Keep awake is on",
            detail: "Automatic locking and screen power-off are paused.", action: "Turn off", actionId: "keep-awake"},
        {shown: services.source?.audio?.muted ?? false, icon: "mic", title: "Microphone is muted",
            detail: "The default microphone is not sending audio.", action: "Unmute", actionId: "mic-mute"},
        {shown: services.sink?.audio?.muted ?? false, icon: "volume", title: "Audio output is muted",
            detail: "The default output is silent.", action: "Unmute", actionId: "output-mute"}
    ].filter(entry => entry.shown)
    visible: entries.length > 0
    border.color: style.accentWarm

    Repeater {
        model: notices.entries
        RowLayout {
            id: notice
            required property var modelData
            Layout.fillWidth: true
            spacing: notices.style.spaceMd
            StatusIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                kind: notice.modelData.icon
                muted: notice.modelData.actionId !== "keep-awake"
                ink: notices.style.accentWarm
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: notices.style.spaceXs
                Text {
                    Layout.fillWidth: true
                    text: notice.modelData.title
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: notices.style.textPrimary
                    font.family: notices.style.fontFamily
                    font.pixelSize: notices.style.fontSizeBody
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: notice.modelData.detail
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: notices.style.textSecondary
                    font.family: notices.style.fontFamily
                    font.pixelSize: notices.style.fontSizeCaption
                }
            }
            ChoiceButton {
                Layout.preferredWidth: 76
                Layout.preferredHeight: 34
                style: notices.style
                label: notice.modelData.action
                available: notices.actions.available(notice.modelData.actionId)
                onTriggered: notices.actions.execute(notice.modelData.actionId)
            }
        }
    }
}
