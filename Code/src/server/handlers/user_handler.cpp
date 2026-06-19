#include "server/handlers/user_handler.h"
#include "common/utils/logger.h"
#include <sodium.h>

namespace chatties {
namespace server {

UserHandler::UserHandler(db::Database& database)
    : db_(database)
{
    utils::Logger::instance().info("[UserHandler] Khởi tạo xong.");
}

std::optional<db::UserRecord> UserHandler::register_user(const std::string& username,
                                                         const std::string& password,
                                                         const std::string& display_name) {
    if (username.size() < 3 || username.size() > 32) {
        utils::Logger::instance().warning("[UserHandler] Username không hợp lệ.");
        return std::nullopt;
    }
    if (password.size() < 6) {
        utils::Logger::instance().warning("[UserHandler] Mật khẩu quá ngắn.");
        return std::nullopt;
    }
    if (db_.find_user(username)) {
        utils::Logger::instance().warning("[UserHandler] Username đã tồn tại: " + username);
        return std::nullopt;
    }

    std::string hash = hash_password(password);
    if (hash.empty()) return std::nullopt;

    std::string display = display_name.empty() ? username : display_name;
    auto rec = db_.create_user(username, display, hash);
    if (rec) {
        utils::Logger::instance().info("[UserHandler] Đã đăng ký user: " + username);
    }
    return rec;
}

std::optional<db::UserRecord> UserHandler::authenticate(const std::string& username,
                                                        const std::string& password) {
    auto rec = db_.find_user(username);
    if (!rec) {
        utils::Logger::instance().warning("[UserHandler] Không tìm thấy user: " + username);
        return std::nullopt;
    }
    std::string hash = db_.get_password_hash(rec->id);
    if (!verify_password(hash, password)) {
        utils::Logger::instance().warning("[UserHandler] Sai mật khẩu cho: " + username);
        return std::nullopt;
    }
    utils::Logger::instance().info("[UserHandler] Đăng nhập thành công: " + username);
    return rec;
}

std::string UserHandler::hash_password(const std::string& password) {
    char hashed[crypto_pwhash_STRBYTES];
    if (crypto_pwhash_str(
            hashed,
            password.c_str(), password.size(),
            crypto_pwhash_OPSLIMIT_INTERACTIVE,
            crypto_pwhash_MEMLIMIT_INTERACTIVE) != 0) {
        utils::Logger::instance().error("[UserHandler] Hash mật khẩu thất bại (thiếu RAM?).");
        return std::string();
    }
    return std::string(hashed);
}

bool UserHandler::verify_password(const std::string& hash, const std::string& password) {
    if (hash.empty()) return false;
    return crypto_pwhash_str_verify(
               hash.c_str(),
               password.c_str(), password.size()) == 0;
}

} // namespace server
} // namespace chatties
