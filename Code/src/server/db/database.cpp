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
    // [Forward] Tên tác giả gốc nếu tin này được chuyển tiếp.
    ensure_column(db_, "messages", "forwarded_from", "TEXT");

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
        "  server_id  INTEGER NOT NULL,"
        "  shortcode  TEXT NOT NULL,"
        "  image_url  TEXT NOT NULL,"
        "  UNIQUE(server_id, shortcode)"
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

    // [M6] Ai được nhắc (@mention) trong 1 tin nhắn.
    db_.exec(
        "CREATE TABLE IF NOT EXISTS mentions ("
        "  message_id INTEGER NOT NULL,"
        "  user_id    INTEGER NOT NULL,"
        "  PRIMARY KEY (message_id, user_id)"
        ")"
    );
    db_.exec(
        "CREATE INDEX IF NOT EXISTS idx_mentions_user "
        "ON mentions(user_id)"
    );

    // [M6] Tin nhắn cuối cùng mỗi user đã đọc trong mỗi channel.
    db_.exec(
        "CREATE TABLE IF NOT EXISTS channel_reads ("
        "  user_id          INTEGER NOT NULL,"
        "  channel_id       INTEGER NOT NULL,"
        "  last_read_msg_id INTEGER NOT NULL DEFAULT 0,"
        "  PRIMARY KEY (user_id, channel_id)"
        ")"
    );

    // [M6-6B] Quan hệ bạn bè. user_a luôn là id nhỏ hơn để (a,b) là duy nhất.
    db_.exec(
        "CREATE TABLE IF NOT EXISTS friendships ("
        "  user_a       INTEGER NOT NULL,"
        "  user_b       INTEGER NOT NULL,"
        "  status       TEXT NOT NULL,"          // 'pending' | 'accepted'
        "  requested_by INTEGER NOT NULL,"
        "  created_at   INTEGER NOT NULL,"
        "  PRIMARY KEY (user_a, user_b)"
        ")"
    );

    // [M6-6B] Thành viên của 1 kênh DM (kênh có server_id = 0).
    db_.exec(
        "CREATE TABLE IF NOT EXISTS dm_participants ("
        "  channel_id INTEGER NOT NULL,"
        "  user_id    INTEGER NOT NULL,"
        "  PRIMARY KEY (channel_id, user_id)"
        ")"
    );
    db_.exec(
        "CREATE INDEX IF NOT EXISTS idx_dm_user ON dm_participants(user_id)"
    );

    // [M7] Tin nhắn được ghim theo channel.
    db_.exec(
        "CREATE TABLE IF NOT EXISTS pins ("
        "  channel_id INTEGER NOT NULL,"
        "  message_id INTEGER NOT NULL,"
        "  pinned_by  INTEGER NOT NULL,"
        "  pinned_at  INTEGER NOT NULL,"
        "  PRIMARY KEY (channel_id, message_id)"
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
        "SELECT u.username, m.content, m.deleted, "
        "       (SELECT COUNT(*) FROM attachments a WHERE a.message_id = m.id) "
        "FROM messages m JOIN users u ON u.id = m.author_id WHERE m.id = ?");
    q.bind(1, message_id);
    if (q.executeStep()) {
        out_username = q.getColumn(0).getString();
        const bool deleted = q.getColumn(2).getInt() != 0;
        const std::string content = q.getColumn(1).getString();
        const int att_count = q.getColumn(3).getInt();
        if (deleted)               out_excerpt = "[deleted]";
        else if (!content.empty()) out_excerpt = make_excerpt(content);
        else if (att_count > 0)    out_excerpt = "[attachment]";
        else                       out_excerpt = "";
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

std::optional<MessageRecord> Database::message_by_id(uint32_t message_id) {
    SQLite::Statement q(db_,
        "SELECT m.id, m.channel_id, m.author_id, "
        "       COALESCE(NULLIF(u.display_name,''), u.username), u.avatar_url, "
        "       m.content, m.created_at, m.deleted, m.forwarded_from "
        "FROM messages m JOIN users u ON u.id = m.author_id "
        "WHERE m.id = ?");
    q.bind(1, message_id);
    if (!q.executeStep()) return std::nullopt;
    MessageRecord rec;
    rec.id             = q.getColumn(0).getUInt();
    rec.channel_id     = q.getColumn(1).getUInt();
    rec.author_id      = q.getColumn(2).getUInt();
    rec.author_name    = q.getColumn(3).getString();
    rec.avatar_url     = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
    rec.content        = q.getColumn(5).getString();
    rec.created_at     = q.getColumn(6).getUInt();
    rec.deleted        = q.getColumn(7).getInt() != 0;
    rec.forwarded_from = q.getColumn(8).isNull() ? std::string() : q.getColumn(8).getString();
    if (!rec.deleted) rec.attachments = attachments_for(rec.id);
    return rec;
}

void Database::set_forwarded_from(uint32_t message_id, const std::string& name) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_, "UPDATE messages SET forwarded_from = ? WHERE id = ?");
    q.bind(1, name);
    q.bind(2, message_id);
    q.exec();
}

