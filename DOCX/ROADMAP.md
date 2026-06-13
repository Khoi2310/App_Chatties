# Chatties — Product & Engineering Plan

*A Discord-style desktop chat app. Planning document — implementation comes later.*

---

## 1. Vision & Scope

Build a polished desktop chat application in the spirit of Discord:

- **Servers** (a.k.a. "guilds") containing multiple **text channels**.
- **Direct messages** (1:1) between users.
- Rich messaging: **emoji** (Unicode + custom), **GIFs** (Tenor/Giphy), **replies**,
  **reactions**, **forwarding** a message to a DM or another channel/server,
  image/file **attachments**, edit & delete.
- A modern, themeable **Qt Quick / QML** GUI.

**Scope decisions for this project:**

| Decision | Choice | Why |
|---|---|---|
| Ambition | Learning / portfolio | Favor clarity and breadth of concepts over production scale |
| Client UI | Qt Quick / QML | Animated, themeable, much closer to Discord's feel |
| Platforms | Desktop only (Windows/macOS/Linux) | Smaller scope; Qt is cross-platform by default |
| GIF / emoji | Tenor or Giphy API + Unicode + custom emoji | The full experience |
| Database | SQLite | Zero-setup, embeddable, perfect for a learning backend |

**Explicitly out of scope (for now):** voice/video calls, mobile clients,
multi-server federation, horizontal scaling. The architecture below leaves room
for these later but does not build them.

---

## 2. Where We Are Today

- **Server:** single Boost.Asio TCP process. Accepts connections, parses
  newline-delimited JSON, assigns a per-connection id + timestamp, and broadcasts
  an authoritative message to all other connections. `MessageHandler` validates and
  logs; `store_message()` is a stub. `UserHandler` exists but is unused.
- **Client:** Qt Widgets window with a username field, message list, and composer.
  Uses `QTcpSocket`, sends/receives the agreed JSON schema.
- **Protocol:** `{ type, channel_id, username, content, timestamp }`, one JSON
  object per line over TCP.
- **Persistence:** none yet. SQLite is already a vcpkg dependency.

This is a working MVP for a single global channel. Everything below grows from it.

---

## 3. Target Architecture

```
                 ┌──────────────────────────────────────────┐
                 │              Qt Quick Client               │
                 │  QML UI  ◄──►  C++ backend (models, net)    │
                 └───────────────┬───────────────┬────────────┘
                                 │ TCP (JSON)    │ HTTP(S)
                  realtime events│ + requests    │ media upload/download
                                 ▼               ▼
                 ┌──────────────────────────────────────────┐
                 │            Chatties Server (C++)            │
                 │  Asio TCP gateway  +  small HTTP media API   │
                 │  Session/auth · routing · handlers          │
                 └───────────────┬─────────────┬──────────────┘
                                 ▼             ▼
                          ┌────────────┐  ┌──────────────┐
                          │  SQLite DB │  │ media storage │
                          │ (messages, │  │ (uploads,     │
                          │  users, …) │  │  custom emoji)│
                          └────────────┘  └──────────────┘

External: Tenor/Giphy CDN (GIF search + hosting — we only store URLs)
```

**Two transport channels, on purpose:**

1. **Realtime control channel (TCP + JSON)** — login, send message, reactions,
   replies, typing, presence, channel/guild lists, history requests. Small,
   frequent, latency-sensitive messages.
2. **Media channel (HTTP)** — uploading and downloading images, files, and custom
   emoji. Binary blobs don't belong in the line-based JSON stream. A tiny embedded
   HTTP server (e.g. `cpp-httplib`, header-only) handles `POST /upload` and
   `GET /media/{id}`. Messages then reference media by URL/id.
3. **GIFs need no storage** — when a user picks a GIF, we save the **Tenor/Giphy
   URL** and the client loads it straight from their CDN.

---

## 4. Domain & Data Model (SQLite)

Core entities and the key columns (not exhaustive):

