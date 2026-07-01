import QtQuick 
import QtQuick.Controls 
import QtQuick.Layouts 

Item {
    id: root
    
    // Tín hiệu phát ra khi người dùng click chọn 1 file GIF
    signal gifSelected(string url)

    ListModel {
        id: gifModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.pad // Tận dụng luôn Theme.pad (12) thay vì số 10
        spacing: Theme.spacing

        // 1. Thanh tìm kiếm (Đồng bộ thiết kế 100%)
        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: 38 // Giới hạn chiều cao cho gọn gàng
            placeholderText: "Tìm kiếm GIF..."
            
            color: Theme.textPrimary
            placeholderTextColor: Theme.textMuted
            font.pixelSize: Theme.fontNormal // Sử dụng font từ Theme

            padding: 10
            verticalAlignment: TextInput.AlignVCenter
            leftPadding: Theme.pad
            rightPadding: Theme.pad
            
            background: Rectangle {
                color: Theme.inputBg
                radius: Theme.radius
                // Sử dụng Theme.accent thay cho mã HEX hardcode
                border.color: searchField.activeFocus ? Theme.accent : "transparent" 
            }
            
            onAccepted: {
                fetchGifs(searchField.text)
            }
        }

        BusyIndicator {
            id: loadingIndicator
            Layout.alignment: Qt.AlignHCenter
            running: false
            visible: running
        }

        // 2. Khung lưới hiển thị ảnh GIF
        GridView {
            id: gridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            cellWidth: gridView.width / 3
            cellHeight: 100
            
            model: gifModel

            delegate: Item {
                width: gridView.cellWidth
                height: gridView.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: Theme.inputBg // Dùng màu nền khung nhập liệu cho ô chứa GIF
                    radius: Theme.radius
                    clip: true

                    AnimatedImage {
                        id: gifImage
                        source: modelData
                        anchors.fill: parent
                        fillMode: AnimatedImage.PreserveAspectCrop
                        asynchronous: true
                        cache: false 
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.gifSelected(modelData)
                        }
                        
                        // Lớp phủ sáng lên khi di chuột vào ảnh
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.textPrimary
                            opacity: parent.containsMouse ? 0.1 : 0.0
                        }
                    }
                }
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
        }
    }

    // 3. Hàm gọi API tới trạm trung chuyển C++ (Cổng 8081)
    function fetchGifs(keyword) {
        gifModel.clear()
        loadingIndicator.running = true
        
        var xhr = new XMLHttpRequest();
        var url = "http://localhost:8081/gif.search?q=" + encodeURIComponent(keyword);
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                loadingIndicator.running = false
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    for (var i = 0; i < response.length; i++) {
                        gifModel.append({"modelData": response[i]});
                    }
                } else {
                    console.log("[GIF Picker] Lỗi kết nối Proxy: ", xhr.status)
                }
            }
        }
        
        xhr.open("GET", url);
        xhr.send();
    }

    // Tự động load GIF trending khi mở Popup
    Component.onCompleted: {
        fetchGifs("")
    }
}