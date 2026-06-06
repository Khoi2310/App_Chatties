# API Documentation

## Authentication Endpoints

### Login
```
POST /api/auth/login
Content-Type: application/json

{
  "username": "user@example.com",
  "password": "password_hash"
}

Response: 200 OK
{
  "token": "jwt_token_here",
  "user_id": 1,
  "expires_in": 3600
}
```

### Logout
```
POST /api/auth/logout
Authorization: Bearer {token}

Response: 200 OK
```

---

## Message Endpoints

### Send Message
```
Protocol: TCP/WebSocket
Message Type: 10

Packet Structure:
{
  "type": 10,
  "channel_id": 1,
  "content": "Hello, World!",
  "timestamp": 1234567890
}
```

### Receive Message
```
Protocol: TCP/WebSocket (Broadcast)
Message Type: 11

Packet Structure:
{
  "type": 11,
  "channel_id": 1,
  "sender_id": 2,
  "content": "Hello!",
  "timestamp": 1234567890
}
```

---

## Voice/Video Streaming

### Start Voice Call
```
Protocol: UDP
Message Type: 20

Connects to: server_host:8081
Sends audio frames continuously
```

### Start Video Stream
```
Protocol: UDP
Message Type: 22

Connects to: server_host:8082
Sends video frames continuously
```

---

## Server Management

### Create Server
```
POST /api/servers
Content-Type: application/json
Authorization: Bearer {token}

{
  "server_name": "My Community",
  "description": "A great community",
  "is_public": true
}

Response: 201 Created
{
  "server_id": 1,
  "owner_id": 1,
  "created_at": "2024-01-01T12:00:00Z"
}
```

---

## Channel Management

### Create Channel
```
POST /api/channels
Content-Type: application/json
Authorization: Bearer {token}

{
  "server_id": 1,
  "channel_name": "general",
  "channel_type": "text",
  "is_private": false
}

Response: 201 Created
{
  "channel_id": 1,
  "server_id": 1,
  "created_at": "2024-01-01T12:00:00Z"
}
```

---

## Error Codes

| Code | Message | Description |
|------|---------|-------------|
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Missing or invalid token |
| 403 | Forbidden | Access denied |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Resource already exists |
| 500 | Server Error | Internal server error |
| 503 | Service Unavailable | Server temporarily unavailable |
