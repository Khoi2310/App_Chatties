import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Chatties

Item {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(root.width - 40, 360)
        spacing: Theme.spacing

        Label {
            text: qsTr("Chatties")
            color: Theme.textPrimary
            font.pixelSize: Theme.fontTitle
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            TabButton { text: qsTr("Login") }
            TabButton { text: qsTr("Register") }
        }

        StackLayout {
            Layout.fillWidth: true
            currentIndex: tabBar.currentIndex

            // ── Tab Đăng nhập ──
            ColumnLayout {
                spacing: Theme.spacing
                TextField {
                    id: loginUsername
                    Layout.fillWidth: true
                    placeholderText: qsTr("Username")
                }
                TextField {
                    id: loginPassword
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                }
                Button {
                    text: qsTr("Login")
                    Layout.fillWidth: true
                    highlighted: true
                    onClicked: {
                        errorLabel.text = ""
                        chatClient.login(loginUsername.text.trim(),
                                         loginPassword.text)
                    }
                }
            }

            // ── Tab Đăng ký ──
            ColumnLayout {
                spacing: Theme.spacing
                TextField { id: regUsername; Layout.fillWidth: true; placeholderText: qsTr("Username") }
                TextField { id: regEmail;    Layout.fillWidth: true; placeholderText: qsTr("Email") }
                TextField { id: regDisplay;  Layout.fillWidth: true; placeholderText: qsTr("Display name") }
                TextField {
                    id: regPassword
                    Layout.fillWidth: true
                    placeholderText: qsTr("Password")
                    echoMode: TextInput.Password
                }
                TextField {
                    id: regConfirm
                    Layout.fillWidth: true
                    placeholderText: qsTr("Confirm password")
                    echoMode: TextInput.Password
                }
                Button {
                    text: qsTr("Register")
                    Layout.fillWidth: true
                    highlighted: true
                    onClicked: {
                        errorLabel.text = ""
                        if (regPassword.text !== regConfirm.text) {
                            errorLabel.text = qsTr("⚠️ Passwords do not match.")
                            return
                        }
                        chatClient.registerUser(regUsername.text.trim(),
                                                regEmail.text.trim(),
                                                regPassword.text,
                                                regDisplay.text.trim())
                    }
                }
            }
        }

        Label {
            id: errorLabel
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: Theme.danger
            text: ""
        }
    }

    Connections {
        target: chatClient
        function onAuthError(reason) { errorLabel.text = reason }
    }
}