std::vector<MessageRecord> Database::recent_messages(uint32_t channel_id, int limit) {
    std::vector<MessageRecord> result;

    SQLite::Statement q(db_,
        "SELECT m.id, m.channel_id, m.author_id, "
        "       COALESCE(NULLIF(u.display_name,''), u.username), u.avatar_url, "
        "       m.content, m.created_at, "
        "       m.edited_at, m.deleted, "
        "       m.reply_to_id, COALESCE(NULLIF(ru.display_name,''), ru.username), "
        "       rm.content, rm.deleted, "
        "       (SELECT COUNT(*) FROM attachments a WHERE a.message_id = rm.id), "
        "       m.forwarded_from "
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
            rec.reply_username = q.getColumn(10).getString();           // ru.username
            const bool reply_deleted = q.getColumn(12).getInt() != 0;  // rm.deleted
            const std::string reply_content = q.getColumn(11).getString(); // rm.content
            const int reply_att = q.getColumn(13).getInt();            // số đính kèm
            if (reply_deleted)               rec.reply_excerpt = "[deleted]";
            else if (!reply_content.empty()) rec.reply_excerpt = make_excerpt(reply_content);
            else if (reply_att > 0)          rec.reply_excerpt = "[attachment]";
            else                             rec.reply_excerpt = "";
        }
        rec.forwarded_from = q.getColumn(14).isNull()
            ? std::string() : q.getColumn(14).getString();
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

std::vector<UserRecord> Database::members_of(uint32_t server_id) {
    std::vector<UserRecord> out;
    SQLite::Statement q(db_,
        "SELECT u.id, u.username, u.display_name, u.avatar_url "
        "FROM server_members sm JOIN users u ON u.id = sm.user_id "
        "WHERE sm.server_id = ? ORDER BY u.username COLLATE NOCASE");
    q.bind(1, server_id);
    while (q.executeStep()) {
        UserRecord r;
        r.id           = q.getColumn(0).getUInt();
        r.username     = q.getColumn(1).getString();
        r.display_name = q.getColumn(2).isNull() ? std::string() : q.getColumn(2).getString();
        r.avatar_url   = q.getColumn(3).isNull() ? std::string() : q.getColumn(3).getString();
        out.push_back(std::move(r));
    }
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

void Database::add_custom_emoji(uint32_t server_id, const std::string& shortcode,
                                const std::string& image_url) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    // INSERT OR REPLACE: cập nhật ảnh nếu (server_id, shortcode) đã tồn tại.
    SQLite::Statement q(db_,
        "INSERT OR REPLACE INTO custom_emojis (server_id, shortcode, image_url) "
        "VALUES (?, ?, ?)");
    q.bind(1, server_id);
    q.bind(2, shortcode);
    q.bind(3, image_url);
    q.exec();

    utils::Logger::instance().info(
        "[Database] Emoji server " + std::to_string(server_id) + ": " +
        shortcode + " -> " + image_url);
}

std::vector<CustomEmojiRecord> Database::emojis_for_server(uint32_t server_id) {
    std::vector<CustomEmojiRecord> out;
    SQLite::Statement q(db_,
        "SELECT shortcode, image_url FROM custom_emojis "
        "WHERE server_id = ? ORDER BY shortcode ASC");
    q.bind(1, server_id);
    while (q.executeStep()) {
        CustomEmojiRecord r;
        r.shortcode = q.getColumn(0).getString();
        r.image_url = q.getColumn(1).getString();
        out.push_back(std::move(r));
    }
    return out;
}

void Database::delete_custom_emoji(uint32_t server_id, const std::string& shortcode) {
    // Khóa luồng để bảo vệ DB khi ghi dữ liệu
    std::lock_guard<std::mutex> lock(db_mutex_);

    // Chỉ xóa emoji của đúng server này (emoji theo từng server).
    SQLite::Statement q(db_,
        "DELETE FROM custom_emojis WHERE server_id = ? AND shortcode = ?");
    q.bind(1, server_id);
    q.bind(2, shortcode);
    q.exec();

    utils::Logger::instance().info(
        "[Database] Đã xóa Emoji (server " + std::to_string(server_id) + "): " + shortcode);
}
void Database::rename_custom_emoji(uint32_t server_id,
                                   const std::string& old_shortcode,
                                   const std::string& new_shortcode) {
    // Khóa luồng để bảo vệ DB khi ghi dữ liệu
    std::lock_guard<std::mutex> lock(db_mutex_);

    // Chỉ đổi tên emoji của đúng server này.
    SQLite::Statement q(db_,
        "UPDATE custom_emojis SET shortcode = ? WHERE server_id = ? AND shortcode = ?");
    q.bind(1, new_shortcode);
    q.bind(2, server_id);
    q.bind(3, old_shortcode);
    q.exec();

    utils::Logger::instance().info(
        "[Database] Đã đổi tên Emoji (server " + std::to_string(server_id) + "): "
        + old_shortcode + " -> " + new_shortcode);
}

// ─── [M6] Mentions & unread ──────────────────────────────────────
void Database::add_mention(uint32_t message_id, uint32_t user_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT OR IGNORE INTO mentions (message_id, user_id) VALUES (?, ?)");
    q.bind(1, message_id);
    q.bind(2, user_id);
    q.exec();
}

std::optional<uint32_t> Database::resolve_member(uint32_t server_id,
                                                 const std::string& username) {
    SQLite::Statement q(db_,
        "SELECT u.id FROM users u "
        "JOIN server_members sm ON sm.user_id = u.id "
        "WHERE sm.server_id = ? AND lower(u.username) = lower(?) LIMIT 1");
    q.bind(1, server_id);
    q.bind(2, username);
    if (q.executeStep())
        return static_cast<uint32_t>(q.getColumn(0).getInt64());
    return std::nullopt;
}

void Database::mark_channel_read(uint32_t user_id, uint32_t channel_id,
                                 uint32_t last_read_msg_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT INTO channel_reads (user_id, channel_id, last_read_msg_id) "
        "VALUES (?, ?, ?) "
        "ON CONFLICT(user_id, channel_id) DO UPDATE SET "
        "last_read_msg_id = MAX(last_read_msg_id, excluded.last_read_msg_id)");
    q.bind(1, user_id);
    q.bind(2, channel_id);
    q.bind(3, last_read_msg_id);
    q.exec();
}

