#include <iostream>
#include <asio.hpp>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

int main() {
    std::cout << "--- Discord Clone Server Bat Dau ---" << std::endl;

    // 1. Thử nghiệm tạo một chuỗi JSON (Giao thức truyền tin)
    json test_packet;
    test_packet["type"] = "XAC_THUC";
    test_packet["status"] = "Thành công!";
    
    std::cout << "Gói tin mẫu: " << test_packet.dump() << std::endl;

    // 2. Thử nghiệm khởi tạo vùng quản lý mạng của Asio
    try {
        asio::io_context io;
        std::cout << "Khoi tao Asio io_context thanh cong!" << std::endl;
    } catch (std::exception& e) {
        std::cerr << "Loi Asio: " << e.what() << std::endl;
    }

    return 0;
}