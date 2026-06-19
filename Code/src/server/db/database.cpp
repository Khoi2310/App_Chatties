#include "server/db/database.h"
#include "common/utils/logger.h"
#include <algorithm>

namespace chatties {
namespace server {
namespace db {

Database::Database(const std::string& path)
    : db_(path, SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE)
{
    run_migrations();
    seed_defaults();
    utils::Logger::instance().info("[Database] Đã mở DB tại " + path);
}

void Database::run_migrations() {
    db_.exec(
        "CREATE TABLE IF NOT EXISTS users ("
        "  id            INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  username      TEXT UNIQUE NOT NULL,"
        "  email         TEXT UNIQUE NOT NULL,"
        "  display_name  TEXT NOT NULL,"
        "  password_hash TEXT NOT NULL,"
        "  created_at    INTEGER NOT NULL"
        ")"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS messages ("
        "  id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  channel_id  INTEGER NOT NULL,"
        "  author_id   INTEGER NOT NULL,"
        "  content     TEXT NOT NULL,"
        "  created_at  INTEGER NOT NULL,"
        "  FOREIGN KEY (author_id) REFERENCES users(id)"
        ")"
    );

    db_.exec(
        "CREATE INDEX IF NOT EXISTS idx_messages_channel "
        "ON messages(channel_id, id)"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS servers ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name       TEXT NOT NULL,"
        "  owner_id   INTEGER NOT NULL,"
        "  created_at INTEGER NOT NULL"
        ")"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS server_members ("
        "  server_id INTEGER NOT NULL,"
        "  user_id   INTEGER NOT NULL,"
        "  joined_at INTEGER NOT NULL,"
        "  PRIMARY KEY (server_id, user_id)"
        ")"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS channels ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  server_id  INTEGER NOT NULL,"
        "  name       TEXT NOT NULL,"
        "  position   INTEGER NOT NULL DEFAULT 0,"
        "  created_at INTEGER NOT NULL"
        ")"
    );
}

void Database::seed_defaults() {
    // Dùng lại server đầu tiên nếu đã có, nếu chưa thì tạo mặc định.
    SQLite::Statement q(db_, "SELECT id FROM servers ORDER BY id LIMIT 1");
    if (q.executeStep()) {
        default_server_id_ = q.getColumn(0).getUInt();
        return;
    }
    default_server_id_ = create_server("Chatties", 0);
    create_channel(default_server_id_, "general");
    utils::Logger::instance().info(
        "[Database] Đã tạo server mặc định (id=" +
        std::to_string(default_server_id_) + ")");
}

std::optional<UserRecord> Database::create_user(const std::string& username,
                                                const std::string& email,
                                                const std::string& display_name,
                                                const std::string& password_hash) {
    try {
        SQLite::Statement q(db_,
            "INSERT INTO users (username, email, display_name, password_hash, created_at) "
            "VALUES (?, ?, ?, ?, strftime('%s','now'))");
        q.bind(1, username);
        q.bind(2, email);
        q.bind(3, display_name);
        q.bind(4, password_hash);
        q.exec();

        UserRecord rec;
        rec.id           = static_cast<uint32_t>(db_.getLastInsertRowid());
        rec.username     = username;
        rec.email        = email;
        rec.display_name = display_name;
        return rec;
    } catch (const SQLite::Exception& e) {
        // Nhiều khả năng do vi phạm UNIQUE(username) hoặc UNIQUE(email)
        utils::Logger::instance().warning(
            std::string("[Database] create_user thất bại: ") + e.what());
        return std::nullopt;
    }
}

std::optional<UserRecord> Database::find_user(const std::string& username) {
    SQLite::Statement q(db_,
        "SELECT id, username, email, display_name FROM users WHERE username = ?");
    q.bind(1, username);
    if (q.executeStep()) {
        UserRecord rec;
        rec.id           = q.getColumn(0).getUInt();
        rec.username     = q.getColumn(1).getString();
        rec.email        = q.getColumn(2).getString();
        rec.display_name = q.getColumn(3).getString();
        return rec;
    }
    return std::nullopt;
}

bool Database::email_exists(const std::string& email) {
    SQLite::Statement q(db_, "SELECT 1 FROM users WHERE email = ?");
    q.bind(1, email);
    return q.executeStep();
}

std::string Database::get_password_hash(uint32_t user_id) {
    SQLite::Statement q(db_,
        "SELECT password_hash FROM users WHERE id = ?");
    q.bind(1, user_id);
    if (q.executeStep()) {
        return q.getColumn(0).getString();
    }
    return std::string();
}

uint32_t Database::insert_message(uint32_t channel_id,
                                  uint32_t author_id,
                                  const std::string& content,
                                  uint32_t created_at) {
    SQLite::Statement q(db_,
        "INSERT INTO messages (channel_id, author_id, content, created_at) "
        "VALUES (?, ?, ?, ?)");
    q.bind(1, channel_id);
    q.bind(2, author_id);
    q.bind(3, content);
    q.bind(4, created_at);
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

std::vector<MessageRecord> Database::recent_messages(uint32_t channel_id, int limit) {
    std::vector<MessageRecord> result;

    SQLite::Statement q(db_,
        "SELECT m.id, m.channel_id, m.author_id, u.username, m.content, m.created_at "
        "FROM messages m "
        "JOIN users u ON u.id = m.author_id "
        "WHERE m.channel_id = ? "
        "ORDER BY m.id DESC "
        "LIMIT ?");
    q.bind(1, channel_id);
    q.bind(2, limit);

    while (q.executeStep()) {
        MessageRecord rec;
        rec.id          = q.getColumn(0).getUInt();
        rec.channel_id  = q.getColumn(1).getUInt();
        rec.author_id   = q.getColumn(2).getUInt();
        rec.author_name = q.getColumn(3).getString();
        rec.content     = q.getColumn(4).getString();
        rec.created_at  = q.getColumn(5).getUInt();
        result.push_back(std::move(rec));
    }

    // Đảo lại để có thứ tự tăng dần theo thời gian.
    std::reverse(result.begin(), result.end());
    return result;
}

uint32_t Database::create_server(const std::string& name, uint32_t owner_id) {
    SQLite::Statement q(db_,
        "INSERT INTO servers (name, owner_id, created_at) "
        "VALUES (?, ?, strftime('%s','now'))");
    q.bind(1, name);
    q.bind(2, owner_id);
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

uint32_t Database::create_channel(uint32_t server_id, const std::string& name) {
    SQLite::Statement q(db_,
        "INSERT INTO channels (server_id, name, position, created_at) "
        "VALUES (?, ?, 0, strftime('%s','now'))");
    q.bind(1, server_id);
    q.bind(2, name);
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

void Database::add_member(uint32_t server_id, uint32_t user_id) {
    SQLite::Statement q(db_,
        "INSERT OR IGNORE INTO server_members (server_id, user_id, joined_at) "
        "VALUES (?, ?, strftime('%s','now'))");
    q.bind(1, server_id);
    q.bind(2, user_id);
    q.exec();
}

bool Database::is_member(uint32_t user_id, uint32_t server_id) {
    SQLite::Statement q(db_,
        "SELECT 1 FROM server_members WHERE user_id = ? AND server_id = ?");
    q.bind(1, user_id);
    q.bind(2, server_id);
    return q.executeStep();
}

std::vector<ServerRecord> Database::servers_for_user(uint32_t user_id) {
    std::vector<ServerRecord> out;
    SQLite::Statement q(db_,
        "SELECT s.id, s.name, s.owner_id FROM servers s "
        "JOIN server_members m ON m.server_id = s.id "
        "WHERE m.user_id = ? ORDER BY s.id");
    q.bind(1, user_id);
    while (q.executeStep()) {
        ServerRecord r;
        r.id       = q.getColumn(0).getUInt();
        r.name     = q.getColumn(1).getString();
        r.owner_id = q.getColumn(2).getUInt();
        out.push_back(std::move(r));
    }
    return out;
}

std::vector<ChannelRecord> Database::channels_for_server(uint32_t server_id) {
    std::vector<ChannelRecord> out;
    SQLite::Statement q(db_,
        "SELECT id, server_id, name FROM channels "
        "WHERE server_id = ? ORDER BY position, id");
    q.bind(1, server_id);
    while (q.executeStep()) {
        ChannelRecord r;
        r.id        = q.getColumn(0).getUInt();
        r.server_id = q.getColumn(1).getUInt();
        r.name      = q.getColumn(2).getString();
        out.push_back(std::move(r));
    }
    return out;
}

uint32_t Database::channel_server_id(uint32_t channel_id) {
    SQLite::Statement q(db_, "SELECT server_id FROM channels WHERE id = ?");
    q.bind(1, channel_id);
    if (q.executeStep()) {
        return q.getColumn(0).getUInt();
    }
    return 0;
}

} // namespace db
} // namespace server
} // namespace chatties
