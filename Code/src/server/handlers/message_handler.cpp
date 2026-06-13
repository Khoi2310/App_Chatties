#include "server/handlers/message_handler.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include <stdexcept>
#include <algorithm>

namespace chatties {
namespace server {

MessageHandler::MessageHandler() {
    utils::Logger::instance().info("[MessageHandler] Khởi tạo xong.");
}

MessageHandler::~MessageHandler() {
    utils::Logger::instance().info("[MessageHandler] Hủy.");
}

void MessageHandler::handle_message(const protocol::MessagePacket& packet) {
    try {
        // Kiểm tra hợp lệ trước
        validate_message(packet);

        utils::Logger::instance().info(
            "[MessageHandler] Nhận tin từ " + packet.username +
            " (user " + std::to_string(packet.sender_id) + ")" +
            " ở channel " + std::to_string(packet.channel_id) +
            ": " + packet.content
        );

        // Lưu vào DB rồi broadcast
        store_message(packet);
        broadcast_message(packet.channel_id, packet);

    } catch (const std::exception& e) {
        utils::Logger::instance().error(
            "[MessageHandler] Lỗi xử lý tin nhắn: " + std::string(e.what())
        );
    }
}

void MessageHandler::broadcast_message(uint32_t channel_id,
                                       const protocol::MessagePacket& packet) {
    // TODO (Bước sau): Lấy danh sách connection trong channel_id
    // rồi gửi packet đến từng connection
    utils::Logger::instance().info(
        "[MessageHandler] Broadcast channel " +
        std::to_string(channel_id)
    );
}

void MessageHandler::store_message(const protocol::MessagePacket& packet) {
    // TODO (Bước sau): Kết nối MySQL và INSERT vào bảng Messages
    utils::Logger::instance().debug(
        "[MessageHandler] Lưu tin nhắn vào DB (chưa implement MySQL)."
    );
}

void MessageHandler::validate_message(const protocol::MessagePacket& packet) {
    if (packet.content.empty()) {
        throw std::invalid_argument("Nội dung tin nhắn không được rỗng.");
    }
    if (packet.content.size() > chatties::MAX_MESSAGE_LENGTH) {
        throw std::invalid_argument("Tin nhắn vượt quá giới hạn độ dài.");
    }
    if (packet.channel_id == 0) {
        throw std::invalid_argument("channel_id không hợp lệ.");
    }
    // sender_id do server gán (>= 1)
}

std::string MessageHandler::sanitize_content(const std::string& content) {
    std::string result = content;
    // Xóa ký tự điều khiển nguy hiểm
    result.erase(std::remove_if(result.begin(), result.end(),
        [](unsigned char c) { return c < 0x20 && c != '\n' && c != '\t'; }
    ), result.end());
    return result;
}

} // namespace server
} // namespace chatties