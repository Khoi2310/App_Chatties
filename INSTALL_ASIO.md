# Installing C++ Asio

C++ Asio is a cross-platform C++ library for network and low-level I/O programming. It can be used as a standalone header-only library or with Boost.

## 1. Header-Only (Recommended)

You can use Asio as a header-only library. Download the latest release from:
https://think-async.com/Asio/Download.html

- Extract the archive.
- Copy the `asio` folder from the `include` directory to your project's include path.

## 2. Using vcpkg (Windows)

If you use [vcpkg](https://github.com/microsoft/vcpkg):

```sh
vcpkg install asio
```

Or, for the standalone version (without Boost):

```sh
vcpkg install asio[standalone]
```

## 3. Using CMake

Add to your `CMakeLists.txt`:

```
find_package(Asio REQUIRED)
target_link_libraries(your_target PRIVATE Asio::asio)
```

Or, if using header-only:

```
target_include_directories(your_target PRIVATE path/to/asio/include)
```

## 4. Using Boost (Optional)

If you prefer Boost.Asio, install Boost via vcpkg or download from https://www.boost.org/.

```sh
vcpkg install boost-asio
```

## References
- [Asio official site](https://think-async.com/Asio/)
- [Asio GitHub](https://github.com/chriskohlhoff/asio)
- [Boost.Asio](https://www.boost.org/doc/libs/release/doc/html/boost_asio.html)
