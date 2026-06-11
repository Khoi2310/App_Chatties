#include "server/handlers/user_handler.h"
#include "common/utils/logger.h"
#include <stdexcept>
#include <sstream>
#include <iomanip>
#include <random>

namespace chatties {
namespace server {

UserHandler::UserHandler() {
    utils::Logger::instance().info("[UserHandler] Khởi tạo xong.");
}

UserHandler::~UserHandler() {
    utils::Logger::instance().info("[UserHandler] Hủy.");
}

bool UserHandler::authenticate_user(const protocol::AuthPacket& auth) {
    try {
        // Dùng token nếu có
        if (!auth.token.empty()) {
            utils::Logger::instance().info(
                "[UserHandler] Xác thực bằng token cho user: " + auth.username
            );
            // TODO: Kiểm tra token trong Redis
            return true;
        }

        // Xác thực bằng username/password
        if (auth.username.empty() || auth.password.empty()) {
            utils::Logger::instance().warning(
                "[UserHandler] Thiếu username hoặc password."
            );
            return false;
        }

        bool result = verify_credentials(auth.username, auth.password);
        utils::Logger::instance().info(
            "[UserHandler] Xác thực " + auth.username +
            (result ? " thành công." : " thất bại.")
        );
        return result;

    } catch (const std::exception& e) {
        utils::Logger::instance().error(
            "[UserHandler] Lỗi xác thực: " + std::string(e.what())
        );
        return false;
    }
}

void UserHandler::handle_status_change(const protocol::UserStatusPacket& packet) {
    utils::Logger::instance().info(
        "[UserHandler] User " + std::to_string(packet.user_id) +
        " đổi trạng thái sang " + std::to_string(packet.status)
    );
    // TODO: Cập nhật trạng thái trong MySQL và Redis
    // TODO: Thông báo đến các user liên quan
}

void UserHandler::handle_user_join(uint32_t user_id, uint32_t server_id) {
    utils::Logger::instance().info(
        "[UserHandler] User " + std::to_string(user_id) +
        " tham gia server " + std::to_string(server_id)
    );
    // TODO: Cập nhật danh sách thành viên trong server
    // TODO: Broadcast USER_JOIN đến các user khác trong server
}

void UserHandler::handle_user_leave(uint32_t user_id, uint32_t server_id) {
    utils::Logger::instance().info(
        "[UserHandler] User " + std::to_string(user_id) +
        " rời server " + std::to_string(server_id)
    );
    // TODO: Xóa user khỏi danh sách active trong server
    // TODO: Broadcast USER_LEAVE đến các user khác
}

bool UserHandler::verify_credentials(const std::string& username,
                                     const std::string& password) {
    // TODO: Query MySQL để kiểm tra username + password_hash
    // Tạm thời hardcode để test
    return (username == "admin" && password == "admin123");
}

std::string UserHandler::generate_auth_token(uint32_t user_id) {
    // Tạo token ngẫu nhiên dạng hex
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<uint32_t> dis;

    std::ostringstream oss;
    oss << std::hex << std::setfill('0')
        << std::setw(8) << user_id
        << std::setw(8) << dis(gen)
        << std::setw(8) << dis(gen)
        << std::setw(8) << dis(gen);
    return oss.str();
}

} // namespace server
} // namespace chatties