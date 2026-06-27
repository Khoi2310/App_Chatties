#include "logger.h"
#include <iomanip>
#include <ctime>

namespace chatties {
namespace utils {

Logger& Logger::instance() {
    static Logger instance;
    return instance;
}

void Logger::initialize(const std::string& log_file, LogLevel level) {
    current_level_ = level;
    log_file_.open(log_file, std::ios::app);
    if (!log_file_.is_open()) {
        std::cerr << "[Logger] Không thể mở file log: " << log_file << "\n";
    }
}

void Logger::log(LogLevel level, const std::string& message) {
    if (level < current_level_) return;

    std::string entry = "[" + get_timestamp() + "] "
                      + "[" + level_to_string(level) + "] "
                      + message;

    // In ra console
    std::cout << entry << "\n";

    // Ghi vào file nếu đã mở
    if (log_file_.is_open()) {
        log_file_ << entry << "\n";
        log_file_.flush();
    }
}

Logger::~Logger() {
    if (log_file_.is_open()) {
        log_file_.close();
    }
}

std::string Logger::level_to_string(LogLevel level) {
    switch (level) {
        case LogLevel::DEBUG:       return "DEBUG";
        case LogLevel::INFO:        return "INFO";
        case LogLevel::WARNING:     return "WARNING";
        case LogLevel::ERROR_LEVEL: return "ERROR";
        case LogLevel::CRITICAL:    return "CRITICAL";
        default:                 return "UNKNOWN";
    }
}

std::string Logger::get_timestamp() {
    auto now = std::chrono::system_clock::now();
    std::time_t t = std::chrono::system_clock::to_time_t(now);
    std::tm tm{};
#ifdef _WIN32
    localtime_s(&tm, &t);
#else
    localtime_r(&t, &tm);
#endif
    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

} // namespace utils
} // namespace chatties