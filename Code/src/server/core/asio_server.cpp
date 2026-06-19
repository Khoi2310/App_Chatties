#include "server/core/asio_server.h"
#include "common/utils/logger.h"
#include "common/constants.h"
#include "server/db/database.h"
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
    enum class State { Unauthenticated, Authenticated };

    Connection(asio::ip::tcp::socket socket,
               std::vector<std::shared_ptr<Connection>>& connections,
               db::Database& db,
               UserHandler& user_handler)
        : socket_(std::move(socket))
        , connections_(connections)
        , db_(db)
        , user_handler_(user_handler)
    {}

    void start() {
        utils::Logger::instance().info("[Connection] Client mới kết nối.");
        do_read();
    }

    void deliver(const std::string& data) {
        // Giữ buffer sống đến khi ghi xong (async_write chạy bất đồng bộ).
        auto self = shared_from_this();
        auto msg  = std::make_shared<std::string>(data);
        asio::async_write(socket_, asio::buffer(*msg),
            [self, msg](std::error_code, std::size_t) {});
    }

    bool is_authenticated() const { return state_ == State::Authenticated; }

private:
    static constexpr uint32_t DEFAULT_CHANNEL = 1;

    void send_op(const std::string& op, const nlohmann::json& data) {
        nlohmann::json env;
        env["op"]   = op;
        env["data"] = data;
        deliver(env.dump() + "\n");
    }

    void do_read() {
        auto self = shared_from_this();
        asio::async_read_until(socket_, buffer_, '\n',
            [this, self](std::error_code ec, std::size_t length) {
                if (!ec) {
                    std::string line(
                        asio::buffers_begin(buffer_.data()),
                        asio::buffers_begin(buffer_.data()) + length
                    );
                    buffer_.consume(length);

                    handle_line(line);
                    do_read();
                } else {
                    on_disconnect();
                }
            });
    }

    void handle_line(const std::string& line) {
        try {
            auto j = nlohmann::json::parse(line);
            std::string op = j.value("op", std::string());
            nlohmann::json data =
                j.contains("data") ? j["data"] : nlohmann::json::object();

            if (state_ == State::Unauthenticated) {
                if (op == "auth.register")   handle_register(data);
                else if (op == "auth.login") handle_login(data);
                else send_op("auth.error",
                             { {"reason", "Bạn cần đăng nhập trước."} });
            } else { // Authenticated
                if (op == "message.create")  handle_message_create(data);
                // Các op khác sẽ bổ sung ở milestone sau.
            }
        } catch (const std::exception& e) {
            utils::Logger::instance().warning(
                std::string("[Connection] Gói tin lỗi: ") + e.what());
        }
    }

    void handle_register(const nlohmann::json& data) {
        std::string username     = data.value("username", std::string());
        std::string password     = data.value("password", std::string());
        std::string display_name = data.value("display_name", std::string());

        auto rec = user_handler_.register_user(username, password, display_name);
        if (rec) {
            on_auth_success(*rec);
        } else {
            send_op("auth.error",
                    { {"reason", "Đăng ký thất bại (username đã tồn tại hoặc dữ liệu không hợp lệ)."} });
        }
    }

    void handle_login(const nlohmann::json& data) {
        std::string username = data.value("username", std::string());
        std::string password = data.value("password", std::string());

        auto rec = user_handler_.authenticate(username, password);
        if (rec) {
            on_auth_success(*rec);
        } else {
            send_op("auth.error",
                    { {"reason", "Sai tên đăng nhập hoặc mật khẩu."} });
        }
    }

    void on_auth_success(const db::UserRecord& rec) {
        state_        = State::Authenticated;
        user_id_      = rec.id;
        username_     = rec.username;
        display_name_ = rec.display_name;

        send_op("auth.ok", {
            {"user_id",      rec.id},
            {"username",     rec.username},
            {"display_name", rec.display_name}
        });

        // Gửi lịch sử gần đây.
        nlohmann::json history = nlohmann::json::array();
        for (const auto& m : db_.recent_messages(DEFAULT_CHANNEL, 50)) {
            history.push_back(message_to_json(m));
        }
        send_op("ready", { {"recent_messages", history} });
    }

    void handle_message_create(const nlohmann::json& data) {
        std::string content = data.value("content", std::string());
        if (content.empty()) return;
        if (content.size() > chatties::MAX_MESSAGE_LENGTH) {
            content = content.substr(0, chatties::MAX_MESSAGE_LENGTH);
        }

        uint32_t ts = static_cast<uint32_t>(
            std::chrono::duration_cast<std::chrono::seconds>(
                std::chrono::system_clock::now().time_since_epoch()
            ).count());

        uint32_t id = db_.insert_message(DEFAULT_CHANNEL, user_id_, content, ts);

        db::MessageRecord rec;
        rec.id          = id;
        rec.channel_id  = DEFAULT_CHANNEL;
        rec.author_id   = user_id_;
        rec.author_name = display_name_;
        rec.content     = content;
        rec.created_at  = ts;

        utils::Logger::instance().info(
            "[Message] " + display_name_ +
            " (user " + std::to_string(user_id_) + "): " + content);

        nlohmann::json env;
        env["op"]   = "message.create";
        env["data"] = message_to_json(rec);
        std::string payload = env.dump() + "\n";

        // Phát cho mọi client đã đăng nhập (kể cả người gửi).
        for (auto& conn : connections_) {
            if (conn->is_authenticated()) {
                conn->deliver(payload);
            }
        }
    }

    nlohmann::json message_to_json(const db::MessageRecord& m) {
        return {
            {"id",         m.id},
            {"channel_id", m.channel_id},
            {"author_id",  m.author_id},
            {"username",   m.author_name},
            {"content",    m.content},
            {"timestamp",  m.created_at}
        };
    }

    void on_disconnect() {
        utils::Logger::instance().info("[Connection] Client ngắt kết nối.");
        connections_.erase(
            std::remove_if(connections_.begin(), connections_.end(),
                [this](const std::shared_ptr<Connection>& c) {
                    return c.get() == this;
                }),
            connections_.end());
    }

    asio::ip::tcp::socket socket_;
    asio::streambuf buffer_;
    std::vector<std::shared_ptr<Connection>>& connections_;
    db::Database& db_;
    UserHandler&  user_handler_;

    State       state_   = State::Unauthenticated;
    uint32_t    user_id_ = 0;
    std::string username_;
    std::string display_name_;
};

