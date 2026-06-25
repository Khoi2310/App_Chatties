#pragma once
#include <thread>
#include <string>
#include <memory>
#include "server/db/database.h"

// Forward declaration để tránh lỗi biên dịch LNK2005
namespace httplib { class Server; }

class HttpMediaServer {
public:
    HttpMediaServer(const std::string& host, int port, const std::string& storage_path, chatties::server::db::Database& db);
    ~HttpMediaServer();

    void start();
    void stop();

private:
    std::string m_host;
    int m_port;
    std::string m_storage_path;
    
    std::unique_ptr<httplib::Server> m_svr;
    std::thread m_server_thread;
    bool m_running;

    // [MỚI BỔ SUNG] - Biến hứng lấy Database để dùng cho các luồng HTTP API
    chatties::server::db::Database& m_db;

    void setupRoutes();
    std::string generateSafeFilename(const std::string& original_filename);
};