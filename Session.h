#pragma once
#include <asio.hpp>
#include <memory>

using asio::ip::tcp;

class Session : public std::enable_shared_from_this<Session> {
public:
    Session(tcp::socket&& socket);
    void start();
private:
    void do_read();
    tcp::socket socket_;
    enum { max_length = 1024 };
    char data_[max_length];
};
