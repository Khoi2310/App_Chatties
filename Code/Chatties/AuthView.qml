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
            TabButton { text: qsTr("Đăng nhập") }
            TabButton { text: qsTr("Đăng ký") }
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
                    placeholderText: qsTr("Tên đăng nhập")
                }
                TextField {
                    id: loginPassword
                    Layout.fillWidth: true
                    placeholderText: qsTr("Mật khẩu")
                    echoMode: TextInput.Password
                }
                Button {
                    text: qsTr("Đăng nhập")
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
                TextField { id: regUsername; Layout.fillWidth: true; placeholderText: qsTr("Tên đăng nhập") }
                TextField { id: regEmail;    Layout.fillWidth: true; placeholderText: qsTr("Email") }
                TextField { id: regDisplay;  Layout.fillWidth: true; placeholderText: qsTr("Tên hiển thị") }
                TextField {
                    id: regPassword
                    Layout.fillWidth: true
                    placeholderText: qsTr("Mật khẩu")
                    echoMode: TextInput.Password
                }
                TextField {
                    id: regConfirm
                    Layout.fillWidth: true
                    placeholderText: qsTr("Xác nhận mật khẩu")
                    echoMode: TextInput.Password
                }
                Button {
                    text: qsTr("Đăng ký")
                    Layout.fillWidth: true
                    highlighted: true
                    onClicked: {
                        errorLabel.text = ""
                        if (regPassword.text !== regConfirm.text) {
                            errorLabel.text = qsTr("⚠️ Mật khẩu xác nhận không khớp.")
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
