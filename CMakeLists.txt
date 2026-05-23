cmake_minimum_required(VERSION 3.15)

# Đảm bảo dòng này nằm trên cùng và trỏ đúng file vcpkg.cmake của bạn
# Trỏ trực tiếp vào folder vcpkg nằm ngay trong dự án của bạn
set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/vcpkg/scripts/buildsystems/vcpkg.cmake" CACHE STRING "vcpkg toolchain")
project(DiscordCloneServer)

set(CMAKE_CXX_STANDARD 17)

# Khai báo tìm kiếm package
find_package(asio CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_executable(ServerApp main.cpp)

# Chỉ cần dòng này là tự động include và link mọi thứ của asio và json bản standalone
target_link_libraries(ServerApp PRIVATE asio::asio nlohmann_json::nlohmann_json)