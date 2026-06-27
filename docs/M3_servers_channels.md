# M3 — Servers & Channels (Detailed Plan)

*Milestone 3. Add Discord-style "servers" (guilds) each containing multiple text
channels, route messages per channel, and give the UI a server rail + channel
sidebar. Design only — build in steps.*

---

## Goal

Move from one hardcoded global channel to real structure:

- A user belongs to one or more **servers**; each server has multiple **channels**.
- Messages are scoped to a channel and only reach people viewing that channel.
- Users can **create** a server, **join** a server, and **create** channels.
- The UI gains a **server rail** (left), a **channel list**, and the message area.

**Definition of done:** create a server, add a couple of channels, switch between
them (each loads its own history), and a second user who joins the same server sees
messages live in the matching channel.

This keeps the M1/M2 chat working by auto-creating a default server + `general`
channel and auto-joining every new user to it.

---

## Data Model (new tables)

`messages` already has `channel_id`, so we add the structure around it:

| Table | Purpose | Key fields |
|---|---|---|
| `servers` | Guilds | id, name, owner_id, created_at |
| `server_members` | Membership | server_id, user_id, joined_at (PK: server_id+user_id) |
| `channels` | Text channels | id, server_id, name, position, created_at |

`messages.channel_id` now references `channels.id`. On first run we **seed** a
default server ("Chatties") with a `general` channel, and every newly registered
user is **auto-joined** to it — so existing single-channel behavior still works.

> Dev DB is throwaway, so we recreate `chatties.db` rather than migrate.

---

## Routing Model

Today the server broadcasts every message to all authenticated connections. New
rule:

- Each connection tracks the **channel it's currently viewing** (`current_channel_id`).
- On `message.create`, the server checks the user is a **member of that channel's
  server**, persists the message, then delivers it to every connection whose
  `current_channel_id` matches.

This is the simplest correct "live chat per channel." Delivering to channels you're
*not* currently viewing (for unread badges) is deliberately deferred to M7 — it
needs per-channel client state and is a separate concern.

**Security:** the server validates membership and the channel id on every action;
it never trusts a client-supplied channel/server id without checking access.

---

## Protocol (new ops)

Building on the `{op, data}` envelope:

| Direction | op | data |
|---|---|---|
| S→C | `ready` (expanded) | `servers: [{ id, name, channels:[{id,name}] }]` |
| C→S | `server.create` | `name` → makes server + `general` channel, joins creator |
| C→S | `server.join` | `server_id` |
| C→S | `channel.create` | `server_id, name` |
| C→S | `channel.select` | `channel_id` → sets active channel |
| S→C | `channel.history` | `channel_id, messages:[...]` |
| C→S | `message.create` | `channel_id, content` |
| S→C | `message.create` | `id, channel_id, author_id, username, content, timestamp` |
| S→C | `server.created` / `channel.created` | the new server/channel (to members) |

Flow: after login, `ready` lists the user's servers+channels. The client picks a
default channel → `channel.select` → server replies `channel.history`. Switching
channels repeats `channel.select`.

---

## Server Changes

- **`Database`**: add `create_server`, `add_member`, `is_member(user_id, server_id)`,
  `servers_for_user(user_id)` (with their channels), `create_channel`,
  `channel_server_id(channel_id)`, and reuse `recent_messages(channel_id, limit)`.
  Seeding helper for the default server/channel on startup.
- **`Connection`**: add `current_channel_id_`; handle the new ops; enforce
  membership; route `message.create` only to connections viewing the same channel.
- **`AsioServer`**: ensure the default server/channel exist at startup.
- Auto-join new users to the default server in the registration path.

---

## Client (QML) Changes

- **Models**: `ServerModel` (servers list) and `ChannelModel` (channels of the
  selected server). `MessageModel` is reused per active channel (clear + load on
  switch).
- **`ChatClient`**: add invokables `createServer`, `joinServer`, `createChannel`,
  `selectChannel`; signals `serversReceived`, `channelHistory`, `serverCreated`,
  `channelCreated`.
- **UI** (`ChatView`): a left **server rail** (icon/initial per server), a
  **channel list** for the selected server, and the message area on the right.
  Buttons/dialogs for create-server, join-server, create-channel.
- Selecting a channel → clear `MessageModel`, send `channel.select`, fill from
  `channel.history`; live `message.create` for the active channel appends.

---

## Build Order (within M3)

1. **DB**: new tables + methods + seed default server/channel + auto-join users.
2. **Protocol/server**: `server.create/join`, `channel.create/select`, expanded
   `ready`, membership checks, per-channel routing.
3. **Client data**: `ServerModel`/`ChannelModel`, `ChatClient` invokables/signals,
   channel-select → history wiring (logic first, minimal UI).
4. **UI**: server rail + channel list + message area layout.
5. **Create/join server + create channel** UI (dialogs).
6. **Test** the done-criteria across two users.

---

## Risks & Notes

- **Routing choice**: per-active-channel delivery now; unread/badges later (M7).
- **Membership enforcement**: always check server/channel access server-side.
- **Seeding & auto-join**: keep the app usable immediately and preserve M1/M2 flow.
- **Recreate the dev DB** when the schema changes; no migration needed yet.
- **UI grows**: the message list/composer from M2 get reused inside the new
  three-pane layout, so most of M2's `ChatView` carries over.
