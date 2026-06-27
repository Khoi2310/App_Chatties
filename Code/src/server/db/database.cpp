#include "server/db/database.h"
#include "common/utils/logger.h"
#include <algorithm>

namespace chatties {
namespace server {
namespace db {

static bool table_has_column(SQLite::Database& db, const std::string& table, const std::string& column) {
    SQLite::Statement q(db, "PRAGMA table_info(" + table + ")");
    while (q.executeStep()) {
        if (q.getColumn("name").getString() == column) {
            return true;
        }
    }
    return false;
}

static void ensure_column(SQLite::Database& db, const std::string& table, const std::string& column,
                          const std::string& definition) {
    if (!table_has_column(db, table, column)) {
        db.exec("ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition);
    }
}

// Cắt chuỗi an toàn theo ranh giới UTF-8 (tránh cắt giữa 1 ký tự/emoji).
static std::string make_excerpt(const std::string& s, std::size_t max_bytes = 60) {
    if (s.size() <= max_bytes) return s;
    std::size_t cut = max_bytes;
    while (cut > 0 && (static_cast<unsigned char>(s[cut]) & 0xC0) == 0x80) {
        --cut;
    }
    return s.substr(0, cut) + "…";
}

Database::Database(const std::string& path)
    : db_(path, SQLite::OPEN_READWRITE | SQLite::OPEN_CREATE)
{
    // Thực thi lệnh này để bật chế độ Write-Ahead Logging
    // Cho phép HTTP và TCP đọc/ghi database cùng một lúc mà không bị crash
    db_.exec("PRAGMA journal_mode=WAL;");
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
        "  avatar_url    TEXT,"
        "  bio           TEXT,"
        "  status        TEXT,"
        "  created_at    INTEGER NOT NULL"
        ")"
    );

    ensure_column(db_, "users", "display_name", "TEXT NOT NULL DEFAULT ''");
    ensure_column(db_, "users", "password_hash", "TEXT NOT NULL DEFAULT ''");
    ensure_column(db_, "users", "avatar_url", "TEXT");
    ensure_column(db_, "users", "bio", "TEXT");
    ensure_column(db_, "users", "status", "TEXT");
    ensure_column(db_, "users", "created_at", "INTEGER NOT NULL DEFAULT 0");

    db_.exec(
        "CREATE TABLE IF NOT EXISTS messages ("
        "  id          INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  channel_id  INTEGER NOT NULL,"
        "  author_id   INTEGER NOT NULL,"
        "  content     TEXT NOT NULL,"
        "  created_at  INTEGER NOT NULL,"
        "  reply_to_id INTEGER,"
        "  edited_at   INTEGER,"
        "  deleted     INTEGER NOT NULL DEFAULT 0,"
        "  FOREIGN KEY (author_id) REFERENCES users(id)"
        ")"
    );

    db_.exec(
        "CREATE INDEX IF NOT EXISTS idx_messages_channel "
        "ON messages(channel_id, id)"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS reactions ("
        "  message_id INTEGER NOT NULL,"
        "  user_id    INTEGER NOT NULL,"
        "  emoji      TEXT    NOT NULL,"
        "  PRIMARY KEY (message_id, user_id, emoji)"
        ")"
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
    
    // [MỚI BỔ SUNG] - Bảng lưu trữ Custom Emojis
    db_.exec(
        "CREATE TABLE IF NOT EXISTS custom_emojis ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  shortcode  TEXT UNIQUE NOT NULL,"
        "  image_url  TEXT NOT NULL"
        ")"
    );

    db_.exec(
        "CREATE TABLE IF NOT EXISTS attachments ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  message_id INTEGER NOT NULL,"
        "  url        TEXT NOT NULL,"
        "  kind       TEXT NOT NULL,"
        "  filename   TEXT,"
        "  size       INTEGER"
        ")"
    );
    db_.exec(
        "CREATE INDEX IF NOT EXISTS idx_attachments_msg "
        "ON attachments(message_id)"
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
    std::lock_guard<std::mutex> lock(db_mutex_);
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
        rec.avatar_url   = std::string();
        rec.bio          = std::string();
        rec.status       = std::string();
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
        "SELECT id, username, email, display_name, avatar_url, bio, status FROM users WHERE username = ?");
    q.bind(1, username);
    if (q.executeStep()) {
        UserRecord rec;
        rec.id           = q.getColumn(0).getUInt();
        rec.username     = q.getColumn(1).getString();
        rec.email        = q.getColumn(2).getString();
        rec.display_name = q.getColumn(3).getString();
        rec.avatar_url   = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
        rec.bio          = q.getColumn(5).isNull() ? std::string() : q.getColumn(5).getString();
        rec.status       = q.getColumn(6).isNull() ? std::string() : q.getColumn(6).getString();
        return rec;
    }
    return std::nullopt;
}

std::optional<UserRecord> Database::get_user_profile(uint32_t user_id) {
    SQLite::Statement q(db_,
        "SELECT id, username, email, display_name, avatar_url, bio, status FROM users WHERE id = ?");
    q.bind(1, user_id);
    if (q.executeStep()) {
        UserRecord rec;
        rec.id           = q.getColumn(0).getUInt();
        rec.username     = q.getColumn(1).getString();
        rec.email        = q.getColumn(2).getString();
        rec.display_name = q.getColumn(3).getString();
        rec.avatar_url   = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
        rec.bio          = q.getColumn(5).isNull() ? std::string() : q.getColumn(5).getString();
        rec.status       = q.getColumn(6).isNull() ? std::string() : q.getColumn(6).getString();
        return rec;
    }
    return std::nullopt;
}

bool Database::update_user_profile(uint32_t user_id,
                                    const std::string& display_name,
                                    const std::string& bio,
                                    const std::string& avatar_url) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    try {
        SQLite::Statement q(db_,
            "UPDATE users SET display_name = ?, bio = ?, avatar_url = ? WHERE id = ?");
        q.bind(1, display_name);
        q.bind(2, bio);
        q.bind(3, avatar_url);
        q.bind(4, user_id);
        q.exec();
        return db_.getChanges() > 0;
    } catch (const SQLite::Exception& e) {
        utils::Logger::instance().warning(
            std::string("[Database] update_user_profile thất bại: ") + e.what());
        return false;
    }
}

bool Database::update_user_avatar(uint32_t user_id, const std::string& avatar_url) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    try {
        SQLite::Statement q(db_,
            "UPDATE users SET avatar_url = ? WHERE id = ?");
        q.bind(1, avatar_url);
        q.bind(2, user_id);
        q.exec();
        return db_.getChanges() > 0;
    } catch (const SQLite::Exception& e) {
        utils::Logger::instance().warning(
            std::string("[Database] update_user_avatar thất bại: ") + e.what());
        return false;
    }
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
                                  uint32_t created_at,
                                  uint32_t reply_to_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT INTO messages (channel_id, author_id, content, created_at, reply_to_id) "
        "VALUES (?, ?, ?, ?, ?)");
    q.bind(1, channel_id);
    q.bind(2, author_id);
    q.bind(3, content);
    q.bind(4, created_at);
    if (reply_to_id != 0) q.bind(5, reply_to_id);
    else                  q.bind(5);   // NULL
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

bool Database::reply_preview(uint32_t message_id,
                             std::string& out_username,
                             std::string& out_excerpt) {
    SQLite::Statement q(db_,
        "SELECT u.username, m.content, m.deleted FROM messages m "
        "JOIN users u ON u.id = m.author_id WHERE m.id = ?");
    q.bind(1, message_id);
    if (q.executeStep()) {
        out_username = q.getColumn(0).getString();
        out_excerpt  = (q.getColumn(2).getInt() != 0)
            ? std::string("[deleted]")
            : make_excerpt(q.getColumn(1).getString());
        return true;
    }
    return false;
}

void Database::update_message(uint32_t message_id, const std::string& content,
                              uint32_t edited_at) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "UPDATE messages SET content = ?, edited_at = ? WHERE id = ?");
    q.bind(1, content);
    q.bind(2, edited_at);
    q.bind(3, message_id);
    q.exec();
}

void Database::delete_message(uint32_t message_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_, "UPDATE messages SET deleted = 1 WHERE id = ?");
    q.bind(1, message_id);
    q.exec();

