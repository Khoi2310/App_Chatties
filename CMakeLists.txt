cmake_minimum_required(VERSION 3.15)

# Nếu người dùng chạy trên VS Code, tự động link tới toolchain của vcpkg nếu có file vcpkg.json
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

project(DiscordCloneServer)
set(CMAKE_CXX_STANDARD 17)

find_package(asio CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "App_Chatties/*.cpp" "App_Chatties/*.hpp")

add_executable(ServerApp ${SOURCES})
target_link_libraries(ServerApp PRIVATE asio::asio nlohmann_json::nlohmann_json)