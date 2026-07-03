# Feature Spec — Voice / Audio Messages

**Goal:** let users send audio files (`.mp3`, `.wav`, `.ogg`, `.m4a`) that play back **inline** in the channel, with a play/pause button, a seek bar, and a time readout.

**Scope / non-goals**
- This is an **audio file attachment**, not live voice. It rides the existing attachment pipeline over HTTP/TCP — **no UDP, no networking changes.**
- **Not** microphone recording (that's a bigger stretch goal — see the end).
- **No DB or protocol changes needed.** The `attachments.kind` column is free-text and the whole `{url, kind, filename, size}` attachment object already flows end-to-end. You're just adding a new `kind` value (`"audio"`) and a QML component to render it.

---

## How attachments already work (read this first)

When you attach a file today:

1. **Pick + upload (client):** the composer's `+` button calls `chatClient.chooseFile()` → `chatClient.uploadAttachment(path)`. `uploadAttachment` (in `Code/Chatties/chatclient.cpp`) picks a **`kind`** from the file suffix (`image` / `gif` / `file`), uploads the bytes to the media server (`POST /upload`), and emits `attachmentUploaded(url, kind, filename, size)`.
2. **Attach to message:** `ChatView.qml`'s `onAttachmentUploaded` pushes it onto `root.pendingAttachments`; sending the message includes those attachments.
3. **Server:** stores the message + attachments and broadcasts `message.create` with the attachment array (unchanged).
4. **Render (client):** in `ChatView.qml`, each attachment goes through a `Loader` whose `sourceComponent` is chosen by `modelData.kind`:
   ```qml
   sourceComponent: modelData.kind === "image" ? imageAtt
                    : (modelData.kind === "gif" ? gifAtt : fileAtt)
   ```
   `imageAtt` / `gifAtt` render inline; everything else falls back to `fileAtt` (a file card).

So an `.mp3` **already uploads and shows up** — but as a generic file card (`kind = "file"`). Your job: make it `kind = "audio"` and render an audio player instead.

---

## Slice 1 — Build: link Qt Multimedia

**File:** `Code/Chatties/CMakeLists.txt`

Add `Multimedia` to the `find_package` components and to `target_link_libraries`:

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets Network Multimedia)
```
```cmake
target_link_libraries(Chatties PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Network
    Qt6::Multimedia          # <-- add
)
```

> Qt Multimedia ships with the standard Qt install. `windeployqt` (already used by `launch.ps1`) will copy the multimedia DLLs **and** the audio backend plugins next to the exe, so playback works from a standalone run.

---

## Slice 2 — Client: tag audio uploads as `kind = "audio"`

**File:** `Code/Chatties/chatclient.cpp`, function `uploadAttachment(...)`.

Find the suffix → kind block:

```cpp
const QString suffix = QFileInfo(path).suffix().toLower();
QString contentType, kind;
if      (suffix == "png")               { contentType = "image/png";  kind = "image"; }
else if (suffix == "jpg" || suffix == "jpeg") { contentType = "image/jpeg"; kind = "image"; }
else if (suffix == "gif")               { contentType = "image/gif";  kind = "gif"; }
else if (suffix == "webp")              { contentType = "image/webp"; kind = "image"; }
else {
    contentType = "application/octet-stream";
    kind = "file";
}
```

Add audio cases **before** the final `else`:

```cpp
else if (suffix == "mp3")               { contentType = "audio/mpeg"; kind = "audio"; }
else if (suffix == "wav")               { contentType = "audio/wav";  kind = "audio"; }
else if (suffix == "ogg" || suffix == "oga") { contentType = "audio/ogg"; kind = "audio"; }
else if (suffix == "m4a" || suffix == "aac") { contentType = "audio/mp4"; kind = "audio"; }
```

That's the only client-upload change. `attachmentUploaded` already carries `kind`, and the model already stores it.

*(Optional nicety: in `chooseFile()` you can add an audio filter, e.g. `"Audio (*.mp3 *.wav *.ogg *.m4a)"`, but any file is already pickable via "All files".)*

---

## Slice 3 — Server: confirm audio is allowed (usually no change)

**File:** `Code/src/server/core/http_media_server.cpp`

- The `POST /upload` route already saves any body and derives the extension from `Content-Type` (`extFromContentType`) or the `X-Filename` header (`safeExtFromFilename`). For audio it falls back to the filename ext (`.mp3` etc.) — fine.
- **Check the blocklist:** `isBlockedExt()` rejects executable/markup types. Audio extensions are **not** in it, so audio passes. Don't add them.
- **Optional robustness:** add audio to `extFromContentType` so the saved file keeps a correct extension even if `X-Filename` is missing:
  ```cpp
  if (ct == "audio/mpeg") return ".mp3";
  if (ct == "audio/wav")  return ".wav";
  if (ct == "audio/ogg")  return ".ogg";
  if (ct == "audio/mp4")  return ".m4a";
  ```
- **Size:** the server caps uploads at 5 MB (`set_payload_max_length`). A short voice clip fits, but longer recordings may not. If you want bigger audio, raise the cap in the `HttpMediaServer` constructor **and** the client's `MAX_UPLOAD` in `uploadAttachment` — keep them in sync.

---

## Slice 4 — Client: inline audio player

**File:** `Code/Chatties/ChatView.qml`

**4a. Import** at the top of the file (next to the other imports):
```qml
import QtMultimedia
```

**4b. Route `kind === "audio"`.** Find the attachment `Loader` and update `sourceComponent`:
```qml
sourceComponent: modelData.kind === "image" ? imageAtt
                 : (modelData.kind === "gif" ? gifAtt
                    : (modelData.kind === "audio" ? audioAtt : fileAtt))
