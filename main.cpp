
#include <iostream>
#include "Session.h"
#include "Server.h"

int main() {
    try {
        asio::io_context io_context;
        short port = 12345;
        Server server(io_context, port);
        std::cout << "TCP Server listening on port " << port << std::endl;
        io_context.run();
    } catch (std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
    }
    return 0;
}