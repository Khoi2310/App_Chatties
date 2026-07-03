# 💬 Chatties

> A modern desktop chat app inspired by Discord, built with a C++ server and a Qt-based client.

Chatties is a Windows-first communication app for communities, friends, and teams. The project currently focuses on a working local server/client stack with account-based access, real-time messaging, and a polished desktop interface.

## ✨ What Chatties includes

- Account registration and sign-in
- Real-time chat experience
- Server and channel-style conversation flow
- Media and GIF support
- Custom avatar and theme styling
- A simple build-and-run workflow for Windows

## 🚀 Quick start (Windows)

### Prerequisites

Install these once on your machine:

- Visual Studio 2022 with the Desktop development with C++ workload
- CMake 3.16 or newer
- vcpkg and a configured VCPKG_ROOT environment variable
- Qt 6.11 for MSVC 2022 64-bit

### Run with one command

```powershell
git clone https://github.com/Khoi2310/App_Chatties.git
cd App_Chatties
./launch.ps1
```

The launch script will:

1. Create Code/server_config.json from the example template if needed
2. Configure and build the server
3. Configure and build the Qt client
4. Deploy the Qt runtime next to the executable
5. Launch the server and client

Useful options:

- ./launch.ps1 -QtDir "C:\Qt\6.11.1\msvc2022_64"
- ./launch.ps1 -Clean
- ./launch.ps1 -NoRun

> The first build can take a while because the server dependencies are compiled from source. Later runs are much faster.

## 🔧 Manual build steps

### Build the server

```powershell
cd Code
cmake --preset default
cmake --build --preset debug
```

### Build the client

```powershell
cmake -S Code/Chatties -B Code/Chatties/build -G "Visual Studio 17 2022" -DCMAKE_PREFIX_PATH="C:\Qt\6.11.1\msvc2022_64"
cmake --build Code/Chatties/build --config Debug
```

## 📁 Project structure

- Code/ contains the CMake project, server source, and shared build configuration
- Code/Chatties/ contains the Qt client application
- config/ stores runtime configuration files
- database/ contains schema and migration assets
- docs/ contains implementation and design notes

## 🛠️ Development notes

- The server binary is built from Code and the client from Code/Chatties
- Register an account in the client to start using the app
- Add your Giphy API key to Code/server_config.json if you want GIF support enabled
- For a second client instance, launch the client again to test multi-user behavior against the same local server

## 📝 License

This project is licensed under the MIT License. See the LICENSE file for details.

