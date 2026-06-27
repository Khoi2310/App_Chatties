#ifndef CHATTIES_ASIO_SERVER_H
#define CHATTIES_ASIO_SERVER_H

#include <boost/asio.hpp>
#include <memory>
#include <vector>
#include <string>
#include "common/constants.h"
#include "server/db/database.h"
#include "server/handlers/user_handler.h"

namespace asio = boost::asio;
namespace chatties {
namespace server {

class Connection;

class AsioServer {
public:
    AsioServer(const std::string& host, uint16_t port,
               const std::string& db_path = "chatties.db");
    ~AsioServer();

    void start();
    void stop();
    void run();

private:
    void accept_connection();

    asio::io_context io_context_;
    std::unique_ptr<asio::ip::tcp::acceptor> acceptor_;
    std::vector<std::shared_ptr<Connection>> connections_;

    db::Database db_;
    UserHandler  user_handler_;

    std::string host_;
    uint16_t port_;
    bool running_;
};

} // namespace server
} // namespace chatties

#endif // CHATTIES_ASIO_SERVER_H
