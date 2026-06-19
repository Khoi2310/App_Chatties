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

struct ServerRecord {
    uint32_t    id;
    std::string name;
    uint32_t    owner_id;
};

struct ChannelRecord {
    uint32_t    id;
    uint32_t    server_id;
    std::string name;
};

class Database {
public:
    // Mở (hoặc tạo) file DB rồi chạy migration.
    explicit Database(const std::string& path);

    // ─── Tài khoản ───────────────────────────────────────────────
    // Trả về user mới nếu thành công; nullopt nếu username/email đã tồn tại.
    std::optional<UserRecord> create_user(const std::string& username,
                                          const std::string& email,
                                          const std::string& display_name,
                                          const std::string& password_hash);

    std::optional<UserRecord> find_user(const std::string& username);

    // true nếu email đã được dùng.
    bool email_exists(const std::string& email);

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

    // ─── Server (guild) & Channel ────────────────────────────────
    uint32_t create_server(const std::string& name, uint32_t owner_id);
    uint32_t create_channel(uint32_t server_id, const std::string& name);
    void     add_member(uint32_t server_id, uint32_t user_id);
    bool     is_member(uint32_t user_id, uint32_t server_id);

    std::vector<ServerRecord>  servers_for_user(uint32_t user_id);
    std::vector<ChannelRecord> channels_for_server(uint32_t server_id);

    // server_id của channel; 0 nếu không tồn tại.
    uint32_t channel_server_id(uint32_t channel_id);

    // Server mặc định (tạo sẵn lúc khởi động).
    uint32_t default_server_id() const { return default_server_id_; }

private:
    void run_migrations();
    void seed_defaults();

    SQLite::Database db_;
    uint32_t default_server_id_ = 0;
};

} // namespace db
} // namespace server
} // namespace chatties

#endif // CHATTIES_DATABASE_H
