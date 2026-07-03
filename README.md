# 💬 Chatties

> A Discord-style desktop chat app built as a learning-focused C++ + Qt project.

Chatties is designed as a polished desktop messaging experience with servers, channels, direct messages, rich messaging, and a modern Qt-based interface. The current implementation is an MVP foundation, while the roadmap expands it into a fuller chat platform.

## ✨ Core goals

- Servers and channels for organized conversations
- Direct messages between users
- Rich messaging with replies, reactions, forwarding, attachments, and GIFs
- A modern, themeable Qt Quick/QML client experience
- A simple local-first architecture using SQLite and a lightweight C++ server

## 🏗️ Architecture overview

The planned architecture uses two transport channels:

- A realtime control channel over TCP with newline-delimited JSON
- A media channel over HTTP for uploads, downloads, and media references

```text
Qt Quick / QML Client
    └─> TCP JSON control channel / HTTP media requests
          └─> Chatties Server (C++)
                ├─ Asio TCP gateway
                ├─ session/auth/routing handlers
                └─> SQLite database + media storage
```

### Server-side responsibilities

- Accept and route client connections
- Validate and process message operations
- Manage users, sessions, and channels
- Persist data in SQLite
- Serve media uploads/downloads over HTTP

### Client-side responsibilities

- Render the UI with Qt Quick/QML
- Manage connection state and networking
- Display messages, channels, servers, and member lists
- Provide composer actions for emoji, GIFs, replies, reactions, and attachments

## 🧱 Tech stack

| Area | Choice | Notes |
|---|---|---|
| Server runtime | C++ | Core application logic |
| Networking | Boost.Asio | Asynchronous TCP server |
| JSON | nlohmann-json | Message envelopes and protocol payloads |
| Database | SQLite | Local persistence for users, messages, servers, and channels |
| Media API | cpp-httplib | Lightweight HTTP upload/download endpoint |
| Password hashing | libsodium / argon2-style flow | Planned for secure auth |
| Client UI | Qt 6 Quick / QML | Modern Discord-like experience |
| GIF support | Tenor or Giphy API | URLs are stored; no server-side GIF hosting needed |

## 🗄️ Data model

The roadmap defines a SQLite schema centered on the following entities:

- users
- servers
- server_members
- channels
- dm_participants
- messages
- attachments
- reactions
- custom_emoji

Key design ideas:

- DMs are represented as channels with DM participants
- Replies, forwarding, and reactions are stored as first-class message relationships
- Attachments can include images, files, and GIFs
- The same message pipeline supports both channels and DMs

## 📁 Project structure

- Code/ — main CMake project, server implementation, and shared configuration
- Code/Chatties/ — Qt client application
- config/ — runtime configuration files
- database/ — schema and migration assets
- docs/ — architecture and development notes
- DOCX/ — planning documents such as the roadmap

## 🚀 Current status

The project currently contains:

- A working Boost.Asio TCP server foundation
- A Qt-based client UI
- A basic JSON-based protocol over TCP
- Early scaffolding for message and user handling

The roadmap extends this toward:

- persistent SQLite-backed messaging
- authentication and account management
- QML-based UI migration
- servers, channels, and DMs
- rich messaging and media support

## ⚙️ Build and run (Windows)

### Prerequisites

- Visual Studio 2022 with Desktop development with C++
- CMake 3.16+
- vcpkg with VCPKG_ROOT configured
- Qt 6.11 for MSVC 2022 64-bit

### One-command launch

```powershell
git clone https://github.com/Khoi2310/App_Chatties.git
cd App_Chatties
./launch.ps1
```

Useful options:

- ./launch.ps1 -QtDir "C:\Qt\6.11.1\msvc2022_64"
- ./launch.ps1 -Clean
- ./launch.ps1 -NoRun

### Manual build steps

```powershell
cd Code
cmake --preset default
cmake --build --preset debug
```

```powershell
cmake -S Code/Chatties -B Code/Chatties/build -G "Visual Studio 17 2022" -DCMAKE_PREFIX_PATH="C:\Qt\6.11.1\msvc2022_64"
cmake --build Code/Chatties/build --config Debug
```

## 📝 License

This project is licensed under the MIT License. See the LICENSE file for details.

