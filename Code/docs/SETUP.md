# Setup Guide

## System Requirements

- **OS**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+)
- **CPU**: Intel i5/AMD Ryzen 5 or better
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 5GB free space
- **Network**: Stable internet connection

## Software Requirements

### Development Tools
- C++ 17 compatible compiler (MSVC 2019+, GCC 9+, or Clang 10+)
- CMake 3.20 or later
- Git
- Visual Studio Code (recommended) or Visual Studio 2019+

### Dependencies
All dependencies are managed through vcpkg. They will be automatically installed during setup.

## Step-by-Step Installation

### 1. Clone Repository
```bash
git clone https://github.com/Khoi2310/App_Chatties.git
cd App_Chatties
```

### 2. Install vcpkg (if not already installed)
```bash
cd vcpkg
.\bootstrap-vcpkg.bat    # Windows
# or
./bootstrap-vcpkg.sh     # Linux/macOS
cd ..
```

### 3. Install Dependencies
```bash
# Windows
.\vcpkg\vcpkg.exe install asio:x64-windows nlohmann-json:x64-windows sqlite3:x64-windows portaudio:x64-windows opencv:x64-windows ffmpeg:x64-windows qt6-base:x64-windows --triplet=x64-windows

# Linux
./vcpkg/vcpkg install asio:x64-linux nlohmann-json:x64-linux sqlite3:x64-linux portaudio:x64-linux opencv:x64-linux ffmpeg:x64-linux qt6-base:x64-linux
```

### 4. Configure CMake
```bash
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../vcpkg/scripts/buildsystems/vcpkg.cmake -DCMAKE_BUILD_TYPE=Release
```

### 5. Build Project
```bash
cmake --build . --config Release
```

## Database Setup

### 1. Install MySQL
- Download from [mysql.com](https://www.mysql.com/downloads/)
- Follow installation wizard
- Create database user: `chatties_user`

### 2. Initialize Database
```bash
mysql -u root -p
CREATE DATABASE chatties_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'chatties_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON chatties_db.* TO 'chatties_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Run Schemas
```bash
mysql -u chatties_user -p chatties_db < database/schemas/users.sql
mysql -u chatties_user -p chatties_db < database/schemas/servers.sql
mysql -u chatties_user -p chatties_db < database/schemas/channels.sql
mysql -u chatties_user -p chatties_db < database/schemas/messages.sql
mysql -u chatties_user -p chatties_db < database/schemas/permissions.sql
```

### 4. Install Redis
- Download from [redis.io](https://redis.io/download) (or use package manager)
- Start Redis server: `redis-server`
- Verify: `redis-cli ping` (should return PONG)

## Running the Application

### Server
```bash
cd build
.\Release\ServerApp.exe      # Windows
# or
./Release/ServerApp          # Linux/macOS
```

### Client
```bash
cd build
.\Release\ClientApp.exe      # Windows
# or
./Release/ClientApp          # Linux/macOS
```

## Configuration

### Server Configuration
Edit `config/server_config.json`:
```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 8080
  },
  "database": {
    "host": "localhost",
    "user": "chatties_user",
    "name": "chatties_db"
  }
}
```

### Client Configuration
Edit `config/client_config.json`:
```json
{
  "server": {
    "default_host": "localhost",
    "default_port": 8080
  }
}
```

## Troubleshooting

### "vcpkg not found"
- Ensure vcpkg is initialized: `./vcpkg/bootstrap-vcpkg.bat`
- Verify CMake toolchain path is correct

### MySQL Connection Error
- Check MySQL service is running
- Verify credentials in server_config.json
- Ensure database is created

### Port Already in Use
- Change port in `config/server_config.json`
- Or kill process on port: `netstat -ano | findstr :8080`

### Missing OpenCV/FFmpeg
- Reinstall dependencies: `.\vcpkg\vcpkg.exe install opencv ffmpeg --triplet=x64-windows`
- Clear vcpkg cache: `rm -rf vcpkg/buildtrees`

## Building with VS Code

1. Install "CMake Tools" extension
2. Select kit: `Visual Studio 2022` or your compiler
3. Configure: Click "Configure" in CMake panel
4. Build: Click "Build" in CMake panel
5. Run: Debug via VS Code's Debug panel

## Next Steps

- Read [DEVELOPMENT.md](DEVELOPMENT.md) for development guidelines
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Review [API.md](API.md) for API specifications
