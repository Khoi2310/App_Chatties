#ifndef CHATTIES_ASIO_SERVER_H
#define CHATTIES_ASIO_SERVER_H

#include <asio.hpp>
#include <memory>
#include <vector>
#include <string>
#include "common/constants.h"

namespace chatties {
namespace server {

class Connection;

class AsioServer {
public:
    AsioServer(const std::string& host, uint16_t port);
    ~AsioServer();
    
    void start();
    void stop();
    void run();
    
private:
    void accept_connection();
    void on_connection_accepted(std::shared_ptr<Connection> conn);
    
    asio::io_context io_context_;
    std::unique_ptr<asio::ip::tcp::acceptor> acceptor_;
    std::vector<std::shared_ptr<Connection>> connections_;
    
    std::string host_;
    uint16_t port_;
    bool running_;
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_ASIO_SERVER_H
