# M1 — Persistence & Accounts (Detailed Plan)

*Milestone 1 from the roadmap, broken into concrete, buildable steps. Design only —
implementation later.*

---

## Goal

Turn the in-memory relay into a real backend with identity and memory:

1. Users **register** and **log in** (hashed passwords).
2. Every connection **authenticates** before it can send messages.
3. Messages are **persisted** in SQLite and **history** loads on login.
4. The server knows *who* each connection is (real user id + username), replacing
   the per-connection counter from M0.

**Definition of done:** start the server, register two users from two clients, chat,
**restart the server**, log back in — and the previous messages are still there.

This milestone deliberately keeps a *single* channel (channel_id = 1). Multi-server
and multi-channel routing is M3.

---

## New Dependencies

Add to `Code/vcpkg.json`, then re-run `vcpkg x-update-baseline`:

| Package | Use |
|---|---|
| `sqlitecpp` | Friendly C++ RAII wrapper over SQLite (parameterized queries, transactions). Pulls in `sqlite3`. |
| `libsodium` | Password hashing (`crypto_pwhash_str`) — never store plaintext. |

CMake additions in `Code/CMakeLists.txt`:

```cmake
find_package(SQLiteCpp CONFIG REQUIRED)
find_package(unofficial-sodium CONFIG REQUIRED)
# target_link_libraries: SQLiteCpp  unofficial-sodium::sodium
```

---

## Database Layer

New module: `src/server/db/database.{h,cpp}` — owns the connection and exposes
intent-revealing methods (no raw SQL leaking out).

```cpp
namespace chatties::server::db {

struct UserRecord   { uint32_t id; std::string username, display_name; };
struct MessageRecord{ uint32_t id; uint32_t channel_id, author_id;
                      std::string author_name, content; uint32_t created_at; };

class Database {
public:
    explicit Database(const std::string& path);   // opens + runs migrations
    // Accounts
    std::optional<UserRecord> create_user(const std::string& username,
                                          const std::string& password_hash);
    std::optional<UserRecord> find_user(const std::string& username);
    std::string get_password_hash(uint32_t user_id);
    // Messages
    uint32_t insert_message(uint32_t channel_id, uint32_t author_id,
                            const std::string& content, uint32_t created_at);
    std::vector<MessageRecord> recent_messages(uint32_t channel_id, int limit);
private:
    void run_migrations();
    SQLite::Database db_;
};

} // namespace
```

**Schema (M1 subset)** — created in `run_migrations()` if absent; track a
`schema_version` row so later milestones can migrate forward:

```sql
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT UNIQUE NOT NULL,
  display_name  TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  channel_id  INTEGER NOT NULL,
  author_id   INTEGER NOT NULL,
  content     TEXT NOT NULL,
  created_at  INTEGER NOT NULL,
  FOREIGN KEY (author_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_messages_channel ON messages(channel_id, id);
```

**Rules:** always use parameterized queries (SQLiteCpp `bind`) — never string
concatenation. One `Database` instance owned by the server; with a single-threaded
`io_context`, calls are naturally serialized.

---

## Authentication

**Hashing (libsodium):**
- On register: `crypto_pwhash_str(...)` produces a self-describing hash string →
  store in `password_hash`.
- On login: `crypto_pwhash_str_verify(hash, password)`.

**Rewire `UserHandler`** (currently unused) to depend on `Database`:

```cpp
std::optional<UserRecord> register_user(const std::string& username,
                                        const std::string& password,
                                        const std::string& display_name);
std::optional<UserRecord> authenticate(const std::string& username,
                                        const std::string& password);
```

Validation: username length/charset, password minimum length, reject duplicate
usernames (the DB `UNIQUE` constraint is the backstop).

---

## Protocol Changes

Adopt the tagged envelope from the roadmap now (it's foundational):

```json
{ "op": "<operation>", "data": { ... }, "nonce": "optional-client-id" }
```

**M1 operations:**

| Direction | op | data |
|---|---|---|
| C→S | `auth.register` | `username, password, display_name` |
| C→S | `auth.login` | `username, password` |
| S→C | `auth.ok` | `user_id, username, display_name` |
| S→C | `auth.error` | `reason` |
| S→C | `ready` | `recent_messages: [...]` (history for the default channel) |
| C→S | `message.create` | `content` (channel_id implied = 1 for now) |
| S→C | `message.create` | `id, channel_id, author_id, username, content, timestamp` |

**Connection state machine:** a connection starts `Unauthenticated`. Only
`auth.register` / `auth.login` are accepted in that state; anything else →
`auth.error`. On success it moves to `Authenticated`, the server sends `auth.ok`
then `ready`, and `message.create` is now allowed.

---

## Server Changes

- **`Connection`** gains: `enum State`, `uint32_t user_id_`, `std::string username_`,
  and a `db_` + `user_handler_` reference. Replace the M0 per-connection id counter
  with the authenticated `user_id`.
- **Dispatch by `op`** in the read handler instead of assuming every line is a chat
  message. A small `switch`/map: auth ops → `UserHandler`; `message.create` →
  validate → `Database::insert_message` → broadcast the stored message (with its DB
  id + author) to other authenticated connections in the channel.
- **`AsioServer`** owns one `Database` and passes references into connections.
- **History:** after `auth.ok`, call `recent_messages(1, 50)` and send `ready`.
- **`MessageHandler::store_message`** stops being a stub — it writes via `Database`.

---

## Client Changes (still Qt Widgets — QML is M2)

Keep the client minimal this milestone:

- Add a small **login/register dialog** shown at startup (username + password, a
  "Register" toggle). On submit, send `auth.login` / `auth.register`.
- Handle `auth.ok` (proceed to chat), `auth.error` (show message), and `ready`
  (populate the message list with history).
- Update send to emit `message.create` with just `content`; the displayed name now
  comes from the server's stored author, so drop the free-text username field added
  in M0.

> These are throwaway-ish: M2 replaces this UI with QML. Keep the networking logic
> (envelope encode/decode, op handling) cleanly separated from the widgets so it
> carries over.

---

## Build Order (within M1)

1. Add deps (`sqlitecpp`, `libsodium`) + CMake wiring; confirm it still builds.
2. `Database` class + migrations; unit-test create/find user and insert/recent
   messages against a temp DB file.
3. Hashing helpers + `UserHandler` register/authenticate.
4. Protocol envelope + op dispatch on the server; connection state machine.
5. Persist messages + send `ready` history.
6. Client login dialog + op handling.
7. End-to-end test + the restart-persistence check.

---

## Testing

- **Unit:** `Database` round-trips (user uniqueness, password hash stored, recent
  messages ordering/limit). Hash verify accepts correct / rejects wrong password.
- **Integration:** register A and B; B logs in and sees history; messages from A
  appear for B live; wrong password → `auth.error`; sending before auth → rejected.
- **Persistence:** stop server, restart, log in → history intact.

---

## Risks & Notes

- **Secrets/config:** DB path and any keys live in an untracked `server_config.json`.
- **SQL injection:** parameterized queries only.
- **Blocking DB calls** on the io thread are fine at this scale; revisit only if
  measured. Don't share one SQLite handle across threads without care.
- **Don't trust the client:** author id/username come from the authenticated session,
  never from the message payload.
- **Migrations:** bump `schema_version` and add forward migrations as later
  milestones extend the schema (servers, channels, attachments, …).
