import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Chatties
// import Qt5Compat.GraphicalEffects

Item {
    id: root

    // Dữ liệu server truyền từ Main.qml
    property var servers: []
    property int currentServerIndex: 0
    property int currentChannelId: 0

    // BỔ SUNG: Từ điển lưu trữ ánh xạ giữa Shortcode và Link thật của Custom Emoji
    property var customEmojiDictionary: ({})

    // --- BẢNG THẢ REACTION TOÀN CỤC ---
    Popup {
        id: globalReactPopup
        property int targetMsgId: 0

        width: 320
        height: 280
        modal: false
        padding: 0
        
        background: Rectangle {
            color: Theme.surface
            radius: 8
            border.color: Theme.inputBg
        }

        onAboutToShow: {
            reactionCustomModel.clear()
            for (var key in root.customEmojiDictionary) {
                if (root.customEmojiDictionary.hasOwnProperty(key)) {
                    reactionCustomModel.append({ "shortcode": key, "url": root.customEmojiDictionary[key] })
                }
            }
        }

        ListModel { id: reactionCustomModel }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // 1. THANH TAB BAR
            TabBar {
                id: reactTabBar
                Layout.fillWidth: true
                background: Rectangle { color: "transparent" }
                
                TabButton {
                    text: "Mặc định"
                    width: implicitWidth
                    contentItem: Text {
                        text: parent.text
                        color: reactTabBar.currentIndex === 0 ? Theme.textPrimary : Theme.textMuted
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle { width: parent.width; height: 2; color: Theme.accent; anchors.bottom: parent.bottom; visible: reactTabBar.currentIndex === 0 }
                    }
                }
                TabButton {
                    text: "Tùy chỉnh"
                    width: implicitWidth
                    contentItem: Text {
                        text: parent.text
                        color: reactTabBar.currentIndex === 1 ? Theme.textPrimary : Theme.textMuted
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle { width: parent.width; height: 2; color: Theme.accent; anchors.bottom: parent.bottom; visible: reactTabBar.currentIndex === 1 }
                    }
                }
            }

            // Đường kẻ ngang phân cách
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.inputBg }

            // 2. KHU VỰC NỘI DUNG (CHUYỂN TAB)
            StackLayout {
                currentIndex: reactTabBar.currentIndex
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Tab 1: Emoji Mặc định
                ScrollView {
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Flow {
                        width: globalReactPopup.width
                        padding: 12
                        spacing: 8
                        Repeater {
                            model: root.emojis
                            Text {
                                text: modelData; font.pixelSize: 24
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    Rectangle { anchors.fill: parent; color: Theme.textPrimary; opacity: parent.containsMouse ? 0.1 : 0.0; radius: 6; z: -1 }
                                    onClicked: { 
                                        chatClient.toggleReaction(globalReactPopup.targetMsgId, modelData)
                                        globalReactPopup.close() 
                                    }
                                }
                            }
                        }
                    }
                }

                // Tab 2: Emoji Tùy chỉnh
                ScrollView {
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    Flow {
                        width: globalReactPopup.width
                        padding: 12
                        spacing: 8
                        Repeater {
                            model: reactionCustomModel
                            Image {
                                width: 24; height: 24
                                source: model.url
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                                    Rectangle { anchors.fill: parent; color: Theme.textPrimary; opacity: parent.containsMouse ? 0.1 : 0.0; radius: 6; z: -1 }
                                    onClicked: { 
                                        chatClient.toggleReaction(globalReactPopup.targetMsgId, ":" + model.shortcode + ":")
                                        globalReactPopup.close() 
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Bộ emoji Unicode cho composer.
    property var emojis: [
        "😀","😁","😂","🤣","😊","😍","😎","😉","🙂","😴",
        "😢","😭","😡","😱","🤔","😅","🥳","🤯","😬","🙄",
        "👍","👎","🙏","👏","🙌","💪","👀","🤝","✌️","🤙",
        "❤️","🔥","🎉","💯","⭐","✨","✅","❌","💀","🚀",
        "☕","🍕","🍻","🎮","🐱","🐶","🌟","💬","📌","🎵"
    ]

    // Custom emoji từ server: danh sách [{shortcode, url}] và map shortcode->url
    property var customEmojis: []
    property var emojiMap: ({})
    property string emojiUploadPath: ""

    // Kết quả tìm GIF từ Giphy
    property var gifResults: []

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
    property string settingsAvatarUrlAtOpen: ""
    property int avatarRenderSize: 1024

    // Đính kèm đang chờ gửi: [{url, kind, filename, size}]
    property var    pendingAttachments: []

    readonly property var currentChannels:
        (servers.length > currentServerIndex && currentServerIndex >= 0)
            ? servers[currentServerIndex].channels : []
    readonly property int currentServerId:
        (servers.length > currentServerIndex && currentServerIndex >= 0)
            ? servers[currentServerIndex].id : 0

    // Đổi server → nạp custom emoji của server đó.
    onCurrentServerIdChanged: {
        root.emojiMap = ({})
        root.customEmojis = []
        if (currentServerId !== 0)
            chatClient.fetchCustomEmojis(currentServerId)
    }

    function selectChannel(id) {
        currentChannelId = id
        chatClient.selectChannel(id)
    }

    function avatarColorForName(name) {
        var base = String(name || "?").toUpperCase()
        var hash = 0

        for (var i = 0; i < base.length; ++i) {
            hash = base.charCodeAt(i) + ((hash << 5) - hash)
        }

        var palette = ["#5865f2", "#f26522", "#1f9d7a", "#f0b232", "#e84d4d", "#8e5bdc", "#2ecc71", "#3498db"]
        var index = Math.abs(hash) % palette.length
        return palette[index]
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
        var resolved = PresetAvatars.resolveAvatarUrl(url)
        return resolved && String(resolved).trim().length > 0 ? String(resolved) : ""
    }

    function avatarBackgroundColor(avatarUrl, displayName) {
        var presetColor = PresetAvatars.backgroundColorForUrl(avatarUrl)
        return presetColor.length > 0
                ? presetColor
                : avatarColorForName(displayName || "?")
    }

    function avatarImageMargins(containerSize, avatarUrl) {
        return PresetAvatars.isPresetUrl(avatarUrl)
                ? Math.round(containerSize * 0.06)
                : 0
    }

    // Nhãn cho vạch phân chia ngày, vd: "May 29, 2026" — giống style Discord trong ảnh mẫu.
    function formatDateDivider(date) {
        return Qt.formatDate(date, "MMMM d, yyyy")
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
        settingsAvatarUrlAtOpen = currentUserAvatar
        settingsDialog.open()
    }

    function revertSettings() {
        settingsDisplayName = currentUserDisplayName
        settingsBio = currentUserBio
        settingsAvatarUrl = currentUserAvatar
        profileDisplayName.text = currentUserDisplayName
        profileBio.text = currentUserBio
    }

    function saveProfile() {
        chatClient.updateProfile(settingsDisplayName, settingsBio)
        if (settingsAvatarUrl !== settingsAvatarUrlAtOpen) {
            chatClient.updateProfileAvatar(settingsAvatarUrl)
            currentUserAvatar = settingsAvatarUrl
        }
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

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ── Cột 1: dãy server ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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

                /* =========================== GHI ĐÈ MÀU TÍM LÊN AVATAR SERVER ===============
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
                ================================================================= */

                Repeater {
                    model: root.servers
                    delegate: Item {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        Layout.alignment: Qt.AlignHCenter
                        width: 56
                        height: 56

                        // Glow khi được chọn
                        Rectangle {
                            anchors.centerIn: parent
                            width: 56
                            height: 56
                            radius: 28
                            visible: index === root.currentServerIndex
                            color: "transparent"
                            border.color: "#FFB347"
                            border.width: 2
                            opacity: 0.9
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 60
                            height: 60
                            radius: 30
                            visible: index === root.currentServerIndex
                            color: "transparent"
                            border.color: "#FFB347"
                            border.width: 1.5
                            opacity: 0.5
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64
                            height: 64
                            radius: 32
                            visible: index === root.currentServerIndex
                            color: "transparent"
                            border.color: "#FFB347"
                            border.width: 1
                            opacity: 0.2
                        }

                        // Icon server
                        Rectangle {
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            radius: 24
                            color: root.avatarColorForName(modelData.name)
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
                    id: userAvatarContainer
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: false
                    width: 48; height: 48; radius: 24
                    color: root.avatarBackgroundColor(root.currentUserAvatar, root.currentUserDisplayName)
                    layer.enabled: true
                    Label {
                        anchors.centerIn: parent
                        visible: !(root.currentUserAvatar && root.currentUserAvatar.length > 0)
                        text: root.avatarInitial(root.currentUserDisplayName || root.userId)
                        color: Theme.textPrimary; font.bold: true; font.pixelSize: 18
                    }
                    Image {
                        anchors.fill: parent
                        anchors.margins: root.avatarImageMargins(parent.width, root.currentUserAvatar)
                        visible: root.currentUserAvatar && root.currentUserAvatar.length > 0
                        source: root.avatarImageSource(root.currentUserAvatar)
                        fillMode: PresetAvatars.isPresetUrl(root.currentUserAvatar)
                                  ? Image.PreserveAspectFit
                                  : Image.PreserveAspectCrop
                        sourceSize: Qt.size(root.avatarRenderSize, root.avatarRenderSize)
                        smooth: true
                        mipmap: true
                        asynchronous: true; cache: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSettings()
                    }
                }
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ── Cột 2: danh sách channel ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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


        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        // ── Cột 3: tin nhắn + ô soạn /////////////////////////////////////////////////////////////////////////////////////////
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
                spacing: 2
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

                    // Lưu lại giá trị từ model (Popup nằm ở overlay nên không
                    // truy cập được "model" trực tiếp bên trong).
                    property int    mId:          model.messageId
                    property int    mAuthor:      model.authorId
                    property string mUser:        model.username
                    property string mContent:     model.content
                    property var    mAttachments: model.attachments
                    property string mAvatar:      model.avatarUrl

                    // Tin nhắn đầu tiên của một ngày mới → hiện vạch phân chia ngày.
                    property bool isNewDay: {
                        if (index <= 0) return true
                        var prevTs = messageModel.data(messageModel.index(index - 1, 0), 259)
                        if (prevTs === undefined || prevTs === null) return true
                        var cur  = new Date(model.timestamp * 1000)
                        var prev = new Date(prevTs * 1000)
                        return cur.getFullYear() !== prev.getFullYear()
                            || cur.getMonth()    !== prev.getMonth()
                            || cur.getDate()     !== prev.getDate()
                    }
                    property real dividerHeight: isNewDay ? 32 : 0

                    // Discord-style: cùng author liên tiếp → ẩn avatar + username, giữ indent.
                    property bool groupedWithPrevious: {
                        if (isNewDay) return false
                        if (index <= 0) return false
                        var prev = messageModel.index(index - 1, 0)
                        if (!prev.valid) return false
                        return messageModel.data(prev, 260) === model.authorId
                    }
                    property bool mGrouped: groupedWithPrevious
                    property real groupLeadGap: groupedWithPrevious ? 0 : 6
                    height: dividerHeight + groupLeadGap + msgCol.implicitHeight

                    HoverHandler { id: msgHover }

                    // ── Vạch phân chia ngày (vd: "Today" / "May 29, 2026") ──
                    Item {
                        id: dateDivider
                        visible: msgItem.isNewDay
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: msgItem.dividerHeight

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Theme.textMuted
                            opacity: 0.25
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            color: Theme.background
                            radius: 4
                            height: dateLabel.implicitHeight + 4
                            width: dateLabel.implicitWidth + 16

                            Label {
                                id: dateLabel
                                anchors.centerIn: parent
                                text: root.formatDateDivider(new Date(model.timestamp * 1000))
                                color: Theme.textMuted
                                font.bold: true
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                    }

                    Rectangle {
                        id: avatarBubble
                        anchors.top: parent.top
                        anchors.topMargin: msgItem.dividerHeight + groupLeadGap
                        anchors.left: parent.left
                        width: 32
                        height: 32
                        radius: 16
                        clip: true
                        opacity: groupedWithPrevious ? 0 : 1
                        color: root.avatarBackgroundColor(msgItem.mAvatar, msgItem.mUser || "?")

                        Label {
                            anchors.centerIn: parent
                            visible: !(msgItem.mAvatar && msgItem.mAvatar.length > 0)
                            text: root.avatarInitial(msgItem.mUser)
                            color: Theme.textPrimary
                            font.bold: true
                            font.pixelSize: 14
                        }

                        Image {
                            anchors.fill: parent
                            visible: msgItem.mAvatar && msgItem.mAvatar.length > 0
                            source: msgItem.mAvatar && msgItem.mAvatar.length > 0
                                    ? root.avatarImageSource(msgItem.mAvatar)
                                    : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(root.avatarRenderSize, root.avatarRenderSize)
                            smooth: true
                            mipmap: true
                            asynchronous: true
                            cache: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !groupedWithPrevious
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (msgItem.mAuthor === root.userId) {
                                    root.openSettings()
                                } else {
                                    root.showUserProfile(msgItem.mAuthor, msgItem.mUser,
                                                        msgItem.mAvatar, msgItem.mUser, "")
                                }
                            }
                        }
                    }

                    Column {
                        id: msgCol
                        anchors.top: parent.top
                        anchors.topMargin: msgItem.dividerHeight + groupLeadGap
                        anchors.left: avatarBubble.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
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
                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 6
                                visible: !msgItem.mGrouped
                                Label {
                                    id: usernameLabel
                                    text: (model.username && model.username.length ? model.username : "?")
                                    color: Theme.accent
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                                Label {
                                    visible: !msgItem.mGrouped
                                    text: Qt.formatTime(new Date(model.timestamp * 1000), "hh:mm AP")
                                    color: Theme.textMuted
                                    font.pixelSize: 11
                                }
                            }
                            Label {
                                id: msgTextLabel
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                width: parent.width
                                textFormat: Text.RichText
                                color: Theme.textPrimary
                                wrapMode: Text.WordWrap

                                // Thuộc tính lưu giữ văn bản đã lọc
                                property string cleanContent: (msgItem.mContent || "").replace(/(https?:\/\/[^\s]+?\.gif(?:\?[^\s]*)?)/gi, "").trim()
                                
                                // Gọi biến thông qua ID để không bao giờ bị báo undefined
                                visible: msgTextLabel.cleanContent.length > 0 || model.deleted

                                // HÀM PARSER ĐA NĂNG - Biến :token: thành Icon nhỏ xinh
                                function parseCustomEmoji(rawText) {
                                    if (model.deleted) return "";
                                    var escapedText = root.escapeHtml(rawText);
                                    var emojiRegex = /:([a-zA-Z0-9_\-]+):/g;

                                    return escapedText.replace(emojiRegex, function(match, emojiName) {
                                        // 1. Lấy link thực sự từ Từ điển
                                        var realUrl = root.customEmojiDictionary[emojiName];
                                        
                                        // 2. Nếu tìm thấy link thực, render ảnh. Nếu không, trả lại nguyên chữ :ten_emoji:
                                        if (realUrl) {
                                            return '<img src="' + realUrl + '" width="22" height="22" align="middle" />';
                                        }
                                        return match; 
                                    });
                                }

                                text: model.deleted
                                      ? "<i><span style='color:#b5bac1;'>" + qsTr("[message deleted]") + "</span></i>"
                                      : root.renderContent(model.content)
                                        + (model.edited
                                           ? " <span style='color:#b5bac1; font-size:11px;'>" + qsTr("(edited)") + "</span>"
                                           : "")

                                // Bổ sung sự kiện để khi người dùng click vào cái ảnh động (bây giờ là thẻ HTML img), 
                                // nó sẽ mở link trên trình duyệt
                                onLinkActivated: Qt.openUrlExternally(link)           
                            }

                            // KHU VỰC HIỂN THỊ GIF ẢO (Từ Giphy)
                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 4
                                visible: !model.deleted
                                
                                Repeater {
                                    model: {
                                        var urls = [];
                                        var regex = /(https?:\/\/[^\s]+?\.gif(?:\?[^\s]*)?)/gi;
                                        var match;
                                        var raw = msgItem.mContent || "";
                                        while ((match = regex.exec(raw)) !== null) {
                                            urls.push(match[1]);
                                        }
                                        return urls;
                                    }
                                    
                                    delegate: AnimatedImage {
                                        source: modelData
                                        asynchronous: true
                                        fillMode: AnimatedImage.PreserveAspectFit
                                        sourceSize.width: 320
                                        sourceSize.height: 250
                                        width: implicitWidth > 0 ? Math.min(implicitWidth, 320) : 200
                                        height: implicitHeight > 0 ? Math.min(implicitHeight, 250) : 200
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Qt.openUrlExternally(modelData)
                                        }
                                    }
                                }
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
                                        sourceComponent: modelData.kind === "image" ? imageAtt
                                                         : (modelData.kind === "gif" ? gifAtt : fileAtt)
                                        property var att: modelData

                                        Component {
                                            id: gifAtt
                                            Rectangle {
                                                radius: 10
                                                clip: true
                                                color: "transparent"
                                                width: gimg.width
                                                height: gimg.height
                                                AnimatedImage {
                                                    id: gimg
                                                    source: att.url
                                                    asynchronous: true
                                                    cache: true
                                                    playing: true
                                                    fillMode: Image.PreserveAspectFit
                                                    // AnimatedImage không hỗ trợ sourceSize ổn định —
                                                    // tự co theo tỉ lệ gốc, chặn bề rộng tối đa 320.
                                                    width: implicitWidth > 0 ? Math.min(implicitWidth, 320) : 240
                                                    height: implicitWidth > 0
                                                            ? width * implicitHeight / implicitWidth
                                                            : 180
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Qt.openUrlExternally(att.url)
                                                }
                                            }
                                        }

                                        Component {
                                            id: imageAtt
                                            
                                            // Dùng Rectangle bo góc 10px (Kế thừa từ code mới)
                                            Rectangle {
                                                radius: 10
                                                clip: true
                                                color: "transparent"
                                                width: img.width
                                                height: img.height
                                                
                                                // Dùng AnimatedImage để render được file .gif (Kế thừa từ code cũ)
                                                AnimatedImage {
                                                    id: img
                                                    source: att.url
                                                    asynchronous: true
                                                    fillMode: Image.PreserveAspectFit
                                                    sourceSize.width: 320
                                                    sourceSize.height: 250
                                                    // Lấy logic tính toán kích thước an toàn từ code mới
                                                    width: Math.min(implicitWidth > 0 ? implicitWidth : 320, 320)
                                                    height: Math.min(implicitHeight > 0 ? implicitHeight : 250, 250)
                                                }
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
                                        id: reactionPill
                                        height: 22
                                        width: chipRow.implicitWidth + 14
                                        radius: 11
                                        color: Theme.inputBg

                                        // 1. Phân tích: Có phải là Custom Emoji dạng :shortcode: không?
                                        property string rawEmoji: modelData.emoji || ""
                                        property bool isCustom: rawEmoji.startsWith(":") && rawEmoji.endsWith(":")
                                        property string cleanShortcode: isCustom ? rawEmoji.substring(1, rawEmoji.length - 1) : ""
                                        property string customUrl: isCustom ? (root.customEmojiDictionary[cleanShortcode] || "") : ""

                                        Row {
                                            id: chipRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            // 2A. Nếu là Custom Emoji -> Hiện ẢNH
                                            Image {
                                                visible: reactionPill.isCustom && reactionPill.customUrl !== ""
                                                source: reactionPill.customUrl
                                                width: 16
                                                height: 16
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // 2B. Nếu là Emoji mặc định (hoặc lỗi link) -> Hiện TEXT
                                            Label { 
                                                visible: !reactionPill.isCustom || reactionPill.customUrl === ""
                                                text: reactionPill.rawEmoji 
                                                font.pixelSize: 13 
                                                color: Theme.textPrimary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // 3. Hiển thị số lượng
                                            Label { 
                                                text: modelData.count 
                                                color: Theme.textMuted 
                                                font.pixelSize: 12 
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: chatClient.toggleReaction(reactionFlow.msgId, reactionPill.rawEmoji)
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
                        // Lùi xuống dưới vạch chia ngày để không đè lên timeline.
                        anchors.topMargin: msgItem.dividerHeight + groupLeadGap
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
                                        onClicked: { 
                                            actionMenu.close() 
                                            globalReactPopup.targetMsgId = msgItem.mId
                                            
                                            // Quét tọa độ Y của nút bấm
                                            var absolutePos = mapToItem(root, 0, 0)
                                            
                                            // FIX: Gắn chết trục X sang bên phải màn hình (cách lề 24px)
                                            globalReactPopup.x = root.width - globalReactPopup.width - 24
                                            globalReactPopup.y = absolutePos.y
                                            
                                            // Chống tràn màn hình trục Y
                                            if (globalReactPopup.y < 8) {
                                                globalReactPopup.y = 8
                                            } else if (globalReactPopup.y + globalReactPopup.height > root.height) {
                                                globalReactPopup.y = root.height - globalReactPopup.height - 8
                                            }
                                            
                                            globalReactPopup.open()
                                        }
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

                        // Nút GIF bên trong hộp.
                        Label {
                            id: gifIcon
                            text: "GIF"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 32
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            opacity: root.currentChannelId !== 0 ? 1.0 : 0.4
                            color: gifArea.containsMouse ? Theme.textPrimary : Theme.textMuted

                            MouseArea {
                                id: gifArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: root.currentChannelId !== 0
                                onClicked: gifPopup.open()
                            }

                            Popup {
                                id: gifPopup
                                width: 360
                                height: 380
                                padding: 8
                                modal: false
                                x: gifIcon.width - width
                                y: -height - 8
                                onAboutToShow: {
                                    gifSearchField.text = ""
                                    chatClient.searchGifs("")   // trending
                                }
                                background: Rectangle {
                                    color: Theme.surface
                                    radius: Theme.radius
                                    border.color: Theme.inputBg
                                }
                                contentItem: ColumnLayout {
                                    spacing: 6
                                    TextField {
                                        id: gifSearchField
                                        Layout.fillWidth: true
                                        placeholderText: qsTr("Search GIFs…")
                                        onTextChanged: gifSearchTimer.restart()
                                    }
                                    Timer {
                                        id: gifSearchTimer
                                        interval: 350
                                        onTriggered: chatClient.searchGifs(gifSearchField.text)
                                    }
                                    GridView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        cellWidth: 114
                                        cellHeight: 90
                                        model: root.gifResults
                                        delegate: Item {
                                            width: 112; height: 88
                                            AnimatedImage {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                source: modelData.preview
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: true
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    chatClient.sendMessage("", root.replyingToId, [
                                                        { "url": modelData.url, "kind": "gif",
                                                          "filename": "giphy.gif", "size": 0 }
                                                    ])
                                                    root.replyingToId = 0
                                                    root.replyingToName = ""
                                                    gifPopup.close()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
                                width: 350
                                height: 300
                                modal: false
                                x: emojiIcon.width - width
                                y: -height - 8
                                padding: 0

                                background: Rectangle {
                                    color: Theme.surface
                                    radius: Theme.radius
                                    border.color: Theme.inputBg
                                }

                                onAboutToShow: chatClient.fetchCustomEmojis(root.currentServerId)
                                contentItem: Column {
                                    width: 320
                                    spacing: 6

                                    // Emoji Unicode
                                    Grid {
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
                                                        input.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width; height: 1
                                        color: Theme.inputBg
                                        visible: root.customEmojis.length > 0
                                    }

                                    // Custom emoji của server (chèn :shortcode:)
                                    Grid {
                                        columns: 10
                                        spacing: 4
                                        visible: root.customEmojis.length > 0
                                        Repeater {
                                            model: root.customEmojis
                                            Item {
                                                width: 28; height: 28
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 24; height: 24
                                                    source: modelData.url
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        input.insert(input.cursorPosition, ":" + modelData.shortcode + ":")
                                                        input.forceActiveFocus()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Button {
                                        text: qsTr("+ Add custom emoji")
                                        flat: true
                                        font.pixelSize: 12
                                        onClicked: { emojiPopup.close(); addEmojiDialog.open() }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    // Dialog thêm custom emoji
    Dialog {
        id: addEmojiDialog
        title: qsTr("Add custom emoji")
        anchors.centerIn: parent
        modal: true
        width: 320
        padding: 16
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: {
            var sc = emojiShortcode.text.trim()
            if (sc.length > 0 && root.emojiUploadPath.length > 0 && root.currentServerId !== 0)
                chatClient.uploadCustomEmoji(root.currentServerId, sc, root.emojiUploadPath)
            emojiShortcode.text = ""
            root.emojiUploadPath = ""
        }
        contentItem: ColumnLayout {
            spacing: 8
            TextField {
                id: emojiShortcode
                Layout.fillWidth: true
                placeholderText: qsTr("shortcode (e.g. kek)")
            }
            Button {
                Layout.fillWidth: true
                text: root.emojiUploadPath.length > 0
                      ? qsTr("Image selected ✓") : qsTr("Choose image")
                onClicked: {
                    var p = chatClient.chooseFile()
                    if (p && p.length > 0) root.emojiUploadPath = p
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

    // Escape + thay :shortcode: bằng ảnh emoji nếu có trong emojiMap.
    function renderContent(s) {
        return root.escapeHtml(s).replace(/:([A-Za-z0-9_]+):/g, function(match, code) {
            var url = root.emojiMap[code]
            return url
                ? "<img src='" + url + "' width='20' height='20'>"
                : match
        })
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
        function onCustomEmojisReceived(emojis) {
            root.customEmojis = emojis
            var m = ({})
            for (var i = 0; i < emojis.length; ++i)
                m[emojis[i].shortcode] = emojis[i].url
            root.emojiMap = m
        }
        function onGifResults(gifs) {
            root.gifResults = gifs
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
                    id: profileAvatarContainer
                    Layout.alignment: Qt.AlignHCenter
                    width: 64; height: 64; radius: 32
                    color: root.avatarBackgroundColor(
                               root.profileTargetAvatar,
                               root.profileTargetDisplayName || root.profileTargetUsername || "?")
                    layer.enabled: true
                    Label {
                        anchors.centerIn: parent
                        visible: !(root.profileTargetAvatar && root.profileTargetAvatar.length > 0)
                        text: root.avatarInitial(root.profileTargetDisplayName || root.profileTargetUsername)
                        color: Theme.textPrimary; font.bold: true; font.pixelSize: 24
                    }
                    Image {
                        anchors.fill: parent
                        visible: root.profileTargetAvatar && root.profileTargetAvatar.length > 0
                        source: root.avatarImageSource(root.profileTargetAvatar)
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(root.avatarRenderSize, root.avatarRenderSize)
                        smooth: true
                        mipmap: true
                        asynchronous: true; cache: true
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

    PresetAvatarPopup {
        id: presetAvatarPopup
        onAvatarConfirmed: function(url) {
            root.settingsAvatarUrl = url
        }
    }

    Dialog {
        id: settingsDialog
        title: qsTr("Profile settings")
        anchors.centerIn: parent
        modal: true
        width: 360
        height: Math.min(460, root.height - 60)
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: root.saveProfile()
        onRejected: root.revertSettings()

        // contentItem giờ là ScrollView bọc toàn bộ nội dung, không phải Item cố định cao 340px nữa.
        // => sau này thêm field mới vào contentColumn vẫn luôn cuộn được, không bị cắt mất.
        contentItem: ScrollView {
            id: settingsScroll
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            // Thanh cuộn mảnh, tối giản — đồng bộ với style của message list.
            // Dùng anchors.right để ép vị trí bên phải (thay vì x tự tính), tránh lỗi scope id.
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 3
                anchors.right: parent ? parent.right : undefined
                anchors.top: parent ? parent.top : undefined
                anchors.bottom: parent ? parent.bottom : undefined
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius: 1.5
                    color: Theme.textMuted
                    opacity: parent.pressed ? 0.8 : 0.4
                }
            }

            Item {
                width: settingsScroll.availableWidth
                implicitHeight: contentColumn.implicitHeight + 24

                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Rectangle {
                        id: settingsAvatarContainer
                        Layout.alignment: Qt.AlignHCenter
                        width: 72; height: 72; radius: 36
                        color: root.avatarBackgroundColor(
                                   root.settingsAvatarUrl,
                                   root.settingsDisplayName || root.currentUserDisplayName)
                        layer.enabled: true
                        Label {
                            anchors.centerIn: parent
                            visible: !(root.settingsAvatarUrl && root.settingsAvatarUrl.length > 0)
                            text: root.avatarInitial(root.settingsDisplayName || root.currentUserDisplayName)
                            color: Theme.textPrimary; font.bold: true; font.pixelSize: 28
                        }
                        Image {
                            anchors.fill: parent
                            anchors.margins: root.avatarImageMargins(parent.width, root.settingsAvatarUrl)
                            visible: root.settingsAvatarUrl && root.settingsAvatarUrl.length > 0
                            source: root.avatarImageSource(root.settingsAvatarUrl)
                            fillMode: PresetAvatars.isPresetUrl(root.settingsAvatarUrl)
                                      ? Image.PreserveAspectFit
                                      : Image.PreserveAspectCrop
                            sourceSize: Qt.size(root.avatarRenderSize, root.avatarRenderSize)
                            smooth: true
                            mipmap: true
                            asynchronous: true; cache: true
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
                    Button {
                        text: qsTr("Choose preset")
                        Layout.fillWidth: true
                        onClicked: presetAvatarPopup.open()
                    }
                    TextField {
                        id: profileDisplayName
                        Layout.fillWidth: true
                        text: root.settingsDisplayName
                        placeholderText: qsTr("Display name")
                        onTextChanged: root.settingsDisplayName = text
                    }

                    // Ô Bio vẫn giữ ScrollView riêng để cuộn mượt trong khung 90px cố định của nó,
                    // độc lập với ScrollView ngoài cùng bọc cả dialog.
                    ScrollView {
                        id: bioScrollView
                        Layout.fillWidth: true
                        Layout.preferredHeight: 90
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }
                        TextArea {
                            id: profileBio
                            width: parent.width
                            wrapMode: TextEdit.Wrap
                            text: root.settingsBio
                            placeholderText: qsTr("Bio")
                            onTextChanged: root.settingsBio = text
                        }
                    }

                    // ── Thêm field mới ở đây trong tương lai ──
                    // Nhờ ScrollView bọc ngoài (settingsScroll), field mới luôn cuộn tới được,
                    // kể cả khi tổng chiều cao nội dung vượt quá height của dialog.
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
