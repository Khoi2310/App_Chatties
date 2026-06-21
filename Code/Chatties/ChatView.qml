import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Chatties

Item {
    id: root

    // Dữ liệu server truyền từ Main.qml
    property var servers: []
    property int currentServerIndex: 0
    property int currentChannelId: 0

    // Bộ emoji Unicode cho composer.
    property var emojis: [
        "😀","😁","😂","🤣","😊","😍","😎","😉","🙂","😴",
        "😢","😭","😡","😱","🤔","😅","🥳","🤯","😬","🙄",
        "👍","👎","🙏","👏","🙌","💪","👀","🤝","✌️","🤙",
        "❤️","🔥","🎉","💯","⭐","✨","✅","❌","💀","🚀",
        "☕","🍕","🍻","🎮","🐱","🐶","🌟","💬","📌","🎵"
    ]

    // Trạng thái trả lời / sửa
    property int    replyingToId: 0
    property string replyingToName: ""
    property int    userId: 0
    property int    editingId: 0

    readonly property var currentChannels:
        (servers.length > currentServerIndex && currentServerIndex >= 0)
            ? servers[currentServerIndex].channels : []
    readonly property int currentServerId:
        (servers.length > currentServerIndex && currentServerIndex >= 0)
            ? servers[currentServerIndex].id : 0

    function selectChannel(id) {
        currentChannelId = id
        chatClient.selectChannel(id)
    }

    function selectServer(idx) {
        currentServerIndex = idx
        currentChannelId = 0
        if (servers[idx].channels.length > 0)
            selectChannel(servers[idx].channels[0].id)
    }

    // Reset trạng thái khi đăng xuất (visible = false).
    onVisibleChanged: {
        if (!visible) {
            currentChannelId = 0
            currentServerIndex = 0
        }
    }

    // Tự chọn channel đầu tiên khi danh sách server thay đổi.
    onServersChanged: {
        if (servers.length > 0) {
            if (currentServerIndex >= servers.length) currentServerIndex = 0
            if (currentChannelId === 0
                    && servers[currentServerIndex].channels.length > 0) {
                selectChannel(servers[currentServerIndex].channels[0].id)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Cột 1: dãy server ──────────────────────────────────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 68
            color: Theme.serverBar

            Column {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 10
                spacing: 10

                Repeater {
                    model: root.servers
                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: index === root.currentServerIndex ? Theme.accent : Theme.inputBg
                        Label {
                            anchors.centerIn: parent
                            text: modelData.name.length > 0 ? modelData.name.charAt(0).toUpperCase() : "?"
                            color: Theme.textPrimary
                            font.bold: true
                            font.pixelSize: 18
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectServer(index)
                        }
                    }
                }

                // Nút thêm server
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: Theme.inputBg
                    Label {
                        anchors.centerIn: parent
                        text: "+"; color: Theme.accent; font.pixelSize: 24
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addServerDialog.open()
                    }
                }
            }
        }

        // ── Cột 2: danh sách channel ───────────────────────────
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 190
            color: Theme.surface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: root.servers.length > 0 ? root.servers[root.currentServerIndex].name : ""
                        color: Theme.textPrimary
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Button {
                        text: "+"
                        enabled: root.currentServerId !== 0
                        onClicked: addChannelDialog.open()
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.currentChannels
                    spacing: 2
                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: 30
                        radius: Theme.radius
                        color: modelData.id === root.currentChannelId ? Theme.accent : "transparent"
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 8
                            text: "# " + modelData.name
                            color: Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectChannel(modelData.id)
                        }
                    }
                }
            }
        }

        // ── Cột 3: tin nhắn + ô soạn ───────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            spacing: 8

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: messageModel

                // Không nảy khi cuộn tới biên.
                boundsBehavior: Flickable.StopAtBounds

                // Thanh cuộn mảnh, tối giản bên phải.
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 6
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: Theme.textMuted
                        opacity: parent.pressed ? 0.8 : 0.4
                    }
                }

                delegate: Item {
                    width: ListView.view ? ListView.view.width : 0
                    implicitHeight: msgCol.implicitHeight

                    HoverHandler { id: msgHover }

                    Column {
                        id: msgCol
                        width: parent.width
                        spacing: 1

                        // Trích dẫn tin được trả lời
                        Label {
                            visible: model.replyToId !== 0
                            leftPadding: 8
                            width: parent.width
                            text: "↪ " + model.replyUsername + ": " + model.replyExcerpt
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
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
                            textFormat: Text.RichText
                            color: Theme.textPrimary
                            wrapMode: Text.WordWrap
                            text: model.deleted
                                  ? "<i><span style='color:#b5bac1;'>" + qsTr("[message deleted]") + "</span></i>"
                                  : root.escapeHtml(model.content)
                                    + (model.edited
                                       ? " <span style='color:#b5bac1; font-size:11px;'>" + qsTr("(edited)") + "</span>"
                                       : "")
                        }

                        // Chip reaction
                        Flow {
                            id: reactionFlow
                            leftPadding: 8
                            width: parent.width
                            spacing: 4
                            property var reactionsData: model.reactions
                            property int msgId: model.messageId
                            visible: reactionsData && reactionsData.length > 0

                            Repeater {
                                model: reactionFlow.reactionsData
                                Rectangle {
                                    height: 22
                                    width: chipRow.implicitWidth + 14
                                    radius: 11
                                    color: Theme.inputBg

                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Label { text: modelData.emoji; font.pixelSize: 13 }
                                        Label { text: modelData.count; color: Theme.textMuted; font.pixelSize: 12 }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: chatClient.toggleReaction(reactionFlow.msgId, modelData.emoji)
                                    }
                                }
                            }
                        }
                    }

                    // Nút ⋯ tròn (hiện khi rê chuột) → menu hành động icon-only
                    Rectangle {
                        id: moreBtn
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 8
                        anchors.topMargin: 2
                        width: 28; height: 28; radius: 14
                        visible: (msgHover.hovered || actionMenu.opened) && !model.deleted
                        color: moreArea.containsMouse || actionMenu.opened ? Theme.inputBg : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "⋯"
                            color: Theme.textMuted
                            font.pixelSize: 20
                        }
                        MouseArea {
                            id: moreArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: actionMenu.open()
                        }

                        Popup {
                            id: actionMenu
                            x: moreBtn.width - width
                            y: moreBtn.height + 2
                            padding: 4
                            modal: false
                            background: Rectangle {
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.inputBg
                            }
                            contentItem: Row {
                                spacing: 2
                                Button {
                                    text: "😀"; flat: true
                                    implicitWidth: 32; implicitHeight: 32; padding: 0; font.pixelSize: 16
                                    onClicked: { actionMenu.close(); reactPopup.open() }
                                }
                                Button {
                                    text: "↩"; flat: true
                                    implicitWidth: 32; implicitHeight: 32; padding: 0; font.pixelSize: 16
                                    onClicked: {
                                        actionMenu.close()
                                        root.editingId = 0
                                        root.replyingToId = model.messageId
                                        root.replyingToName = model.username
                                        input.forceActiveFocus()
                                    }
                                }
                                Button {
                                    visible: model.authorId === root.userId
                                    text: "✎"; flat: true
                                    implicitWidth: 32; implicitHeight: 32; padding: 0; font.pixelSize: 16
                                    onClicked: {
                                        actionMenu.close()
                                        root.replyingToId = 0
                                        root.replyingToName = ""
                                        root.editingId = model.messageId
                                        input.text = model.content
                                        input.forceActiveFocus()
                                    }
                                }
                                Button {
                                    visible: model.authorId === root.userId
                                    text: "🗑"; flat: true
                                    implicitWidth: 32; implicitHeight: 32; padding: 0; font.pixelSize: 16
                                    onClicked: { actionMenu.close(); chatClient.deleteMessage(model.messageId) }
                                }
                            }
                        }
                    }

                    // Bảng chọn emoji để thả cảm xúc cho tin nhắn
                    Popup {
                        id: reactPopup
                        property int msgId: model.messageId
                        width: 280
                        padding: 6
                        modal: false
                        // Canh phải; tự lật lên trên nếu không đủ chỗ bên dưới.
                        x: parent.width - width - 8
                        y: 28
                        onAboutToShow: {
                            var topInList = parent.mapToItem(list, 0, 0).y
                            var spaceBelow = list.height - topInList
                            y = (spaceBelow > height + 40) ? 28 : (-height - 4)
                        }

                        background: Rectangle {
                            color: Theme.surface
                            radius: Theme.radius
                            border.color: Theme.inputBg
                        }
                        contentItem: Grid {
                            columns: 10
                            spacing: 2
                            Repeater {
                                model: root.emojis
                                Item {
                                    width: 26; height: 26
                                    Label { anchors.centerIn: parent; text: modelData; font.pixelSize: 18 }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            chatClient.toggleReaction(reactPopup.msgId, modelData)
                                            reactPopup.close()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                onCountChanged: positionViewAtEnd()
            }

            // Banner "đang trả lời"
            RowLayout {
                Layout.fillWidth: true
                visible: root.replyingToId !== 0
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Replying to ") + root.replyingToName
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
                Button {
                    text: "✕"
                    flat: true
                    onClicked: { root.replyingToId = 0; root.replyingToName = "" }
                }
            }

            // Banner "đang sửa"
            RowLayout {
                Layout.fillWidth: true
                visible: root.editingId !== 0
                Label {
                    Layout.fillWidth: true
                    text: qsTr("Editing message")
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
                Button {
                    text: "✕"
                    flat: true
                    onClicked: { root.editingId = 0; input.text = "" }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Hộp nhập bo tròn, emoji nằm bên trong (kiểu Discord).
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: Theme.inputBg

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 4

                        TextField {
                            id: input
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            enabled: root.currentChannelId !== 0
                            placeholderText: qsTr("Message...")
                            color: Theme.textPrimary
                            verticalAlignment: TextInput.AlignVCenter
                            background: Rectangle { color: "transparent" }
                            onAccepted: root.doSend()
                        }

                        // Icon emoji bên trong hộp.
                        Label {
                            id: emojiIcon
                            text: "😀"
                            font.pixelSize: 20
                            Layout.preferredWidth: 30
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            opacity: root.currentChannelId !== 0 ? 1.0 : 0.4

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.currentChannelId !== 0
                                onClicked: emojiPopup.open()
                            }

                            // Bảng emoji hiện ngay phía trên icon, canh phải.
                            Popup {
                                id: emojiPopup
                                width: 336
                                padding: 8
                                modal: false
                                x: emojiIcon.width - width
                                y: -height - 8

                                background: Rectangle {
                                    color: Theme.surface
                                    radius: Theme.radius
                                    border.color: Theme.inputBg
                                }

                                contentItem: Grid {
                                    columns: 10
                                    spacing: 4
                                    Repeater {
                                        model: root.emojis
                                        Item {
                                            width: 28; height: 28
                                            Label {
                                                anchors.centerIn: parent
                                                text: modelData
                                                font.pixelSize: 20
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    input.insert(input.cursorPosition, modelData)
                                                    // Giữ bảng emoji mở để chọn nhiều emoji liên tiếp.
                                                    input.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Button {
                    text: qsTr("Send")
                    highlighted: true
                    enabled: root.currentChannelId !== 0
                    onClicked: root.doSend()
                }
            }
        }
    }

    // Escape ký tự HTML để dùng an toàn với Text.RichText.
    function escapeHtml(s) {
        return String(s)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
    }

    function doSend() {
        var t = input.text.trim()
        if (t.length === 0) return
        if (root.editingId !== 0) {
            chatClient.editMessage(root.editingId, t)
            root.editingId = 0
        } else {
            chatClient.sendMessage(t, root.replyingToId)
            root.replyingToId = 0
            root.replyingToName = ""
        }
        input.text = ""
    }

    // ── Dialog: thêm / tham gia server ─────────────────────────
    Dialog {
        id: addServerDialog
        title: qsTr("Server")
        anchors.centerIn: parent
        modal: true
        width: 340
        padding: 16
        standardButtons: Dialog.Close

        contentItem: ColumnLayout {
            spacing: 10

            Label { text: qsTr("Create a server"); color: Theme.textPrimary; font.bold: true }
            TextField { id: newServerName; Layout.fillWidth: true; placeholderText: qsTr("Server name") }
            Button {
                text: qsTr("Create")
                Layout.fillWidth: true
                onClicked: {
                    if (newServerName.text.trim().length > 0) {
                        chatClient.createServer(newServerName.text.trim())
                        newServerName.text = ""
                        addServerDialog.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: Theme.inputBg
            }

            Label { text: qsTr("Join by ID"); color: Theme.textPrimary; font.bold: true }
            TextField {
                id: joinServerId
                Layout.fillWidth: true
                placeholderText: qsTr("Server ID")
                inputMethodHints: Qt.ImhDigitsOnly
            }
            Button {
                text: qsTr("Join")
                Layout.fillWidth: true
                onClicked: {
                    var raw = joinServerId.text.trim()
                    if (/^\d+$/.test(raw)) {
                        var id = parseInt(raw, 10)
                        if (id > 0) {
                            chatClient.joinServer(id)
                            joinServerId.text = ""
                            addServerDialog.close()
                        }
                    }
                }
            }
        }
    }

    // ── Dialog: tạo channel ────────────────────────────────────
    Dialog {
        id: addChannelDialog
        title: qsTr("Create channel")
        anchors.centerIn: parent
        modal: true
        width: 340
        padding: 16
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            if (newChannelName.text.trim().length > 0 && root.currentServerId !== 0) {
                chatClient.createChannel(root.currentServerId, newChannelName.text.trim())
                newChannelName.text = ""
            }
        }

        contentItem: ColumnLayout {
            spacing: 12
            TextField {
                id: newChannelName
                Layout.fillWidth: true
                placeholderText: qsTr("Channel name")
            }
        }
    }
}
