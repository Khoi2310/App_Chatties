#include "server/core/asio_server.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include "server/handlers/message_handler.h"
#include "server/handlers/user_handler.h"
#include <iostream>
#include <algorithm>
#include <chrono>
#include <nlohmann/json.hpp>

namespace asio = boost::asio;
namespace chatties {
namespace server {

// ─── Connection: đại diện 1 client đang kết nối ───────────────────────────
class Connection : public std::enable_shared_from_this<Connection> {
public:
    Connection(asio::ip::tcp::socket socket,
               std::vector<std::shared_ptr<Connection>>& connections,
               MessageHandler& msg_handler,
               uint32_t id)
        : socket_(std::move(socket))
        , connections_(connections)
        , msg_handler_(msg_handler)
        , id_(id)
    {}

    void start() {
        utils::Logger::instance().info("[Connection] Client mới kết nối.");
        do_read();
    }

    void deliver(const std::string& data) {
        // Giữ buffer sống đến khi ghi xong: async_write chạy bất đồng bộ,
        // nên dữ liệu phải tồn tại sau khi hàm này trả về.
        auto self = shared_from_this();
        auto msg  = std::make_shared<std::string>(data);
        asio::async_write(socket_,
            asio::buffer(*msg),
            [self, msg](std::error_code, std::size_t) {});
    }

private:
    void do_read() {
        auto self = shared_from_this();
        asio::async_read_until(socket_, buffer_, '\n',
            [this, self](std::error_code ec, std::size_t length) {
                if (!ec) {
                    std::string data(
                        asio::buffers_begin(buffer_.data()),
                        asio::buffers_begin(buffer_.data()) + length
                    );
                    buffer_.consume(length);

                    try {
                        // Parse JSON đến từ client
                        auto j = nlohmann::json::parse(data);

                        protocol::MessagePacket packet;
                        packet.channel_id = j.value("channel_id", 1u);
                        packet.username   = j.value("username", std::string("Unknown"));
                        packet.content    = j.value("content", std::string());
                        packet.sender_id  = id_;   // server tự gán theo connection
                        packet.timestamp  = static_cast<uint32_t>(
                            std::chrono::duration_cast<std::chrono::seconds>(
                                std::chrono::system_clock::now().time_since_epoch()
                            ).count()
                        );

                        // Kiểm tra hợp lệ + ghi log (lưu DB sẽ làm ở Phase 4).
                        // Chỉ broadcast khi tin nhắn hợp lệ.
                        if (msg_handler_.handle_message(packet)) {
                            // Tạo gói tin chuẩn do server phát đi
                            nlohmann::json out;
                            out["type"]       = "message";
                            out["channel_id"] = packet.channel_id;
                            out["sender_id"]  = packet.sender_id;
                            out["username"]   = packet.username;
                            out["content"]    = packet.content;
                            out["timestamp"]  = packet.timestamp;
                            std::string payload = out.dump() + "\n";

                            // Broadcast đến tất cả client khác
                            for (auto& conn : connections_) {
                                if (conn.get() != this) {
                                    conn->deliver(payload);
                                }
                            }
                        }
                    } catch (const std::exception& e) {
                        utils::Logger::instance().warning(
                            std::string("[Connection] Bỏ qua gói tin lỗi: ") + e.what()
                        );
                    }

                    do_read(); // Tiếp tục lắng nghe
                } else {
                    utils::Logger::instance().info(
                        "[Connection] Client ngắt kết nối."
                    );
                    // Xóa khỏi danh sách
                    connections_.erase(
                        std::remove_if(connections_.begin(), connections_.end(),
                            [this](const std::shared_ptr<Connection>& c) {
                                return c.get() == this;
                            }),
                        connections_.end()
                    );
                }
            });
    }

    asio::ip::tcp::socket socket_;
    asio::streambuf buffer_;
    std::vector<std::shared_ptr<Connection>>& connections_;
    MessageHandler& msg_handler_;
    uint32_t id_;
};

// ─── AsioServer ────────────────────────────────────────────────────────────
AsioServer::AsioServer(const std::string& host, uint16_t port)
    : host_(host)
    , port_(port)
    , running_(false)
{
    utils::Logger::instance().initialize("server.log", utils::LogLevel::DEBUG);
    utils::Logger::instance().info(
        "[AsioServer] Khởi tạo tại " + host + ":" + std::to_string(port)
    );
}

AsioServer::~AsioServer() {
    stop();
}

void AsioServer::start() {
    try {
        asio::ip::tcp::endpoint endpoint(
            asio::ip::make_address(host_), port_
        );
        acceptor_ = std::make_unique<asio::ip::tcp::acceptor>(
            io_context_, endpoint
        );
        running_ = true;
        utils::Logger::instance().info(
            "[AsioServer] Đang lắng nghe cổng " + std::to_string(port_)
        );
        accept_connection();
    } catch (const std::exception& e) {
        utils::Logger::instance().critical(
            "[AsioServer] Không thể khởi động: " + std::string(e.what())
        );
        throw;
    }
}

void AsioServer::stop() {
    if (running_) {
        running_ = false;
        io_context_.stop();
        utils::Logger::instance().info("[AsioServer] Đã dừng.");
    }
}

void AsioServer::run() {
    utils::Logger::instance().info("[AsioServer] Vòng lặp bắt đầu chạy.");
    io_context_.run();
}

void AsioServer::accept_connection() {
    acceptor_->async_accept(
        [this](std::error_code ec, asio::ip::tcp::socket socket) {
            if (!ec && running_) {
                static MessageHandler msg_handler;
                static uint32_t next_id = 1;
                auto conn = std::make_shared<Connection>(
                    std::move(socket), connections_, msg_handler, next_id++
                );
                connections_.push_back(conn);
                conn->start();
            }
            if (running_) {
                accept_connection(); // Tiếp tục chờ client mới
            }
        });
}

void AsioServer::on_connection_accepted(std::shared_ptr<Connection> conn) {
    conn->start();
}

} // namespace server
} // namespace chatties