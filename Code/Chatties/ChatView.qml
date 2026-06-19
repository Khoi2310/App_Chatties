import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Chatties

Item {
    id: root

    function doSend() {
        var t = input.text.trim()
        if (t.length === 0) return
        chatClient.sendMessage(t)
        input.text = ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacing
        spacing: Theme.spacing

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.spacing
            model: messageModel

            delegate: Column {
                width: ListView.view ? ListView.view.width : 0
                spacing: 1

                Label {
                    leftPadding: 8
                    text: (model.username && model.username.length ? model.username : "?")
                    color: Theme.accent
                    font.bold: true
                    font.pixelSize: Theme.fontSmall
                }
                Label {
                    leftPadding: 8
                    rightPadding: 8
                    width: parent.width
                    text: model.content
                    color: Theme.textPrimary
                    wrapMode: Text.WordWrap
                }
            }

            onCountChanged: positionViewAtEnd()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacing
            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: qsTr("Nhập tin nhắn...")
                onAccepted: root.doSend()
            }
            Button {
                text: qsTr("Gửi")
                highlighted: true
                onClicked: root.doSend()
            }
        }
    }
}
