#include "server/core/asio_server.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include <iostream>
#include <sodium.h>

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

        chatties::server::AsioServer server(
            chatties::SERVER_HOST,
            chatties::SERVER_PORT
        );

        server.start();
        server.run();

    } catch (const std::exception& e) {
        std::cerr << "[FATAL] " << e.what() << "\n";
        return 1;
    }
    return 0;
}