std::vector<UnreadInfo> Database::unread_counts(uint32_t user_id) {
    std::vector<UnreadInfo> out;
    // Mỗi channel thuộc server user là thành viên:
    //   unread   = số tin (không phải của mình) có id > last_read.
    //   mentions = trong số đó, bao nhiêu tin nhắc tới user.
    SQLite::Statement q(db_,
        "SELECT c.id, "
        "  (SELECT COUNT(*) FROM messages m "
        "     WHERE m.channel_id = c.id AND m.deleted = 0 AND m.author_id != ? "
        "       AND m.id > COALESCE(cr.last_read_msg_id, 0)), "
        "  (SELECT COUNT(*) FROM messages m "
        "     JOIN mentions mn ON mn.message_id = m.id "
        "     WHERE m.channel_id = c.id AND m.deleted = 0 AND mn.user_id = ? "
        "       AND m.id > COALESCE(cr.last_read_msg_id, 0)) "
        "FROM channels c "
        "JOIN server_members sm ON sm.server_id = c.server_id AND sm.user_id = ? "
        "LEFT JOIN channel_reads cr ON cr.channel_id = c.id AND cr.user_id = ?");
    q.bind(1, user_id);
    q.bind(2, user_id);
    q.bind(3, user_id);
    q.bind(4, user_id);
    while (q.executeStep()) {
        UnreadInfo u;
        u.channel_id = static_cast<uint32_t>(q.getColumn(0).getInt64());
        u.unread     = static_cast<uint32_t>(q.getColumn(1).getInt64());
        u.mentions   = static_cast<uint32_t>(q.getColumn(2).getInt64());
        out.push_back(u);
    }
    return out;
}

