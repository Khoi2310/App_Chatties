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

    // [M6] username hiện tại (để tô đậm @mention chính mình).
    property string currentUsername: ""
    // [M6] unread/mention theo channelId: { channelId: {unread, mentions} }
    property var unreadMap: ({})

    // [M6-6B] Chế độ tin nhắn riêng (DM) / bạn bè.
    property bool dmMode: false
    property var  friends: []
    property var  dms: []
    property var  dmOtherUser: ({})

    // [M7] Tìm kiếm & ghim
    property bool searchOpen: false
    property var  searchResultList: []
    property string searchQueryStr: ""
    property bool pinsOpen: false
    property var  pinsList: []
    property var  pinnedIds: ({})     // { messageId: true } của channel hiện tại
    property int  pendingJumpId: 0

    // [Polish] @-autocomplete
    property var  serverMembers: []   // [{user_id, username, display_name, avatar_url}]
    property var  mentionMatches: []  // thành viên khớp với @token đang gõ
    property int  mentionTokenStart: -1  // vị trí ký tự '@' trong ô nhập; -1 = không có
    property int  mentionIndex: 0     // mục đang chọn trong danh sách gợi ý

    // [Forward] Chuyển tiếp tin nhắn
    property int  forwardMsgId: 0     // tin đang được chuyển tiếp
    // Danh sách đích = mọi channel của các server + các DM (tự cập nhật).
    property var  forwardTargetList: {
        var out = []
        for (var i = 0; i < root.servers.length; i++) {
            var s = root.servers[i]
            for (var j = 0; j < s.channels.length; j++)
                out.push({ "channel_id": s.channels[j].id,
                           "label": s.name + "   # " + s.channels[j].name })
        }
        for (var k = 0; k < root.dms.length; k++) {
            var d = root.dms[k]
            out.push({ "channel_id": d.channel_id,
                       "label": "@ " + ((d.display_name && d.display_name.length > 0)
                                        ? d.display_name : d.username) })
        }
        return out
    }

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

    // Đổi server → nạp custom emoji + danh sách thành viên của server đó.
    onCurrentServerIdChanged: {
        root.emojiMap = ({})
        root.customEmojis = []
        root.serverMembers = []
        if (currentServerId !== 0) {
            chatClient.fetchCustomEmojis(currentServerId)
            chatClient.requestMembers(currentServerId)   // [Polish] cho @-autocomplete
        }
    }

    function selectChannel(id) {
        currentChannelId = id
        chatClient.selectChannel(id)
        root.clearUnreadLocal(id)   // [M6] xóa badge ngay
    }

    // [M6] Xóa unread/mention của 1 channel khỏi bản đồ (reassign để cập nhật UI).
    function clearUnreadLocal(id) {
        if (root.unreadMap[id] !== undefined) {
            var m = Object.assign({}, root.unreadMap)
            delete m[id]
            root.unreadMap = m
        }
    }

    // [M7] Nhảy tới 1 tin nhắn (từ kết quả tìm kiếm / ghim).
    function jumpToMessage(channelId, messageId) {
        root.searchOpen = false
        root.pinsOpen = false
        if (channelId !== root.currentChannelId) {
            root.pendingJumpId = messageId       // cuộn sau khi history nạp xong
            root.selectChannel(channelId)
        } else {
            root.scrollToMessage(messageId)
        }
    }
    function scrollToMessage(messageId) {
        var idx = messageModel.indexOfMessage(messageId)
        if (idx >= 0)
            list.positionViewAtIndex(idx, ListView.Center)
    }

    // [Polish] Phát hiện @token tại con trỏ, lọc thành viên khớp.
    function updateMention() {
        var pos = input.cursorPosition
        var t = input.text
        var i = pos - 1
        while (i >= 0 && /[A-Za-z0-9_]/.test(t.charAt(i))) i--
        if (i >= 0 && t.charAt(i) === "@"
            && (i === 0 || /\s/.test(t.charAt(i - 1)))) {
            var q = t.substring(i + 1, pos).toLowerCase()
            var out = []
            for (var k = 0; k < root.serverMembers.length; k++) {
                var m = root.serverMembers[k]
                var un = (m.username || "").toLowerCase()
                var dn = (m.display_name || "").toLowerCase()
                if (un.indexOf(q) === 0 || dn.indexOf(q) === 0) out.push(m)
                if (out.length >= 8) break
            }
            root.mentionTokenStart = i
            root.mentionMatches = out
            root.mentionIndex = 0
            return
        }
        root.mentionTokenStart = -1
        root.mentionMatches = []
    }
    // [Polish] Chèn @username hoàn chỉnh, thay phần đang gõ.
    function applyMention(username) {
        if (root.mentionTokenStart < 0) return
        var pos = input.cursorPosition
        var before = input.text.substring(0, root.mentionTokenStart)
        var after = input.text.substring(pos)
        var ins = "@" + username + " "
        input.text = before + ins + after
        input.cursorPosition = (before + ins).length
        root.mentionTokenStart = -1
        root.mentionMatches = []
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
        root.dmMode = false          // [M6-6B] rời chế độ DM khi chọn server
        currentServerIndex = idx
        currentChannelId = 0
        if (servers[idx].channels.length > 0)
            selectChannel(servers[idx].channels[0].id)
    }

    // [M6-6B] Vào chế độ DM: nạp danh sách bạn bè + DM.
    function enterDmMode() {
        root.dmMode = true
        currentChannelId = 0
        chatClient.requestFriends()
        chatClient.requestDmList()
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

                // [M6-6B] Nút Direct Messages (Home)
                Item {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignHCenter
                    width: 56; height: 56
                    Rectangle {
                        anchors.centerIn: parent
                        width: 48; height: 48; radius: 24
                        color: root.dmMode ? Theme.accent : Theme.inputBg
                        Label { anchors.centerIn: parent; text: "💬"; font.pixelSize: 22 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.enterDmMode()
                        }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 2
                    Layout.alignment: Qt.AlignHCenter
                    color: Theme.inputBg
                    radius: 1
                }

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
                    visible: !root.dmMode
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
                    visible: !root.dmMode
                    model: root.currentChannels
                    spacing: 2
                    delegate: Rectangle {
                        id: chRow
                        width: ListView.view ? ListView.view.width : 0
                        height: 30
                        radius: Theme.radius
                        color: modelData.id === root.currentChannelId ? Theme.accent : "transparent"
                        property var unread: root.unreadMap[modelData.id]
                        property bool showBadge: unread !== undefined
                                                 && modelData.id !== root.currentChannelId
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: chBadge.left
                            anchors.rightMargin: 4
                            elide: Text.ElideRight
                            text: "# " + modelData.name
                            color: Theme.textPrimary
                            font.bold: chRow.showBadge
                        }
                        Rectangle {
                            id: chBadge
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            property bool hasMention: chRow.unread !== undefined && chRow.unread.mentions > 0
                            visible: chRow.showBadge
                            width: hasMention ? Math.max(16, chBadgeLabel.implicitWidth + 8) : 8
                            height: hasMention ? 16 : 8
                            radius: height / 2
                            color: hasMention ? Theme.danger : Theme.textMuted
                            Label {
                                id: chBadgeLabel
                                anchors.centerIn: parent
                                visible: chBadge.hasMention
                                text: chRow.unread ? chRow.unread.mentions : ""
                                color: "white"
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectChannel(modelData.id)
                        }
                    }
                }

                // [M6-6B] Bảng Direct Messages (hiện khi dmMode)
                ColumnLayout {
                    visible: root.dmMode
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 6

                    Label {
                        text: qsTr("Direct Messages")
                        color: Theme.textPrimary
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        TextField {
                            id: addFriendField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Add friend by username")
                            color: Theme.textPrimary
                            background: Rectangle { color: Theme.inputBg; radius: 4 }
                            onAccepted: {
                                var u = text.trim()
                                if (u.length > 0) { chatClient.sendFriendRequest(u); text = "" }
                            }
                        }
                        Button {
                            text: "+"
                            onClicked: {
                                var u = addFriendField.text.trim()
                                if (u.length > 0) { chatClient.sendFriendRequest(u); addFriendField.text = "" }
                            }
                        }
                    }

                    Label {
                        text: qsTr("Friends")
                        color: Theme.textMuted
                        font.pixelSize: 11
                        visible: root.friends.length > 0
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, 180)
                        clip: true
                        model: root.friends
                        spacing: 2
                        delegate: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 34
                            radius: Theme.radius
                            color: friendArea.containsMouse ? Theme.inputBg : "transparent"
                            MouseArea {
                                id: friendArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.status === "accepted")
                                        chatClient.openDm(modelData.user_id)
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 4
                                Label {
                                    Layout.fillWidth: true
                                    text: (modelData.display_name && modelData.display_name.length > 0
                                           ? modelData.display_name : modelData.username)
                                          + (modelData.status === "pending"
                                             ? (modelData.incoming ? "  • wants to add you" : "  • pending")
                                             : "")
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }
                                Button {
                                    text: qsTr("Accept")
                                    visible: modelData.incoming === true
                                    onClicked: chatClient.acceptFriend(modelData.user_id)
                                }
                                Label {
                                    text: "✕"
                                    color: Theme.textMuted
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: chatClient.removeFriend(modelData.user_id)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.inputBg }

                    Label {
                        text: qsTr("Conversations")
                        color: Theme.textMuted
                        font.pixelSize: 11
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.dms
                        spacing: 2
                        delegate: Rectangle {
                            id: dmRow
                            width: ListView.view ? ListView.view.width : 0
                            height: 34
                            radius: Theme.radius
                            property var unread: root.unreadMap[modelData.channel_id]
                            property bool active: modelData.channel_id === root.currentChannelId
                            color: active ? Theme.accent
                                          : (dmArea.containsMouse ? Theme.inputBg : "transparent")
                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: dmBadge.left
                                anchors.rightMargin: 4
                                elide: Text.ElideRight
                                text: "@ " + (modelData.display_name && modelData.display_name.length > 0
                                              ? modelData.display_name : modelData.username)
                                color: Theme.textPrimary
                                font.bold: dmRow.unread !== undefined && !dmRow.active
                            }
                            Rectangle {
                                id: dmBadge
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                width: 8; height: 8; radius: 4
                                color: Theme.danger
                                visible: dmRow.unread !== undefined && !dmRow.active
                            }
                            MouseArea {
                                id: dmArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.dmOtherUser = modelData
                                    root.selectChannel(modelData.channel_id)
                                }
                            }
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

            // [M7] Thanh tìm kiếm + nút ghim
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.currentChannelId !== 0
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search messages…")
                    color: Theme.textPrimary
                    background: Rectangle { color: Theme.inputBg; radius: 6 }
                    onTextChanged: searchTimer.restart()
                    onAccepted: {
                        if (text.trim().length >= 2) {
                            root.searchOpen = true
                            chatClient.searchMessages(text.trim(), "all", 0, 0)
                        }
                    }
                }
                Timer {
                    id: searchTimer
                    interval: 350
                    onTriggered: {
                        if (searchField.text.trim().length >= 2) {
                            root.searchOpen = true
                            chatClient.searchMessages(searchField.text.trim(), "all", 0, 0)
                        } else {
                            root.searchOpen = false
                        }
                    }
                }
                Label {
                    text: "📌"
                    font.pixelSize: 18
                    opacity: root.pinsOpen ? 1.0 : 0.7
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.searchOpen = false
                            root.pinsOpen = !root.pinsOpen
                            if (root.pinsOpen) chatClient.requestPins(root.currentChannelId)
                        }
                    }
                }
            }

            // [M7] Popup kết quả tìm kiếm (phủ lên danh sách tin)
            Popup {
                id: searchPopup
                parent: list
                visible: root.searchOpen
                width: list.width
                height: list.height
                x: 0; y: 0
                padding: 8
                modal: false
                closePolicy: Popup.NoAutoClose
                background: Rectangle {
                    color: Theme.surface; radius: Theme.radius; border.color: Theme.inputBg
                }
                contentItem: ColumnLayout {
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: root.searchResultList.length + qsTr(" result(s) for “") + root.searchQueryStr + "”"
                            color: Theme.textMuted; font.pixelSize: 12; elide: Text.ElideRight
                        }
                        Label {
                            text: "✕"; color: Theme.textMuted
                            MouseArea { anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor; onClicked: root.searchOpen = false }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        model: root.searchResultList
                        spacing: 4
                        delegate: Rectangle {
                            width: ListView.view ? ListView.view.width : 0
                            height: 46; radius: 6
                            color: resArea.containsMouse ? Theme.inputBg : "transparent"
                            Column {
                                anchors.fill: parent; anchors.margins: 6; spacing: 2
                                Row {
                                    spacing: 6
                                    Label { text: modelData.author_name; color: Theme.textPrimary; font.bold: true; font.pixelSize: 12 }
                                    Label { text: "# " + modelData.channel_name; color: Theme.textMuted; font.pixelSize: 11 }
                                }
                                Label {
                                    text: modelData.content
                                    color: Theme.textMuted; font.pixelSize: 12
                                    width: parent.width; elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: resArea; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.jumpToMessage(modelData.channel_id, modelData.id)
                            }
                        }
                    }
                }
            }

            // [M7] Popup danh sách tin ghim
            Popup {
                id: pinsPopup
                parent: list
                visible: root.pinsOpen
                width: list.width
                height: list.height
                x: 0; y: 0
                padding: 8
                modal: false
                closePolicy: Popup.NoAutoClose
                background: Rectangle {
                    color: Theme.surface; radius: Theme.radius; border.color: Theme.inputBg
                }
                contentItem: ColumnLayout {
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: qsTr("Pinned messages"); color: Theme.textPrimary; font.bold: true }
                        Label { text: "✕"; color: Theme.textMuted
                            MouseArea { anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor; onClicked: root.pinsOpen = false } }
                    }
                    Label {
                        visible: root.pinsList.length === 0
                        text: qsTr("No pinned messages yet.")
                        color: Theme.textMuted; font.pixelSize: 12
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        model: root.pinsList
                        spacing: 4
                        delegate: Rectangle {
                            id: pinRow
                            width: ListView.view ? ListView.view.width : 0
                            height: 52; radius: 6
                            color: pinItemArea.containsMouse ? Theme.inputBg : "transparent"
                            // Đính kèm đầu tiên (nếu có) để hiện thumbnail.
                            property var att0: (modelData.attachments && modelData.attachments.length > 0)
                                               ? modelData.attachments[0] : null
                            property bool isImg: pinRow.att0 !== null
                                                 && (pinRow.att0.kind === "image" || pinRow.att0.kind === "gif")

                            // Thumbnail ảnh/gif (AnimatedImage render được cả gif).
                            Rectangle {
                                id: pinThumbBox
                                visible: pinRow.isImg
                                anchors.left: parent.left; anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: visible ? 40 : 0
                                height: 40; radius: 4; clip: true
                                color: Theme.background
                                AnimatedImage {
                                    anchors.fill: parent
                                    source: pinRow.isImg ? pinRow.att0.url : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true
                                }
                            }
                            Column {
                                anchors.left: pinThumbBox.right
                                anchors.leftMargin: pinRow.isImg ? 8 : 6
                                anchors.right: unpinBtn.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Label { text: modelData.username; color: Theme.textPrimary; font.bold: true; font.pixelSize: 12 }
                                Label { text: modelData.content; color: Theme.textMuted; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                            }
                            Label {
                                id: unpinBtn
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "✕"; color: Theme.textMuted
                                MouseArea { anchors.fill: parent; anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: chatClient.unpinMessage(root.currentChannelId, modelData.id) }
                            }
                            MouseArea {
                                id: pinItemArea
                                anchors.left: parent.left; anchors.right: unpinBtn.left
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.jumpToMessage(modelData.channel_id, modelData.id)
                            }
                        }
                    }
                }
            }

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
                            // [Forward] Nhãn "Forwarded from X"
                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                visible: (model.forwardedFrom || "").length > 0 && !model.deleted
                                text: "↪ " + qsTr("Forwarded from ") + (model.forwardedFrom || "")
                                color: Theme.textMuted
                                font.pixelSize: 11
                                font.italic: true
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
                                // [M7] Pin / Unpin
                                Rectangle {
                                    width: parent.width; height: 34; radius: 4
                                    color: pinArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: root.pinnedIds[msgItem.mId] ? qsTr("Unpin") : qsTr("Pin")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "📌"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: pinArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            actionMenu.close()
                                            if (root.pinnedIds[msgItem.mId])
                                                chatClient.unpinMessage(root.currentChannelId, msgItem.mId)
                                            else
                                                chatClient.pinMessage(root.currentChannelId, msgItem.mId)
                                        }
                                    }
                                }
                                // [Forward] Forward
                                Rectangle {
                                    width: parent.width; height: 34; radius: 4
                                    color: fwdArea.containsMouse ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10; anchors.rightMargin: 10
                                        Label {
                                            text: qsTr("Forward")
                                            color: Theme.textPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 24
                                        }
                                        Label {
                                            text: "↪"; font.pixelSize: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    MouseArea {
                                        id: fwdArea
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            actionMenu.close()
                                            root.forwardMsgId = msgItem.mId
                                            chatClient.requestDmList()   // đảm bảo có DM trong đích
                                            forwardDialog.open()
                                        }
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
                            onTextChanged: root.updateMention()
                            onCursorPositionChanged: root.updateMention()
                            // [Polish] Điều hướng danh sách @mention bằng phím.
                            Keys.onPressed: (event) => {
                                if (root.mentionTokenStart >= 0 && root.mentionMatches.length > 0) {
                                    if (event.key === Qt.Key_Tab
                                        || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.applyMention(root.mentionMatches[root.mentionIndex].username)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.mentionIndex = Math.min(root.mentionIndex + 1, root.mentionMatches.length - 1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.mentionIndex = Math.max(root.mentionIndex - 1, 0)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Escape) {
                                        root.mentionTokenStart = -1
                                        root.mentionMatches = []
                                        event.accepted = true
                                    }
                                }
                            }

                            // [Polish] Popup gợi ý @mention (phía trên ô nhập).
                            Popup {
                                id: mentionPopup
                                parent: input
                                visible: root.mentionTokenStart >= 0 && root.mentionMatches.length > 0
                                width: 240
                                height: Math.min(root.mentionMatches.length * 34 + 8, 220)
                                x: 0
                                y: -height - 4
                                padding: 4
                                closePolicy: Popup.NoAutoClose
                                background: Rectangle {
                                    color: Theme.surface; radius: Theme.radius; border.color: Theme.inputBg
                                }
                                contentItem: ListView {
                                    clip: true
                                    model: root.mentionMatches
                                    currentIndex: root.mentionIndex
                                    delegate: Rectangle {
                                        width: ListView.view ? ListView.view.width : 0
                                        height: 34; radius: 4
                                        color: (index === root.mentionIndex || mArea.containsMouse)
                                               ? Theme.inputBg : "transparent"
                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            spacing: 6
                                            Label {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: (modelData.display_name && modelData.display_name.length > 0
                                                       ? modelData.display_name : modelData.username)
                                                color: Theme.textPrimary; font.pixelSize: 13
                                            }
                                            Label {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "@" + modelData.username
                                                color: Theme.textMuted; font.pixelSize: 11
                                            }
                                        }
                                        MouseArea {
                                            id: mArea
                                            anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.applyMention(modelData.username)
                                        }
                                    }
                                }
                            }
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
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    // Trái: chèn :shortcode: — Phải: menu đổi tên/xóa.
                                                    onClicked: (mouse) => {
                                                        if (mouse.button === Qt.RightButton) {
                                                            emojiCtxMenu.popup()
                                                        } else {
                                                            input.insert(input.cursorPosition, ":" + modelData.shortcode + ":")
                                                            input.forceActiveFocus()
                                                        }
                                                    }
                                                }
                                                Menu {
                                                    id: emojiCtxMenu
                                                    MenuItem {
                                                        text: qsTr("Rename")
                                                        onTriggered: {
                                                            renameEmojiDialog.oldShortcode = modelData.shortcode
                                                            renameEmojiField.text = modelData.shortcode
                                                            emojiPopup.close()
                                                            renameEmojiDialog.open()
                                                        }
                                                    }
                                                    MenuItem {
                                                        text: qsTr("Delete")
                                                        onTriggered: {
                                                            if (root.currentServerId !== 0)
                                                                chatClient.deleteCustomEmoji(root.currentServerId, modelData.shortcode)
                                                        }
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

    // [M6-6B] Dialog đổi tên custom emoji (theo server hiện tại)
    Dialog {
        id: renameEmojiDialog
        title: qsTr("Rename custom emoji")
        anchors.centerIn: parent
        modal: true
        width: 320
        padding: 16
        standardButtons: Dialog.Cancel | Dialog.Ok
        property string oldShortcode: ""
        onAccepted: {
            var sc = renameEmojiField.text.trim()
            if (sc.length > 0 && sc !== renameEmojiDialog.oldShortcode && root.currentServerId !== 0)
                chatClient.renameCustomEmoji(root.currentServerId, renameEmojiDialog.oldShortcode, sc)
            renameEmojiField.text = ""
            renameEmojiDialog.oldShortcode = ""
        }
        contentItem: ColumnLayout {
            spacing: 8
            TextField {
                id: renameEmojiField
                Layout.fillWidth: true
                placeholderText: qsTr("new shortcode (e.g. kek)")
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
        var html = root.escapeHtml(s).replace(/:([A-Za-z0-9_]+):/g, function(match, code) {
            var url = root.emojiMap[code]
            return url
                ? "<img src='" + url + "' width='20' height='20'>"
                : match
        })
        // [M6] @mention: @chính-mình / @everyone tô đậm màu nhấn.
        html = html.replace(/@([A-Za-z0-9_]+)/g, function(match, name) {
            var me = root.currentUsername
                     && name.toLowerCase() === root.currentUsername.toLowerCase()
            var all = (name === "everyone" || name === "here")
            var color  = (me || all) ? "#5865f2" : "#8a8fd6"
            var weight = (me || all) ? "bold" : "normal"
            return "<span style='color:" + color + "; font-weight:" + weight
                 + ";'>@" + name + "</span>"
        })
        return html
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
            root.currentUsername = username || ""
            root.currentUserDisplayName = displayName || username || ""
            root.currentUserAvatar = avatarUrl || ""
            root.currentUserBio = bio || ""
            root.settingsDisplayName = root.currentUserDisplayName
            root.settingsAvatarUrl = root.currentUserAvatar
            root.settingsBio = root.currentUserBio
        }
        // [M6] Trạng thái unread ban đầu (lúc login).
        function onUnreadState(channels) {
            var mm = ({})
            for (var i = 0; i < channels.length; ++i) {
                var c = channels[i]
                if (c.unread > 0 || c.mentions > 0)
                    mm[c.channel_id] = { unread: c.unread, mentions: c.mentions }
            }
            root.unreadMap = mm
        }
        // [M6] Có tin mới ở channel không xem → +1 unread.
        function onChannelActivity(channelId) {
            if (channelId === root.currentChannelId) return
            var mm = Object.assign({}, root.unreadMap)
            var e = mm[channelId] || { unread: 0, mentions: 0 }
            mm[channelId] = { unread: e.unread + 1, mentions: e.mentions }
            root.unreadMap = mm
        }
        // [M6] Bị nhắc ở channel không xem → +1 mention.
        function onMentionPinged(channelId, serverId, messageId, authorName) {
            var mm = Object.assign({}, root.unreadMap)
            var e = mm[channelId] || { unread: 0, mentions: 0 }
            mm[channelId] = { unread: e.unread, mentions: e.mentions + 1 }
            root.unreadMap = mm
        }
        // [M6] Nạp lịch sử channel đang xem → đánh dấu đã đọc tới tin cuối.
        function onChannelHistory(channelId, messages) {
            if (channelId === root.currentChannelId && messages.length > 0)
                chatClient.markChannelRead(channelId, messages[messages.length - 1].id)
            root.clearUnreadLocal(channelId)
            if (channelId === root.currentChannelId) {
                chatClient.requestPins(channelId)   // [M7] nạp trạng thái ghim
                if (root.pendingJumpId !== 0) {
                    var jid = root.pendingJumpId
                    root.pendingJumpId = 0
                    Qt.callLater(function() { root.scrollToMessage(jid) })
                }
            }
        }
        // [M6] Tin mới ở channel đang xem → đánh dấu đã đọc luôn.
        function onMessageReceived(message) {
            if (message.channel_id === root.currentChannelId)
                chatClient.markChannelRead(root.currentChannelId, message.id)
        }
        // [M6-6B] Bạn bè & DM
        function onFriendsReceived(friends) { root.friends = friends }
        function onDmListReceived(dms) { root.dms = dms }
        function onDmOpened(channelId, otherUser) {
            root.dmMode = true
            root.dmOtherUser = otherUser
            root.selectChannel(channelId)
        }
        // [M7] Tìm kiếm & ghim
        function onSearchResults(query, results, hasMore) {
            root.searchQueryStr = query
            root.searchResultList = results
        }
        function onPinsReceived(channelId, pins) {
            if (channelId !== root.currentChannelId) return
            root.pinsList = pins
            var ids = ({})
            for (var i = 0; i < pins.length; ++i)
                ids[pins[i].id] = true
            root.pinnedIds = ids
        }
        function onPinsChanged(channelId) {
            if (channelId === root.currentChannelId)
                chatClient.requestPins(channelId)
        }
        function onMembersReceived(serverId, members) {
            if (serverId === root.currentServerId)
                root.serverMembers = members
        }
        function onCustomEmojisReceived(emojis) {
            root.customEmojis = emojis
            var m = ({})
            var dict = ({})
            for (var i = 0; i < emojis.length; ++i) {
                m[emojis[i].shortcode] = emojis[i].url
                dict[emojis[i].shortcode] = emojis[i].url
            }
            root.emojiMap = m
            // [Fix] Cũng nạp customEmojiDictionary để react bằng emoji tùy chỉnh + render chip.
            root.customEmojiDictionary = dict
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
                    // [Auth] Username (chỉ đọc) dưới avatar.
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.currentUsername.length > 0
                        text: "@" + root.currentUsername
                        color: Theme.textMuted
                        font.pixelSize: 12
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

                    // [Auth] Nút đăng xuất.
                    Button {
                        text: qsTr("Log out")
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        background: Rectangle { color: Theme.danger; radius: 6 }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            settingsDialog.close()
                            chatClient.logout()
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

    // [Forward] Dialog chọn đích chuyển tiếp
    Dialog {
        id: forwardDialog
        title: qsTr("Forward to…")
        anchors.centerIn: parent
        modal: true
        width: 360
        height: 420
        standardButtons: Dialog.Cancel
        contentItem: ColumnLayout {
            spacing: 8
            Label {
                text: qsTr("Choose a channel or DM")
                color: Theme.textMuted
                font.pixelSize: 12
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.forwardTargetList
                spacing: 2
                delegate: Rectangle {
                    width: ListView.view ? ListView.view.width : 0
                    height: 36
                    radius: 6
                    color: fwdRowArea.containsMouse ? Theme.inputBg : "transparent"
                    Label {
                        anchors.left: parent.left; anchors.leftMargin: 10
                        anchors.right: parent.right; anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: fwdRowArea
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.forwardMsgId !== 0)
                                chatClient.forwardMessage(root.forwardMsgId, modelData.channel_id)
                            root.forwardMsgId = 0
                            forwardDialog.close()
                        }
                    }
                }
            }
        }
    }
}
