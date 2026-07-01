import QtQuick 
import QtQuick.Controls 
import QtQuick.Layouts 
import QtQuick.Dialogs
import QtQml

Item {
    id: rootPicker
    
    // Mảng nhận danh sách emoji mặc định từ bên ngoài truyền vào
    property var defaultEmojis: []
    
    // Tín hiệu phát ra khi user bấm chọn (trả về 😀 hoặc :doge:)
    signal emojiSelected(string emojiText)

    ListModel { 
        id: customEmojiModel 
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // THANH ĐIỀU HƯỚNG 2 TAB
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            background: Rectangle { color: Theme.surface }
            
            TabButton {
                text: "Mặc định"
                width: implicitWidth
                contentItem: Text {
                    text: parent.text
                    color: parent.checked ? Theme.accent : Theme.textMuted
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { color: "transparent" }
            }
            TabButton {
                text: "Tùy chỉnh"
                width: implicitWidth
                contentItem: Text {
                    text: parent.text
                    color: parent.checked ? Theme.accent : Theme.textMuted
                    font.bold: parent.checked
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { color: "transparent" }
            }
        }

        // KHUNG HIỂN THỊ CHUYỂN ĐỔI THEO TAB
        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8

            // Tab 1: Emoji Mặc định
            GridView {
                id: defaultGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 40
                cellHeight: 40
                leftMargin: Math.floor((width - (Math.floor(width / cellWidth) * cellWidth)) / 2)
                bottomMargin: 8
                model: rootPicker.defaultEmojis
                
                delegate: Item {
                    width: defaultGrid.cellWidth
                    height: defaultGrid.cellHeight
                    
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 22 
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: Theme.textPrimary
                            opacity: parent.containsMouse ? 0.1 : 0.0
                            radius: 6
                        }

                        onClicked: rootPicker.emojiSelected(modelData)
                    }
                }        
            }

            // Tab 2: Emoji Tùy chỉnh
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
            
                // Nút Thêm Emoji nổi bật ở trên cùng
                Button {
                    Layout.fillWidth: true
                    Layout.margins: 8
                    text: "✨ Thêm Emoji Tùy Chỉnh"

                    background: Rectangle { 
                        color: Theme.serverBar
                        radius: 6 
                        border.color: Theme.inputBg 
                    }

                    contentItem: Text { 
                        text: parent.text
                        color: Theme.accent
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter 
                    }
                    
                    onClicked: fileDialog.open()
                }

                // Lưới hiển thị Custom Emoji
                GridView {
                    id: customGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth: 44
                    cellHeight: 44
                    model: customEmojiModel

                    delegate: Item {
                        width: customGrid.cellWidth
                        height: customGrid.cellHeight
                        
                        Image {
                            anchors.centerIn: parent
                            width: 28
                            height: 28
                            source: model.url // Lấy đường link từ API trả về
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            
                            // Hiệu ứng hover giống Discord
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.textPrimary
                                opacity: parent.containsMouse ? 0.1 : 0.0
                                radius: 4
                            }
                            
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    // Mở menu khi click chuột phải
                                    emojiContextMenu.popup()
                                } else {
                                    // Gửi emoji khi click chuột trái
                                    rootPicker.emojiSelected(":" + model.shortcode + ":")
                                }
                            }                          
                        }

                        Menu {
                            id: emojiContextMenu
                            MenuItem {
                                text: "Đổi tên"
                                onTriggered: {
                                    renamePopup.oldShortcode = model.shortcode
                                    renameInput.text = model.shortcode
                                    renamePopup.open()
                                }
                            }
                            MenuItem {
                                text: "Xóa"
                                contentItem: Text { text: parent.text; color: "#ed4245" }
                                onTriggered: {
                                    chatClient.deleteCustomEmoji(model.shortcode)
                                }
                            }
                        }
                    }
                }
            }    
        }
    }

    // Tự động kéo API danh sách Emoji từ C++ Server
    Component.onCompleted: {
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                for (var i = 0; i < data.length; i++) {
                    customEmojiModel.append(data[i]);
                    root.customEmojiDictionary[data[i].shortcode] = data[i].url;
                }
            }
        }
        xhr.open("GET", "http://localhost:8081/emojis");
        xhr.send();
    }

    // 1. Hộp thoại chọn file từ máy tính
    FileDialog {
        id: fileDialog
        title: "Chọn ảnh Emoji"
        nameFilters: ["Transparent Images (*.png *.gif)"]
        onAccepted: {
            // Lấy dung lượng từ C++ (Tính bằng Byte)
            var fileSizeInBytes = chatClient.getLocalFileSize(fileDialog.selectedFile)
            if (fileSizeInBytes > 1048576) {
                errorToast.showError("Kích thước ảnh quá lớn! Vui lòng chọn ảnh dưới 1MB.")
            } else {
            nameInputPopup.fileUrl = fileDialog.selectedFile
            nameInputPopup.open()
        }
    }

    Popup {
        id: errorToast
        width: 300
        height: 40
        // Căn giữa bảng EmojiPicker, nổi lơ lửng ở phía trên
        x: (parent.width - width) / 2
        y: 10
        modal: false
        
        background: Rectangle {
            color: "#ed4245" // Mã màu đỏ báo lỗi chuẩn của Discord
            radius: 8
            border.color: "#da373c"
        }

        property string errorMsg: ""
        
        // Hàm kích hoạt thông báo
        function showError(msg) {
            errorMsg = msg
            open()
            closeTimer.start() // Bắt đầu đếm ngược để tự tắt
        }

        Text {
            anchors.centerIn: parent
            text: errorToast.errorMsg
            color: "#ffffff"
            font.bold: true
            font.pixelSize: 13
        }

        // Đồng hồ đếm ngược 3 giây tự động ẩn thông báo
        Timer {
            id: closeTimer
            interval: 3000 // 3000ms = 3 giây
            onTriggered: errorToast.close()
        }
    }

    // 2. Bảng nhập tên (Shortcode) cho Emoji vừa chọn
    Popup {
        id: nameInputPopup
        width: 300
        height: 180
        modal: true
        anchors.centerIn: parent
        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.inputBg
        }
        
        property url fileUrl

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Label { 
                text: "Nhập mã Emoji:"
                color: Theme.textPrimary
                font.pixelSize: 14
            }
            
            TextField {
                id: shortcodeInput
                Layout.fillWidth: true
                color: Theme.textPrimary
                background: Rectangle { color: Theme.inputBg; radius: 4 }
                
                // Quy tắc của Server C++: Chỉ cho phép chữ cái, số và dấu gạch dưới
                validator: RegularExpressionValidator { regularExpression: /^[a-zA-Z0-9_]{1,32}$/ }
            }
            
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 12
                
                Button {
                    text: "Hủy"
                    font.pixelSize: 13
                    background: Rectangle { 
                        color: "transparent"
                        border.color: Theme.textMuted 
                        radius: 4 
                    }
                    contentItem: Text { 
                        text: parent.text; color: Theme.textPrimary; 
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter;
                        font.pixelSize: 13
                    }
                    onClicked: {
                        nameInputPopup.close()
                        shortcodeInput.text = ""
                    }
                }
                Button {
                    text: "Tải lên"
                    font.pixelSize: 13
                    background: Rectangle { color: Theme.accent; radius: 4 }
                    contentItem: Text { 
                        text: parent.text; color: "#ffffff"; 
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter;
                        font.pixelSize: 13
                        font.bold: true  
                    }
                    
                    onClicked: {
                        if (shortcodeInput.text.length > 0) {
                            // GIAO VIỆC CHO C++ XỬ LÝ NHỊ PHÂN
                            chatClient.uploadCustomEmoji(nameInputPopup.fileUrl, shortcodeInput.text)
                            
                            nameInputPopup.close()
                            shortcodeInput.text = ""
                        }
                    }
                }
            }
        }        
    }

    // Bảng nhập tên mới
    Popup {
        id: renamePopup
        width: 300
        height: 180
        modal: true
        anchors.centerIn: parent
        background: Rectangle { color: Theme.surface; radius: Theme.radius; border.color: Theme.inputBg }
        
        property string oldShortcode: ""

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Label { text: "Nhập mã Emoji mới:"; color: Theme.textPrimary; font.pixelSize: 14 }
            TextField {
                id: renameInput
                Layout.fillWidth: true
                color: Theme.textPrimary
                background: Rectangle { color: Theme.inputBg; radius: 4 }
                validator: RegularExpressionValidator { regularExpression: /^[a-zA-Z0-9_]{1,32}$/ }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 12
                Button {
                    text: "Hủy"; font.pixelSize: 13
                    background: Rectangle { color: "transparent"; border.color: Theme.textMuted; radius: 4 }
                    contentItem: Text { text: parent.text; color: Theme.textPrimary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                    onClicked: renamePopup.close()
                }
                Button {
                    text: "Lưu"; font.pixelSize: 13
                    background: Rectangle { color: Theme.accent; radius: 4 }
                    contentItem: Text { text: parent.text; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13; font.bold: true }
                    onClicked: {
                        if (renameInput.text.length > 0 && renameInput.text !== renamePopup.oldShortcode) {
                            chatClient.renameCustomEmoji(renamePopup.oldShortcode, renameInput.text)
                            renamePopup.close()
                        }
                    }
                }
            }
        }
    }

    // 3. Lắng nghe báo cáo từ C++ (Chỉ cập nhật UI khi Server đã xác nhận)
        Connections {
            target: chatClient
            function onCustomEmojiUploaded(shortcode, url) {
                var realUrl = String(url)
                customEmojiModel.append({ "shortcode": shortcode, "url": realUrl })
                    
                // Cập nhật từ điển ngay lập tức
                root.customEmojiDictionary[shortcode] = realUrl;
            }
            function onCustomEmojiDeleted(shortcode) {
                for (var i = 0; i < customEmojiModel.count; i++) {
                    if (customEmojiModel.get(i).shortcode === shortcode) {
                        customEmojiModel.remove(i)
                        break
                    }
                }
            }
            function onCustomEmojiRenamed(oldShortcode, newShortcode) {
                for (var i = 0; i < customEmojiModel.count; i++) {
                    if (customEmojiModel.get(i).shortcode === oldShortcode) {
                        customEmojiModel.setProperty(i, "shortcode", newShortcode)
                        break
                    }
                }
            }
        }
    }       
}
