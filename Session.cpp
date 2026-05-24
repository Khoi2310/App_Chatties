#include "Session.h"
#include <iostream>

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
                std::cout << "[Client] " << std::string(data_, length) << std::endl;
                do_read();
            }
        });
}
