# 📊 App_Chatties Repository Structure

## 🌳 Complete Directory Tree

```
App_Chatties/
│
├── 📄 Configuration Files (Root Level)
│   ├── CMakeLists.txt                 # CMake build configuration (C++17, Asio, nlohmann-json)
│   ├── vcpkg.json                     # vcpkg dependencies manifest
│   ├── main.cpp                       # Server entry point
│   ├── README.md                      # Project overview
│   ├── .gitignore                     # Git ignore rules
│   └── .vscode/                       # VS Code workspace config
│       ├── settings.json              # IntelliSense & workspace settings
│       ├── tasks.json                 # Build/run tasks
│       └── c_cpp_properties.json      # C++ include paths
│
├── 📁 Code/ (Main Source)
│   │
│   ├── src/                           # ⭐ Primary source code
│   │   │
│   │   ├── server/                    # 🖥️ Server Components
│   │   │   ├── core/
│   │   │   │   ├── asio_server.h      # ASIO TCP/UDP async server
│   │   │   │   └── asio_server.cpp    # Server implementation
│   │   │   │
│   │   │   ├── handlers/
│   │   │   │   ├── message_handler.h  # Message routing & broadcast
│   │   │   │   ├── message_handler.cpp
│   │   │   │   ├── user_handler.h     # User auth & session management
│   │   │   │   └── user_handler.cpp
│   │   │   │
│   │   │   └── media/
│   │   │       ├── audio_processor.h  # PortAudio integration
│   │   │       └── video_processor.h  # OpenCV integration
│   │   │
│   │   ├── client/                    # 💻 Client Components
│   │   │   ├── ui/
│   │   │   │   └── main_window.h      # Qt main window & UI
│   │   │   │
│   │   │   ├── network/
│   │   │   │   └── socket_client.h    # TCP/UDP client socket
│   │   │   │
│   │   │   └── media/
│   │   │       ├── audio_manager.h    # Audio device management
│   │   │       └── video_manager.h    # Video device management
│   │   │
│   │   └── common/                    # 🔄 Shared Components
│   │       ├── protocol/
│   │       │   └── packet_definitions.h  # Protocol packet structures
│   │       │       • PacketType enum (MESSAGE, VOICE, VIDEO, AUTH, etc.)
│   │       │       • Message/Auth/Media packet structs
│   │       │       • Packet serialization helpers
│   │       │
│   │       └── utils/
│   │           ├── logger.h/.cpp      # Logging system
│   │           │   • LogLevel::DEBUG/INFO/WARNING/ERROR_LEVEL/CRITICAL
│   │           │   • File & console output
│   │           │
│   │           └── constants.h        # Global constants
│   │               • SERVER_HOST, SERVER_PORT (8080)
│   │               • VOICE_PORT (8081), VIDEO_PORT (8082)
│   │               • DB_HOST, DB_PORT (3306)
│   │               • REDIS settings
│   │               • Audio/Video config (48kHz, 30FPS, 1280x720)
│   │               • Message size limits
│   │
│   ├── database/                      # 🗄️ Database Schema
│   │   ├── schemas/
│   │   │   ├── users.sql              # Users, auth, profiles
│   │   │   ├── servers.sql            # Server instances & settings
│   │   │   ├── channels.sql           # Text/voice channels
│   │   │   ├── messages.sql           # Message history
│   │   │   └── permissions.sql        # RBAC permissions
│   │   │
│   │   └── migrations/
│   │       └── README.md              # Migration guidelines
│   │
│   ├── config/                        # ⚙️ Configuration Files
│   │   ├── server_config.json         # Server runtime config
│   │   │   • Network ports & connection limits
│   │   │   • Database credentials
│   │   │   • Redis cache settings
│   │   │   • Logging configuration
│   │   │
│   │   └── client_config.json         # Client runtime config
│   │       • Server connection params
│   │       • SQLite local cache
│   │       • UI theme & window config
│   │       • Audio/video device settings
│   │
│   ├── Chatties/                      # ⚠️ Legacy Qt Project
│   │   ├── chatclient.h/.cpp          # Early chat client
│   │   ├── mainwindow.h/.cpp          # Initial Qt window
│   │   ├── mainwindow.ui              # Qt Designer UI
│   │   ├── main.cpp                   # Legacy entry point
│   │   ├── CMakeLists.txt             # Qt build config
│   │   ├── build/                     # Legacy build artifacts
│   │   └── .qtcreator/                # Qt Creator IDE config
│   │
│   ├── README_new.md                  # Updated project documentation
│   └── SETUP_COMPLETE.md              # Setup completion summary
│
├── 📁 build/                          # 🏗️ CMake Build Artifacts
│   ├── ServerApp.sln                  # Visual Studio solution
│   ├── ServerApp.vcxproj/.filters     # MSVC project files
│   ├── ALL_BUILD.vcxproj              # CMake auto-generated project
│   ├── ZERO_CHECK.vcxproj             # CMake dependency checker
│   │
│   ├── CMakeLists.txt                 # CMake install config
│   ├── CMakeCache.txt                 # CMake configuration cache
│   ├── CMakeFiles/                    # CMake internal files
│   │   ├── cmake.check_cache
│   │   ├── cmake.verify_globs
│   │   ├── CMakeConfigureLog.yaml
│   │   ├── generate.stamp
│   │   ├── TargetDirectories.txt
│   │   ├── VerifyGlobs.cmake
│   │   ├── 3.31.6-msvc6/              # MSVC compiler version
│   │   └── pkgRedirects/
│   │
│   ├── Debug/                         # 🔴 Debug Build
│   │   └── ServerApp.exe              # Compiled executable
│   │
│   ├── ServerApp.dir/
│   │   ├── Debug/
│   │   │   ├── *.obj files            # Compiled object files
│   │   │   ├── asio_server.obj
│   │   │   ├── message_handler.obj
│   │   │   ├── user_handler.obj
│   │   │   ├── logger.obj
│   │   │   └── main.obj
│   │   │
│   │   └── ServerApp.vcxproj
│   │
│   ├── x64/
│   │   └── Debug/                     # x64 platform binaries
│   │
│   ├── vcpkg_installed/               # 📦 VCpkg Dependencies
│   │   ├── x64-windows/
│   │   │   ├── bin/                   # Runtime DLLs
│   │   │   ├── lib/                   # Static libraries
│   │   │   ├── include/               # Header files
│   │   │   │   ├── asio/              # Asio networking library
│   │   │   │   ├── nlohmann/json/     # JSON parsing
│   │   │   │   ├── sqlite3/           # SQLite3 database
│   │   │   │   └── ...
│   │   │   ├── debug/                 # Debug symbols
│   │   │   └── share/
│   │   │
│   │   └── vcpkg/
│   │
│   └── linkerrors.txt                 # Linker error log
│
├── 📁 vcpkg/                          # 📦 VCpkg Package Manager
│   ├── bootstrap-vcpkg.bat            # Windows bootstrap script
│   ├── bootstrap-vcpkg.sh             # Unix bootstrap script
│   ├── scripts/
│   │   └── buildsystems/
│   │       └── vcpkg.cmake            # CMake toolchain file
│   │
│   ├── ports/                         # Package port definitions
│   │   ├── asio/                      # Async I/O library
│   │   ├── nlohmann-json/             # JSON library
│   │   ├── sqlite3/                   # Database library
│   │   ├── vcpkg-cmake/               # CMake support
│   │   └── ... (1000+ more ports)
│   │
│   ├── installed/                     # Installed packages
│   │   ├── x64-windows/
│   │   │   └── (compiled libraries)
│   │   │
│   │   └── vcpkg/
│   │
│   ├── buildtrees/                    # Build process artifacts
│   │   ├── asio/
│   │   ├── nlohmann-json/
│   │   ├── sqlite3/
│   │   └── ...
│   │
│   ├── packages/                      # Package build outputs
│   │   ├── asio_x64-windows/
│   │   ├── nlohmann-json_x64-windows/
│   │   ├── sqlite3_x64-windows/
│   │   └── ...
│   │
│   ├── downloads/                     # Downloaded dependencies
│   │   └── tools/
│   │
│   ├── versions/                      # Version tracking
│   ├── triplets/                      # Platform configs
│   ├── toolsrc/                       # Tool source code
│   ├── docs/                          # VCpkg documentation
│   ├── README.md                      # VCpkg info
│   ├── LICENSE.txt                    # VCpkg license
│   └── NOTICE.txt                     # Legal notices
│
├── 📁 DOCX/                           # 📚 Documentation (HTML Exports)
│   ├── tailieu2.html                  # Vietnamese docs
│   └── tailieu3_no_nav.html           # Vietnamese docs (no navigation)
│
├── 📁 PPTX/                           # 🎯 Presentation Files
│   └── (presentation slides)
│
├── 📁 Extra/                          # 🗂️ Extra Resources
│   ├── structure.txt                  # Project structure notes
│   └── (miscellaneous files)
│
└── 📁 .git/                           # 🔄 Git Repository
    ├── objects/                       # Git object database
    ├── refs/                          # Branch & tag references
    ├── HEAD                           # Current branch
    └── config                         # Repository configuration
```

