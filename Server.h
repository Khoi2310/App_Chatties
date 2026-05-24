#pragma once
#include <asio.hpp>
#include "Session.h"

using asio::ip::tcp;

class Server {
public:
    Server(asio::io_context& io_context, short port);
private:
    void do_accept();
    tcp::acceptor acceptor_;
};
