pragma Singleton
import QtQuick

QtObject {
    // ── Màu (phong cách tối kiểu Discord) ──
    readonly property color background:  "#313338"
    readonly property color surface:     "#2b2d31"
    readonly property color inputBg:     "#383a40"
    readonly property color accent:      "#5865f2"
    readonly property color textPrimary: "#f2f3f5"
    readonly property color textMuted:   "#b5bac1"
    readonly property color danger:      "#f23f42"

    // ── Kích thước ──
    readonly property int radius:  8
    readonly property int spacing: 8
    readonly property int pad:     12

    // ── Cỡ chữ ──
    readonly property int fontSmall:  12
    readonly property int fontNormal: 14
    readonly property int fontLarge:  20
    readonly property int fontTitle:  26
}