---

## 🎯 Component Relationships

### Data Flow Architecture
```
┌─────────────────────────────────────────────────────────┐
│                  CLIENT (Qt Desktop App)                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐       │
│  │ Main UI  │  │ Network  │  │ Media Manager    │       │
│  │ (Qt)     │  │ Client   │  │ (Audio/Video)    │       │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘       │
└───────┼──────────────┼─────────────────┼────────────────┘
        │ TCP/UDP      │                 │ Audio/Video
        │ Messages     │                 │ Streams
        │              │                 │
┌───────▼──────────────▼─────────────────▼────────────────┐
│                  SERVER (Asio C++)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐    │
│  │ Asio Server  │  │ Message      │  │ Media      │    │
│  │ (TCP/UDP)    │  │ Handler      │  │ Processor  │    │
│  └──────┬───────┘  └──────┬───────┘  └────┬───────┘    │
│         │                 │               │             │
│  ┌──────▼─────────────────▼───────────────▼────┐        │
│  │      User Handler & Session Manager         │        │
│  └──────────────────┬──────────────────────────┘        │
│                     │                                    │
└─────────────────────┼────────────────────────────────────┘
                      │
      ┌───────────────┼───────────────┐
      │               │               │
   ┌──▼──┐       ┌────▼────┐    ┌────▼────┐
   │MySQL│       │ SQLite  │    │ Redis   │
   │(DB) │       │(Local)  │    │(Cache)  │
   └─────┘       └─────────┘    └─────────┘
```

