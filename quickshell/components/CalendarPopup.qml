pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

PopupWindow {
    id: popup

    required property var style
    required property var barWindow
    required property real anchorX
    property bool open: false
    property date displayedMonth: new Date()
    property string todayKey: ""
    property string todayLabel: ""

    function refreshToday() {
        var now = new Date();
        todayKey = Qt.formatDateTime(now, "yyyy-MM-dd");
        todayLabel = Qt.formatDateTime(now, "dddd · MMMM d").toUpperCase();
    }

    function resetMonth() {
        var now = new Date();
        displayedMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    }

    function shiftMonth(offset) {
        displayedMonth = new Date(
            displayedMonth.getFullYear(),
            displayedMonth.getMonth() + offset,
            1
        );
    }

    function title() {
        return Qt.formatDateTime(displayedMonth, "MMMM yyyy").toUpperCase();
    }

    function cells() {
        todayKey;
        var year = displayedMonth.getFullYear();
        var month = displayedMonth.getMonth();
        var first = new Date(year, month, 1);
        var mondayOffset = (first.getDay() + 6) % 7;
        var result = [];

        for (var i = 0; i < 42; i++) {
            var date = new Date(year, month, 1 - mondayOffset + i);
            result.push({
                day: date.getDate(),
                inMonth: date.getMonth() === month,
                today: Qt.formatDateTime(date, "yyyy-MM-dd") === todayKey
            });
        }
        return result;
    }

    function showCalendar() {
        refreshToday();
        resetMonth();
        open = true;
    }

    function dismiss() {
        open = false;
    }

    parentWindow: barWindow
    visible: open && barWindow.isVisible
    implicitWidth: 280
    implicitHeight: 294
    relativeX: Math.round(Math.max(
        style.barOuterMarginX,
        Math.min(
            barWindow.width - style.barOuterMarginX - width,
            anchorX
        )
    ))
    relativeY: style.barHeight + 6
    color: "transparent"
    grabFocus: true

    onVisibleChanged: {
        if (!visible && open) open = false;
    }

    Component.onCompleted: refreshToday()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: popup.refreshToday()
    }

    Rectangle {
        anchors.fill: parent
        radius: popup.style.radiusPopup
        color: popup.style.surface
        border.width: 1
        border.color: popup.style.outline

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 44

            Item {
                width: 30
                height: 30
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: popup.style.radiusControl
                    color: previousMouse.containsMouse
                        ? popup.style.surfaceHover
                        : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: popup.style.textSecondary
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: previousMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: popup.shiftMonth(-1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: popup.title()
                color: popup.style.textPrimary
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Item {
                width: 30
                height: 30
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: popup.style.radiusControl
                    color: nextMouse.containsMouse
                        ? popup.style.surfaceHover
                        : "transparent"
                }

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: popup.style.textSecondary
                    font.pixelSize: 20
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: popup.shiftMonth(1)
                }
            }
        }

        Rectangle {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            height: 1
            color: popup.style.separator
        }

        Row {
            id: weekdayRow
            anchors.top: header.bottom
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                Item {
                    required property string modelData
                    width: 36
                    height: 22

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: popup.style.textMuted
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Grid {
            anchors.top: weekdayRow.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 7

            Repeater {
                model: popup.cells()

                Item {
                    id: dayCell
                    required property var modelData
                    width: 36
                    height: 32

                    Rectangle {
                        width: 28
                        height: 26
                        radius: popup.style.radiusControl
                        anchors.centerIn: parent
                        color: dayCell.modelData.today
                            ? popup.style.accent
                            : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        color: dayCell.modelData.today
                            ? popup.style.accentInk
                            : (dayCell.modelData.inMonth
                                ? popup.style.textPrimary
                                : popup.style.textMuted)
                        opacity: dayCell.modelData.inMonth || dayCell.modelData.today
                            ? 1
                            : 0.45
                        font.pixelSize: 11
                        font.weight: dayCell.modelData.today
                            ? Font.DemiBold
                            : Font.Normal
                    }
                }
            }
        }

        Item {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 27

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                height: 1
                color: popup.style.separator
            }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: popup.todayLabel
                color: todayMouse.containsMouse
                    ? popup.style.accent
                    : popup.style.textSecondary
                font.pixelSize: 9
                font.weight: Font.Medium
            }

            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: popup.resetMonth()
            }
        }
    }
}