```

**4c. Add the `audioAtt` component** as a sibling of `imageAtt` / `gifAtt` / `fileAtt` (inside the same `Loader`, alongside the other `Component { ... }` blocks). It uses `att` (the `property var att: modelData` already declared on the Loader):

```qml
Component {
    id: audioAtt
    Rectangle {
        width: 280; height: 52; radius: 10
        color: Theme.inputBg

        MediaPlayer {
            id: player
            source: att.url
            audioOutput: AudioOutput { id: audioOut }
        }

        function fmt(ms) {
            if (ms <= 0 || isNaN(ms)) return "0:00"
            var s = Math.floor(ms / 1000)
            return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
        }

        Row {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            // Play / pause
            Rectangle {
                width: 34; height: 34; radius: 17
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    anchors.centerIn: parent
                    text: player.playbackState === MediaPlayer.PlayingState ? "⏸" : "▶"
                    color: "white"; font.pixelSize: 15
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: player.playbackState === MediaPlayer.PlayingState
                               ? player.pause() : player.play()
                }
            }

            // Seek bar + time
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44
                spacing: 2
                Slider {
                    width: parent.width
                    from: 0
                    to: player.duration > 0 ? player.duration : 1
                    value: player.position
                    onMoved: player.position = value
                }
                Row {
                    width: parent.width
                    Label {
                        text: parent.parent.parent.parent.fmt(player.position)
                              + " / " + parent.parent.parent.parent.fmt(player.duration)
                        color: Theme.textMuted; font.pixelSize: 10
                    }
                    Item { width: 8; height: 1 }
                    Label {
                        text: att.filename
                        color: Theme.textMuted; font.pixelSize: 10
                        elide: Text.ElideRight
                        width: parent.width - 90
                    }
                }
            }
        }
    }
}
```

> The `parent.parent...fmt(...)` chain reaches the component's root Rectangle where `fmt` is defined. If that nesting is fiddly, simplest alternative: move `fmt` to a top-level `root` function (`function fmtTime(ms) {...}`) and call `root.fmtTime(player.position)` instead.

---

## Gotchas / house rules

- **Close Qt Creator before editing `ChatView.qml`.** It has truncated the file before when open during external edits. Edit with it closed, reopen to build.
- **Clean rebuild the client after QML changes** so the qmlcache regenerates:
  ```powershell
  cmake --build Code\Chatties\build --target clean
  cmake --build Code\Chatties\build
  ```
  Then `windeployqt` the exe (or run via Qt Creator) so the new Multimedia plugins deploy.
- **No DB migration** — `attachments.kind` is free text; `"audio"` just works. Existing messages are unaffected.
- Keep the client `MAX_UPLOAD` and the server `set_payload_max_length` in sync if you change the size limit.

---

## Test checklist

- [ ] Attach an `.mp3` via `+` → it renders as an audio player (not a file card).
- [ ] Play / pause works; the seek bar moves and is draggable; time updates.
- [ ] The other account sees the same audio message and can play it.
- [ ] Reload the channel (re-login) → the audio message still renders and plays (confirms it round-trips through history).
- [ ] `.wav` / `.ogg` / `.m4a` also work.
- [ ] A `.exe` is still rejected by the server (safety blocklist unchanged).
- [ ] Standalone run (after `windeployqt`) plays audio — confirms multimedia plugins deployed.

---

## Stretch goal — recording from the mic (optional, bigger)

If you later want to *record* voice (not just upload a file):
- Use Qt's `MediaRecorder` + `CaptureSession` + `AudioInput` (QtMultimedia) to record to a temp file, then feed that path into the existing `chatClient.uploadAttachment(path)`.
- Needs a record/stop UI in the composer and OS microphone permission handling.
- Everything downstream (upload, kind `"audio"`, rendering) is identical to this spec — so do this spec first.