// ─── [M6-6B] Bạn bè & DM ─────────────────────────────────────────
bool Database::send_friend_request(uint32_t from_id, uint32_t to_id) {
    if (from_id == to_id || to_id == 0) return false;
    std::lock_guard<std::mutex> lock(db_mutex_);
    uint32_t a = std::min(from_id, to_id);
    uint32_t b = std::max(from_id, to_id);
    SQLite::Statement q(db_,
        "INSERT OR IGNORE INTO friendships "
        "(user_a, user_b, status, requested_by, created_at) "
        "VALUES (?, ?, 'pending', ?, strftime('%s','now'))");
    q.bind(1, a);
    q.bind(2, b);
    q.bind(3, from_id);
    q.exec();
    return true;
}

bool Database::accept_friend_request(uint32_t me, uint32_t other) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    uint32_t a = std::min(me, other);
    uint32_t b = std::max(me, other);
    // Chỉ chấp nhận lời mời do NGƯỜI KHÁC gửi tới mình.
    SQLite::Statement q(db_,
        "UPDATE friendships SET status = 'accepted' "
        "WHERE user_a = ? AND user_b = ? AND status = 'pending' AND requested_by != ?");
    q.bind(1, a);
    q.bind(2, b);
    q.bind(3, me);
    q.exec();
    return db_.getChanges() > 0;
}

void Database::remove_friend(uint32_t me, uint32_t other) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    uint32_t a = std::min(me, other);
    uint32_t b = std::max(me, other);
    SQLite::Statement q(db_,
        "DELETE FROM friendships WHERE user_a = ? AND user_b = ?");
    q.bind(1, a);
    q.bind(2, b);
    q.exec();
}

std::vector<FriendRecord> Database::friends_of(uint32_t user_id) {
    std::vector<FriendRecord> out;
    SQLite::Statement q(db_,
        "SELECT u.id, u.username, u.display_name, u.avatar_url, f.status, f.requested_by "
        "FROM friendships f "
        "JOIN users u ON u.id = (CASE WHEN f.user_a = ?1 THEN f.user_b ELSE f.user_a END) "
        "WHERE f.user_a = ?1 OR f.user_b = ?1");
    q.bind(1, user_id);
    while (q.executeStep()) {
        FriendRecord r;
        r.user_id      = q.getColumn(0).getUInt();
        r.username     = q.getColumn(1).getString();
        r.display_name = q.getColumn(2).isNull() ? std::string() : q.getColumn(2).getString();
        r.avatar_url   = q.getColumn(3).isNull() ? std::string() : q.getColumn(3).getString();
        r.status       = q.getColumn(4).getString();
        uint32_t requested_by = q.getColumn(5).getUInt();
        r.incoming = (r.status == "pending" && requested_by != user_id);
        out.push_back(std::move(r));
    }
    return out;
}

