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
    property string currentUserDisplayName: ""
    property string currentUserAvatar: ""
    property string currentUserBio: ""
    property int    profileTargetUserId: 0
    property string profileTargetUsername: ""
    property string profileTargetDisplayName: ""
    property string profileTargetAvatar: ""
    property string profileTargetBio: ""
    property bool   avatarUploadPending: false
    property string settingsDisplayName: ""
    property string settingsBio: ""
    property string settingsAvatarUrl: ""
    

    // Đính kèm đang chờ gửi: [{url, kind, filename, size}]
    property var    pendingAttachments: []

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

    function avatarColorForName(name) {
        var base = String(name || "?").toUpperCase()
        var sum = 0
        for (var i = 0; i < base.length; ++i) sum += base.charCodeAt(i)
        var palette = ["#5865f2", "#f26522", "#1f9d7a", "#f0b232", "#e84d4d", "#8e5bdc", "#2ecc71", "#3498db"]
        return palette[sum % palette.length]
    }

    function avatarInitial(name) {
        var value = String(name || "?").trim()
        if (value.length === 0) return "?"

        for (var i = 0; i < value.length; ++i) {
            var ch = value.charAt(i)
            if (ch !== " " && ch !== "\t" && ch !== "\n" && ch !== "\r") {
                return ch.toUpperCase()
            }
        }

        return value.charAt(0).toUpperCase()
    }

    function avatarImageSource(url) {
        return url && String(url).trim().length > 0 ? String(url) : ""
    }

    function showUserProfile(userId, username, avatarUrl, displayName, bio) {
        profileTargetUserId = userId
        profileTargetUsername = username || ""
        profileTargetDisplayName = displayName || username || ""
        profileTargetAvatar = avatarUrl || ""
        profileTargetBio = bio || ""
        if (userId > 0) chatClient.requestUserProfile(userId)
        profilePopup.open()
        profilePopup.x = Math.max(12, (root.width - profilePopup.width) / 2)
        profilePopup.y = Math.max(12, (root.height - profilePopup.height) / 2)
    }

    function openSettings() {
        settingsDisplayName = currentUserDisplayName
        settingsBio = currentUserBio
        settingsAvatarUrl = currentUserAvatar
        settingsDialog.open()
    }

    function saveProfile() {
        chatClient.updateProfile(settingsDisplayName, settingsBio)
        settingsDialog.close()
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
            currentServerIndex = 0
            currentChannelId = 0
            replyingToId = 0
            replyingToName = ""
            editingId = 0
            pendingAttachments = []
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

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: root.servers
                    delegate: Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignHCenter
                        width: 48
                        height: 48
                        radius: 24
                        color: index === root.currentServerIndex
                               ? Theme.accent
                               : root.avatarColorForName(modelData.name)
                        Label {
                            anchors.centerIn: parent
                            visible: !(modelData.name && modelData.name.length > 0)
                            text: "?"
                            color: Theme.textPrimary
                            font.bold: true
                            font.pixelSize: 18
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: modelData.name && modelData.name.length > 0
                            text: root.avatarInitial(modelData.name)
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

                // Nút thêm server — ngay dưới server cuối cùng
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter
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

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: false
                    width: 48
                    height: 48
                    radius: width / 2
                    color: Theme.inputBg
                    clip: true
                    Image {
                        anchors.fill: parent
                        visible: root.currentUserAvatar && root.currentUserAvatar.length > 0
                        source: root.avatarImageSource(root.currentUserAvatar)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !(root.currentUserAvatar && root.currentUserAvatar.length > 0)
                        text: root.avatarInitial(root.currentUserDisplayName || root.userId)
                        color: Theme.textPrimary
                        font.bold: true
                        font.pixelSize: 18
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSettings()
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
                            anchors.left: parent.left
                            anchors.leftMargin: 8
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
                    id: msgItem
                    width: ListView.view ? ListView.view.width : 0
                    implicitHeight: Math.max(msgCol.implicitHeight, 32)

                    // Lưu lại giá trị từ model (Popup nằm ở overlay nên không
                    // truy cập được "model" trực tiếp bên trong).
                    property int    mId:          model.messageId
                    property int    mAuthor:      model.authorId
                    property string mUser:        model.username
                    property string mContent:     model.content
                    property var    mAttachments: model.attachments
                    property string mAvatar:      model.avatarUrl

                    HoverHandler { id: msgHover }

                    RowLayout {
                        id: msgRow
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            id: avatarBubble
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 16
                            color: root.avatarColorForName(msgItem.mUser || "?")
                            clip: true
                            Image {
                                anchors.fill: parent
                                visible: msgItem.mAvatar && msgItem.mAvatar.length > 0
                                source: root.avatarImageSource(msgItem.mAvatar)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                            Label {
                                anchors.centerIn: parent
                                visible: !(msgItem.mAvatar && msgItem.mAvatar.length > 0)
                                text: root.avatarInitial(msgItem.mUser)
                                color: Theme.textPrimary
                                font.bold: true
                                font.pixelSize: 14
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (msgItem.mAuthor === root.userId) {
                                        root.openSettings()
                                    } else {
                                        root.showUserProfile(msgItem.mAuthor, msgItem.mUser, msgItem.mAvatar, msgItem.mUser, "")
                                    }
                                }
                            }
                        }

                        

                        Column {
                            id: msgCol
                            Layout.fillWidth: true
                            spacing: 1

                            // Trích dẫn tin được trả lời
                            Label {
                                visible: model.replyToId !== 0
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                width: parent.width
                                text: "↪ " + model.replyUsername + ": " + model.replyExcerpt
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                text: (model.username && model.username.length ? model.username : "?")
                                color: Theme.accent
                                font.bold: true
                                font.pixelSize: 12
                            }
                            Label {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
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

                            // Đính kèm (ảnh/gif hiển thị inline, file khác là thẻ)
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 4
                                visible: !model.deleted && model.attachments && model.attachments.length > 0
                                Repeater {
                                    model: msgItem.mAttachments
                                    Loader {
                                        sourceComponent: (modelData.kind === "image" || modelData.kind === "gif")
                                                         ? imageAtt : fileAtt
                                        property var att: modelData

                                        Component {
                                            id: imageAtt
                                            Image {
                                                source: att.url
                                                asynchronous: true
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize.width: 320
                                                width: Math.min(implicitWidth, 320)
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Qt.openUrlExternally(att.url)
                                                }
                                            }
                                        }
                                        Component {
                                            id: fileAtt
                                            Rectangle {
                                                width: 240; height: 40; radius: 6
                                                color: Theme.inputBg
                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    spacing: 8
                                                    Label { text: "📎"; anchors.verticalCenter: parent.verticalCenter }
                                                    Label {
                                                        text: att.filename
                                                        color: Theme.textPrimary
                                                        elide: Text.ElideRight
                                                        width: 180
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Qt.openUrlExternally(att.url)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Chip reaction
                            Flow {
                                id: reactionFlow
                                anchors.left: parent.left
                                anchors.leftMargin: 8
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
                    }

                    // Nút ⋯ tròn (hiện khi rê chuột) → menu hành động icon-only
                    Rectangle {
                        id: moreBtn
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 8
                        anchors.topMargin: 0
                        width: 26; height: 26; radius: 13
                        z: 10
                        visible: (msgHover.hovered || actionMenu.opened) && !model.deleted
                        color: (moreArea.containsMouse || actionMenu.opened)
                               ? Theme.inputBg : "transparent"

                        Label {
                            anchors.centerIn: parent
                            text: "⋯"
                            color: (moreArea.containsMouse || actionMenu.opened)
                                   ? Theme.textPrimary : Theme.textMuted
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
                            width: 212
                            x: moreBtn.width - width
                            y: moreBtn.height + 2
                            onAboutToShow: {
                                var topInList = moreBtn.mapToItem(list, 0, 0).y
                                var spaceBelow = list.height - topInList
                                y = (spaceBelow > height + 40) ? (moreBtn.height + 2) : (-height - 2)
                            }
                            modal: false
                            background: Rectangle {
                                color: Theme.surface
                                radius: Theme.radius
                                border.color: Theme.serverBar
                            }
                            contentItem: Column {
                                width: parent.width
                                spacing: 2

                                // Add Reaction
                                Rectangle {
                                    width: parent.width; height: 34; radius: 4
                                    color: reactArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Add Reaction")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "😀"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: reactArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { actionMenu.close(); reactPopup.open() }
                                    }
                                }
                                // Reply
                                Rectangle {
                                    width: parent.width; height: 34; radius: 4
                                    color: replyArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Reply")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "↩️"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: replyArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            actionMenu.close()
                                            root.editingId = 0
                                            root.replyingToId = msgItem.mId
                                            root.replyingToName = msgItem.mUser
                                            input.forceActiveFocus()
                                        }
                                    }
                                }
                                // Copy Text
                                Rectangle {
                                    width: parent.width; height: 34; radius: 4
                                    color: copyArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Copy Text")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "📋"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: copyArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { actionMenu.close(); root.copyText(msgItem.mContent) }
                                    }
                                }

                                // Separator (chỉ hiện khi là tin của mình)
                                Rectangle {
                                    width: parent.width - 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: 1
                                    color: Theme.serverBar
                                    visible: msgItem.mAuthor === root.userId
                                }

                                // Edit
                                Rectangle {
                                    visible: msgItem.mAuthor === root.userId
                                    width: parent.width; height: 34; radius: 4
                                    color: editArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Edit")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "✏️"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: editArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            actionMenu.close()
                                            root.replyingToId = 0
                                            root.replyingToName = ""
                                            root.editingId = msgItem.mId
                                            input.text = msgItem.mContent
                                            input.forceActiveFocus()
                                        }
                                    }
                                }
                                // Delete (đỏ)
                                Rectangle {
                                    visible: msgItem.mAuthor === root.userId
                                    width: parent.width; height: 34; radius: 4
                                    color: delArea.containsMouse ? Theme.danger : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Delete")
                                            color: delArea.containsMouse ? "white" : Theme.danger
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "🗑️"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: delArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { actionMenu.close(); chatClient.deleteMessage(msgItem.mId) }
                                    }
                                }
                            }
                        }
                    }

                    // Bảng chọn emoji để thả cảm xúc cho tin nhắn
                    Popup {
                        id: reactPopup
                        property int msgId: msgItem.mId
                        width: 280
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

            // Khay đính kèm đang chờ gửi
            Flow {
                Layout.fillWidth: true
                spacing: 6
                visible: root.pendingAttachments.length > 0
                Repeater {
                    model: root.pendingAttachments
                    Rectangle {
                        width: 120; height: 80; radius: 6
                        color: Theme.inputBg
                        clip: true
                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: (modelData.kind === "image" || modelData.kind === "gif") ? modelData.url : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: modelData.kind !== "image" && modelData.kind !== "gif"
                            text: "📎\n" + modelData.filename
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.textPrimary
                            font.pixelSize: 11
                            width: parent.width - 8
                            elide: Text.ElideRight
                        }
                        // Nút xóa khỏi khay
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.margins: 2
                            width: 18; height: 18; radius: 9
                            color: "#000000AA"
                            Label { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 11 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var copy = root.pendingAttachments.slice()
                                    copy.splice(index, 1)
                                    root.pendingAttachments = copy
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Hộp nhập bo tròn, "+" và emoji nằm bên trong (kiểu Discord).
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 22
                    color: Theme.inputBg

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        spacing: 6

                        // Nút "+" nằm bên trái trong thanh chat (chỉ là icon)
                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            opacity: root.currentChannelId !== 0 ? 1.0 : 0.4
                            Label {
                                anchors.centerIn: parent
                                text: "+"
                                color: plusArea.containsMouse ? Theme.textPrimary : Theme.textMuted
                                font.pixelSize: 24
                                font.bold: true
                            }
                            MouseArea {
                                id: plusArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.currentChannelId !== 0
                                onClicked: {
                                    var p = chatClient.chooseFile()
                                    if (p && p.length > 0) chatClient.uploadAttachment(p)
                                }
                            }
                        }

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

            }
        }
    }

    // TextEdit ẩn để copy nội dung vào clipboard.
    TextEdit { id: clipHelper; visible: false }
    function copyText(t) {
        clipHelper.text = t
        clipHelper.selectAll()
        clipHelper.copy()
        clipHelper.text = ""
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
        if (root.editingId !== 0) {
            if (t.length === 0) return     // sửa thì phải có nội dung
            chatClient.editMessage(root.editingId, t)
            root.editingId = 0
            input.text = ""
            return
        }
        if (t.length === 0 && root.pendingAttachments.length === 0) return
        chatClient.sendMessage(t, root.replyingToId, root.pendingAttachments)
        root.replyingToId = 0
        root.replyingToName = ""
        root.pendingAttachments = []
        input.text = ""
    }

    // Sự kiện upload từ ChatClient
    Connections {
        target: chatClient
        function onAuthOk(userId, username, displayName, avatarUrl, bio) {
            root.userId = userId
            root.currentUserDisplayName = displayName || username || ""
            root.currentUserAvatar = avatarUrl || ""
            root.currentUserBio = bio || ""
            root.settingsDisplayName = root.currentUserDisplayName
            root.settingsAvatarUrl = root.currentUserAvatar
            root.settingsBio = root.currentUserBio
        }
        function onProfileUpdated(avatarUrl, displayName, bio) {
            root.currentUserAvatar = avatarUrl || ""
            root.currentUserDisplayName = displayName || root.currentUserDisplayName
            root.currentUserBio = bio || ""
            root.settingsAvatarUrl = root.currentUserAvatar
            root.settingsDisplayName = root.currentUserDisplayName
            root.settingsBio = root.currentUserBio
        }
        function onUserProfileReceived(userId, username, displayName, avatarUrl, bio) {
            if (root.profileTargetUserId === userId) {
                root.profileTargetUsername = username || root.profileTargetUsername
                root.profileTargetDisplayName = displayName || root.profileTargetDisplayName
                root.profileTargetAvatar = avatarUrl || root.profileTargetAvatar
                root.profileTargetBio = bio || root.profileTargetBio
            }
        }
        function onAttachmentUploaded(url, kind, filename, size) {
            if (root.avatarUploadPending) {
                root.avatarUploadPending = false
                root.settingsAvatarUrl = url
                root.currentUserAvatar = url
                chatClient.updateProfileAvatar(url)
                return
            }
            root.pendingAttachments = root.pendingAttachments.concat([
                { "url": url, "kind": kind, "filename": filename, "size": size }
            ])
        }
        function onUploadFailed(reason) {
            root.avatarUploadPending = false
            console.log("Upload failed: " + reason)
        }
    }

    Popup {
        id: profilePopup
        width: 280
        modal: false
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.inputBg
        }
        contentItem: Item {
            implicitWidth: 280
            implicitHeight: 180
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: root.avatarColorForName(root.profileTargetDisplayName || root.profileTargetUsername || "?")
                    clip: true
                    Image {
                        anchors.fill: parent
                        visible: root.profileTargetAvatar && root.profileTargetAvatar.length > 0
                        source: root.avatarImageSource(root.profileTargetAvatar)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !(root.profileTargetAvatar && root.profileTargetAvatar.length > 0)
                        text: root.avatarInitial(root.profileTargetDisplayName || root.profileTargetUsername)
                        color: Theme.textPrimary
                        font.bold: true
                        font.pixelSize: 24
                    }
                }
                Label {
                    text: root.profileTargetDisplayName || root.profileTargetUsername || qsTr("User")
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontNormal
                }
                Label {
                    text: root.profileTargetUsername ? "@" + root.profileTargetUsername : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                }
                Label {
                    visible: root.profileTargetBio && root.profileTargetBio.length > 0
                    text: root.profileTargetBio
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
    }

    Dialog {
        id: settingsDialog
        title: qsTr("Profile settings")
        anchors.centerIn: parent
        modal: true
        width: 360
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: root.saveProfile()
        contentItem: Item {
            implicitWidth: 360
            implicitHeight: 240
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 72
                    height: 72
                    radius: 36
                    color: root.avatarColorForName(root.settingsDisplayName || root.currentUserDisplayName || "?")
                    clip: true
                    Image {
                        anchors.fill: parent
                        visible: root.settingsAvatarUrl && root.settingsAvatarUrl.length > 0
                        source: root.avatarImageSource(root.settingsAvatarUrl)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: !(root.settingsAvatarUrl && root.settingsAvatarUrl.length > 0)
                        text: root.avatarInitial(root.settingsDisplayName || root.currentUserDisplayName)
                        color: Theme.textPrimary
                        font.bold: true
                        font.pixelSize: 28
                    }
                }
                Button {
                    text: qsTr("Change avatar")
                    Layout.fillWidth: true
                    onClicked: {
                        var p = chatClient.chooseFile()
                        if (p && p.length > 0) {
                            root.avatarUploadPending = true
                            chatClient.uploadAttachment(p)
                        }
                    }
                }
                TextField {
                    id: profileDisplayName
                    Layout.fillWidth: true
                    text: root.settingsDisplayName
                    placeholderText: qsTr("Display name")
                    onTextChanged: root.settingsDisplayName = text
                }
                TextArea {
                    id: profileBio
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    wrapMode: TextEdit.Wrap
                    text: root.settingsBio
                    placeholderText: qsTr("Bio")
                    onTextChanged: root.settingsBio = text
                }
            }
        }
    }

    // ── Dialog: thêm / tham gia server ─────────────────────────
    Dialog {
        id: addServerDialog
        title: qsTr("Server")
        anchors.centerIn: parent
        modal: true
        width: 340
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
