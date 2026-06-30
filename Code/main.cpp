#include "server/core/asio_server.h"
#include "server/core/http_media_server.h"
#include "server/db/database.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include <iostream>
#include <fstream>
#include <sodium.h>
#include <nlohmann/json.hpp>

// Đọc giphy_api_key từ server_config.json (tìm cwd và vài thư mục cha).
static std::string load_giphy_key() {
    const char* candidates[] = {
        "server_config.json", "../server_config.json",
        "../../server_config.json", "../../../server_config.json"
    };
    for (const char* path : candidates) {
        std::ifstream f(path);
        if (!f) continue;
        try {
            nlohmann::json j; f >> j;
            std::string key = j.value("giphy_api_key", std::string());
            if (!key.empty() && key != "PASTE_YOUR_GIPHY_API_KEY_HERE")
                return key;
        } catch (...) {}
    }
    return "";
}

int main() {
    try {
        chatties::utils::Logger::instance().initialize(
            "server.log",
            chatties::utils::LogLevel::DEBUG
        );

        // Khởi tạo libsodium (bắt buộc trước khi hash mật khẩu).
        if (sodium_init() < 0) {
            std::cerr << "[FATAL] Không thể khởi tạo libsodium\n";
            return 1;
        }

        chatties::utils::Logger::instance().info("[Main] Bắt đầu khởi chạy hệ thống Chatties...");

        // [MỚI BỔ SUNG] - Khởi tạo Database trước tiên
        // Cơ sở dữ liệu sẽ mở (hoặc tự tạo mới file chatties.db) và chạy các migration
        chatties::server::db::Database db("chatties.db");

        // 1. Khởi tạo và chạy HTTP Media Server (Cổng 8081)
        // Truyền tham chiếu `db` vào làm tham số thứ 4 để Server có thể kết nối SQLite
        std::string giphy_key = load_giphy_key();
        if (giphy_key.empty())
            chatties::utils::Logger::instance().warning(
                "[Main] Chưa có giphy_api_key trong server_config.json — GIF picker sẽ tắt.");

        HttpMediaServer media_server("0.0.0.0", 8081, "./media_storage", db, giphy_key);
        
        media_server.start();
        chatties::utils::Logger::instance().info("[Main] HTTP Media Server đang chạy tại cổng 8081");
        
        // 2. Khởi tạo TCP Chat Server (Cổng 8080)
        chatties::server::AsioServer server(
            chatties::SERVER_HOST,
            chatties::SERVER_PORT
        );

        server.start();
        server.run();
        
        // 3. Dọn dẹp khi server tắt
        media_server.stop();

    } catch (const std::exception& e) {
        std::cerr << "[FATAL] " << e.what() << "\n";
        return 1;
    }
    return 0;
}
