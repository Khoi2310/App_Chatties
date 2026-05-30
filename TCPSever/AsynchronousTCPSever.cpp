#include <iostream>
#include <memory>
#include <string>
#include <unordered_set>
#include <boost/asio.hpp>
#include <nlohmann/json.hpp>

using boost::asio::ip::tcp;
using json = nlohmann::json;

// Forward declaration
class ChatSession;

// ==========================================
// 1. QUẢN LÝ ROOM / DANH SÁCH CLIENT (Room Manager)
// ==========================================
class ChatRoom {
public:
    void join(std::shared_ptr<ChatSession> session) {
        sessions_.insert(session);
        std::cout << "[Room] Client joined. Total connected: " << sessions_.size() << "\n";
    }

    void leave(std::shared_ptr<ChatSession> session) {
        sessions_.erase(session);
        std::cout << "[Room] Client left. Total connected: " << sessions_.size() << "\n";
    }

    void broadcast(const std::string& message, std::shared_ptr<ChatSession> sender) {
        for (auto& session : sessions_) {
            // Không gửi ngược lại chính người gửi
            if (session != sender) {
                session->deliver(message);
            }
        }
    }

private:
    std::unordered_set<std::shared_ptr<ChatSession>> sessions_;
};

// ==========================================
// 2. LỚP XỬ LÝ PHIÊN KẾT NỐI (Client Session)
// ==========================================
class ChatSession : public std::enable_shared_from_this<ChatSession> {
public:
    ChatSession(tcp::socket socket, ChatRoom& room)
        : socket_(std::move(socket)), room_(room) {}

    ~ChatSession() {
        std::cout << "[Session] Destructor called.\n";
    }

    void start() {
        room_.join(shared_from_this());
        do_read();
    }

    void deliver(const std::string& message) {
        auto self(shared_from_this());
        // Sử dụng post để đảm bảo an toàn luồng nếu ghi từ nhiều thread khác nhau
        boost::asio::post(socket_.get_executor(), [this, self, message]() {
            bool write_in_progress = !write_msgs_.empty();
            write_msgs_.push_back(message + "\n"); // Thêm delimiter ký tự xuống dòng
            if (!write_in_progress) {
                do_write();
            }
            });
    }

private:
    void do_read() {
        auto self(shared_from_this());
        // Đọc dữ liệu theo dòng (đến khi gặp ký tự '\n')
        boost::asio::async_read_until(socket_, buffer_, '\n',
            [this, self](boost::system::error_code ec, std::size_t length) {
                if (!ec) {
                    std::string message;
                    std::istream is(&buffer_);
                    std::getline(is, message);

                    // Xử lý dữ liệu nhận được
                    process_message(message);

                    // Tiếp tục đọc dữ liệu tiếp theo từ Client
                    do_read();
                }
                else {
                    // Xử lý khi Client ngắt kết nối hoặc có lỗi xảy ra
                    std::cerr << "[Session] Read error/Disconnect: " << ec.message() << "\n";
                    room_.leave(shared_from_this());
                }
            });
    }

    void process_message(const std::string& raw_message) {
        try {
            // Phân tích cú pháp chuỗi JSON nhận được
            auto js = json::parse(raw_message);

            // Kiểm tra định dạng JSON có khớp yêu cầu hay không
            if (js.contains("type") && js["type"] == "message") {
                int channel_id = js["channel_id"];
                int sender_id = js["sender_id"];
                std::string content = js["content"];

                std::cout << "[Broadcast] From Client " << sender_id
                    << " in Channel " << channel_id << ": " << content << "\n";

                // Tiến hành broadcast tới toàn bộ client khác
                // Giữ nguyên định dạng gốc để forward
                room_.broadcast(raw_message, shared_from_this());
            }
        }
        catch (const json::parse_error& e) {
            std::cerr << "[JSON Error] Cú pháp không hợp lệ: " << e.what() << "\n";
        }
        catch (const json::type_error& e) {
            std::cerr << "[JSON Error] Sai kiểu dữ liệu field: " << e.what() << "\n";
        }
        catch (const std::exception& e) {
            std::cerr << "[Error] Lỗi hệ thống: " << e.what() << "\n";
        }
    }

    void do_write() {
        auto self(shared_from_this());
        boost::asio::async_write(socket_, boost::asio::buffer(write_msgs_.front()),
            [this, self](boost::system::error_code ec, std::size_t /*length*/) {
                if (!ec) {
                    write_msgs_.pop_front();
                    if (!write_msgs_.empty()) {
                        do_write();
                    }
                }
                else {
                    std::cerr << "[Session] Write error: " << ec.message() << "\n";
                    room_.leave(shared_from_this());
                }
            });
    }

    tcp::socket socket_;
    ChatRoom& room_;
    boost::asio::streambuf buffer_;
    std::deque<std::string> write_msgs_; // Queue quản lý các tin nhắn chờ gửi đi
};

// ==========================================
// 3. LỚP LẮNG NGHE KẾT NỐI (TCP Server)
// ==========================================
class ChatServer {
public:
    ChatServer(boost::asio::io_context& io_context, short port)
        : acceptor_(io_context, tcp::endpoint(tcp::v4(), port)) {
        std::cout << "[Server] Started on port " << port << ". Waiting for connections...\n";
        do_accept();
    }

private:
    void do_accept() {
        // Chờ kết nối bất đồng bộ một cách liên tục
        acceptor_.async_accept(
            [this](boost::system::error_code ec, tcp::socket socket) {
                if (!ec) {
                    std::cout << "[Server] Accepted new connection from: "
                        << socket.remote_endpoint() << "\n";

                    // Tạo một Session mới, cấp phát động qua shared_ptr và chạy
                    std::make_shared<ChatSession>(std::move(socket), room_)->start();
                }
                else {
                    std::cerr << "[Server] Accept error: " << ec.message() << "\n";
                }

                // Tiếp tục vòng lặp đón nhận kết nối mới
                do_accept();
            });
    }

    tcp::acceptor acceptor_;
    ChatRoom room_;
};

// ==========================================
// 4. HÀM MAIN CHẠY SERVER
// ==========================================
int main() {
    try {
        boost::asio::io_context io_context;

        // Khởi tạo Server lắng nghe tại port 8080
        ChatServer server(io_context, 8080);

        // Chạy vòng lặp sự kiện bất đồng bộ
        io_context.run();
    }
    catch (const std::exception& e) {
        std::cerr << "[Fatal Error] Exception in main: " << e.what() << "\n";
    }

    return 0;
}