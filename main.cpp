#include <boost/asio.hpp>
#include <nlohmann/json.hpp>
#include <iostream>
#include <set>
#include <memory>
#include <string>

using boost::asio::ip::tcp;
using json = nlohmann::json;

// =====================================================
// Session: đại diện cho 1 client đang kết nối
// =====================================================
class Session : public std::enable_shared_from_this<Session> {
public:
    // Nhận socket của client vừa kết nối
    Session(tcp::socket socket, std::set<std::shared_ptr<Session>>& clients)
        : socket_(std::move(socket)), clients_(clients) {}

    void start() {
        // Đăng ký client này vào danh sách
        clients_.insert(shared_from_this());
        do_read(); // Bắt đầu lắng nghe dữ liệu từ client
    }

    // Gửi tin nhắn đến client này
    void deliver(const std::string& message) {
        boost::asio::async_write(socket_,
            boost::asio::buffer(message),
            [](boost::system::error_code, std::size_t) {});
    }

private:
    void do_read() {
        auto self = shared_from_this();
        // Đọc dữ liệu cho đến khi gặp ký tự '\n'
        boost::asio::async_read_until(socket_, buffer_, '\n',
            [this, self](boost::system::error_code ec, std::size_t length) {
                if (!ec) {
                    // Lấy dữ liệu từ buffer
                    std::string data(
                        boost::asio::buffers_begin(buffer_.data()),
                        boost::asio::buffers_begin(buffer_.data()) + length
                    );
                    buffer_.consume(length);

                    try {
                        // Phân tích JSON
                        json msg = json::parse(data);
                        std::cout << "[Server] Nhận tin từ sender_id "
                                  << msg["sender_id"]
                                  << ": " << msg["content"] << "\n";

                        // Broadcast đến tất cả client khác
                        for (auto& client : clients_) {
                            if (client != self) {
                                client->deliver(data);
                            }
                        }
                    } catch (const json::exception& e) {
                        std::cerr << "[Lỗi JSON] " << e.what() << "\n";
                    }

                    do_read(); // Tiếp tục lắng nghe
                } else {
                    // Client ngắt kết nối → xóa khỏi danh sách
                    std::cout << "[Server] Client ngắt kết nối.\n";
                    clients_.erase(self);
                }
            });
    }

    tcp::socket socket_;
    boost::asio::streambuf buffer_;
    std::set<std::shared_ptr<Session>>& clients_;
};

// =====================================================
// Server: lắng nghe kết nối mới liên tục
// =====================================================
class ChatServer {
public:
    ChatServer(boost::asio::io_context& io, short port)
        : acceptor_(io, tcp::endpoint(tcp::v4(), port)) {
        std::cout << "[Server] Đang chạy tại cổng " << port << "...\n";
        do_accept();
    }

private:
    void do_accept() {
        acceptor_.async_accept(
            [this](boost::system::error_code ec, tcp::socket socket) {
                if (!ec) {
                    std::cout << "[Server] Client mới kết nối!\n";
                    std::make_shared<Session>(std::move(socket), clients_)->start();
                }
                do_accept(); // Tiếp tục chờ client tiếp theo
            });
    }

    tcp::acceptor acceptor_;
    std::set<std::shared_ptr<Session>> clients_;
};

// =====================================================
// main: khởi động server
// =====================================================
int main() {
    try {
        boost::asio::io_context io;
        ChatServer server(io, 8080);
        io.run(); // Chạy vòng lặp bất đồng bộ
    } catch (const std::exception& e) {
        std::cerr << "[Lỗi nghiêm trọng] " << e.what() << "\n";
    }
    return 0;
}