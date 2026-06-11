cmake_minimum_required(VERSION 3.16)

project(Chatties VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Widgets
    Network
    Sql
)

add_executable(Chatties
    main.cpp
    mainwindow.cpp
    mainwindow.h
    mainwindow.ui
    chatclient.cpp
    chatclient.h
    ${CMAKE_CURRENT_SOURCE_DIR}/../src/client/network/socket_client.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../src/client/ui/main_window.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../src/common/utils/logger.cpp
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