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
    utils::Logger::instance().info("[Database] Đã mở DB tại " + path);
}

void Database::run_migrations() {
    db_.exec(
        "CREATE TABLE IF NOT EXISTS users ("
        "  id            INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  username      TEXT UNIQUE NOT NULL,"
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
}

std::optional<UserRecord> Database::create_user(const std::string& username,
                                                const std::string& display_name,
                                                const std::string& password_hash) {
    try {
        SQLite::Statement q(db_,
            "INSERT INTO users (username, display_name, password_hash, created_at) "
            "VALUES (?, ?, ?, strftime('%s','now'))");
        q.bind(1, username);
        q.bind(2, display_name);
        q.bind(3, password_hash);
        q.exec();

        UserRecord rec;
        rec.id           = static_cast<uint32_t>(db_.getLastInsertRowid());
        rec.username     = username;
        rec.display_name = display_name;
        return rec;
    } catch (const SQLite::Exception& e) {
        // Nhiều khả năng do vi phạm UNIQUE(username)
        utils::Logger::instance().warning(
            std::string("[Database] create_user thất bại: ") + e.what());
        return std::nullopt;
    }
}

std::optional<UserRecord> Database::find_user(const std::string& username) {
    SQLite::Statement q(db_,
        "SELECT id, username, display_name FROM users WHERE username = ?");
    q.bind(1, username);
    if (q.executeStep()) {
        UserRecord rec;
        rec.id           = q.getColumn(0).getUInt();
        rec.username     = q.getColumn(1).getString();
        rec.display_name = q.getColumn(2).getString();
        return rec;
    }
    return std::nullopt;
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

} // namespace db
} // namespace server
} // namespace chatties
