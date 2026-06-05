# Architecture Overview

## System Design

Chatties follows a client-server architecture with the following layers:

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Layer (Qt/C++)                    │
│  ┌──────────────┬──────────────┬──────────────┐             │
│  │     UI       │   Network    │    Media     │             │
│  │   Framework  │    Stack     │  Management  │             │
│  └──────────────┴──────────────┴──────────────┘             │
│           │                                                  │
│           │ TCP/UDP                                          │
│           ↓                                                  │
├─────────────────────────────────────────────────────────────┤
│                 Server Layer (Asio/C++)                      │
│  ┌──────────────┬──────────────┬──────────────┐             │
│  │  Connection  │   Message    │    Media     │             │
│  │   Manager    │   Handlers   │  Processors  │             │
│  └──────────────┴──────────────┴──────────────┘             │
│           │                                                  │
│           │ Query/Cache                                     │
│           ↓                                                  │
├─────────────────────────────────────────────────────────────┤
│               Data Layer                                     │
│  ┌──────────────┬──────────────┬──────────────┐             │
│  │    MySQL     │     Redis    │   SQLite     │             │
│  │  (Primary)   │   (Cache)    │   (Local)    │             │
│  └──────────────┴──────────────┴──────────────┘             │
└─────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### Client Components

- **UI Framework**: Qt for cross-platform GUI
- **Network Stack**: Async socket communication
- **Media Management**: Voice and video control
- **Local Cache**: SQLite for offline support

### Server Components

- **Connection Manager**: Handles TCP connections
- **Message Handlers**: Routes text messages
- **Media Processors**: Handles voice/video streams
- **Database Interface**: Communicates with MySQL and Redis

### Data Layer

- **MySQL**: Primary persistent storage (users, messages, servers)
- **Redis**: High-speed caching (sessions, active users)
- **SQLite**: Server-side temporary storage and client-side caching

## Communication Flow

1. **User Authentication**
   - Client → Server: Login credentials (TCP)
   - Server: Validates and generates token
   - Server → Client: Auth token (TCP)
   - Token stored in Redis

2. **Message Exchange**
   - Client → Server: Message content (TCP)
   - Server: Stores in MySQL, caches in Redis
   - Server → All Clients: Broadcast (TCP)

3. **Voice/Video**
   - Client: Captures media (PortAudio/OpenCV)
   - Client → Server: Encodes with FFmpeg
   - Server: Routes to recipients (UDP)
   - Recipient: Decodes and plays media

## Technology Integration

- **Asio**: Manages async I/O for multiple concurrent connections
- **OpenCV**: Processes video frames in real-time
- **FFmpeg**: Encodes/decodes audio and video streams
- **PortAudio**: Cross-platform audio I/O
- **Qt**: Provides responsive, native-looking UI
- **MySQL + Redis**: Hybrid storage for performance and persistence
