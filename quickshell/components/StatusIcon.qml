pragma ComponentBehavior: Bound

import QtQuick

// Small line icons drawn in the current palette, independent of icon fonts.
Canvas {
    id: icon
    required property string kind
    required property color ink
    property bool muted: false
    property real level: 1
    implicitWidth: 20
    implicitHeight: 20
    onKindChanged: requestPaint()
    onInkChanged: requestPaint()
    onMutedChanged: requestPaint()
    onLevelChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.strokeStyle = ink;
        c.fillStyle = ink;
        c.lineWidth = 1.5;
        c.lineCap = "round";
        c.lineJoin = "round";
        if (kind === "battery") {
            c.strokeRect(2, 5, 14, 10);
            c.fillRect(17, 8, 2, 4);
            c.fillRect(4, 7, Math.max(0, Math.min(1, level)) * 10, 6);
        } else if (kind === "volume") {
            c.beginPath();
            c.moveTo(2, 8); c.lineTo(5, 8); c.lineTo(9, 4);
            c.lineTo(9, 16); c.lineTo(5, 12); c.lineTo(2, 12); c.closePath(); c.stroke();
            c.beginPath();
            if (muted) {
                c.moveTo(13, 7); c.lineTo(18, 13);
                c.moveTo(18, 7); c.lineTo(13, 13);
            } else {
                c.arc(8, 10, 6, -0.7, 0.7);
                c.moveTo(8 + Math.cos(-0.7) * 10, 10 + Math.sin(-0.7) * 10);
                c.arc(8, 10, 10, -0.7, 0.7);
            }
            c.stroke();
        } else if (kind === "brightness") {
            c.beginPath(); c.arc(10, 10, 3.5, 0, Math.PI * 2); c.stroke();
            for (let i = 0; i < 8; i++) {
                const angle = i * Math.PI / 4;
                c.beginPath();
                c.moveTo(10 + Math.cos(angle) * 6, 10 + Math.sin(angle) * 6);
                c.lineTo(10 + Math.cos(angle) * 8.5, 10 + Math.sin(angle) * 8.5);
                c.stroke();
            }
        } else if (kind === "appearance") {
            c.beginPath(); c.arc(10, 10, 7, 0, Math.PI * 2); c.stroke();
            c.beginPath();
            c.arc(10, 10, 7, level > 0 ? -Math.PI / 2 : Math.PI / 2,
                level > 0 ? Math.PI / 2 : Math.PI * 1.5);
            c.closePath(); c.fill();
        } else if (kind === "wifi") {
            for (let radius of [4, 7, 10]) {
                c.beginPath(); c.arc(10, 16, radius, -Math.PI * 0.77, -Math.PI * 0.23); c.stroke();
            }
            c.beginPath(); c.arc(10, 16, 1, 0, Math.PI * 2); c.fill();
        } else if (kind === "bluetooth") {
            c.beginPath(); c.moveTo(10, 2); c.lineTo(15, 6); c.lineTo(5, 14);
            c.moveTo(5, 6); c.lineTo(15, 14); c.lineTo(10, 18); c.lineTo(10, 2); c.stroke();
        } else if (kind === "power") {
            c.beginPath(); c.arc(10, 11, 7, -Math.PI * 0.3, Math.PI * 1.3); c.stroke();
            c.beginPath(); c.moveTo(10, 2); c.lineTo(10, 10); c.stroke();
        } else if (kind === "calendar") {
            c.strokeRect(3, 4, 14, 13);
            c.beginPath(); c.moveTo(3, 8); c.lineTo(17, 8);
            c.moveTo(7, 2); c.lineTo(7, 5); c.moveTo(13, 2); c.lineTo(13, 5); c.stroke();
            c.fillRect(6, 11, 2, 2); c.fillRect(11, 11, 2, 2);
        }
    }
}