    // Xóa luôn các đính kèm (ảnh/file) gửi kèm tin nhắn này.
    SQLite::Statement qa(db_, "DELETE FROM attachments WHERE message_id = ?");
    qa.bind(1, message_id);
    qa.exec();
}

uint32_t Database::message_author(uint32_t message_id) {
    SQLite::Statement q(db_, "SELECT author_id FROM messages WHERE id = ?");
    q.bind(1, message_id);
    if (q.executeStep()) return q.getColumn(0).getUInt();
    return 0;
}

uint32_t Database::message_channel(uint32_t message_id) {
    SQLite::Statement q(db_, "SELECT channel_id FROM messages WHERE id = ?");
    q.bind(1, message_id);
    if (q.executeStep()) return q.getColumn(0).getUInt();
    return 0;
}

std::vector<MessageRecord> Database::recent_messages(uint32_t channel_id, int limit) {
    std::vector<MessageRecord> result;

    SQLite::Statement q(db_,
        "SELECT m.id, m.channel_id, m.author_id, u.username, u.avatar_url, m.content, m.created_at, "
        "       m.edited_at, m.deleted, "
        "       m.reply_to_id, ru.username, rm.content, rm.deleted "
        "FROM messages m "
        "JOIN users u ON u.id = m.author_id "
        "LEFT JOIN messages rm ON rm.id = m.reply_to_id "
        "LEFT JOIN users    ru ON ru.id = rm.author_id "
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
        rec.avatar_url  = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
        rec.content     = q.getColumn(5).getString();
        rec.created_at  = q.getColumn(6).getUInt();
        rec.edited_at   = q.getColumn(7).isNull() ? 0 : q.getColumn(7).getUInt();
        rec.deleted     = q.getColumn(8).getInt() != 0;
        if (rec.deleted) rec.content.clear();    // không trả nội dung đã xóa
        rec.reply_to_id = q.getColumn(9).isNull() ? 0 : q.getColumn(9).getUInt();
        if (rec.reply_to_id != 0) {
            rec.reply_username = q.getColumn(10).getString();
            bool reply_deleted = q.getColumn(12).getInt() != 0;
            rec.reply_excerpt  = reply_deleted
                ? std::string("[deleted]")
                : make_excerpt(q.getColumn(11).getString());
        }
        result.push_back(std::move(rec));
    }

    // Đảo lại để có thứ tự tăng dần theo thời gian.
    std::reverse(result.begin(), result.end());

    // Gắn reaction + attachment cho từng tin (bỏ qua đính kèm của tin đã xóa).
    for (auto& rec : result) {
        rec.reactions = reactions_for(rec.id);
        if (!rec.deleted) rec.attachments = attachments_for(rec.id);
    }
    return result;
}

