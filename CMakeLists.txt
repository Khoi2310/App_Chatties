cmake_minimum_required(VERSION 3.15)

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

# Đồng bộ tên project (nếu cần)
project(App_Chatties LANGUAGES CXX) 
set(CMAKE_CXX_STANDARD 17)

find_package(asio CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# Only include .cpp files in the root directory, not from vcpkg subdirectories
file(GLOB SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")

add_executable(ServerApp ${SOURCES})
target_link_libraries(ServerApp PRIVATE asio::asio nlohmann_json::nlohmann_json)