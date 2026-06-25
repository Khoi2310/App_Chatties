cmake_minimum_required(VERSION 3.15)

# Set vcpkg toolchain if not already set
if(DEFINED ENV{VCPKG_ROOT} AND NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

# If VCPKG_ROOT not set, fall back to the vcpkg submodule at the repo root
if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../vcpkg/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()

project(ServerApp LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find packages
find_package(Boost CONFIG REQUIRED COMPONENTS system)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(SQLiteCpp CONFIG REQUIRED)
find_package(unofficial-sodium CONFIG REQUIRED)
find_package(httplib CONFIG REQUIRED)

# Add executable
add_executable(ServerApp
    main.cpp
    src/common/utils/logger.cpp
    src/server/core/asio_server.cpp
    src/server/handlers/message_handler.cpp
    src/server/handlers/user_handler.cpp
    src/server/db/database.cpp
    src/server/core/http_media_server.cpp
)

# Include directories - now relative to Code/
target_include_directories(ServerApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Compiler definitions
target_compile_definitions(ServerApp PRIVATE
    _WIN32_WINNT=0x0A00
)

# Link libraries
# Boost.Asio is header-only; Boost::system provides both the include path
# and the compiled Boost.System library it depends on.
target_link_libraries(ServerApp PRIVATE
    Boost::system
    nlohmann_json::nlohmann_json
    SQLiteCpp
    unofficial-sodium::sodium
    httplib::httplib
)

# On Windows, Asio needs the Winsock libraries linked explicitly.
if(WIN32)
    target_link_libraries(ServerApp PRIVATE ws2_32 mswsock)
endif()
