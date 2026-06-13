#include "server/core/asio_server.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include "server/handlers/message_handler.h"
#include "server/handlers/user_handler.h"
#include <iostream>

namespace asio = boost::asio;
namespace chatties {
namespace server {

// ─── Connection: đại diện 1 client đang kết nối ───────────────────────────
class Connection : public std::enable_shared_from_this<Connection> {
public:
    Connection(asio::ip::tcp::socket socket,
               std::vector<std::shared_ptr<Connection>>& connections,
               MessageHandler& msg_handler)
        : socket_(std::move(socket))
        , connections_(connections)
        , msg_handler_(msg_handler)
    {}

    void start() {
        utils::Logger::instance().info("[Connection] Client mới kết nối.");
        do_read();
    }

    void deliver(const std::string& data) {
        asio::async_write(socket_,
            asio::buffer(data),
            [](std::error_code, std::size_t) {});
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

                    // Parse JSON đơn giản → MessagePacket
                    // TODO: Dùng nlohmann/json để parse đầy đủ
                    protocol::MessagePacket packet;
                    packet.content   = data;
                    packet.sender_id = 1;     // tạm hardcode
                    packet.channel_id = 1;    // tạm hardcode
                    packet.timestamp  = 0;

                    msg_handler_.handle_message(packet);

                    // Broadcast đến tất cả client khác
                    for (auto& conn : connections_) {
                        if (conn.get() != this) {
                            conn->deliver(data);
                        }
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
                auto conn = std::make_shared<Connection>(
                    std::move(socket), connections_, msg_handler
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