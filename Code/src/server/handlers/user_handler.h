#ifndef CHATTIES_USER_HANDLER_H
#define CHATTIES_USER_HANDLER_H

#include <string>
#include <optional>
#include "server/db/database.h"

namespace chatties {
namespace server {

class UserHandler {
public:
    explicit UserHandler(db::Database& database);

    // Đăng ký user mới. nullopt nếu dữ liệu không hợp lệ hoặc username/email đã tồn tại.
    std::optional<db::UserRecord> register_user(const std::string& username,
                                                const std::string& email,
                                                const std::string& password,
                                                const std::string& display_name);

    // Xác thực username/password. nullopt nếu sai thông tin.
    std::optional<db::UserRecord> authenticate(const std::string& username,
                                               const std::string& password);

private:
    std::string hash_password(const std::string& password);
    bool        verify_password(const std::string& hash, const std::string& password);

    db::Database& db_;
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_USER_HANDLER_H
