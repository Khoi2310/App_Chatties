cmake_minimum_required(VERSION 3.16)

project(Chatties VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
add_compile_definitions(_WIN32_WINNT=0x0601)

# Qt Quick client. Qt is found via your Qt kit / CMAKE_PREFIX_PATH (not vcpkg).
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets Network)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(Chatties
    main.cpp
    chatclient.cpp
    chatclient.h
    messagemodel.cpp
    messagemodel.h
)

# Theme.qml is a QML singleton (must be marked before qt_add_qml_module).//
set_source_files_properties(Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(Chatties
    URI Chatties
    VERSION 1.0
    QML_FILES
        Main.qml
        AuthView.qml
        ChatView.qml
        Theme.qml
)

target_link_libraries(Chatties PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    Qt6::Network
)
