import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Chatties

Dialog {
    id: root

    title: qsTr("Choose preset avatar")
    modal: true
    property int avatarRenderSize: 1024
    anchors.centerIn: parent
    width: 360
    standardButtons: Dialog.Close

    signal avatarConfirmed(string url)

    // ── Selection state ─────────────────────────────────────────────────────
    // Holds the filename of the currently selected preset (e.g. "fox.png").
    // Remains "" if the user has not selected anything.
    property string selectedFile: ""

    // Discard the temporary selection whenever the popup is closed without Apply.
    onClosed: root.selectedFile = ""

    // ── Inline component: AvatarTile ────────────────────────────────────────
    // Renders one preset avatar: circular background + transparent PNG on top.
    // Kept inline because it is used exclusively by this feature.
    // Generic — all preset-specific data comes from PresetAvatars.presets.
    component AvatarTile: Item {
        id: tile

        property color  backgroundColor: "#5865f2"
        property string imageSource:     ""
        property int    size:            72
        property bool   selected:        false  // driven by root.selectedFile

        signal clicked()  // root sets selectedFile on receiving this

        implicitWidth:  size
        implicitHeight: size

        // Selection ring — peeks out ~4 px behind the avatar circle.
        // Relies on Grid rowSpacing / columnSpacing ≥ 8 px to avoid clipping.
        Rectangle {
            anchors.centerIn: parent
            width:  tile.size + 8
            height: tile.size + 8
            radius: width / 2
            color:  "transparent"
            border.color: Theme.accent
            border.width: 2.5
            visible: tile.selected
            z: -1   // behind the avatar circle
        }

        // Circular background
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color:  tile.backgroundColor
        }

        // Transparent PNG rendered on top of the background
        Image {
            anchors.fill:    parent
            anchors.margins: Math.round(tile.size * 0.06)
            source:          tile.imageSource
            fillMode:        Image.PreserveAspectFit
            sourceSize:      Qt.size(root.avatarRenderSize, root.avatarRenderSize)
            smooth:          true
            mipmap:          true
            asynchronous:    true
            cache:           true
        }

        // Checkmark badge — bottom-right corner, visible when selected
        Rectangle {
            visible:         tile.selected
            anchors.right:   parent.right
            anchors.bottom:  parent.bottom
            anchors.margins: -1
            width:  Math.round(tile.size * 0.28)
            height: width
            radius: width / 2
            color:  Theme.accent
            border.color: Theme.background
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text:           "✓"
                color:          "white"
                font.pixelSize: Math.round(parent.width * 0.62)
                font.bold:      true
            }
        }

        // Click handler
        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    tile.clicked()
        }
    }
    // ── End AvatarTile ───────────────────────────────────────────────────────

    contentItem: ColumnLayout {
        spacing: 12

        Label {
            Layout.fillWidth:    true
            Layout.leftMargin:   4
            Layout.rightMargin:  4
            text:                qsTr("Select a preset avatar for your profile.")
            color:               Theme.textMuted
            font.pixelSize:      Theme.fontSmall
            wrapMode:            Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        ScrollView {
            id: galleryScroll
            Layout.fillWidth:       true
            Layout.preferredHeight: 280
            Layout.leftMargin:      4
            Layout.rightMargin:     4
            clip:                   true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width:  3
                contentItem: Rectangle {
                    implicitWidth: 3
                    radius:        1.5
                    color:         Theme.textMuted
                    opacity:       parent.pressed ? 0.8 : 0.4
                }
            }

            contentWidth: availableWidth

            Item {
                width:          galleryScroll.availableWidth
                implicitHeight: galleryGrid.implicitHeight

                Grid {
                    id: galleryGrid
                    width:         parent.width
                    columns:       Math.max(1, Math.floor(width / 84))
                    rowSpacing:    12
                    columnSpacing: 12

                    Repeater {
                        model: PresetAvatars.presets

                        AvatarTile {
                            size:            72
                            backgroundColor: modelData.backgroundColor
                            imageSource:     PresetAvatars.imageUrl(modelData.file)
                            selected:        root.selectedFile === modelData.file
                            onClicked:       root.selectedFile = modelData.file
                        }
                    }
                }

                Label {
                    anchors.centerIn:    parent
                    visible:             PresetAvatars.presets.length === 0
                    text:                qsTr("No preset avatars configured.")
                    color:               Theme.textMuted
                    font.pixelSize:      Theme.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Button {
            Layout.fillWidth:   true
            Layout.leftMargin:  4
            Layout.rightMargin: 4
            text:               qsTr("Apply")
            enabled:            root.selectedFile.length > 0
            highlighted:        true
            onClicked: {
                root.avatarConfirmed(PresetAvatars.imageUrl(root.selectedFile))
                root.close()
            }
        }
    }
}