uint32_t Database::open_dm(uint32_t a, uint32_t b) {
    // Tìm kênh DM đã có giữa a và b.
    {
        SQLite::Statement q(db_,
            "SELECT dp1.channel_id FROM dm_participants dp1 "
            "JOIN dm_participants dp2 ON dp1.channel_id = dp2.channel_id "
            "WHERE dp1.user_id = ? AND dp2.user_id = ? LIMIT 1");
        q.bind(1, a);
        q.bind(2, b);
        if (q.executeStep())
            return q.getColumn(0).getUInt();
    }
    // Chưa có → tạo kênh server_id = 0 (create_channel tự khóa mutex).
    uint32_t ch = create_channel(0, "dm");
    {
        std::lock_guard<std::mutex> lock(db_mutex_);
        for (uint32_t uid : { a, b }) {
            SQLite::Statement q(db_,
                "INSERT OR IGNORE INTO dm_participants (channel_id, user_id) VALUES (?, ?)");
            q.bind(1, ch);
            q.bind(2, uid);
            q.exec();
        }
    }
    return ch;
}

std::vector<DmRecord> Database::dm_channels_for(uint32_t user_id) {
    std::vector<DmRecord> out;
    SQLite::Statement q(db_,
        "SELECT dp2.channel_id, u.id, u.username, u.display_name, u.avatar_url "
        "FROM dm_participants dp1 "
        "JOIN dm_participants dp2 ON dp1.channel_id = dp2.channel_id "
        "  AND dp2.user_id != dp1.user_id "
        "JOIN users u ON u.id = dp2.user_id "
        "WHERE dp1.user_id = ? "
        "ORDER BY dp2.channel_id DESC");
    q.bind(1, user_id);
    while (q.executeStep()) {
        DmRecord r;
        r.channel_id         = q.getColumn(0).getUInt();
        r.other_id           = q.getColumn(1).getUInt();
        r.other_username     = q.getColumn(2).getString();
        r.other_display_name = q.getColumn(3).isNull() ? std::string() : q.getColumn(3).getString();
        r.other_avatar_url   = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
        out.push_back(std::move(r));
    }
    return out;
}

bool Database::is_dm_participant(uint32_t user_id, uint32_t channel_id) {
    SQLite::Statement q(db_,
        "SELECT 1 FROM dm_participants WHERE user_id = ? AND channel_id = ?");
    q.bind(1, user_id);
    q.bind(2, channel_id);
    return q.executeStep();
}

std::unordered_set<uint32_t> Database::dm_participant_ids(uint32_t channel_id) {
    std::unordered_set<uint32_t> out;
    SQLite::Statement q(db_,
        "SELECT user_id FROM dm_participants WHERE channel_id = ?");
    q.bind(1, channel_id);
    while (q.executeStep())
        out.insert(q.getColumn(0).getUInt());
    return out;
}

// ─── [M7] Tìm kiếm & Ghim ────────────────────────────────────────
std::vector<SearchHit> Database::search_messages(uint32_t user_id, const std::string& query,
                                                 const std::string& scope, uint32_t scope_id,
                                                 uint32_t before_id, int limit) {
    std::vector<SearchHit> out;
    if (query.empty()) return out;

    std::string sql =
        "SELECT m.id, m.channel_id, c.server_id, c.name, "
        "       COALESCE(NULLIF(u.display_name,''), u.username), m.content, m.created_at "
        "FROM messages m "
        "JOIN channels c ON c.id = m.channel_id "
        "JOIN users u ON u.id = m.author_id "
        "WHERE m.deleted = 0 "
        "  AND LOWER(m.content) LIKE '%' || LOWER(?) || '%' "
        "  AND (EXISTS (SELECT 1 FROM server_members sm "
        "               WHERE sm.server_id = c.server_id AND sm.user_id = ?) "
        "    OR EXISTS (SELECT 1 FROM dm_participants dp "
        "               WHERE dp.channel_id = c.id AND dp.user_id = ?)) ";
    if (scope == "channel")     sql += "AND m.channel_id = ? ";
    else if (scope == "server") sql += "AND c.server_id = ? ";
    if (before_id > 0)          sql += "AND m.id < ? ";
    sql += "ORDER BY m.id DESC LIMIT ?";

    SQLite::Statement q(db_, sql);
    int idx = 1;
    q.bind(idx++, query);
    q.bind(idx++, user_id);
    q.bind(idx++, user_id);
    if (scope == "channel" || scope == "server") q.bind(idx++, scope_id);
    if (before_id > 0)                           q.bind(idx++, before_id);
    q.bind(idx++, limit);

    while (q.executeStep()) {
        SearchHit h;
        h.id           = q.getColumn(0).getUInt();
        h.channel_id   = q.getColumn(1).getUInt();
        h.server_id    = q.getColumn(2).getUInt();
        h.channel_name = q.getColumn(3).getString();
        h.author_name  = q.getColumn(4).getString();
        h.content      = q.getColumn(5).getString();
        h.created_at   = q.getColumn(6).getUInt();
        out.push_back(std::move(h));
    }
    return out;
}