---

## 📦 Dependency Tree

```
ServerApp (Executable)
│
├── 📚 External Libraries (VCpkg)
│   ├── Asio (Async I/O networking)
│   ├── nlohmann_json (JSON parsing/serialization)
│   └── SQLite3 (Database)
│
├── 🔨 Compiled Source Files
│   ├── main.cpp → Server entry point
│   ├── asio_server.cpp → TCP/UDP server
│   ├── message_handler.cpp → Message routing
│   ├── user_handler.cpp → User management
│   └── logger.cpp → Logging system
│
└── 🔗 System Libraries
    ├── ws2_32 (Windows Sockets)
    ├── mswsock (Windows Socket Extensions)
    └── kernel32, user32 (Windows System)
```

---

## 📊 Project Statistics

| Category | Count |
|----------|-------|
| **C++ Source Files** | ~10 files |
| **Header Files** | ~15 files |
| **SQL Schema Files** | 5 files |
| **JSON Config Files** | 2 files |
| **Build Artifacts** | 1000+ files |
| **VCpkg Packages** | 6 main + dependencies |
| **Total Project Size** | ~500MB+ (including vcpkg) |

---

## 🚀 Key Technologies Stack

```
┌──────────────────────────────────────────┐
│  Frontend: Qt 6 (C++) - Desktop Client   │
├──────────────────────────────────────────┤
│  Backend:  C++17 + Asio - Async Server   │
├──────────────────────────────────────────┤
│  Protocol: TCP/UDP - Custom packet format│
├──────────────────────────────────────────┤
│  Media:    PortAudio + OpenCV            │
├──────────────────────────────────────────┤
│  Database: MySQL + Redis + SQLite        │
├──────────────────────────────────────────┤
│  Build:    CMake + VCpkg + MSVC          │
└──────────────────────────────────────────┘
```

---

## 🔧 Build Configuration

```
CMakeLists.txt
│
├── Language: C++17
├── Compiler: MSVC (cl.exe)
├── Platform: Windows x64
│
├── Dependencies:
│   ├── asio::asio (Header-only networking)
│   ├── nlohmann_json::nlohmann_json (JSON)
│   └── sqlite3 (Database)
│
├── Include Directories:
│   └── Code/src/ (Absolute include path)
│
├── Source Files:
│   ├── main.cpp
│   ├── Code/src/server/core/asio_server.cpp
│   ├── Code/src/server/handlers/message_handler.cpp
│   ├── Code/src/server/handlers/user_handler.cpp
│   └── Code/src/common/utils/logger.cpp
│
└── Output:
    └── build/Debug/ServerApp.exe
```

---

## 💾 File Organization by Purpose

### 🔐 Configuration & Build
- `CMakeLists.txt` - Build system
- `vcpkg.json` - Dependency manifest
- `.vscode/` - IDE configuration

### 💻 Source Code
- `Code/src/` - Main application code
- `main.cpp` - Entry point

### 🗄️ Data & Schema
- `Code/database/schemas/` - Database design
- `Code/config/` - Runtime configuration

### 📦 Build & Dependencies
- `build/` - Compilation artifacts
- `vcpkg/` - Package manager & libraries

### 📚 Documentation
- `README.md` - Project overview
- `DOCX/`, `PPTX/` - External documentation

---

## 🎯 Development Workflow

```
1. Edit Source Code
   └─→ Code/src/server/core/asio_server.cpp
   └─→ Code/src/server/handlers/message_handler.cpp
   └─→ etc.

2. CMake Configuration
   └─→ CMakeLists.txt
   └─→ build/CMakeCache.txt

3. Compilation
   └─→ MSVC Compiler (cl.exe)
   └─→ Object files in build/ServerApp.dir/Debug/

4. Linking
   └─→ build/Debug/ServerApp.exe

5. Execution
   └─→ ./ServerApp.exe
   └─→ Connects to MySQL/Redis/SQLite
   └─→ Listens on ports 8080/8081/8082
```

---

## ⚙️ Port Configuration

| Port | Purpose | Protocol |
|------|---------|----------|
| 8080 | Main Server (Messages) | TCP |
| 8081 | Voice Communication | UDP |
| 8082 | Video Streaming | UDP |
| 3306 | MySQL Database | TCP |
| 6379 | Redis Cache | TCP |

---

*Last Updated: 2026-06-12*
*Structure verified and documented*
