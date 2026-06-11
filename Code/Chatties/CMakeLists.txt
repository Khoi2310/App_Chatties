cmake_minimum_required(VERSION 3.16)
project(ChatClient VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

target_sources(Chatties
  PRIVATE
    chatclient.cpp
)

# Tìm Qt6
find_package(Qt6 REQUIRED COMPONENTS
    Core
    Widgets
    Network    # ← dùng cho QTcpSocket
    Sql        # ← dùng cho SQLite cache
)

add_executable(ChatClient
    main.cpp
    mainwindow.cpp
    mainwindow.h
    mainwindow.ui
    chatclient.cpp    # ← class kết nối server
    chatclient.h
)

target_link_libraries(ChatClient PRIVATE
    Qt6::Core
    Qt6::Widgets
    Qt6::Network
    Qt6::Sql
)