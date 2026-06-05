#ifndef CHATTIES_USER_HANDLER_H
#define CHATTIES_USER_HANDLER_H

#include <string>
#include <memory>
#include "../../common/protocol/packet_definitions.h"

namespace chatties {
namespace server {

class UserHandler {
public:
    UserHandler();
    ~UserHandler();
    
    bool authenticate_user(const protocol::AuthPacket& auth);
    void handle_status_change(const protocol::UserStatusPacket& packet);
    void handle_user_join(uint32_t user_id, uint32_t server_id);
    void handle_user_leave(uint32_t user_id, uint32_t server_id);
    
private:
    bool verify_credentials(const std::string& username, const std::string& password);
    std::string generate_auth_token(uint32_t user_id);
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_USER_HANDLER_H
