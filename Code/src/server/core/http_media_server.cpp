#include "http_media_server.h"
#include "../../common/utils/logger.h"
#include <nlohmann/json.hpp>

// CHỈ DEFINE Ở ĐÂY, không được define ở file nào khác
#define CPPHTTPLIB_IMPLEMENTATION
#include <httplib.h>

#include <filesystem>
#include <fstream>
#include <chrono>
#include <random>

namespace fs = std::filesystem;

HttpMediaServer::HttpMediaServer(const std::string& host, int port, const std::string& storage_path, chatties::server::db::Database& db)
    : m_host(host), m_port(port), m_storage_path(storage_path), m_running(false), m_db(db) {
    
    m_svr = std::make_unique<httplib::Server>();

    if (!fs::exists(m_storage_path)) {
        fs::create_directories(m_storage_path);
    }

    // Chặn rủi ro: Giới hạn payload 10MB để chống bị hack tràn ổ cứng
    m_svr->set_payload_max_length(1024 * 1024 * 10);

    setupRoutes();
}

HttpMediaServer::~HttpMediaServer() { stop(); }

void HttpMediaServer::setupRoutes() {
    // API GET: Trả file tĩnh cho Client hiển thị (Inline image trên QML)
    m_svr->set_mount_point("/media", m_storage_path.c_str());

    // API GET: Lấy danh sách Emojis thực tế từ Database
    m_svr->Get("/emojis", [this](const httplib::Request& req, httplib::Response& res) {
        try {
            // 1. Lấy dữ liệu thật từ DB thông qua m_db
            auto emojis = m_db.get_all_custom_emojis();
            
            // 2. Chuyển đổi sang chuẩn JSON
            nlohmann::json emojis_list = nlohmann::json::array();
            for (const auto& e : emojis) {
                emojis_list.push_back({
                    {"shortcode", e.shortcode},
                    {"url", e.image_url}
                });
            }

            // 3. Trả về cho Client
            res.status = 200;
            res.set_content(emojis_list.dump(), "application/json");

        } catch (const std::exception& e) {
            res.status = 500;
            res.set_content(R"({"error": "Failed to fetch emojis from database"})", "application/json");
        }
    });

    // API POST: Xử lý Upload
    m_svr->Post("/upload", [this](const httplib::Request& req, httplib::Response& res) {
        
        // 1. Kiểm tra trực tiếp lõi dữ liệu thô
        if (req.body.empty()) {
            res.status = 400;
            res.set_content(R"({"error": "Empty payload"})", "application/json");
            return;
        }

        // 2. Chống giả mạo đuôi file: Lấy đuôi file dựa trên Content-Type chuẩn
        std::string ext = ".bin";
        if (req.has_header("Content-Type")) {
            std::string ct = req.get_header_value("Content-Type");
            if (ct == "image/png") ext = ".png";
            else if (ct == "image/jpeg" || ct == "image/jpg") ext = ".jpg";
            else if (ct == "image/gif") ext = ".gif";
            else if (ct == "video/mp4") ext = ".mp4";
        }

        // 3. Tận dụng lại hàm sinh tên an toàn của bạn
        std::string safe_name = generateSafeFilename("upload" + ext);
        std::string full_path = m_storage_path + "/" + safe_name;

        // 4. Ghi trực tiếp toàn bộ RAM xuống ổ cứng
        std::ofstream ofs(full_path, std::ios::binary);
        if (ofs.is_open()) {
            ofs.write(req.body.data(), req.body.size());
            ofs.close();

            // Sinh URL trả về cho Client
            std::string file_url = "http://" + m_host + ":" + std::to_string(m_port) + "/media/" + safe_name;
            std::string json_resp = R"({"url": ")" + file_url + R"("})";
            
            res.status = 200;
            res.set_content(json_resp, "application/json");
        } else {
            res.status = 500;
            res.set_content(R"({"error": "Disk write failed"})", "application/json");
        }
    });

    // API POST: Upload Custom Emoji (Thao tác 3)
    // Client truyền tên Emoji qua Header "X-Emoji-Shortcode", dữ liệu ảnh qua Body
    m_svr->Post("/upload_emoji", [this](const httplib::Request& req, httplib::Response& res) {
        
        // 1. Kiểm tra Dữ liệu thô và Tên Emoji
        if (req.body.empty()) {
            res.status = 400;
            res.set_content(R"({"error": "Empty image payload"})", "application/json");
            return;
        }

        if (!req.has_header("X-Emoji-Shortcode")) {
            res.status = 400;
            res.set_content(R"({"error": "Missing 'X-Emoji-Shortcode' header"})", "application/json");
            return;
        }

        std::string shortcode = req.get_header_value("X-Emoji-Shortcode");

        // 2. Định danh đuôi file an toàn
        std::string ext = ".png"; // Mặc định Emoji là PNG
        if (req.has_header("Content-Type")) {
            std::string ct = req.get_header_value("Content-Type");
            if (ct == "image/jpeg" || ct == "image/jpg") ext = ".jpg";
            else if (ct == "image/gif") ext = ".gif";
        }

        // 3. Ghi file ra ổ cứng
        std::string safe_name = generateSafeFilename(shortcode + ext);
        std::string full_path = m_storage_path + "/" + safe_name;

        std::ofstream ofs(full_path, std::ios::binary);
        if (ofs.is_open()) {
            ofs.write(req.body.data(), req.body.size());
            ofs.close();

            std::string file_url = "http://" + m_host + ":" + std::to_string(m_port) + "/media/" + safe_name;

            // 4. Kết nối DB thông qua m_db một cách an toàn
            try {
                m_db.add_custom_emoji(shortcode, file_url);
                
                std::string json_resp = R"({"status": "success", "shortcode": ")" + shortcode + R"(", "url": ")" + file_url + R"("})";
                res.status = 200;
                res.set_content(json_resp, "application/json");

            } catch (const std::exception& e) {
                res.status = 500;
                res.set_content(R"({"error": "Database write failed"})", "application/json");
            }
        } else {
            res.status = 500;
            res.set_content(R"({"error": "Disk write failed"})", "application/json");
        }
    });
}

void HttpMediaServer::start() {
    if (m_running) return;
    m_running = true;
    // Chạy trên luồng độc lập để không chặn Asio
    m_server_thread = std::thread([this]() {
        m_svr->listen(m_host.c_str(), m_port);
    });
}

void HttpMediaServer::stop() {
    if (m_running) {
        m_svr->stop();
        if (m_server_thread.joinable()) {
            m_server_thread.join();
        }
        m_running = false;
    }
}

std::string HttpMediaServer::generateSafeFilename(const std::string& original_filename) {
    std::string ext = "";
    size_t dot_pos = original_filename.find_last_of('.');
    // Lấy đuôi file gốc
    if (dot_pos != std::string::npos) ext = original_filename.substr(dot_pos);

    auto now = std::chrono::system_clock::now().time_since_epoch().count();
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 9999);
    
    // Format: timestamp_random.ext (Tránh ghi đè file trùng tên)
    return std::to_string(now) + "_" + std::to_string(dis(gen)) + ext;
}