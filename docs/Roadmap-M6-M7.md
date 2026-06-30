# Chatties Roadmap — M6 & M7

Team-facing engineering spec. Written in the same milestone → slice style we used for M1–M5.
Protocol uses the existing op-envelope `{ "op": "...", "data": {...} }` over the TCP server (port 8080).
HTTP media stays on port 8081. DB is SQLite (WAL + `db_mutex_` on writes).

> **Conventions reminder**
> - Every new **write** method on `Database` must take `std::lock_guard<std::mutex> lk(db_mutex_)`.
> - Every new broadcast must use `dump(-1, ' ', false, error_handler_t::replace)` (never strict `dump()`).
> - New ops are dispatched in `AsioServer`'s op switch; mirror an existing handler (`handle_message_create`) for structure.
> - Client: add `Q_INVOKABLE` methods + `signals` on `ChatClient`, parse incoming ops in `onReadyRead`, surface to QML.

---

## Where we are (M1–M5 recap)

| Milestone | Delivered |
|-----------|-----------|
| **M1** | Boost.Asio TCP server, SQLite, libsodium argon2 auth, op-envelope protocol |
| **M2** | Qt Quick client, `ChatClient`, `MessageModel`, auth views, dark theme |
| **M3** | Servers (guilds) + channels, three-pane UI |
| **M4** | Replies, edit/delete, reactions |
| **M5** | Image attachments, file attachments, per-server custom emoji, Giphy GIF picker |
| *In flight* | User avatars / profiles (parallel branch) |

Building blocks M6/M7 will lean on: `broadcast_to_channel()`, the attachments pipeline, per-connection
`current_channel_id_` / `is_viewing()`, and the `MessageModel` role system.

---

# M6 — Mentions, Notifications & Direct Messages

**Goal:** make Chatties feel "alive" when you're not staring at a channel — you get pinged when someone
talks to you, you can see unread activity, and you can message a person directly without a shared server.

Split into two parts that can ship independently:

- **6A — Mentions & notifications** (depends only on existing channels/messages)
- **6B — Direct messages & friends** (reuses the message pipeline, adds a DM surface)

Do 6A first; it's lower risk and the unread machinery is reused by DMs.

---

## 6A — Mentions & Notifications

### Slices

1. **Mention parsing & storage** (server)
2. **Unread / read-state tracking** (server + protocol)
3. **Mention rendering + `@` autocomplete** (client)
4. **Badges + desktop notifications** (client)

### DB schema

```sql
-- Which users are mentioned by a message (populated at message.create time).
CREATE TABLE mentions (
    message_id INTEGER NOT NULL,
    user_id    INTEGER NOT NULL,
    PRIMARY KEY (message_id, user_id),
    FOREIGN KEY (message_id) REFERENCES messages(id)
);

-- Last message each user has read in each channel.
CREATE TABLE channel_reads (
    user_id            INTEGER NOT NULL,
    channel_id         INTEGER NOT NULL,
    last_read_msg_id   INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, channel_id)
);
```

New `Database` methods (all writes locked):
- `add_mentions(msg_id, vector<uint32_t> user_ids)`
- `mark_read(user_id, channel_id, msg_id)`
- `unread_counts(user_id)` → `vector<{channel_id, unread, mention_count}>`
  (unread = messages with `id > last_read_msg_id` in channels the user is a member of;
  mention_count = of those, how many are in `mentions` for this user).

### Server logic

In `handle_message_create`, after inserting the message:
1. Parse `content` for `@token` runs. Resolve each token against **members of the channel's server**
   (case-insensitive username match; also accept `@everyone` → all members).
2. `db_.add_mentions(id, resolved_ids)` and attach `mentions: [user_id...]` to the broadcast payload
   (so clients can highlight without a second lookup).
3. After broadcasting to viewers, for members **not** currently `is_viewing(channel_id)`, the unread count
   naturally grows; no push needed for the badge. For an *active ping* (toast), emit a lightweight
   `mention.ping` op directly to any mentioned user's connection(s) that aren't viewing the channel.

When a client selects/reads a channel it sends `channel.read`; server updates `channel_reads` and may
echo back updated `unread.state` for that channel.

### Protocol additions