| Table | Purpose | Key fields |
|---|---|---|
| `users` | Accounts | id, username (unique), display_name, password_hash, avatar_url, created_at |
| `servers` | Guilds | id, name, owner_id, icon_url, created_at |
| `server_members` | Membership | server_id, user_id, role, joined_at |
| `channels` | Text channels | id, server_id (NULL = DM), name, type (`text`/`dm`), position |
| `dm_participants` | Who's in a DM | channel_id, user_id (two rows per 1:1 DM) |
| `messages` | All messages | id, channel_id, author_id, content, reply_to_id (NULL), forwarded_from_id (NULL), created_at, edited_at, deleted |
| `attachments` | Files on a message | id, message_id, url, kind (`image`/`gif`/`file`), filename, size |
| `reactions` | Emoji reactions | message_id, user_id, emoji (Unicode or `:customid:`) |
| `custom_emoji` | Per-server emoji | id, server_id, name, image_url |

Design notes that unlock the requested features:

- **Replies** = `messages.reply_to_id` pointing at another message id.
- **Forwarding** = create a *new* message in the target channel with
  `forwarded_from_id` referencing the original (preserving original author/content
  for display). Works identically whether the target is a DM or another
  channel/server.
- **DMs** are just channels with `type = dm` and rows in `dm_participants` — so the
  same message/reply/forward code paths apply with no special cases.
- A message can carry text **and** attachments **and** be a reply — these compose.

---

## 5. Protocol Design

Keep one JSON object per line, but evolve it into a tagged envelope so the same
connection carries many event types:

```json
{ "op": "message.create",
  "data": { "channel_id": 12, "content": "hi", "reply_to_id": 99,
            "attachments": [ { "url": "...", "kind": "gif" } ] } }
```

**Operation families:**

- **Auth:** `auth.login`, `auth.register`, `auth.ok`, `auth.error`
- **Sync:** `ready` (servers, channels, DMs, self), `channel.history` (paged)
- **Messages:** `message.create`, `message.update`, `message.delete`,
  `message.forward`
- **Reactions:** `reaction.add`, `reaction.remove`
- **Presence/typing:** `typing.start`, `presence.update`
- **Server/channel mgmt:** `server.create`, `server.join`, `channel.create`

**Conventions:** client→server ops are requests (server replies with an ack or an
error op); server→client ops are events broadcast to the relevant channel members.
Add a per-request `nonce` so the client can match replies and de-duplicate its own
echoed messages. Keep newline framing for now; revisit length-prefixed framing only
if a single message ever needs to exceed a comfortable line size (media goes over
HTTP, so this is unlikely).

---

## 6. Feature Breakdown

Each feature, sketched across the three layers:

**Accounts & auth.** Register/login over the control channel; store `password_hash`
(use a real hash — e.g. libsodium/argon2 via vcpkg). On login the server returns a
session and a `ready` payload. Wire up the existing `UserHandler`.

**Servers & channels.** Users create/join servers; each server has channels.
Messages route only to members of the target channel (replace today's
"broadcast to everyone" with a `channel_id → set<connection>` map plus DB-backed
membership). UI: a left server rail + channel list.

**Text messaging + history.** Persist every message in SQLite; serve paged history
on channel open (`channel.history`). This is the first thing to build after auth.

**Emoji.** Unicode emoji picker in the composer (a categorized grid). **Custom
emoji** are images uploaded per server (stored via the media API), referenced in
text as `:name:` and rendered inline by the client.

**GIFs.** A GIF picker backed by the **Tenor or Giphy API** (search + trending).
Selecting one attaches its CDN URL as an `attachment` of kind `gif`; no server-side
storage needed. (Requires a free API key, kept in server config — not committed.)

**Replies.** Composer "reply" action sets `reply_to_id`; the message renders with a
quoted preview of the referenced message, clickable to jump to it.

**Reactions.** Hover a message → add emoji; `reactions` table aggregates counts;
`reaction.add/remove` events update all viewers live. (Closely related to emoji, so
build them together.)

**Forwarding.** "Forward" action opens a picker of your DMs + channels; sends a
`message.forward` with the source message id and target channel id. Server copies
the content/attachments into a new message with `forwarded_from_id` set. Uniform for
DMs and channels.

**Direct messages.** Start a DM with a user → creates (or reuses) a `dm` channel.
Same messaging UI and code paths as server channels.

