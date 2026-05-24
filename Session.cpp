#include "Session.h"
#include <iostream>
#include <string_view>

Session::Session(tcp::socket&& socket)
    : socket_(std::move(socket)) {}

void Session::start() {
    do_read();
}

void Session::do_read() {
    auto self(shared_from_this());
    socket_.async_read_some(asio::buffer(data_, max_length),
        [this, self](std::error_code ec, std::size_t length) {
            if (!ec) {
                std::string_view message(data_, length);
                std::cout << "[Client] " << message << std::endl;
                
                do_write(length);
            } else {
                handle_error("Read error", ec);
            }
        });
}

void Session::do_write(std::size_t length) {
    auto self(shared_from_this());
    
    asio::async_write(socket_, asio::buffer(data_, length),
        [this, self](std::error_code ec, std::size_t) {
            if (!ec) {
                do_read();
            } else {
                handle_error("Write error", ec);
            }
        });
}

void Session::handle_error(const std::string& context, std::error_code ec) {
    if (ec == asio::error::eof) {
        std::cout << "[Server] Client disconnected smoothly." << std::endl;
    } else if (ec == asio::error::operation_aborted) {
        // Cổng socket bị đóng chủ động, không cần log lỗi quá nghiêm trọng
    } else {
        std::cerr << "[Server] " << context << ": " << ec.message() << std::endl;
    }
}
