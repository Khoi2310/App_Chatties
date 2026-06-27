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
#include <algorithm>
#include <cctype>

namespace fs = std::filesystem;
using chatties::utils::Logger;

HttpMediaServer::HttpMediaServer(const std::string& host, int port,
                                 const std::string& storage_path,
                                 chatties::server::db::Database& db)
    : m_host(host)
    , m_public_host(host == "0.0.0.0" ? "127.0.0.1" : host)
    , m_port(port)
    , m_storage_path(storage_path)
    , m_running(false)
    , m_db(db)
{
    m_svr = std::make_unique<httplib::Server>();

    if (!fs::exists(m_storage_path)) {
        fs::create_directories(m_storage_path);
    }

    // Giới hạn payload 5MB để chống tràn ổ cứng.
    m_svr->set_payload_max_length(1024 * 1024 * 5);

    setupRoutes();
}

HttpMediaServer::~HttpMediaServer() { stop(); }

bool HttpMediaServer::isValidShortcode(const std::string& s) {
    if (s.empty() || s.size() > 32) return false;
    return std::all_of(s.begin(), s.end(), [](unsigned char c) {
        return std::isalnum(c) || c == '_';
    });
}

std::string HttpMediaServer::extFromContentType(const std::string& ct) {
    if (ct == "image/png")  return ".png";
    if (ct == "image/jpeg" || ct == "image/jpg") return ".jpg";
    if (ct == "image/gif")  return ".gif";
    if (ct == "image/webp") return ".webp";
    if (ct == "video/mp4")  return ".mp4";
    return "";   // không nhận ra từ content-type
}

// Lấy đuôi file an toàn từ tên gốc (chỉ '.', chữ và số, tối đa 10 ký tự).
static std::string safeExtFromFilename(const std::string& name) {
    auto dot = name.find_last_of('.');
    if (dot == std::string::npos) return "";
    std::string ext = name.substr(dot);
    if (ext.size() > 10) return "";
    for (char c : ext) {
        if (c != '.' && !std::isalnum(static_cast<unsigned char>(c))) return "";
    }
    return ext;
}

std::string HttpMediaServer::mediaUrl(const std::string& safe_name) const {
    return "http://" + m_public_host + ":" + std::to_string(m_port) +
           "/media/" + safe_name;
}

void HttpMediaServer::setupRoutes() {
    // GET /media/... : phục vụ file tĩnh (httplib tự chặn path traversal).
    m_svr->set_mount_point("/media", m_storage_path.c_str());

    // GET /emojis : danh sách custom emoji từ DB.
    m_svr->Get("/emojis", [this](const httplib::Request&, httplib::Response& res) {
        try {
            nlohmann::json arr = nlohmann::json::array();
            for (const auto& e : m_db.get_all_custom_emojis()) {
                arr.push_back({ {"shortcode", e.shortcode}, {"url", e.image_url} });
            }
            res.status = 200;
            res.set_content(arr.dump(), "application/json");
        } catch (const std::exception& e) {
            Logger::instance().error(std::string("[Media] /emojis: ") + e.what());
            res.status = 500;
            res.set_content(nlohmann::json{{"error", "db error"}}.dump(),
                            "application/json");
        }
    });

    // POST /upload : nhận body nhị phân, lưu file, trả URL.
    m_svr->Post("/upload", [this](const httplib::Request& req, httplib::Response& res) {
        if (req.body.empty()) {
            res.status = 400;
            res.set_content(nlohmann::json{{"error", "empty payload"}}.dump(),
                            "application/json");
            return;
        }

        const std::string ct = req.get_header_value("Content-Type");
        std::string ext = extFromContentType(ct);
        if (ext.empty()) {
            // Không nhận ra từ content-type → lấy đuôi từ tên file gốc.
            ext = safeExtFromFilename(req.get_header_value("X-Filename"));
            if (ext.empty()) ext = ".bin";
        }

        const std::string safe_name = generateSafeFilename("upload" + ext);
        const std::string full_path = m_storage_path + "/" + safe_name;

        std::ofstream ofs(full_path, std::ios::binary);
        ofs.write(req.body.data(), static_cast<std::streamsize>(req.body.size()));
        if (!ofs) {
            Logger::instance().error("[Media] write failed: " + full_path);
            res.status = 500;
            res.set_content(nlohmann::json{{"error", "disk write failed"}}.dump(),
                            "application/json");
            return;
        }

        const std::string url = mediaUrl(safe_name);
        Logger::instance().info("[Media] upload -> " + url +
                                " (" + std::to_string(req.body.size()) + " bytes)");
        res.status = 200;
        res.set_content(nlohmann::json{{"url", url}}.dump(), "application/json");
    });

    // POST /upload_emoji : ảnh ở body, tên emoji ở header X-Emoji-Shortcode.
    m_svr->Post("/upload_emoji", [this](const httplib::Request& req, httplib::Response& res) {
        if (req.body.empty()) {
            res.status = 400;
            res.set_content(nlohmann::json{{"error", "empty image payload"}}.dump(),
                            "application/json");
            return;
        }

        const std::string shortcode = req.get_header_value("X-Emoji-Shortcode");
        if (!isValidShortcode(shortcode)) {
            res.status = 400;
            res.set_content(nlohmann::json{{"error", "invalid shortcode (use [A-Za-z0-9_], 1-32)"}}.dump(),
                            "application/json");
            return;
        }

        const std::string ct = req.get_header_value("Content-Type");
        std::string ext = extFromContentType(ct);
        if (ext.empty()) ext = ".png";   // emoji mặc định PNG

        const std::string safe_name = generateSafeFilename("emoji" + ext);
        const std::string full_path = m_storage_path + "/" + safe_name;

        std::ofstream ofs(full_path, std::ios::binary);
        ofs.write(req.body.data(), static_cast<std::streamsize>(req.body.size()));
        if (!ofs) {
            res.status = 500;
            res.set_content(nlohmann::json{{"error", "disk write failed"}}.dump(),
                            "application/json");
            return;
        }

        const std::string url = mediaUrl(safe_name);
        try {
            m_db.add_custom_emoji(shortcode, url);
        } catch (const std::exception& e) {
            Logger::instance().error(std::string("[Media] emoji db: ") + e.what());
            res.status = 500;
            res.set_content(nlohmann::json{{"error", "db write failed"}}.dump(),
                            "application/json");
            return;
        }

        res.status = 200;
        res.set_content(nlohmann::json{
            {"status", "success"}, {"shortcode", shortcode}, {"url", url}
        }.dump(), "application/json");
    });
}

void HttpMediaServer::start() {
    if (m_running) return;
    m_running = true;
    m_server_thread = std::thread([this]() {
        Logger::instance().info("[Media] HTTP server lắng nghe cổng " +
                                std::to_string(m_port));
        if (!m_svr->listen(m_host.c_str(), m_port)) {
            Logger::instance().error("[Media] không thể mở cổng " +
                                     std::to_string(m_port));
        }
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
    std::string ext;
    size_t dot_pos = original_filename.find_last_of('.');
    if (dot_pos != std::string::npos) ext = original_filename.substr(dot_pos);

    auto now = std::chrono::system_clock::now().time_since_epoch().count();
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> dis(1000, 9999);

    // timestamp_random.ext — tên do server sinh, không tin tên do client gửi.
    return std::to_string(now) + "_" + std::to_string(dis(gen)) + ext;
}
