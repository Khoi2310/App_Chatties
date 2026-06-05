# Development Guide

## Setup Development Environment

### Prerequisites
- C++ 17 or later
- CMake 3.20+
- Git
- Visual Studio 2019+ or GCC 9+
- vcpkg

### Initial Setup

1. **Clone repository**
```bash
git clone https://github.com/Khoi2310/App_Chatties.git
cd App_Chatties
```

2. **Install dependencies with vcpkg**
```bash
.\vcpkg\vcpkg.exe install asio:x64-windows nlohmann-json:x64-windows sqlite3:x64-windows portaudio:x64-windows opencv:x64-windows ffmpeg:x64-windows --triplet=x64-windows
```

3. **Setup CMake**
```bash
mkdir build
cd build
cmake .. -DCMAKE_TOOLCHAIN_FILE=../vcpkg/scripts/buildsystems/vcpkg.cmake -DCMAKE_BUILD_TYPE=Debug
```

4. **Build project**
```bash
cmake --build . --config Debug
```

## Development Workflow

### Building

**Using VS Code:**
- Install CMake Tools extension
- Use CMake panel to configure and build

**Using command line:**
```bash
cd build
cmake --build . --config Debug
```

### Running

**Server:**
```bash
.\Debug\ServerApp.exe
```

**Client:**
```bash
.\Debug\ClientApp.exe
```

## Code Structure

- `src/server/` - Server implementation
  - `core/` - Network layer (Asio)
  - `handlers/` - Message processing
  - `media/` - Audio/Video processing

- `src/client/` - Client implementation
  - `ui/` - Qt UI components
  - `network/` - Client networking
  - `media/` - Client media handling

- `src/common/` - Shared code
  - `protocol/` - Message protocols
  - `utils/` - Utilities

## Coding Standards

- Use C++ 17 features
- Follow Google C++ Style Guide
- 4-space indentation
- Meaningful variable names
- Document complex logic

## Testing

```bash
# Run all tests
cmake --build . --config Debug --target RUN_TESTS
```

## Debugging

### VS Code Debugger

1. Set breakpoints in code
2. Press F5 or click Run and Debug
3. Select C++ (gdb or msvc depending on compiler)

### Using GDB (if available)
```bash
gdb ./Debug/ServerApp.exe
```

## Troubleshooting

### Missing Dependencies
```bash
# Reinstall all dependencies
.\vcpkg\vcpkg.exe install --reinstall asio:x64-windows nlohmann-json:x64-windows sqlite3:x64-windows portaudio:x64-windows opencv:x64-windows ffmpeg:x64-windows
```

### CMake Configuration Issues
```bash
# Clean and reconfigure
rm -rf build
mkdir build
cd build
cmake ..
```

### Port Already in Use
- Change server port in `config/server_config.json`
- Or kill existing process on the port

## Contributing

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make changes following coding standards
3. Test thoroughly
4. Submit pull request with description
5. Wait for code review

## Resources

- [Asio Documentation](https://think-async.com/Asio/)
- [Qt Documentation](https://doc.qt.io/)
- [OpenCV Tutorials](https://docs.opencv.org/master/)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
