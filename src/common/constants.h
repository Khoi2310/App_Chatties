#ifndef CHATTIES_CONSTANTS_H
#define CHATTIES_CONSTANTS_H

#include <string>
#include <cstdint>

namespace chatties {

// Server Configuration
constexpr const char* SERVER_HOST = "0.0.0.0";
constexpr uint16_t SERVER_PORT = 8080;
constexpr uint16_t VOICE_PORT = 8081;
constexpr uint16_t VIDEO_PORT = 8082;

// Network Settings
constexpr size_t MAX_MESSAGE_SIZE = 65536;  // 64 KB
constexpr size_t BUFFER_SIZE = 4096;
constexpr int CONNECTION_TIMEOUT = 30000;    // 30 seconds in ms

// Database Settings
constexpr const char* DB_HOST = "localhost";
constexpr const char* DB_USER = "chatties_user";
constexpr const char* DB_NAME = "chatties_db";
constexpr uint16_t DB_PORT = 3306;

// Redis Settings
constexpr const char* REDIS_HOST = "localhost";
constexpr uint16_t REDIS_PORT = 6379;

// Audio/Video Settings
constexpr int AUDIO_SAMPLE_RATE = 48000;    // Hz
constexpr int AUDIO_CHANNELS = 2;           // Stereo
constexpr int VIDEO_FRAME_RATE = 30;        // FPS
constexpr int VIDEO_WIDTH = 1280;
constexpr int VIDEO_HEIGHT = 720;

// Message Limits
constexpr size_t MAX_USERNAME_LENGTH = 32;
constexpr size_t MAX_MESSAGE_LENGTH = 2000;
constexpr size_t MAX_SERVER_NAME_LENGTH = 100;
constexpr size_t MAX_CHANNEL_NAME_LENGTH = 100;

} // namespace chatties

#endif // CHATTIES_CONSTANTS_H
