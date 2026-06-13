cmake_minimum_required(VERSION 3.16)

project(Chatties VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_compile_definitions(_WIN32_WINNT=0x0601)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ← Thêm vcpkg toolchain
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Widgets Network Sql)

# Qt client uses QTcpSocket (Qt6::Network), so it does NOT need Asio.
# The alternate Asio-based client in ../src/client/ is intentionally
# left out of this target to avoid duplicate MainWindow classes and a
# Boost/standalone-Asio mismatch. Those files remain in the repo.
add_executable(Chatties
    main.cpp
    mainwindow.cpp
    mainwindow.h
    mainwindow.ui
    chatclient.cpp
    chatclient.h
)

target_include_directories(Chatties PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(Chatties PRIVATE
    Qt6::Core
    Qt6::Widgets
    Qt6::Network
    Qt6::Sql
)