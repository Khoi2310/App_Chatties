#ifndef CHATTIES_SOCKET_CLIENT_H
#define CHATTIES_SOCKET_CLIENT_H

#include <string>
#include <memory>
#include <asio.hpp>

namespace chatties {
namespace client {

class SocketClient {
public:
    SocketClient(const std::string& host, uint16_t port);
    ~SocketClient();
    
    bool connect();
    void disconnect();
    bool is_connected() const;
    
    void send_data(const std::string& data);
    std::string receive_data();
    
private:
    asio::io_context io_context_;
    std::unique_ptr<asio::ip::tcp::socket> socket_;
    std::string host_;
    uint16_t port_;
    bool connected_;
};

} // namespace client
} // namespace chatties

#endif // CHATTIES_SOCKET_CLIENT_H
