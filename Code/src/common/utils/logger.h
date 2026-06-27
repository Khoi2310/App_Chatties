#ifndef CHATTIES_LOGGER_H
#define CHATTIES_LOGGER_H

#include <string>
#include <fstream>
#include <iostream>
#include <sstream>
#include <chrono>

namespace chatties {
namespace utils {

enum class LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR_LEVEL = 3,
    CRITICAL = 4
};

class Logger {
public:
    static Logger& instance();
    
    void initialize(const std::string& log_file, LogLevel level);
    void log(LogLevel level, const std::string& message);
    
    void debug(const std::string& msg) { log(LogLevel::DEBUG, msg); }
    void info(const std::string& msg) { log(LogLevel::INFO, msg); }
    void warning(const std::string& msg) { log(LogLevel::WARNING, msg); }
    void error(const std::string& msg) { log(LogLevel::ERROR_LEVEL, msg); }
    void critical(const std::string& msg) { log(LogLevel::CRITICAL, msg); }
    
private:
    Logger() = default;
    ~Logger();
    
    std::string level_to_string(LogLevel level);
    std::string get_timestamp();
    
    std::ofstream log_file_;
    LogLevel current_level_;
};

} // namespace utils
} // namespace chatties

#endif // CHATTIES_LOGGER_H