void Database::add_attachment(uint32_t message_id, const std::string& url,
                              const std::string& kind, const std::string& filename,
                              uint32_t size) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT INTO attachments (message_id, url, kind, filename, size) "
        "VALUES (?, ?, ?, ?, ?)");
    q.bind(1, message_id);
    q.bind(2, url);
    q.bind(3, kind);
    q.bind(4, filename);
    q.bind(5, size);
    q.exec();
}

std::vector<AttachmentRecord> Database::attachments_for(uint32_t message_id) {
    std::vector<AttachmentRecord> out;
    SQLite::Statement q(db_,
        "SELECT url, kind, filename, size FROM attachments "
        "WHERE message_id = ? ORDER BY id");
    q.bind(1, message_id);
    while (q.executeStep()) {
        AttachmentRecord a;
        a.url      = q.getColumn(0).getString();
        a.kind     = q.getColumn(1).getString();
        a.filename = q.getColumn(2).getString();
        a.size     = q.getColumn(3).getUInt();
        out.push_back(std::move(a));
    }
    return out;
}

void Database::add_reaction(uint32_t message_id, uint32_t user_id,
                            const std::string& emoji) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT OR IGNORE INTO reactions (message_id, user_id, emoji) "
        "VALUES (?, ?, ?)");
    q.bind(1, message_id);
    q.bind(2, user_id);
    q.bind(3, emoji);
    q.exec();
}