| Direction | Op | Data |
|-----------|----|------|
| C→S | `channel.read` | `{ channel_id, last_read_msg_id }` |
| S→C | `unread.state` | `{ channels: [{ channel_id, unread, mentions }] }` (sent on login + on change) |
| S→C | `mention.ping` | `{ channel_id, server_id, message_id, author_name, excerpt }` |

`message.create` broadcast payload gains: `"mentions": [user_id, ...]`.

### Client work

- **`ChatClient`**: `Q_INVOKABLE markChannelRead(int channelId, int lastMsgId)`;
  signals `unreadStateChanged(QVariantList)` and `mentionPinged(QVariantMap)`.
- **`renderContent()`** (ChatView.qml): replace `@username` with a highlighted span
  (accent background pill) when the token resolves; self-mentions get a stronger highlight.
- **`@` autocomplete**: when the composer text matches `/@(\w*)$/`, show a popup listing channel members;
  Tab/Enter inserts `@username `. Reuse the emoji-popup pattern.
- **Badges**: unread dot on channel rows in the channel list; red mention-count pill on both the
  channel row and the server icon in the server bar. Drive from an `UnreadModel` (or a `QVariantMap`
  property keyed by channel id) updated from `unreadStateChanged`.
- **Desktop notifications**: on `mentionPinged`, if the app window is not active
  (`Window.active === false`), call a small C++ helper backed by `QSystemTrayIcon::showMessage`
  (add a tray icon in `main.cpp`). Clicking the toast focuses the window and selects the channel.
- Call `markChannelRead` when a channel is selected and when new messages arrive while it's focused.

### Acceptance criteria (6A)

- Typing `@Emily` resolves to a highlighted pill; Emily sees the message highlighted for her.
- A channel with unseen messages shows an unread dot; if you were mentioned, a count badge.
- Selecting the channel clears its unread/mention badge for you (and persists across reconnect).
- Being @-mentioned while the window is unfocused shows a desktop notification.

---

## 6B — Direct Messages & Friends

**Design decision:** model a DM as a **channel with `server_id = 0`** plus a participants table, so the
entire existing message pipeline (history, send, edit, react, attachments, mentions) is reused unchanged.

### DB schema

```sql
-- Friend graph. One row per pair; store the lower user id as user_a for uniqueness.
CREATE TABLE friendships (
    user_a       INTEGER NOT NULL,
    user_b       INTEGER NOT NULL,
    status       TEXT NOT NULL,          -- 'pending' | 'accepted'
    requested_by INTEGER NOT NULL,       -- who sent the request
    created_at   INTEGER NOT NULL,
    PRIMARY KEY (user_a, user_b)
);

-- DM channels reuse `channels` with server_id = 0. Map participants here.
CREATE TABLE dm_participants (
    channel_id INTEGER NOT NULL,
    user_id    INTEGER NOT NULL,
    PRIMARY KEY (channel_id, user_id)
);
```

`Database` methods:
- `send_friend_request(from, to)`, `accept_friend_request(a, b)`, `remove_friend(a, b)`,
  `friends_of(user_id)` → list with status + direction.
- `open_dm(user_a, user_b)` → finds existing 2-person DM channel or creates a `server_id = 0`
  channel + two `dm_participants` rows; returns `channel_id`.
- `dm_channels_for(user_id)` → `[{ channel_id, other_user, last_msg_excerpt, last_ts }]`.
- `is_dm_participant(user_id, channel_id)` — **add this check to `handle_message_create`'s
  authorization** so DM channels (which have no server membership) still permit posting.

### Protocol additions

| Direction | Op | Data |
|-----------|----|------|
| C→S | `friend.request` | `{ username }` |
| C→S | `friend.accept` | `{ user_id }` |
| C→S | `friend.remove` | `{ user_id }` |
| C→S | `friend.list` | `{}` |
| S→C | `friend.list` | `{ friends: [{ user_id, username, display_name, avatar_url, status, incoming }] }` |
| C→S | `dm.open` | `{ user_id }` → server replies with `dm.opened` |
| S→C | `dm.opened` | `{ channel_id, other_user: {...} }` (client then `channel.select` it) |
| C→S | `dm.list` | `{}` |
| S→C | `dm.list` | `{ dms: [{ channel_id, other_user, last_excerpt, last_ts, unread }] }` |

