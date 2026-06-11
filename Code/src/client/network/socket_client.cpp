#include "socket_client.h"
#include "../../common/utils/logger.h"
#include "../../common/constants.h"
#include <stdexcept>

namespace chatties {
namespace client {

SocketClient::SocketClient(const std::string& host, uint16_t port)
    : host_(host)
    , port_(port)
    , connected_(false)
{
    utils::Logger::instance().info(
        "[SocketClient] Khởi tạo kết nối đến " + host + ":" + std::to_string(port)
    );
}

SocketClient::~SocketClient() {
    disconnect();
}

bool SocketClient::connect() {
    try {
        socket_ = std::make_unique<asio::ip::tcp::socket>(io_context_);

        asio::ip::tcp::resolver resolver(io_context_);
        auto endpoints = resolver.resolve(host_, std::to_string(port_));

        asio::connect(*socket_, endpoints);
        connected_ = true;

        utils::Logger::instance().info(
            "[SocketClient] Kết nối thành công đến " +
            host_ + ":" + std::to_string(port_)
        );
        return true;

    } catch (const std::exception& e) {
        connected_ = false;
        utils::Logger::instance().error(
            "[SocketClient] Kết nối thất bại: " + std::string(e.what())
        );
        return false;
    }
}

void SocketClient::disconnect() {
    if (connected_ && socket_) {
        try {
            socket_->shutdown(asio::ip::tcp::socket::shutdown_both);
            socket_->close();
        } catch (const std::exception& e) {
            utils::Logger::instance().warning(
                "[SocketClient] Lỗi khi đóng kết nối: " + std::string(e.what())
            );
        }
        connected_ = false;
        utils::Logger::instance().info("[SocketClient] Đã ngắt kết nối.");
    }
}

bool SocketClient::is_connected() const {
    return connected_;
}

void SocketClient::send_data(const std::string& data) {
    if (!connected_ || !socket_) {
        utils::Logger::instance().warning(
            "[SocketClient] Chưa kết nối, không thể gửi dữ liệu."
        );
        return;
    }

    try {
        // Thêm '\n' để server nhận đúng (dùng async_read_until '\n')
        std::string payload = data + "\n";
        asio::write(*socket_, asio::buffer(payload));

        utils::Logger::instance().debug(
            "[SocketClient] Đã gửi: " + data
        );
    } catch (const std::exception& e) {
        connected_ = false;
        utils::Logger::instance().error(
            "[SocketClient] Lỗi gửi dữ liệu: " + std::string(e.what())
        );
    }
}

std::string SocketClient::receive_data() {
    if (!connected_ || !socket_) {
        utils::Logger::instance().warning(
            "[SocketClient] Chưa kết nối, không thể nhận dữ liệu."
        );
        return "";
    }

    try {
        asio::streambuf buffer;
        // Đọc đến khi gặp '\n' — giống server
        asio::read_until(*socket_, buffer, '\n');

        std::string data(
            asio::buffers_begin(buffer.data()),
            asio::buffers_end(buffer.data())
        );

        // Xóa ký tự '\n' ở cuối
        if (!data.empty() && data.back() == '\n') {
            data.pop_back();
        }

        utils::Logger::instance().debug(
            "[SocketClient] Nhận được: " + data
        );
        return data;

    } catch (const std::exception& e) {
        connected_ = false;
        utils::Logger::instance().error(
            "[SocketClient] Lỗi nhận dữ liệu: " + std::string(e.what())
        );
        return "";
    }
}

} // namespace client
} // namespace chatties