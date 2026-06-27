# M4 — Rich Messaging (Detailed Plan)

*Milestone 4. Add emoji, replies, reactions, and edit/delete to messages. Design —
build in slices.*

---

## Goal

Make messages feel like a real chat app:

- **Emoji** — a Unicode emoji picker in the composer (custom server emoji come in M5).
- **Replies** — reply to a specific message; it renders a quoted preview.
- **Reactions** — add/remove emoji reactions; show chips with counts.
- **Edit / Delete** — edit or delete your own messages; others see the change live.

**Definition of done:** pick an emoji into a message; reply to a message and see the
quote; react to a message and watch the count update on both clients; edit and delete
your own message and see it reflected everywhere.

---

## Data Model Changes

Extend `messages` and add a `reactions` table:

```sql
ALTER TABLE messages ADD COLUMN reply_to_id INTEGER;   -- NULL = not a reply
ALTER TABLE messages ADD COLUMN edited_at   INTEGER;   -- NULL/0 = never edited
ALTER TABLE messages ADD COLUMN deleted     INTEGER NOT NULL DEFAULT 0;

CREATE TABLE reactions (
  message_id INTEGER NOT NULL,
  user_id    INTEGER NOT NULL,
  emoji      TEXT    NOT NULL,
  PRIMARY KEY (message_id, user_id, emoji)
);
```

(Dev DB is throwaway → recreate rather than migrate.)

Deleted messages are **soft-deleted** (`deleted = 1`) so replies pointing at them
still resolve to a "[message deleted]" placeholder.

---

## Protocol (new / changed ops)

| Direction | op | data |
|---|---|---|
| C→S | `message.create` | `channel_id, content, reply_to_id?` |
| S→C | `message.create` | `… + reply_to_id, reply_username, reply_excerpt` |
| C→S | `message.update` | `message_id, content` |
| S→C | `message.update` | `id, content, edited_at` |
| C→S | `message.delete` | `message_id` |
| S→C | `message.delete` | `id` |
| C→S | `reaction.add` / `reaction.remove` | `message_id, emoji` |
| S→C | `reaction.update` | `message_id, reactions:[{emoji,count}]` |

`channel.history` messages gain the same extra fields (reply info, `edited_at`,
`deleted`, and a `reactions` array). Edit/delete/reaction events are routed to
everyone currently viewing that message's channel (same per-channel rule as M3).

**Security:** the server checks the requester is the message's **author** before
allowing edit/delete; reactions are scoped to the authenticated user.

---

## Server Changes

- **`Database`**: `insert_message` gains `reply_to_id`; add `update_message(id, content)`,
  `delete_message(id)` (soft), `message_author(id)`, `get_message(id)` (for reply
  preview), `add_reaction`/`remove_reaction`, `reactions_for(message_id)` (aggregated
  counts). `recent_messages` returns the new fields + reactions + resolved reply
  preview.
- **`Connection`**: handle `message.update`, `message.delete`, `reaction.add/remove`;
  enforce author check on edit/delete; broadcast the corresponding event to channel
  viewers. `message.create` accepts `reply_to_id` and includes the reply preview in
  the broadcast.

---

## Client Changes

- **`MessageModel`** gains roles: `messageId`, `replyToId`, `replyUsername`,
  `replyExcerpt`, `edited`, `deleted`, `reactions`. New methods to **update an existing
  row by id**: `updateMessage(id, content, editedAt)`, `markDeleted(id)`,
  `setReactions(id, reactions)`. (Today it only appends — M4 needs in-place updates.)
- **`ChatClient`**: invokables `sendMessage(content, replyToId)`, `editMessage(id,
  content)`, `deleteMessage(id)`, `addReaction(id, emoji)`, `removeReaction(id, emoji)`;
  parse the new events and forward to the model.
- **UI (`ChatView`)**:
  - **Emoji picker**: a button in the composer opening a grid popup that inserts the
    chosen Unicode emoji at the cursor.
  - **Message hover actions**: reply, react, and (for your own messages) edit / delete.
  - **Reply**: a "replying to …" banner above the composer; messages render a small
    quoted preview when `replyToId` is set.
  - **Reactions**: chips under a message showing emoji + count, tappable to toggle.
  - **Edited/Deleted**: show "(đã chỉnh sửa)" and replace deleted content with a muted
    "[tin nhắn đã bị xóa]".

---

## Build Order (slices)

1. **Emoji picker** — client-only (emoji are just Unicode in `content`). No server/DB
   change. Quick win.
2. **Replies** — DB `reply_to_id`, protocol, server preview, model role + quoted UI.
3. **Edit / Delete** — DB columns + ops, author check, model in-place update + UI.
4. **Reactions** — `reactions` table + ops, aggregated broadcast, chips + toggle UI.

Each slice is independently testable.

---

## Risks & Notes

- **In-place model updates**: `MessageModel` must find a row by message id and emit
  `dataChanged` — the first time we update messages rather than only append. Store the
  real `messageId` per row.
- **Reply resolution**: keep a short excerpt server-side; deleted targets resolve to a
  placeholder.
- **Reaction "mine" state**: broadcast only counts; each client highlights its own
  reactions locally (simplest; exact cross-client "mine" is a later refinement).
- **Author enforcement** on edit/delete is mandatory — never trust the client.
- **Recreate the dev DB** for the schema change.
- Emoji rendering depends on the system font; Segoe UI Emoji on Windows covers it.