DMs reuse `channel.select`, `channel.history`, `message.create`, reactions, edit/delete as-is.

### Client work

- **Home surface**: add a "Direct Messages" button at the top of the server bar (above the guild icons).
  Selecting it swaps the channel column for a **Friends + DM list** panel and the message pane shows the
  selected DM.
- **Friends panel**: tabs for *Online / All / Pending*; an "Add friend by username" field;
  accept/decline on incoming requests.
- **DM list**: rows with the other user's avatar + last-message excerpt, unread badge (reuses 6A).
- **`ChatClient`**: `sendFriendRequest(QString)`, `acceptFriend(int)`, `removeFriend(int)`,
  `requestFriends()`, `openDm(int userId)`, `requestDmList()`; signals `friendsReceived`,
  `dmListReceived`, `dmOpened(int channelId, QVariantMap other)`.
- On `dmOpened`, call `selectChannel(channelId)` and route the existing message pane to it.
- Entry points to "Message" a user: profile popup (ties into the in-flight avatar/profile work) and a
  context action on a username.

### Acceptance criteria (6B)

- User A adds User B by username; B sees a pending request and accepts; both appear in each other's list.
- Opening a DM creates/reopens a private channel; messages, replies, reactions, and attachments all work.
- A non-participant cannot post to or read a DM channel (server rejects with an error).
- DM list shows last message + unread badge; selecting clears unread.

### M6 risks / notes

- **Mention parsing** must ignore `@` inside code spans / URLs eventually — fine to keep simple for v1
  (plain token scan), but escape before building the RichText `<span>` (we already HTML-escape in
  `renderContent`).
- **`server_id = 0` channels** must be excluded from the normal server→channel listing queries — audit
  `channels_for_server` and any "list channels" path.
- Tray notifications need a real tray icon resource; add it to the Qt resource file.

---

# M7 — Search & Pins

**Goal:** find any message fast, and keep important messages one click away per channel.

- **7A — Full-text message search** (FTS5 + jump-to-message)
- **7B — Pinned messages** (per-channel pin panel)

Both need a shared **jump-to-message** capability, so build that first.

---

## 7A — Full-text Search

### DB schema — SQLite FTS5

```sql
-- Virtual table mirroring messages.content for fast search.
CREATE VIRTUAL TABLE messages_fts USING fts5(
    content,
    content='messages',
    content_rowid='id'
);

-- Keep FTS in sync with the messages table.
CREATE TRIGGER messages_ai AFTER INSERT ON messages BEGIN
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;
CREATE TRIGGER messages_ad AFTER DELETE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES('delete', old.id, old.content);
END;
CREATE TRIGGER messages_au AFTER UPDATE ON messages BEGIN
    INSERT INTO messages_fts(messages_fts, rowid, content) VALUES('delete', old.id, old.content);
    INSERT INTO messages_fts(rowid, content) VALUES (new.id, new.content);
END;
```

> **Migration:** on first run after this ships, backfill existing rows:
> `INSERT INTO messages_fts(rowid, content) SELECT id, content FROM messages;`
> Guard it behind a "does messages_fts have rows / does table exist" check in the migration path.

`Database`:
- `search_messages(user_id, query, scope, scope_id, before_id, limit)` →
  joins FTS hits against channels the user may read (member of server, or DM participant),
  returns message records + channel/server context, newest first, paginated by `before_id`.

### Protocol

| Direction | Op | Data |
|-----------|----|------|
| C→S | `search.messages` | `{ query, scope: "channel"\|"server"\|"all", scope_id, before_id?, limit? }` |
| S→C | `search.results` | `{ query, results: [{ message, channel_id, server_id }], has_more }` |

`message` is the same shape `message_to_json` already emits.

### Jump-to-message (shared)

| Direction | Op | Data |
|-----------|----|------|
| C→S | `channel.context` | `{ channel_id, message_id, around: 25 }` |
| S→C | `channel.context` | `{ channel_id, target_id, messages: [...] }` |

`Database::messages_around(channel_id, message_id, n)` → n messages before + the target + n after.
Client loads them into the model, `positionViewAtIndex` on the target, and flashes a highlight.

### Client work

- **Search bar**: magnifier in the channel header opens a search field (scope defaults to current
  channel, toggle to whole server / everywhere).
