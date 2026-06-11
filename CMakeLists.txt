cmake_minimum_required(VERSION 3.15)

if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

project(ServerApp LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(asio CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

add_executable(ServerApp
    main.cpp
    Code/src/common/utils/logger.cpp
    Code/src/server/core/asio_server.cpp
    Code/src/server/handlers/message_handler.cpp
    Code/src/server/handlers/user_handler.cpp
)

target_include_directories(ServerApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/Code/src
)

target_link_libraries(ServerApp PRIVATE
    asio::asio
    nlohmann_json::nlohmann_json
)