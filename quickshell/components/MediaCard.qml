pragma ComponentBehavior: Bound

import QtQuick

Rectangle {
    id: card

    required property var style
    required property var player
    required property bool panelOpen
    property int positionTick: 0
    readonly property bool hasTimeline: (player?.positionSupported ?? false)
        && (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0
    readonly property real duration: Math.max(0, player?.length ?? 0)
    readonly property real position: {
        card.positionTick;
        return Math.max(0, Math.min(card.duration, card.player?.position ?? 0));
    }

    function timeLabel(seconds) {
        const whole = Math.floor(Math.max(0, seconds));
        return Math.floor(whole / 60) + ":" + String(whole % 60).padStart(2, "0");
    }

    height: 148
    radius: style.radiusCard
    color: style.surfaceRaised
    border.width: 1
    border.color: style.outline

    Timer {
        interval: 1000
        repeat: true
        running: card.panelOpen && card.player?.isPlaying && card.hasTimeline
        onTriggered: card.positionTick++
    }

    Text {
        id: heading
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 10
        text: "MEDIA"
        color: card.style.textMuted
        font.family: card.style.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    Rectangle {
        id: artwork
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: heading.bottom
        anchors.topMargin: 8
        width: 56
        height: 56
        radius: card.style.radiusCard
        color: card.style.surfaceHover
        clip: true

        Image {
            id: cover
            anchors.fill: parent
            source: card.player?.trackArtUrl || ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Text {
            anchors.centerIn: parent
            visible: !cover.visible
            text: "♫"
            color: card.style.accent
            font.family: card.style.fontFamily
            font.pixelSize: 24
        }
    }

    Text {
        id: trackTitle
        anchors.left: artwork.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: artwork.top
        text: card.player?.trackTitle || card.player?.identity || "Player"
        color: card.style.textPrimary
        font.family: card.style.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Text {
        anchors.left: trackTitle.left
        anchors.right: trackTitle.right
        anchors.top: trackTitle.bottom
        anchors.topMargin: 3
        text: card.player?.trackArtist || card.player?.identity || ""
        color: card.style.textSecondary
        font.family: card.style.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Row {
        anchors.horizontalCenter: trackTitle.horizontalCenter
        anchors.top: artwork.bottom
        anchors.topMargin: -9
        spacing: 8

        ChoiceButton {
            width: 42
            height: 38
            style: card.style
            label: "‹"
            textSize: 18
            available: card.player?.canGoPrevious ?? false
            onTriggered: card.player?.previous()
        }

        ChoiceButton {
            width: 46
            height: 38
            style: card.style
            label: card.player?.isPlaying ? "Ⅱ" : "▶"
            textSize: 16
            available: card.player?.canTogglePlaying ?? false
            onTriggered: card.player?.togglePlaying()
        }

        ChoiceButton {
            width: 42
            height: 38
            style: card.style
            label: "›"
            textSize: 18
            available: card.player?.canGoNext ?? false
            onTriggered: card.player?.next()
        }
    }

    Rectangle {
        id: progressTrack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        height: 4
        radius: 2
        color: card.style.separator
        visible: card.hasTimeline

        Rectangle {
            width: parent.width * (card.duration > 0 ? card.position / card.duration : 0)
            height: parent.height
            radius: parent.radius
            color: card.style.accent

            Behavior on width { NumberAnimation { duration: 200 } }
        }
    }

    Text {
        anchors.left: progressTrack.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        text: card.hasTimeline ? card.timeLabel(card.position) : "LIVE / TIME UNAVAILABLE"
        color: card.style.textMuted
        font.family: card.style.fontFamily
        font.pixelSize: 10
    }

    Text {
        anchors.right: progressTrack.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        visible: card.hasTimeline
        text: card.timeLabel(card.duration)
        color: card.style.textMuted
        font.family: card.style.fontFamily
        font.pixelSize: 10
    }
}
