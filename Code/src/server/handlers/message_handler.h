#ifndef CHATTIES_MESSAGE_HANDLER_H
#define CHATTIES_MESSAGE_HANDLER_H

#include <string>
#include <memory>
#include "common/protocol/packet_definitions.h"

namespace chatties {
namespace server {

class MessageHandler {
public:
    MessageHandler();
    ~MessageHandler();
    
    // Trả về true nếu tin nhắn hợp lệ và đã xử lý xong.
    void handle_message(const protocol::MessagePacket& packet);
    void broadcast_message(uint32_t channel_id, const protocol::MessagePacket& packet);
    void store_message(const protocol::MessagePacket& packet);
    
private:
    void validate_message(const protocol::MessagePacket& packet);
    std::string sanitize_content(const std::string& content);
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_MESSAGE_HANDLER_H