**Attachments (images/files).** Composer upload button → HTTP `POST /upload` →
returns a URL → included as an `attachment`. Client renders images/GIFs inline,
other files as download cards.

**Presence & typing (polish).** `typing.start` shows "X is typing…"; `presence`
shows online/idle/offline dots.

---

## 7. GUI Plan (Qt Quick / QML)

Migrate the client to Qt Quick. Recommended structure:

- **C++ side:** thin networking layer + `QAbstractListModel` subclasses exposed to
  QML (`MessageModel`, `ChannelModel`, `ServerModel`, `MemberModel`). C++ owns the
  socket and data; QML owns presentation.
- **QML side, Discord-like layout:**
  - Far-left **server rail** (icons), then **channel sidebar**, then the
    **message view**, with an optional right-side **member list**.
  - **Composer** with buttons for emoji picker, GIF picker, attachment upload, and
    a reply banner when replying.
  - **Message delegate** rendering author, timestamp, text, inline media, reply
    preview, reaction chips, and a hover action bar (reply / react / forward / …).
- **Theming:** a central dark theme via QML singletons (colors, spacing, fonts);
  makes a light theme trivial later.
- **Migration approach:** stand up the QML shell against the *current* protocol
  first (so you keep a working app), then grow it as backend features land.

---

## 8. Phased Roadmap

Each milestone leaves you with a runnable app.

- **M0 — done.** MVP relay + real JSON protocol + usernames.
- **M1 — Persistence & accounts.** SQLite schema, register/login, hashed passwords,
  message history, server tracks authenticated users. *(Backend foundation.)*
- **M2 — QML client shell.** Migrate client to Qt Quick; core layout + theme wired
  to the existing protocol; keep feature parity with today.
- **M3 — Servers & channels.** Multi-server/multi-channel data model, per-channel
  routing, create/join, UI navigation.
- **M4 — Rich messaging.** Unicode emoji picker, replies, reactions, edit/delete.
- **M5 — Media.** HTTP media API for image/file uploads + custom emoji; GIF picker
  via Tenor/Giphy.
- **M6 — DMs & forwarding.** Direct-message channels; forward to DM or any channel.
- **M7 — Polish.** Presence, typing indicators, desktop notifications, search,
  settings, avatars.
- **Later / out of scope.** Voice/video, mobile, production infra, federation.

Suggested quick win before M1: the per-connection **write queue** (hardening) to
remove the lurking overlapping-`async_write` risk.

---

## 9. Tech Stack & New Dependencies

| Area | Choice | vcpkg package(s) |
|---|---|---|
| Server networking | Boost.Asio (have it) | `boost-asio`, `boost-system` |
| JSON | nlohmann_json (have it) | `nlohmann-json` |
| Database | SQLite (have it) | `sqlite3` (consider `sqlitecpp` wrapper) |
| Media HTTP API | cpp-httplib (header-only) | `cpp-httplib` |
| Password hashing | libsodium / argon2 | `libsodium` |
| Client UI | Qt 6 Quick/QML | (Qt installed separately, not vcpkg) |
| GIFs | Tenor or Giphy REST API | none (HTTP + API key in config) |

Add new packages to `Code/vcpkg.json` and re-run the baseline as features land.
Keep API keys and secrets in an untracked config file (e.g. `server_config.json`,
git-ignored).

---

## 10. Hard Parts & Learning Notes

- **Async write correctness.** Every `async_write` buffer must outlive the
  operation, and writes on one socket must be serialized (write queue). This already
  bit us once.
- **Connection ↔ user mapping & lifetimes.** As routing gets richer, be deliberate
  about `shared_ptr` ownership and removing connections on disconnect.
- **Schema migrations.** Even with SQLite, plan for versioned migrations as tables
  evolve.
- **Threading.** A single-threaded `io_context` keeps shared state simple; only add
  threads (and locks) if you measure a need.
- **Security basics** (even for a learning project): hash passwords, validate all
  input server-side, scope every action to the user's permissions, and don't trust
  client-supplied ids.
- **Media safety.** Validate upload types/sizes; don't serve uploads from a path the
  client controls.

---

*This document is the north star; treat the milestones as independent, shippable
slices and adjust as you learn.*