void Database::pin_message(uint32_t channel_id, uint32_t message_id,
                           uint32_t pinned_by, uint32_t pinned_at) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "INSERT OR IGNORE INTO pins (channel_id, message_id, pinned_by, pinned_at) "
        "VALUES (?, ?, ?, ?)");
    q.bind(1, channel_id);
    q.bind(2, message_id);
    q.bind(3, pinned_by);
    q.bind(4, pinned_at);
    q.exec();
}

void Database::unpin_message(uint32_t channel_id, uint32_t message_id) {
    std::lock_guard<std::mutex> lock(db_mutex_);
    SQLite::Statement q(db_,
        "DELETE FROM pins WHERE channel_id = ? AND message_id = ?");
    q.bind(1, channel_id);
    q.bind(2, message_id);
    q.exec();
}

bool Database::is_pinned(uint32_t channel_id, uint32_t message_id) {
    SQLite::Statement q(db_,
        "SELECT 1 FROM pins WHERE channel_id = ? AND message_id = ?");
    q.bind(1, channel_id);
    q.bind(2, message_id);
    return q.executeStep();
}

std::vector<MessageRecord> Database::pins_for(uint32_t channel_id) {
    std::vector<MessageRecord> out;
    SQLite::Statement q(db_,
        "SELECT m.id, m.channel_id, m.author_id, "
        "       COALESCE(NULLIF(u.display_name,''), u.username), u.avatar_url, "
        "       m.content, m.created_at, m.deleted "
        "FROM pins p "
        "JOIN messages m ON m.id = p.message_id "
        "JOIN users u ON u.id = m.author_id "
        "WHERE p.channel_id = ? "
        "ORDER BY p.pinned_at DESC");
    q.bind(1, channel_id);
    while (q.executeStep()) {
        MessageRecord rec;
        rec.id          = q.getColumn(0).getUInt();
        rec.channel_id  = q.getColumn(1).getUInt();
        rec.author_id   = q.getColumn(2).getUInt();
        rec.author_name = q.getColumn(3).getString();
        rec.avatar_url  = q.getColumn(4).isNull() ? std::string() : q.getColumn(4).getString();
        rec.content     = q.getColumn(5).getString();
        rec.created_at  = q.getColumn(6).getUInt();
        rec.deleted     = q.getColumn(7).getInt() != 0;
        if (rec.deleted) rec.content.clear();
        out.push_back(std::move(rec));
    }
    // [M7] Gắn đính kèm + nhãn thay thế cho tin chỉ có ảnh/gif/file.
    for (auto& rec : out) {
        if (rec.deleted) continue;
        rec.attachments = attachments_for(rec.id);
        if (rec.content.empty() && !rec.attachments.empty()) {
            const std::string& k = rec.attachments[0].kind;
            if      (k == "gif")   rec.content = "[GIF]";
            else if (k == "image") rec.content = "[image]";
            else                   rec.content = "[file] " + rec.attachments[0].filename;
        }
    }
    return out;
}

} // namespace db
} // namespace server
} // namespace chatties
