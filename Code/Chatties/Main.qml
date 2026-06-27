import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Chatties

ApplicationWindow {
    id: window
    visible: true
    width: 860
    height: 640
    title: qsTr("Chatties")
    color: Theme.background

    Material.theme: Material.Dark
    Material.accent: Theme.accent
    Material.primary: Theme.accent

    property bool loggedIn: false
    property var servers: []          // [{id, name, channels:[{id,name}]}]
    property int userId: 0

    AuthView {
        anchors.fill: parent
        visible: !window.loggedIn
    }

    ChatView {
        anchors.fill: parent
        visible: window.loggedIn
        servers: window.servers
        userId: window.userId
    }

    Connections {
        target: chatClient
        function onAuthOk(userId, username, displayName) {
            window.userId = userId
            window.loggedIn = true
        }
        function onDisconnected() {
            window.loggedIn = false
            window.servers = []
        }
        function onServersReceived(servers) { window.servers = servers }
    }
}