void Database::remove_reaction(uint32_t message_id, uint32_t user_id,
                               const std::string& emoji) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "DELETE FROM reactions WHERE message_id = ? AND user_id = ? AND emoji = ?");
    q.bind(1, message_id);
    q.bind(2, user_id);
    q.bind(3, emoji);
    q.exec();
}

bool Database::reaction_exists(uint32_t message_id, uint32_t user_id,
                               const std::string& emoji) {
    SQLite::Statement q(db_,
        "SELECT 1 FROM reactions WHERE message_id = ? AND user_id = ? AND emoji = ?");
    q.bind(1, message_id);
    q.bind(2, user_id);
    q.bind(3, emoji);
    return q.executeStep();
}

std::vector<ReactionCount> Database::reactions_for(uint32_t message_id) {
    std::vector<ReactionCount> out;
    SQLite::Statement q(db_,
        "SELECT emoji, COUNT(*) FROM reactions WHERE message_id = ? "
        "GROUP BY emoji ORDER BY COUNT(*) DESC, emoji");
    q.bind(1, message_id);
    while (q.executeStep()) {
        ReactionCount r;
        r.emoji = q.getColumn(0).getString();
        r.count = q.getColumn(1).getUInt();
        out.push_back(std::move(r));
    }
    return out;
}

uint32_t Database::create_server(const std::string& name, uint32_t owner_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT INTO servers (name, owner_id, created_at) "
        "VALUES (?, ?, strftime('%s','now'))");
    q.bind(1, name);
    q.bind(2, owner_id);
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

uint32_t Database::create_channel(uint32_t server_id, const std::string& name) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT INTO channels (server_id, name, position, created_at) "
        "VALUES (?, ?, 0, strftime('%s','now'))");
    q.bind(1, server_id);
    q.bind(2, name);
    q.exec();
    return static_cast<uint32_t>(db_.getLastInsertRowid());
}

void Database::add_member(uint32_t server_id, uint32_t user_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
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

bool Database::server_exists(uint32_t server_id) {
    SQLite::Statement q(db_, "SELECT 1 FROM servers WHERE id = ?");
    q.bind(1, server_id);
    return q.executeStep();
}

std::unordered_set<uint32_t> Database::member_ids(uint32_t server_id) {
    std::unordered_set<uint32_t> out;
    SQLite::Statement q(db_,
        "SELECT user_id FROM server_members WHERE server_id = ?");
    q.bind(1, server_id);
    while (q.executeStep())
        out.insert(q.getColumn(0).getUInt());
    return out;
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

void Database::add_custom_emoji(const std::string& shortcode, const std::string& image_url) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    // Dùng INSERT OR REPLACE để tự động cập nhật ảnh nếu shortcode đã tồn tại
    // Chống SQL Injection bằng cơ chế bind tham số của SQLiteCpp
    SQLite::Statement q(db_,
        "INSERT OR REPLACE INTO custom_emojis (shortcode, image_url) VALUES (?, ?)");
    q.bind(1, shortcode);
    q.bind(2, image_url);
    q.exec();
    
    utils::Logger::instance().info(
        "[Database] Đã lưu/cập nhật Emoji: " + shortcode + " -> " + image_url);
}

// [MỚI BỔ SUNG] - Hàm kết nối SQLite lấy danh sách
std::vector<CustomEmojiRecord> Database::get_all_custom_emojis() {
    std::vector<CustomEmojiRecord> out;
    // Sắp xếp theo ABC để Client hiển thị đẹp mắt hơn
    SQLite::Statement q(db_, "SELECT shortcode, image_url FROM custom_emojis ORDER BY shortcode ASC");
    
    while (q.executeStep()) {
        CustomEmojiRecord r;
        r.shortcode = q.getColumn(0).getString();
        r.image_url = q.getColumn(1).getString();
        out.push_back(std::move(r));
    }
    return out;
}

} // namespace db
} // namespace server
} // namespace chatties
