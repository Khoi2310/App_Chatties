#ifndef CHATTIES_DATABASE_H
#define CHATTIES_DATABASE_H

#include <cstdint>
#include <string>
#include <vector>
#include <optional>
#include <SQLiteCpp/SQLiteCpp.h>

namespace chatties {
namespace server {
namespace db {

struct UserRecord {
    uint32_t    id;
    std::string username;
    std::string email;
    std::string display_name;
};

struct MessageRecord {
    uint32_t    id;
    uint32_t    channel_id;
    uint32_t    author_id;
    std::string author_name;
    std::string content;
    uint32_t    created_at;
};

class Database {
public:
    // Mở (hoặc tạo) file DB rồi chạy migration.
    explicit Database(const std::string& path);

    // ─── Tài khoản ───────────────────────────────────────────────
    // Trả về user mới nếu thành công; nullopt nếu username đã tồn tại.
    std::optional<UserRecord> create_user(const std::string& username,
                                          const std::string& display_name,
                                          const std::string& password_hash);

    std::optional<UserRecord> find_user(const std::string& username);

    // Lấy chuỗi hash mật khẩu của user; rỗng nếu không tìm thấy.
    std::string get_password_hash(uint32_t user_id);

    // ─── Tin nhắn ────────────────────────────────────────────────
    // Trả về id của tin nhắn vừa chèn.
    uint32_t insert_message(uint32_t channel_id,
                            uint32_t author_id,
                            const std::string& content,
                            uint32_t created_at);

    // Lấy `limit` tin nhắn gần nhất của channel, sắp xếp tăng dần theo thời gian.
    std::vector<MessageRecord> recent_messages(uint32_t channel_id, int limit);

private:
    void run_migrations();

    SQLite::Database db_;
};

} // namespace db
} // namespace server
} // namespace chatties

#endif // CHATTIES_DATABASE_H
