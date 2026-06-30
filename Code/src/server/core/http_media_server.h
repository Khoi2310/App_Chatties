#pragma once
#include <thread>
#include <string>
#include <memory>
#include "server/db/database.h"

// Forward declaration để tránh lỗi biên dịch LNK2005
namespace httplib { class Server; }

class HttpMediaServer {
public:
    HttpMediaServer(const std::string& host, int port, const std::string& storage_path,
                    chatties::server::db::Database& db,
                    const std::string& giphy_key = "");
    ~HttpMediaServer();

    void start();
    void stop();

private:
    std::string m_host;        // địa chỉ bind (vd 0.0.0.0)
    std::string m_public_host; // host dùng trong URL trả về client
    int m_port;
    std::string m_storage_path;
    std::string m_giphy_key;   // API key Giphy (giữ ở server)

    std::unique_ptr<httplib::Server> m_svr;
    std::thread m_server_thread;
    bool m_running;

    chatties::server::db::Database& m_db;

    void setupRoutes();
    std::string generateSafeFilename(const std::string& original_filename);
    std::string mediaUrl(const std::string& safe_name) const;

    // shortcode chỉ cho phép [A-Za-z0-9_], dài 1..32.
    static bool isValidShortcode(const std::string& s);
    // Suy ra đuôi file từ Content-Type; trả "" nếu không hỗ trợ.
    static std::string extFromContentType(const std::string& ct);
};