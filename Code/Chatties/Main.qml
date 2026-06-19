import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    visible: true
    width: 480
    height: 320
    title: qsTr("Chatties")

    Column {
        anchors.centerIn: parent
        spacing: 16

        Label {
            id: statusLabel
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Đang kết nối...")
        }

        
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Test đăng nhập (admin)")
            onClicked: chatClient.login("admin", "admin123")
        }
    }

    
    Connections {
        target: chatClient

        function onConnected() {
            statusLabel.text = qsTr("✅ Đã kết nối server")
        }
        function onDisconnected() {
            statusLabel.text = qsTr("❌ Mất kết nối server")
        }
        function onAuthOk(userId, username, displayName) {
            statusLabel.text = qsTr("Đăng nhập OK: ") + displayName
        }
        function onAuthError(reason) {
            statusLabel.text = qsTr("Lỗi: ") + reason
        }
    }
}
