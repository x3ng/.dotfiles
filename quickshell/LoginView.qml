import QtQuick

Item {
    id: root
    required property var theme
    property bool transparentBackground: false
    property real cardOpacity: 1
    property bool frosted: false
    function surfaceColor(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, color.a * alpha);
    }
    property string userName: ""
    property bool editableUser: false
    property string message: ""
    property bool busy: false
    property var sessions: []
    property string selectedSessionId: ""
    property bool sessionPickerOpen: false
    property bool showPowerActions: false
    property bool powerMenuOpen: false
    property string pendingPowerAction: ""
    signal submit(string userName, string secret)
    signal selectSession(string id)
    signal powerRequested(string action)

    function requestPower(action) {
        if (pendingPowerAction === action) {
            pendingPowerAction = "";
            powerMenuOpen = false;
            powerRequested(action);
        } else {
            pendingPowerAction = action;
            powerConfirmTimeout.restart();
        }
    }

    readonly property string selectedSessionName: {
        const entry = sessions.find(session => session.id === selectedSessionId);
        return entry ? entry.name : "Choose a session";
    }

    function clearSecret() { passwordInput.text = ""; }
    function focusInput() {
        if (editableUser && !userInput.text.trim()) userInput.forceActiveFocus();
        else passwordInput.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: root.transparentBackground ? "transparent" : root.theme.panelSurface
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 420)
        spacing: 24

        Rectangle {
            width: parent.width
            height: (root.powerMenuOpen ? powerPage.implicitHeight : form.implicitHeight) + 56
            radius: root.theme.radiusPanel
            color: root.surfaceColor(root.theme.surfaceRaised, root.cardOpacity)
            border.color: root.frosted ? "#20ffffff" : root.surfaceColor(root.theme.separator, root.cardOpacity)
            border.width: 1

            Column {
                id: form
                x: 28
                y: 28
                width: parent.width - 56
                spacing: 16
                visible: !root.powerMenuOpen

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        id: clockText
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        text: Qt.formatTime(new Date(), "HH:mm")
                    }

                    Text {
                        id: dateText
                        anchors.right: root.showPowerActions ? powerTrigger.left : parent.right
                        anchors.rightMargin: root.showPowerActions ? 18 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 13
                        text: Qt.formatDate(new Date(), "ddd · d MMM")
                    }

                    Text {
                        id: powerTrigger
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.showPowerActions
                        text: "⏻"
                        color: root.theme.textSecondary
                        font.pixelSize: 18
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.powerMenuOpen = !root.powerMenuOpen;
                                if (!root.powerMenuOpen) root.pendingPowerAction = "";
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.editableUser ? 50 : 56
                    radius: root.theme.radiusInput
                    color: root.editableUser ? root.theme.panelSurface : "transparent"
                    border.width: root.editableUser ? 1 : 0
                    border.color: userInput.activeFocus ? root.theme.accent : root.theme.separator

                    TextInput {
                        id: userInput
                        anchors.left: parent.left
                        anchors.leftMargin: root.editableUser ? 15 : 0
                        anchors.right: parent.right
                        anchors.rightMargin: root.editableUser ? 15 : 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: root.editableUser ? 15 : 24
                        font.weight: root.editableUser ? Font.Normal : Font.Medium
                        text: root.userName
                        readOnly: !root.editableUser
                        selectByMouse: root.editableUser
                        clip: true
                        enabled: !root.busy
                        onAccepted: passwordInput.forceActiveFocus()
                        Text {
                            visible: !userInput.text.length
                            text: "Username"
                            color: root.theme.textMuted
                            font: userInput.font
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: root.theme.radiusInput
                    color: root.frosted ? "#40101418" : root.surfaceColor(root.theme.panelSurface, root.cardOpacity)
                    border.color: passwordInput.activeFocus ? root.theme.accent : root.theme.separator
                    border.width: 1

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: 15
                        verticalAlignment: TextInput.AlignVCenter
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 15
                        echoMode: TextInput.Password
                        enabled: !root.busy
                        onAccepted: root.submit(userInput.text.trim(), text)

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: root.theme.textMuted
                            font.family: root.theme.fontFamily
                            font.pixelSize: 15
                            visible: passwordInput.text.length === 0
                            text: "Password"
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6
                    visible: root.sessions.length > 0

                    Rectangle {
                        width: parent.width
                        height: 32
                        radius: root.theme.radiusInput
                        color: "transparent"
                        border.width: 0

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Session"
                            color: root.theme.textMuted
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 76
                            anchors.right: sessionArrow.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.selectedSessionName
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            id: sessionArrow
                            anchors.right: parent.right
                            anchors.rightMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.sessionPickerOpen ? "⌃" : "⌄"
                            color: root.theme.textSecondary
                            font.pixelSize: 16
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.busy
                            onClicked: root.sessionPickerOpen = !root.sessionPickerOpen
                        }
                    }

                    Flickable {
                        width: parent.width
                        height: root.sessionPickerOpen ? Math.min(sessionOptions.height, 176) : 0
                        contentWidth: width
                        contentHeight: sessionOptions.height
                        clip: true
                        visible: root.sessionPickerOpen

                        Column {
                            id: sessionOptions
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: root.sessions
                                delegate: Rectangle {
                                    id: optionRow
                                    required property var modelData
                                    width: sessionOptions.width
                                    height: 42
                                    radius: root.theme.radiusInput
                                    color: optionRow.modelData.id === root.selectedSessionId
                                        ? root.theme.surfaceSelected : root.theme.panelSurface

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: optionRow.modelData.name
                                        color: root.theme.textPrimary
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 13
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            root.selectSession(optionRow.modelData.id);
                                            root.sessionPickerOpen = false;
                                            passwordInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text.length > 0
                    color: root.theme.accentWarm
                    font.family: root.theme.fontFamily
                    font.pixelSize: 13
                    text: root.message
                }

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: root.theme.radiusInput
                    color: submitArea.pressed ? root.theme.surfaceHover : root.theme.accent
                    opacity: root.busy ? 0.6 : 1

                    Text {
                        anchors.centerIn: parent
                        text: root.busy ? "Authenticating…" : "Continue"
                        color: root.theme.accentInk
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: submitArea
                        anchors.fill: parent
                        enabled: !root.busy
                        onClicked: root.submit(userInput.text.trim(), passwordInput.text)
                    }
                }

            }

            Column {
                id: powerPage
                x: 28
                y: 28
                width: parent.width - 56
                spacing: 16
                visible: root.powerMenuOpen

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "←  Back"
                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 14
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.powerMenuOpen = false;
                                root.pendingPowerAction = "";
                                root.focusInput();
                            }
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Power"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 15
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: root.theme.radiusInput
                    color: restartArea.containsMouse ? root.theme.surfaceHover : "transparent"
                    border.color: root.theme.outline
                    border.width: 0
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingPowerAction === "reboot" ? "Confirm restart" : "Restart"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: restartArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.requestPower("reboot")
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    radius: root.theme.radiusInput
                    color: shutdownArea.containsMouse ? root.theme.surfaceHover : "transparent"
                    border.color: root.theme.outline
                    border.width: 0
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pendingPowerAction === "poweroff" ? "Confirm shut down" : "Shut down"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 15
                    }
                    MouseArea {
                        id: shutdownArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.requestPower("poweroff")
                    }
                }
            }
        }
    }

    Timer {
        id: powerConfirmTimeout
        interval: 5000
        onTriggered: root.pendingPowerAction = ""
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            const now = new Date();
            clockText.text = Qt.formatTime(now, "HH:mm");
            dateText.text = Qt.formatDate(now, "ddd · d MMM");
        }
    }
}
