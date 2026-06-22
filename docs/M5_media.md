# M5 — Media (Detailed Plan)

*Milestone 5. Image/file attachments, a GIF picker (Tenor/Giphy), and custom
server emoji. This is the first milestone that adds a second transport — **HTTP** —
alongside the existing JSON-over-TCP control channel. Design only; build in slices.*

---

## Goal

- **Attachments**: upload and view images and files in messages.
- **GIFs**: a GIF picker (Tenor or Giphy) that attaches a GIF to a message.
- **Custom emoji**: per-server uploaded emoji, used inline as `:name:`.

**Definition of done:** drop/upload an image and see it inline on both clients;
upload a non-image file and see a download card; pick a GIF from search and have it
play; upload a custom emoji to a server and use `:name:` in a message.

---

## Why a second transport (HTTP)

The JSON-over-TCP channel is great for small, frequent control messages, but binary
blobs (images, files) don't belong in a line-delimited text stream. So the server
gains a small **HTTP endpoint** (via `cpp-httplib`, header-only) on a second port
(e.g. **8081**):

- `POST /upload` — receives a file, stores it, returns a JSON `{ url, kind, filename, size }`.
- `GET  /media/{id}` — serves a stored file.

Messages then reference media by **URL** over the existing TCP protocol. GIFs need
no storage at all — we keep the Tenor/Giphy CDN URL and the client loads it directly.

```
Client ──TCP(JSON)──►  control: messages reference attachment URLs
Client ──HTTP POST──►  /upload  ──► server stores file, returns URL
Client ──HTTP GET ──►  /media/{id}  (QtQuick Image loads it directly)
Client ──TCP gif.search──► server ──HTTPS──► Tenor/Giphy ──► results (URLs)
```

---

## New Dependencies

Add to `Code/vcpkg.json`, then re-run `vcpkg x-update-baseline`:

| Package | Use |
|---|---|
| `cpp-httplib` | Tiny embedded HTTP server for upload/download (and HTTPS client for the GIF proxy). Needs OpenSSL for HTTPS. |
| `openssl` | TLS for the outbound Tenor/Giphy request. |

CMake: `find_package(httplib CONFIG REQUIRED)` + `find_package(OpenSSL REQUIRED)`,
link `httplib::httplib` and `OpenSSL::SSL OpenSSL::Crypto`.

Client uses Qt's own `QNetworkAccessManager` (already in `Qt6::Network`) for the
HTTP upload; QtQuick `Image` loads `http://` URLs out of the box.

---

## Data Model (new tables)

```sql
CREATE TABLE attachments (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id INTEGER NOT NULL,
  url        TEXT    NOT NULL,
  kind       TEXT    NOT NULL,   -- 'image' | 'gif' | 'file'
  filename   TEXT,
  size       INTEGER
);

CREATE TABLE custom_emoji (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  server_id INTEGER NOT NULL,
  name      TEXT    NOT NULL,    -- used as :name:
  url       TEXT    NOT NULL,
  UNIQUE (server_id, name)
);
```

Uploaded files live on disk under a `media/` folder, named by a generated id;
`/media/{id}` serves them. (Dev DB is throwaway → recreate.)

---

## Protocol Changes

Building on the `{op, data}` envelope:

| Direction | op | data |
|---|---|---|
| C→S | `message.create` | `… + attachments: [{url, kind, filename, size}]` |
| S→C | `message.create` / `channel.history` | each message includes its `attachments` array |
| C→S | `gif.search` | `query` → server proxies to Tenor/Giphy |
| S→C | `gif.results` | `gifs: [{url, preview, width, height}]` |
| C→S | `emoji.create` | `server_id, name, url` (after uploading the image) |
| S→C | `ready` (expanded) | each server includes its `custom_emoji: [{name, url}]` |

Uploads themselves go over **HTTP**, not this channel — the client uploads first,
then sends `message.create` with the returned URLs.

**GIF key stays server-side:** the client sends `gif.search`; the server holds the
Tenor/Giphy API key (in untracked `server_config.json`) and makes the HTTPS call.
This avoids shipping the key in the client.

---

## Server Changes

- **New `MediaServer`** (`cpp-httplib`) run on its own thread alongside the Asio
  `io_context`: handles `POST /upload` (validate type/size, store to `media/`,
  insert into a files registry, return JSON) and `GET /media/{id}`.
- **`Database`**: `add_attachment(message_id, url, kind, filename, size)`,
  `attachments_for(message_id)`; `create_emoji`, `emoji_for_server`. Messages query
  attaches its attachments; `ready`/server list includes custom emoji.
- **`Connection`**: `message.create` stores attachments and echoes them; new
  `gif.search` (HTTPS to Tenor/Giphy via httplib client) and `emoji.create`.
- **Config**: `server_config.json` (git-ignored) for the GIF API key, ports, media
  dir, and max upload size.

---

## Client Changes

- **Upload**: a "+" / attach button in the composer → file picker (`FileDialog`) →
  HTTP `POST /upload` via `QNetworkAccessManager` → on success, add the returned URL
  to a *pending attachments* tray → included when the message is sent.
- **`MessageModel`**: each item gains an `attachments` list (role) parsed from the
  message JSON.
- **Rendering** in the message delegate:
  - `image` / `gif` → inline `Image` (with a max size + click-to-enlarge later).
  - `file` → a download card (filename + size + open/download).
- **GIF picker**: a popup with a search box → `gif.search` → grid of animated
  previews → selecting one attaches its URL (kind `gif`) and sends.
- **Custom emoji**: the emoji picker gains a "server emoji" section; in message text,
  `:name:` is replaced with the emoji image when rendering.

---

## Build Order (slices)

1. **Media server + image attachments** — `cpp-httplib` upload/download,
   `attachments` table, composer upload button, inline image rendering. The core.
2. **File attachments** — non-image files render as download cards.
3. **GIF picker** — `gif.search`/`gif.results` via the server's Tenor/Giphy proxy;
   GIFs attach by URL (no storage).
4. **Custom emoji** — `custom_emoji` table, upload + `emoji.create`, `:name:`
   tokenized rendering in messages and an emoji-picker section.

Each slice is independently testable.

---

## Risks & Notes

- **HTTP server threading**: run `cpp-httplib` on a dedicated `std::thread`; keep DB
  access serialized (it's shared with the Asio thread — guard or route DB writes
  through one place).
- **URL building**: the server must hand back a reachable base URL
  (`http://<host>:8081/media/{id}`). For localhost dev this is simple; note it for
  later networked use.
- **Upload validation**: cap size, check MIME/extension, generate the stored name
  (never trust the client filename for the path).
- **Custom-emoji inline rendering is the trickiest part**: QtQuick `Text` won't fetch
  network images inside rich text reliably, so render messages by **tokenizing**
  content into text/`:emoji:` segments and laying them out in a `Flow` of `Text` +
  `Image` items. Plan for this when building slice 4.
- **TLS for the GIF proxy**: `cpp-httplib` needs OpenSSL for the HTTPS call to
  Tenor/Giphy; make sure it's linked.
- **Secrets**: GIF API key and any config live in an untracked `server_config.json`.
- **Recreate the dev DB** for the new tables.
