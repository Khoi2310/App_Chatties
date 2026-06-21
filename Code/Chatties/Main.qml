import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Chatties

ApplicationWindow {
    id: window
    visible: true
    width: 520
    height: 620
    title: qsTr("Chatties")
    color: Theme.background

    Material.theme: Material.Dark
    Material.accent: Theme.accent
    Material.primary: Theme.accent

    property bool loggedIn: false
    property var servers: []          // [{id, name, channels:[{id,name}]}]
    property int currentChannelId: 0

    AuthView {
        anchors.fill: parent
        visible: !window.loggedIn
    }

    ChatView {
        anchors.fill: parent
        visible: window.loggedIn
    }

    Connections {
        target: chatClient
        function onAuthOk(userId, username, displayName) { window.loggedIn = true }
        function onDisconnected() {
            window.loggedIn = false
            window.servers = []
            window.currentChannelId = 0
        }
        function onServersReceived(servers) {
            window.servers = servers
            // Tự chọn channel đầu tiên nếu chưa chọn channel nào.
            if (window.currentChannelId === 0
                    && servers.length > 0
                    && servers[0].channels.length > 0) {
                window.currentChannelId = servers[0].channels[0].id
                chatClient.selectChannel(window.currentChannelId)
            }
        }
    }
}
