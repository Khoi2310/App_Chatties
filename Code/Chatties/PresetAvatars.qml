pragma Singleton
import QtQuick

QtObject {
    // Base URL for bundled preset PNGs (see CMakeLists.txt RESOURCES glob).
    readonly property string resourceBase: "qrc:/qt/qml/Chatties/images/presets/"

    // ── How to add a new preset avatar ──────────────────────────────────────
    //
    // Step 1 — Add the PNG file
    //   Place a transparent PNG (character only, no background) in:
    //     Code/Chatties/images/presets/
    //   Rebuild the project. CMake auto-bundles every *.png in that folder.
    //
    // Step 2 — Register the background color
    //   Append one object to the `presets` list below:
    //     { file: "your_file.png", backgroundColor: "#rrggbb" }
    //   Use the exact filename from step 1. Pick any hex color you want.
    //
    // Do not edit PresetAvatarTile.qml or PresetAvatarPopup.qml — rendering
    // picks up new entries from this list automatically.
    // ───────────────────────────────────────────────────────────────────────

    readonly property var presets: [
        { file: "Main.png",    backgroundColor: "#e6e7e5" },
        { file: "Clara.png",   backgroundColor: "#fdde79" },
        { file: "DanHeng.png", backgroundColor: "#b1fda1" },
        { file: "Kafka.png",   backgroundColor: "#c39afa" },
        { file: "Himeko.png",   backgroundColor: "#f79d82" },
        { file: "Firefly.png",   backgroundColor: "#97f1d3" },
        { file: "Herta.png",   backgroundColor: "#97a5f1" },
        { file: "Ica.png",   backgroundColor: "#f7a1c9" }
    ]

    function imageUrl(fileName) {
        return resourceBase + fileName
    }

    function resolveAvatarUrl(url) {
        if (!url || String(url).length === 0)
            return ""

        var normalized = String(url).trim()
        if (normalized.indexOf(resourceBase) === 0) {
            var fileName = normalized.substring(resourceBase.length)
            for (var i = 0; i < presets.length; ++i) {
                if (String(presets[i].file).toLowerCase() === String(fileName).toLowerCase()) {
                    return imageUrl(presets[i].file)
                }
            }
            return ""
        }

        return normalized
    }

    function backgroundColorForUrl(url) {
        var resolvedUrl = resolveAvatarUrl(url)
        if (!resolvedUrl || String(resolvedUrl).length === 0)
            return ""
        for (var i = 0; i < presets.length; ++i) {
            if (String(resolvedUrl) === imageUrl(presets[i].file))
                return presets[i].backgroundColor
        }
        return ""
    }

    function isPresetUrl(url) {
        return backgroundColorForUrl(url).length > 0
    }
}