// ─── AsioServer ────────────────────────────────────────────────────────────
AsioServer::AsioServer(const std::string& host, uint16_t port,
                       const std::string& db_path)
    : db_(db_path)
    , user_handler_(db_)
    , host_(host)
    , port_(port)
    , running_(false)
{
    utils::Logger::instance().info(
        "[AsioServer] Khởi tạo tại " + host + ":" + std::to_string(port));
}

AsioServer::~AsioServer() {
    stop();
}

void AsioServer::start() {
    try {
        asio::ip::tcp::endpoint endpoint(
            asio::ip::make_address(host_), port_);
        acceptor_ = std::make_unique<asio::ip::tcp::acceptor>(
            io_context_, endpoint);
        running_ = true;
        utils::Logger::instance().info(
            "[AsioServer] Đang lắng nghe cổng " + std::to_string(port_));
        accept_connection();
    } catch (const std::exception& e) {
        utils::Logger::instance().critical(
            "[AsioServer] Không thể khởi động: " + std::string(e.what()));
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
                auto conn = std::make_shared<Connection>(
                    std::move(socket), connections_, db_, user_handler_);
                connections_.push_back(conn);
                conn->start();
            }
            if (running_) {
                accept_connection();
            }
        });
}

} // namespace server
} // namespace chatties
