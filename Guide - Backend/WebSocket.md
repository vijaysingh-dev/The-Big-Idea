# The Ultimate WebSocket Guide

> For interviews, system design, and real-world production engineering · Python-focused

---

## Table of Contents

1. [What is WebSocket?](#1-what-is-websocket)
2. [The WebSocket Handshake](#2-the-websocket-handshake)
3. [WebSocket vs HTTP vs gRPC vs SSE](#3-websocket-vs-http-vs-grpc-vs-sse)
4. [Core Concepts: Frames, Opcodes, and the Wire Protocol](#4-core-concepts-frames-opcodes-and-the-wire-protocol)
5. [Python: Basic Server and Client](#5-python-basic-server-and-client)
6. [Python: Rooms and Broadcasting](#6-python-rooms-and-broadcasting)
7. [Python: FastAPI + WebSockets (Production Pattern)](#7-python-fastapi--websockets-production-pattern)
8. [Connection Lifecycle Management](#8-connection-lifecycle-management)
9. [Authentication and Authorization](#9-authentication-and-authorization)
10. [Scaling WebSockets: The Hard Problem](#10-scaling-websockets-the-hard-problem)
11. [Heartbeats, Reconnection, and Reliability](#11-heartbeats-reconnection-and-reliability)
12. [Building a Message Protocol on Top of WebSockets](#12-building-a-message-protocol-on-top-of-websockets)
13. [Observability: Logging, Metrics, Tracing](#13-observability-logging-metrics-tracing)
14. [Common Pitfalls and How to Avoid Them](#14-common-pitfalls-and-how-to-avoid-them)
15. [Decision Framework: WebSocket vs Alternatives](#15-decision-framework-websocket-vs-alternatives)
16. [Interview Cheat Sheet](#16-interview-cheat-sheet)
17. [High-Quality Resources](#17-high-quality-resources)

---

## 1. What is WebSocket?

**WebSocket** is a protocol that provides a **persistent, full-duplex** communication channel over a single TCP connection.

- **Persistent**: the connection stays open after the initial handshake — no reconnecting per message
- **Full-duplex**: both sides can send data simultaneously and independently — the server can push data to the client at any time without the client asking first

This is fundamentally different from HTTP, where the client must always initiate every exchange.

```
HTTP (request-response):
Client: "Hey, any new messages?"   ──►  Server
Client:  ◄──  "No"
Client: "Hey, any new messages?"   ──►  Server
Client:  ◄──  "Yes, here's one"
(polling — wasteful)

WebSocket (full-duplex):
[one-time handshake to upgrade connection]
Server  ──► "New message from Alice"   ──►  Client
Client  ──► "User is typing..."        ──►  Server
Server  ──► "Alice sent a file"        ──►  Client
(both sides push whenever they want)
```

### What WebSocket is NOT

- It is **not a replacement for HTTP** — REST APIs for CRUD operations, WebSocket for real-time events
- It is **not peer-to-peer** — traffic always goes through your server (unlike WebRTC)
- It is **not a message queue** — it has no built-in durability, delivery guarantees, or replay
- It is **not gRPC** — no schema, no codegen, no typed contracts

### Who uses WebSockets in production?

|Company|Use Case|
|---|---|
|Slack|Real-time messaging and presence|
|Figma|Collaborative multiplayer editing|
|Robinhood|Live stock price updates|
|GitHub|Live PR status, notifications|
|Discord|Voice coordination, messaging|
|Notion|Collaborative document editing|

---

## 2. The WebSocket Handshake

WebSocket starts life as an HTTP request, then **upgrades** to the WebSocket protocol. This is called the **opening handshake**.

```
1. Client sends an HTTP/1.1 GET request with upgrade headers:

GET /chat HTTP/1.1
Host: server.example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==   ← random base64 nonce
Sec-WebSocket-Version: 13

2. Server accepts the upgrade:

HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=  ← SHA-1 hash of key
                                                       (proves server received it)

3. The TCP connection is now a WebSocket connection.
   HTTP is gone. Both sides speak the WebSocket framing protocol.
```

**Why does this matter in production?**

- WebSocket upgrades go through your existing HTTP infrastructure (port 80/443)
- Firewalls and load balancers that understand HTTP can be configured to allow or reject upgrades
- **TLS (wss://)** is established at the HTTP layer before the upgrade — so the WebSocket connection inherits encryption

---

## 3. WebSocket vs HTTP vs gRPC vs SSE

**SSE** = Server-Sent Events — a simpler protocol where the server pushes a stream of text events to the browser over a plain HTTP connection. One-directional only.

||**WebSocket**|**HTTP REST**|**gRPC**|**SSE**|
|---|---|---|---|---|
|**Direction**|Full-duplex|Request-response|Full-duplex (streaming)|Server → Client only|
|**Protocol**|WS/WSS over TCP|HTTP/1.1 or HTTP/2|HTTP/2|HTTP/1.1|
|**Transport**|TCP|TCP|TCP|TCP|
|**Schema/typing**|None|Optional (OpenAPI)|Protobuf (strong)|None|
|**Browser native**|✅|✅|❌ (needs grpc-web)|✅|
|**Server push**|✅|❌ (polling)|✅|✅|
|**Client push**|✅|✅ (new request)|✅|❌|
|**Reconnection**|Manual|Stateless, trivial|Manual|Auto (built-in)|
|**Overhead per msg**|Very low (2–14 byte frame header)|High (HTTP headers per request)|Low (binary)|Medium (text framing)|
|**Best for**|Chat, games, collab tools|APIs, CRUD|Microservices|Live feeds, notifications|

### When to choose SSE over WebSocket

SSE is often underused. Choose SSE when:

- You only need **server → client** updates (live scores, notifications, log streaming)
- You want **automatic reconnection** built into the browser
- You need **simpler infrastructure** (SSE works over plain HTTP/1.1, proxies handle it well)
- You want **event IDs and replay** — SSE has this built in; WebSocket does not

Choose WebSocket when the **client also needs to push data** to the server in real time (chat, gaming, collaborative editing).

---

## 4. Core Concepts: Frames, Opcodes, and the Wire Protocol

After the handshake, WebSocket communication is structured as **frames** — small binary envelopes wrapping each message.

```
WebSocket Frame Structure:
┌─────────────────────────────────────────────────────┐
│ FIN (1 bit) │ RSV (3 bits) │ Opcode (4 bits)        │
│ MASK (1 bit) │ Payload Length (7, 7+16, or 7+64 bits)│
│ [Masking Key (32 bits, only if MASK=1)]              │
│ Payload Data                                         │
└─────────────────────────────────────────────────────┘
```

**Opcodes** define what kind of frame this is:

|Opcode|Meaning|
|---|---|
|`0x0`|Continuation frame (part of fragmented message)|
|`0x1`|Text frame (UTF-8 string)|
|`0x2`|Binary frame (raw bytes)|
|`0x8`|Close frame (initiating clean close)|
|`0x9`|Ping frame (keepalive probe)|
|`0xA`|Pong frame (response to ping)|

**Masking**: frames sent from client to server **must** be masked (XOR'd with a 4-byte key). Server-to-client frames are unmasked. This prevents cache poisoning attacks on intermediate proxies.

**Why this matters in production**: The 2-byte minimum frame overhead is why WebSocket is efficient for high-frequency small messages (game state updates, cursor positions) — you're not resending HTTP headers on every message.

---

## 5. Python: Basic Server and Client

The standard Python library for WebSockets is `websockets`. For async frameworks, `FastAPI` has built-in WebSocket support.

```bash
pip install websockets
```

### Echo Server

```python
import asyncio
import websockets

# ─── Handle a single client connection ───────────────────────────────────────
# Each connected client gets its own coroutine. The server echoes
# every message back to the sender.
async def handle_client(websocket):
    print(f"Client connected: {websocket.remote_address}")
    try:
        async for message in websocket:
            print(f"Received: {message}")
            await websocket.send(f"Echo: {message}")
    except websockets.exceptions.ConnectionClosedOK:
        print("Client disconnected cleanly")
    except websockets.exceptions.ConnectionClosedError as e:
        print(f"Client disconnected with error: {e}")
    finally:
        print(f"Client gone: {websocket.remote_address}")


# ─── Start the WebSocket server ───────────────────────────────────────────────
async def main():
    async with websockets.serve(handle_client, "localhost", 8765):
        print("Server running on ws://localhost:8765")
        await asyncio.Future()  # run forever


asyncio.run(main())
```

### Python Client

```python
import asyncio
import websockets

# ─── Connect and exchange messages ───────────────────────────────────────────
async def client():
    uri = "ws://localhost:8765"
    async with websockets.connect(uri) as websocket:
        # Send a message
        await websocket.send("Hello, server!")

        # Wait for the echo response
        response = await websocket.recv()
        print(f"Server said: {response}")

        # Send multiple messages in a loop
        for i in range(3):
            await websocket.send(f"Message {i}")
            reply = await websocket.recv()
            print(f"Got: {reply}")


asyncio.run(client())
```

### Sending Binary Data

```python
# ─── Send and receive binary frames ──────────────────────────────────────────
async def binary_example(websocket):
    # Send raw bytes (e.g., a serialized Protobuf, image chunk, or NumPy array)
    payload = b"\x00\x01\x02\x03\xff"
    await websocket.send(payload)

    response = await websocket.recv()
    if isinstance(response, bytes):
        print(f"Got binary: {response.hex()}")
    else:
        print(f"Got text: {response}")
```

---

## 6. Python: Rooms and Broadcasting

A **room** is a named group of WebSocket connections. Messages sent to a room are broadcast to all members. This pattern is the foundation of chat apps, multiplayer games, and collaborative tools.

```python
import asyncio
import json
import websockets
from collections import defaultdict

# ─── Global connection registry ───────────────────────────────────────────────
# Maps room_id → set of active WebSocket connections in that room.
# defaultdict automatically creates an empty set for new room names.
rooms: dict[str, set] = defaultdict(set)


# ─── Broadcast a message to all connections in a room ─────────────────────────
async def broadcast(room_id: str, message: str, exclude=None):
    connections = rooms.get(room_id, set())
    if not connections:
        return

    # Send concurrently to all clients in the room
    tasks = [
        conn.send(message)
        for conn in connections
        if conn != exclude  # optionally skip the sender
    ]
    # gather() runs all sends concurrently and collects results/exceptions
    results = await asyncio.gather(*tasks, return_exceptions=True)

    # Remove any connections that errored (client disconnected mid-broadcast)
    for conn, result in zip(
        [c for c in connections if c != exclude], results
    ):
        if isinstance(result, Exception):
            rooms[room_id].discard(conn)


# ─── Handle a client joining a room and exchanging messages ───────────────────
async def handle_client(websocket):
    room_id = None
    try:
        # Expect the first message to be a join event with room info
        raw = await websocket.recv()
        data = json.loads(raw)

        if data.get("type") != "join":
            await websocket.close(1008, "First message must be a join event")
            return

        room_id = data["room_id"]
        username = data["username"]

        # Register this connection in the room
        rooms[room_id].add(websocket)
        print(f"{username} joined room '{room_id}'")

        # Notify everyone else in the room
        await broadcast(
            room_id,
            json.dumps({"type": "system", "text": f"{username} joined"}),
            exclude=websocket,
        )

        # Listen for chat messages and broadcast them to the room
        async for raw_msg in websocket:
            msg = json.loads(raw_msg)
            if msg.get("type") == "chat":
                await broadcast(
                    room_id,
                    json.dumps({"type": "chat", "user": username, "text": msg["text"]}),
                )

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        # Always clean up: remove from room on disconnect
        if room_id:
            rooms[room_id].discard(websocket)
            print(f"Client left room '{room_id}', {len(rooms[room_id])} remaining")


async def main():
    async with websockets.serve(handle_client, "localhost", 8765):
        await asyncio.Future()


asyncio.run(main())
```

---

## 7. Python: FastAPI + WebSockets (Production Pattern)

FastAPI is the standard choice for Python production APIs. Its WebSocket support integrates cleanly with Pydantic validation, dependency injection, and existing middleware.

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, status
from fastapi.websockets import WebSocketState
from typing import Optional
import json
import asyncio

app = FastAPI()


# ─── Connection Manager: central registry for all active connections ──────────
# Encapsulates connect/disconnect/broadcast logic in one place.
# In production, this state lives in Redis (not in-memory) for multi-server setups.
class ConnectionManager:
    def __init__(self):
        # Maps client_id → WebSocket for targeted messaging
        self.active: dict[str, WebSocket] = {}

    async def connect(self, client_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active[client_id] = websocket

    def disconnect(self, client_id: str):
        self.active.pop(client_id, None)

    async def send_to(self, client_id: str, message: dict):
        """Send a message to one specific client."""
        ws = self.active.get(client_id)
        if ws and ws.client_state == WebSocketState.CONNECTED:
            await ws.send_json(message)

    async def broadcast(self, message: dict, exclude: Optional[str] = None):
        """Send a message to all connected clients."""
        disconnected = []
        for client_id, ws in self.active.items():
            if client_id == exclude:
                continue
            try:
                await ws.send_json(message)
            except Exception:
                disconnected.append(client_id)

        # Clean up dead connections found during broadcast
        for cid in disconnected:
            self.disconnect(cid)

    @property
    def count(self):
        return len(self.active)


manager = ConnectionManager()


# ─── WebSocket endpoint with client ID from path ──────────────────────────────
@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(client_id, websocket)
    await manager.broadcast(
        {"type": "system", "text": f"{client_id} connected ({manager.count} online)"},
        exclude=client_id,
    )

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type")

            # Route message based on type
            if msg_type == "broadcast":
                await manager.broadcast(
                    {"type": "message", "from": client_id, "text": data["text"]},
                    exclude=client_id,
                )
            elif msg_type == "dm":
                await manager.send_to(
                    data["to"],
                    {"type": "dm", "from": client_id, "text": data["text"]},
                )
            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        manager.disconnect(client_id)
        await manager.broadcast(
            {"type": "system", "text": f"{client_id} disconnected ({manager.count} online)"}
        )
```

### Adding JWT Authentication to FastAPI WebSockets

```python
from fastapi import WebSocket, HTTPException, Query
from jose import jwt, JWTError

SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"


# ─── Extract and verify JWT from query param before upgrading ─────────────────
# WebSocket connections can't send custom headers, so tokens are passed
# as query parameters (wss://server/ws?token=xxx) or as the first message.
async def get_current_user(
    websocket: WebSocket,
    token: str = Query(...),  # required query param
):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if not user_id:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return None
        return user_id
    except JWTError:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None


@app.websocket("/ws/secure")
async def secure_ws(
    websocket: WebSocket,
    user_id: str = Depends(get_current_user),
):
    if not user_id:
        return  # already closed in dependency

    await websocket.accept()
    try:
        async for message in websocket.iter_text():
            await websocket.send_text(f"[{user_id}]: {message}")
    except WebSocketDisconnect:
        pass
```

---

## 8. Connection Lifecycle Management

Every WebSocket connection transitions through these states:

```
CONNECTING → OPEN → CLOSING → CLOSED
     │          │        │
     │      (data flows) │
     │                   └── Triggered by close frame or error
     └── TCP + HTTP upgrade happening
```

### Clean Close Handshake

A proper close involves a **close frame exchange** — both sides agree to close:

```python
# ─── Initiate a clean close from the server side ─────────────────────────────
async def graceful_close(websocket, code: int = 1000, reason: str = "Normal closure"):
    """
    Send a close frame and wait for the client's acknowledgment.
    Code 1000 = normal closure. See close codes table below.
    """
    try:
        await websocket.close(code=code, reason=reason)
    except Exception:
        pass  # Connection may already be dead


# ─── Handle server shutdown: close all connections gracefully ─────────────────
async def shutdown_all_connections(manager: ConnectionManager):
    close_tasks = [
        ws.close(1001, "Server shutting down")
        for ws in manager.active.values()
    ]
    await asyncio.gather(*close_tasks, return_exceptions=True)
    manager.active.clear()
```

### WebSocket Close Codes

|Code|Meaning|Who uses it|
|---|---|---|
|`1000`|Normal closure|Either side, planned disconnect|
|`1001`|Going away|Server shutting down, browser tab closed|
|`1002`|Protocol error|Frame structure violated|
|`1003`|Unsupported data|Received binary when only text expected|
|`1006`|Abnormal closure|TCP dropped without close frame (no code sent)|
|`1007`|Invalid data|Non-UTF-8 in text frame|
|`1008`|Policy violation|Auth failure, rate limit, bad message|
|`1009`|Message too big|Exceeded size limit|
|`1011`|Internal server error|Unexpected condition on server|

---

## 9. Authentication and Authorization

WebSockets cannot send custom HTTP headers after the initial handshake. Auth must happen at one of these points:

### Option 1: Token in Query Parameter (most common)

```python
# Client connects with: wss://server/ws?token=eyJhbGc...
@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket, token: str = Query(...)):
    user = verify_token(token)
    if not user:
        await websocket.close(1008, "Unauthorized")
        return
    await websocket.accept()
    # ... handle connection
```

**Tradeoff**: Token appears in server access logs. Use short-lived tokens (< 60s) generated specifically for the WebSocket connection.

### Option 2: Token as First Message (more secure)

```python
# ─── Auth-before-accept pattern ───────────────────────────────────────────────
# Accept at transport level but don't process messages until auth is confirmed.
# Avoids logging tokens in URLs.
@app.websocket("/ws")
async def ws_endpoint(websocket: WebSocket):
    await websocket.accept()

    # Give client 5 seconds to send auth token
    try:
        auth_data = await asyncio.wait_for(websocket.receive_json(), timeout=5.0)
    except asyncio.TimeoutError:
        await websocket.close(1008, "Auth timeout")
        return

    user = verify_token(auth_data.get("token"))
    if not user:
        await websocket.close(1008, "Unauthorized")
        return

    await websocket.send_json({"type": "auth_ok", "user_id": user.id})

    # Now handle normal messages
    async for message in websocket.iter_json():
        await handle_message(user, message, websocket)
```

### Option 3: Cookie-based Auth (browser clients)

Browsers automatically send cookies with WebSocket upgrade requests. This is the cleanest option for browser clients using session-based auth:

```python
from fastapi import Cookie

@app.websocket("/ws")
async def ws_endpoint(
    websocket: WebSocket,
    session_id: Optional[str] = Cookie(default=None),
):
    user = await get_user_from_session(session_id)
    if not user:
        await websocket.close(1008, "Unauthorized")
        return
    await websocket.accept()
    # ...
```

---

## 10. Scaling WebSockets: The Hard Problem

This is the most critical topic for senior interviews. WebSockets are **stateful** — the connection is tied to a specific server process. This breaks horizontal scaling.

### The Problem

```
User A connects to Server 1
User B connects to Server 2

User A sends a message to User B.
Server 1 has no connection to User B.
How does Server 1 reach User B on Server 2?
```

### Solution: Pub/Sub Backplane with Redis

A **pub/sub backplane** is a message bus that all server instances subscribe to. When Server 1 needs to send a message to User B (on Server 2), it publishes to Redis. Server 2 is subscribed and forwards to User B.

**Pub/Sub** = Publish/Subscribe — a messaging pattern where publishers send messages to named channels, and subscribers receive all messages on channels they subscribed to, without knowing each other.

```
User A ──► [Server 1] ──publish──► [Redis Pub/Sub] ──subscribe──► [Server 2] ──► User B
```

```python
import asyncio
import json
import redis.asyncio as aioredis
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

app = FastAPI()
redis = aioredis.from_url("redis://localhost:6379")

# ─── Local connection store for this server instance ──────────────────────────
local_connections: dict[str, WebSocket] = {}

CHANNEL = "global_chat"


# ─── Subscribe to Redis and forward messages to local WebSocket clients ────────
# This runs as a background task on every server instance.
async def redis_listener():
    pubsub = redis.pubsub()
    await pubsub.subscribe(CHANNEL)

    async for raw_message in pubsub.listen():
        if raw_message["type"] != "message":
            continue

        message = json.loads(raw_message["data"])
        recipient_id = message.get("to")

        if recipient_id:
            # Targeted message: only send if this server holds the connection
            ws = local_connections.get(recipient_id)
            if ws:
                await ws.send_json(message)
        else:
            # Broadcast: send to all local connections
            for ws in list(local_connections.values()):
                try:
                    await ws.send_json(message)
                except Exception:
                    pass


# ─── WebSocket endpoint that publishes outgoing messages to Redis ──────────────
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await websocket.accept()
    local_connections[user_id] = websocket

    try:
        async for data in websocket.iter_json():
            # Publish to Redis — all server instances will receive and route it
            message = {"from": user_id, "text": data["text"], "to": data.get("to")}
            await redis.publish(CHANNEL, json.dumps(message))

    except WebSocketDisconnect:
        pass
    finally:
        local_connections.pop(user_id, None)


# ─── Start Redis listener as background task on server startup ─────────────────
@app.on_event("startup")
async def startup():
    asyncio.create_task(redis_listener())
```

### Sticky Sessions (Alternative, Less Preferred)

Configure your load balancer to route all connections from one user to the same server instance (**sticky sessions** / **session affinity**). Simpler to implement, but:

- Uneven load distribution
- Server restart drops all its connections
- Doesn't work for broadcasting to users on other servers

**Production recommendation**: Redis pub/sub for correctness; sticky sessions only as a temporary shortcut.

---

## 11. Heartbeats, Reconnection, and Reliability

WebSocket connections die silently — a TCP connection can drop without either side noticing (NAT timeout, mobile network switch, idle proxy timeout). You need heartbeats to detect dead connections.

### Server-Side Ping/Pong

```python
import asyncio
import websockets

HEARTBEAT_INTERVAL = 30  # seconds
HEARTBEAT_TIMEOUT = 10   # seconds to wait for pong


# ─── Send periodic pings and disconnect if pong is not received ───────────────
async def heartbeat(websocket):
    """
    Runs alongside the message handler. Sends a ping every 30 seconds.
    If the client doesn't respond within 10 seconds, the connection is dead.
    """
    while True:
        await asyncio.sleep(HEARTBEAT_INTERVAL)
        try:
            pong_waiter = await websocket.ping()
            await asyncio.wait_for(pong_waiter, timeout=HEARTBEAT_TIMEOUT)
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            print("Heartbeat failed — closing dead connection")
            await websocket.close()
            break


async def handle_client(websocket):
    # Run heartbeat concurrently with message handling
    heartbeat_task = asyncio.create_task(heartbeat(websocket))
    try:
        async for message in websocket:
            await websocket.send(f"Echo: {message}")
    finally:
        heartbeat_task.cancel()
```

### Client-Side Reconnection with Exponential Backoff

**Exponential backoff** = each retry waits twice as long as the previous one. This prevents thundering herd — _when all clients retry simultaneously after a server restart, overwhelming it the moment it comes back up_.

```python
import asyncio
import websockets
import random

# ─── Reconnect with exponential backoff + jitter ──────────────────────────────
# Jitter (random spread) prevents all clients from retrying at exactly the
# same time after a server restart (thundering herd problem).
async def connect_with_retry(uri: str):
    backoff = 1      # start with 1 second
    max_backoff = 60 # cap at 60 seconds

    while True:
        try:
            async with websockets.connect(uri) as websocket:
                print("Connected!")
                backoff = 1  # reset on successful connection

                async for message in websocket:
                    print(f"Received: {message}")

        except (websockets.exceptions.ConnectionClosed,
                OSError,
                websockets.exceptions.InvalidHandshake) as e:
            # Add jitter: sleep between backoff and backoff*1.5 seconds
            sleep_time = backoff + random.uniform(0, backoff * 0.5)
            print(f"Disconnected ({e}). Retrying in {sleep_time:.1f}s...")
            await asyncio.sleep(sleep_time)

            # Double the backoff, capped at max
            backoff = min(backoff * 2, max_backoff)


asyncio.run(connect_with_retry("ws://localhost:8765"))
```

---

## 12. Building a Message Protocol on Top of WebSockets

WebSocket is a transport — it delivers raw bytes or strings. For a real application you need a **message protocol**: a standard structure for all messages your app sends and receives.

### Typed Message Envelope

```python
from pydantic import BaseModel
from typing import Any, Literal, Optional
from enum import Enum
import json


# ─── Message type enum ────────────────────────────────────────────────────────
class MessageType(str, Enum):
    CHAT = "chat"
    JOIN = "join"
    LEAVE = "leave"
    TYPING = "typing"
    ERROR = "error"
    ACK = "ack"         # acknowledgment — confirms a message was received
    SYSTEM = "system"


# ─── Standard envelope wrapping all WebSocket messages ────────────────────────
# Every message sent or received has this shape. The `payload` field
# varies by type, validated separately.
class WSMessage(BaseModel):
    type: MessageType
    id: Optional[str] = None    # message ID for deduplication and ACKs
    payload: Any = None
    timestamp: Optional[float] = None


# ─── Serialize / deserialize helpers ──────────────────────────────────────────
def encode(message: WSMessage) -> str:
    return message.model_dump_json()


def decode(raw: str) -> WSMessage:
    return WSMessage.model_validate_json(raw)


# ─── Server handler using typed protocol ──────────────────────────────────────
async def handle_typed_message(websocket, raw: str):
    try:
        msg = decode(raw)
    except Exception:
        # Malformed message — send error and continue (don't crash the connection)
        error = WSMessage(type=MessageType.ERROR, payload={"reason": "Invalid message format"})
        await websocket.send(encode(error))
        return

    if msg.type == MessageType.CHAT:
        # Broadcast chat message
        await broadcast_to_room(msg)

    elif msg.type == MessageType.TYPING:
        # Notify others that user is typing
        await notify_typing(msg)

    elif msg.type == MessageType.JOIN:
        await join_room(websocket, msg.payload["room_id"])

    # Send ACK back if message had an ID
    if msg.id:
        ack = WSMessage(type=MessageType.ACK, payload={"ack_id": msg.id})
        await websocket.send(encode(ack))
```

### Message Deduplication

In unreliable networks, clients may resend messages on reconnect. Use message IDs to deduplicate:

```python
import time
import uuid
from collections import OrderedDict


# ─── Sliding window deduplication cache ───────────────────────────────────────
# Remembers recently seen message IDs to drop duplicates.
# OrderedDict preserves insertion order for efficient eviction.
class MessageDeduplicator:
    def __init__(self, max_size: int = 10_000):
        self.seen: OrderedDict[str, float] = OrderedDict()
        self.max_size = max_size

    def is_duplicate(self, message_id: str) -> bool:
        if message_id in self.seen:
            return True

        # Add to seen set
        self.seen[message_id] = time.time()

        # Evict oldest entries if over limit
        while len(self.seen) > self.max_size:
            self.seen.popitem(last=False)

        return False


deduplicator = MessageDeduplicator()

async def handle_with_dedup(websocket, raw: str):
    msg = decode(raw)
    if msg.id and deduplicator.is_duplicate(msg.id):
        return  # silently drop duplicate
    await handle_typed_message(websocket, raw)
```

---

## 13. Observability: Logging, Metrics, Tracing

### Structured Logging Per Connection

```python
import structlog
import time

# ─── Build a per-connection logger with contextual fields ─────────────────────
# structlog adds context fields (client_id, remote_addr) to every log line
# automatically, making it easy to filter logs by connection in Grafana/Loki.
async def handle_client(websocket, client_id: str):
    log = structlog.get_logger().bind(
        client_id=client_id,
        remote_addr=str(websocket.remote_address),
    )

    log.info("ws.connected")
    start = time.time()
    messages_received = 0

    try:
        async for message in websocket:
            messages_received += 1
            log.debug("ws.message_received", size=len(message))
            await websocket.send(message)

    except websockets.exceptions.ConnectionClosed as e:
        log.info("ws.disconnected", code=e.code, reason=e.reason)
    finally:
        duration = time.time() - start
        log.info(
            "ws.session_ended",
            duration_seconds=round(duration, 3),
            messages=messages_received,
        )
```

### Prometheus Metrics

```python
from prometheus_client import Gauge, Counter, Histogram

# ─── Define WebSocket-specific metrics ───────────────────────────────────────
ws_connections_active = Gauge(
    "ws_connections_active",
    "Number of currently open WebSocket connections"
)
ws_messages_total = Counter(
    "ws_messages_total",
    "Total WebSocket messages processed",
    ["direction"]  # labels: 'inbound' or 'outbound'
)
ws_message_size_bytes = Histogram(
    "ws_message_size_bytes",
    "Size of WebSocket messages in bytes",
    buckets=[64, 256, 1024, 4096, 16384]
)
ws_connection_duration_seconds = Histogram(
    "ws_connection_duration_seconds",
    "Duration of WebSocket connections",
    buckets=[1, 5, 30, 60, 300, 900, 3600]
)


# ─── Instrumented connection handler ──────────────────────────────────────────
async def instrumented_handler(websocket):
    ws_connections_active.inc()
    start = time.time()
    try:
        async for message in websocket:
            ws_messages_total.labels(direction="inbound").inc()
            ws_message_size_bytes.observe(len(message))

            response = process_message(message)
            await websocket.send(response)
            ws_messages_total.labels(direction="outbound").inc()

    finally:
        ws_connections_active.dec()
        ws_connection_duration_seconds.observe(time.time() - start)
```

---

## 14. Common Pitfalls and How to Avoid Them

|Pitfall|What Happens|Fix|
|---|---|---|
|No heartbeat|Dead connections accumulate; server leaks memory|Implement server-side ping/pong with timeout|
|In-memory connection store|Doesn't work across multiple server instances|Use Redis pub/sub as backplane|
|Token in URL query param|Token logged in access logs|Use short-lived tokens or first-message auth|
|No message size limit|Malicious client sends a 1GB message, OOM crash|Set `max_size` on the server (default 1MB in `websockets`)|
|No reconnection logic|One network blip = permanently disconnected client|Implement exponential backoff with jitter|
|Unhandled exceptions crash handler|One bad client kills all others|Wrap message handling in try/except per client|
|Sending to closed connection|`ConnectionClosed` exception crashes the sender|Check `ws.client_state` before sending; catch exceptions in broadcast|
|No auth before accepting|Unauthenticated clients consume server resources|Validate token before or immediately after `accept()`|
|Thundering herd on reconnect|Server restart → all clients retry simultaneously → overload|Exponential backoff + jitter on client|
|No close code on server shutdown|Clients don't know why they disconnected|Send close frame with code `1001` on graceful shutdown|

---

## 15. Decision Framework: WebSocket vs Alternatives

```
Does the server need to push data to the browser in real time?
└── YES → Do you also need the client to push data back?
         ├── YES → WebSocket
         └── NO  → Consider SSE (simpler, auto-reconnect, HTTP caching)

Is this service-to-service communication (no browser)?
└── YES → gRPC (bidirectional streaming) — typed contracts, better tooling

Is this browser-to-browser (video, audio, file transfer)?
└── YES → WebRTC (peer-to-peer, no server relay for media)

Is this simple polling (check every N seconds is fine)?
└── YES → HTTP long polling or SSE — WebSocket overhead not justified

Do you need message history / replay / durability?
└── YES → WebSocket + message queue (Kafka/Redis Streams) for persistence
          (WebSocket itself has no durability guarantee)
```

---

## 16. Interview Cheat Sheet

### "What is WebSocket and how does it work?"

> WebSocket is a persistent, full-duplex TCP connection established via an HTTP upgrade handshake. After the handshake, both client and server can send frames at any time without the overhead of HTTP headers on every message.

### "How is WebSocket different from HTTP polling?"

> Polling means the client repeatedly asks the server for updates — wasteful, adds latency. WebSocket lets the server push updates the moment they happen, with no repeated connection overhead.

### "How do you scale WebSockets horizontally?"

> WebSocket connections are stateful and tied to a server instance. To scale, use a pub/sub backplane (typically Redis). Each server instance subscribes to Redis channels. When a message needs to reach a user on a different server, publish it to Redis, and that server forwards it to the connected client.

### "How do you handle authentication with WebSockets?"

> Three options: (1) JWT in query param — simple but logs token in URLs; use short-lived tokens. (2) JWT as first message — more secure. (3) Cookie-based — cleanest for browsers since cookies are sent automatically with the upgrade request.

### "What are WebSocket close codes?"

> Standardized codes like HTTP status codes: 1000 = normal close, 1001 = server going away, 1008 = policy violation (auth failure), 1011 = internal server error. Always send the appropriate close code to help clients decide whether to reconnect.

### "What is a heartbeat and why do you need it?"

> TCP connections can silently die (NAT timeout, mobile network switch). A heartbeat is a periodic ping frame sent by the server; if the client doesn't respond with a pong within a timeout, the connection is considered dead and closed so the client can reconnect.

### "WebSocket vs SSE — when do you choose each?"

> SSE when you only need server→client push: simpler, built-in reconnection, works well with HTTP caching and proxies. WebSocket when the client also needs to push data in real time (chat, gaming, collaborative editing).

---

## 17. High-Quality Resources

|Resource|Why It's Worth Your Time|
|---|---|
|[RFC 6455 — The WebSocket Protocol](https://datatracker.ietf.org/doc/html/rfc6455)|The actual spec — read sections 1, 4, 5, and 7 to understand handshake, framing, and close|
|[websockets Python library docs](https://websockets.readthedocs.io/en/stable/)|Best Python WebSocket library — excellent docs covering production patterns|
|[FastAPI WebSockets docs](https://fastapi.tiangolo.com/advanced/websockets/)|Official FastAPI WebSocket guide with connection manager patterns|
|[Ably — WebSocket deep dive](https://ably.com/topic/websockets)|Best non-official resource: covers scaling, fallbacks, and real-world architecture|
|[Redis Pub/Sub docs](https://redis.io/docs/manual/pubsub/)|Official Redis pub/sub reference for the scaling backplane pattern|
