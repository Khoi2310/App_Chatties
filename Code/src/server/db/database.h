#ifndef CHATTIES_DATABASE_H
#define CHATTIES_DATABASE_H

#include <cstdint>
#include <string>
#include <vector>
#include <optional>
#include <unordered_set>
#include <mutex>
#include <SQLiteCpp/SQLiteCpp.h>

namespace chatties {
namespace server {
namespace db {

struct UserRecord {
    uint32_t    id;
    std::string username;
    std::string email;
    std::string display_name;
    std::string avatar_url;
    std::string bio;
    std::string status;
};

struct ReactionCount {
    std::string emoji;
    uint32_t    count;
};

struct AttachmentRecord {
    std::string url;
    std::string kind;       // 'image' | 'gif' | 'file'
    std::string filename;
    uint32_t    size = 0;
};

struct MessageRecord {
    uint32_t    id;
    uint32_t    channel_id;
    uint32_t    author_id;
    std::string author_name;
    std::string avatar_url;
    std::string content;
    uint32_t    created_at;
    uint32_t    reply_to_id = 0;     // 0 = không phải trả lời
    std::string reply_username;      // preview: ai được trả lời
    std::string reply_excerpt;       // preview: trích nội dung
    uint32_t    edited_at = 0;       // 0 = chưa sửa
    bool        deleted   = false;
    std::vector<ReactionCount> reactions;
    std::vector<AttachmentRecord> attachments;
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

struct CustomEmojiRecord {
    std::string shortcode;
    std::string image_url;
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
    std::optional<UserRecord> get_user_profile(uint32_t user_id);
    bool update_user_profile(uint32_t user_id,
                             const std::string& display_name,
                             const std::string& bio,
                             const std::string& avatar_url);
    bool update_user_avatar(uint32_t user_id, const std::string& avatar_url);

    // true nếu email đã được dùng.
    bool email_exists(const std::string& email);

    // Lấy chuỗi hash mật khẩu của user; rỗng nếu không tìm thấy.
    std::string get_password_hash(uint32_t user_id);

    // ─── Tin nhắn ────────────────────────────────────────────────
    // Trả về id của tin nhắn vừa chèn.
    uint32_t insert_message(uint32_t channel_id,
                            uint32_t author_id,
                            const std::string& content,
                            uint32_t created_at,
                            uint32_t reply_to_id = 0);

    // Lấy `limit` tin nhắn gần nhất của channel, sắp xếp tăng dần theo thời gian.
    std::vector<MessageRecord> recent_messages(uint32_t channel_id, int limit);

    // Lấy preview của tin được trả lời; false nếu không tồn tại.
    bool reply_preview(uint32_t message_id,
                       std::string& out_username,
                       std::string& out_excerpt);

    // Sửa / xóa (mềm) tin nhắn.
    void     update_message(uint32_t message_id, const std::string& content, uint32_t edited_at);
    void     delete_message(uint32_t message_id);
    uint32_t message_author(uint32_t message_id);   // 0 nếu không tồn tại
    uint32_t message_channel(uint32_t message_id);  // 0 nếu không tồn tại

    // ─── Reaction ────────────────────────────────────────────────
    void add_reaction(uint32_t message_id, uint32_t user_id, const std::string& emoji);
    void remove_reaction(uint32_t message_id, uint32_t user_id, const std::string& emoji);
    bool reaction_exists(uint32_t message_id, uint32_t user_id, const std::string& emoji);
    std::vector<ReactionCount> reactions_for(uint32_t message_id);

    // ─── Server (guild) & Channel ────────────────────────────────
    uint32_t create_server(const std::string& name, uint32_t owner_id);
    uint32_t create_channel(uint32_t server_id, const std::string& name);
    void     add_member(uint32_t server_id, uint32_t user_id);
    bool     is_member(uint32_t user_id, uint32_t server_id);
    bool     server_exists(uint32_t server_id);

    // Returns the set of user_ids that are members of server_id (single query).
    std::unordered_set<uint32_t> member_ids(uint32_t server_id);

    std::vector<ServerRecord>  servers_for_user(uint32_t user_id);
    std::vector<ChannelRecord> channels_for_server(uint32_t server_id);

    // server_id của channel; 0 nếu không tồn tại.
    uint32_t channel_server_id(uint32_t channel_id);

    // Server mặc định (tạo sẵn lúc khởi động).
    uint32_t default_server_id() const { return default_server_id_; }

    // ─── Attachment ────────────────────────────────────────────────
    void add_attachment(uint32_t message_id, const std::string& url,
                        const std::string& kind, const std::string& filename,
                        uint32_t size);
    std::vector<AttachmentRecord> attachments_for(uint32_t message_id);

    // ─── Custom Emoji ──────────────────────────────────────────────
    void add_custom_emoji(const std::string& shortcode, const std::string& image_url);

    // [MỚI BỔ SUNG] - Hàm quét toàn bộ Emoji
    std::vector<CustomEmojiRecord> get_all_custom_emojis();

private:
    void run_migrations();
    void seed_defaults();

    SQLite::Database db_;
    uint32_t default_server_id_ = 0;

    // Bảo vệ db_ khi truy cập từ nhiều luồng (TCP server + HTTP media server).
    // Chỉ cần khóa các thao tao GHI để tránh đua getLastInsertRowid().
    std::mutex db_mutex_;
};

} // namespace db
} // namespace server
} // namespace chatties

#endif // CHATTIES_DATABASE_H
