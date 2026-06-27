#ifndef CHATTIES_PACKET_DEFINITIONS_H
#define CHATTIES_PACKET_DEFINITIONS_H

#include <cstdint>
#include <string>
#include <vector>

namespace chatties {
namespace protocol {

// Packet Types
enum class PacketType : uint8_t {
    // Authentication
    AUTH_REQUEST = 1,
    AUTH_RESPONSE = 2,
    
    // Messages
    MESSAGE_SEND = 10,
    MESSAGE_RECEIVE = 11,
    MESSAGE_ACK = 12,
    
    // Voice/Video
    VOICE_START = 20,
    VOICE_STOP = 21,
    VIDEO_START = 22,
    VIDEO_STOP = 23,
    MEDIA_FRAME = 24,
    
    // User
    USER_STATUS_CHANGE = 30,
    USER_JOIN = 31,
    USER_LEAVE = 32,
    
    // Server/Channel
    SERVER_CREATE = 40,
    CHANNEL_CREATE = 41,
    SERVER_UPDATE = 42,
    
    // Error/System
    ERROR_PACKET = 255,
};

// Base packet header
struct PacketHeader {
    uint32_t length;        // Total packet length
    PacketType type;        // Packet type
    uint32_t timestamp;     // Server timestamp
    uint32_t user_id;       // Sender user ID
};

// Authentication packet
struct AuthPacket {
    std::string username;
    std::string password;
    std::string token;      // For token-based auth
};

// Text message packet
struct MessagePacket {
    uint32_t channel_id;
    uint32_t sender_id;
    std::string username;
    std::string content;
    uint32_t timestamp;
};

// Media frame packet (voice/video)
struct MediaFramePacket {
    uint32_t sender_id;
    uint8_t media_type;     // 0: Audio, 1: Video
    std::vector<uint8_t> frame_data;
    uint32_t frame_number;
    uint32_t timestamp;
};

// User status packet
struct UserStatusPacket {
    uint32_t user_id;
    uint8_t status;         // 0: Offline, 1: Online, 2: Away, 3: In Voice
    std::string status_message;
};

} // namespace protocol
} // namespace chatties

#endif // CHATTIES_PACKET_DEFINITIONS_H