- **Results panel**: right-side drawer listing hits (author, channel, timestamp, snippet with the match
  emphasized); infinite scroll via `before_id`.
- Clicking a result → `channel.select` if needed, then `channel.context` → jump + highlight.
- **`ChatClient`**: `searchMessages(QString query, QString scope, int scopeId, int beforeId)`,
  `loadContext(int channelId, int messageId)`; signals `searchResults(QVariantMap)`,
  `contextLoaded(int channelId, int targetId, QJsonArray messages)`.
- **`MessageModel`**: add `loadContext()` (reset to the context window) and an `indexOfMessage(id)` helper
  so the view can scroll to + flash the target row.

### Acceptance criteria (7A)

- Searching a word returns matching messages from channels you can access, newest first, paginated.
- You cannot find messages in servers/DMs you're not a member of.
- Clicking a result jumps to that message in context and briefly highlights it.
- Edited messages reflect new text in search; deleted messages drop out.

---

## 7B — Pinned Messages

### DB schema

```sql
CREATE TABLE pins (
    channel_id INTEGER NOT NULL,
    message_id INTEGER NOT NULL,
    pinned_by  INTEGER NOT NULL,
    pinned_at  INTEGER NOT NULL,
    PRIMARY KEY (channel_id, message_id)
);
```

`Database`: `pin_message(channel_id, message_id, by, ts)`, `unpin_message(channel_id, message_id)`,
`pins_for(channel_id)` → message records ordered by `pinned_at` desc.

### Protocol

| Direction | Op | Data |
|-----------|----|------|
| C→S | `message.pin` | `{ channel_id, message_id }` |
| C→S | `message.unpin` | `{ channel_id, message_id }` |
| C→S | `pins.list` | `{ channel_id }` |
| S→C | `pins.list` | `{ channel_id, pins: [message...] }` |
| S→C | `pins.changed` | `{ channel_id }` (broadcast to viewers so open panels refresh) |

Permission for v1: any server member can pin/unpin (tighten later when M-roles lands, if ever).

### Client work

- **`⋯` action menu** (ChatView.qml `actionMenu`): add **Pin** / **Unpin** entries.
- **Channel header**: a pin icon → opens a **pinned-messages panel** (`pins.list`), each entry clickable
  to jump-to-message (reuse 7A's context jump).
- Live refresh the panel on `pins.changed`.
- **`ChatClient`**: `pinMessage(int,int)`, `unpinMessage(int,int)`, `requestPins(int)`;
  signal `pinsReceived(int channelId, QJsonArray pins)`, `pinsChanged(int channelId)`.

### Acceptance criteria (7B)

- Pinning a message adds it to the channel's pin panel for everyone, live.
- Unpinning removes it live.
- Clicking a pinned message jumps to it in the channel with a highlight.
- Pins survive restart.

---

## Suggested task breakdown

**M6 (6A then 6B)**
1. DB: `mentions`, `channel_reads` + methods + migration.
2. Server: mention parsing in `handle_message_create`; `channel.read`; `unread.state`; `mention.ping`.
3. Client: mention highlight + `@` autocomplete.
4. Client: unread/mention badges; tray notifications.
5. DB: `friendships`, `dm_participants` + methods; DM auth in `handle_message_create`.
6. Server: friend + DM ops.
7. Client: Home/DM surface, friends panel, DM list; "Message" entry points.

**M7 (jump-to-message, then 7A, then 7B)**
1. DB: `messages_around` + `channel.context` op; client context load + flash.
2. DB: FTS5 table + triggers + backfill migration; `search_messages` with access filtering.
3. Server: `search.messages` / `search.results`.
4. Client: search bar, results drawer, jump.
5. DB: `pins` + methods.
6. Server: pin/unpin/list ops + `pins.changed` broadcast.
7. Client: pin actions in `⋯` menu, header pin icon, pin panel.

## Cross-cutting reminders

- Keep `server_config.json` out of git; no new secrets are introduced by M6/M7.
- Thread-safety: any DB method touched by both the Asio thread and the HTTP thread needs the mutex.
- Coordinate with the avatar/profile branch — 6B's "Message this user" hangs off the profile popup.
- Add acceptance checks to a manual test pass before merging each slice (we have no automated tests yet —
  consider a lightweight harness as its own task).
