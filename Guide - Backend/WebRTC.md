# The Ultimate WebRTC Guide

> For interviews, system design, and real-world production engineering · Python-focused

---

## Table of Contents

1. [What is WebRTC?](#1-what-is-webrtc)
2. [The Core Architecture: Why WebRTC is Different](#2-the-core-architecture-why-webrtc-is-different)
3. [The Four Key Components](#3-the-four-key-components)
4. [How a WebRTC Connection is Established (Step by Step)](#4-how-a-webrtc-connection-is-established-step-by-step)
5. [Signaling: The Part WebRTC Doesn't Define](#5-signaling-the-part-webrtc-doesnt-define)
6. [Python: Building a Signaling Server](#6-python-building-a-signaling-server)
7. [Python: aiortc — WebRTC in Python](#7-python-aiortc--webrtc-in-python)
8. [Python: Peer-to-Peer Data Channel](#8-python-peer-to-peer-data-channel)
9. [Python: Receiving and Processing Media Streams](#9-python-receiving-and-processing-media-streams)
10. [NAT Traversal: STUN, TURN, and ICE](#10-nat-traversal-stun-turn-and-ice)
11. [SDP: The Session Description Protocol](#11-sdp-the-session-description-protocol)
12. [Media: Codecs, Tracks, and Bandwidth](#12-media-codecs-tracks-and-bandwidth)
13. [Topology Patterns: Mesh, SFU, MCU](#13-topology-patterns-mesh-sfu-mcu)
14. [Security: DTLS and SRTP](#14-security-dtls-and-srtp)
15. [Observability and Debugging](#15-observability-and-debugging)
16. [Common Pitfalls and How to Avoid Them](#16-common-pitfalls-and-how-to-avoid-them)
17. [Decision Framework: WebRTC vs Alternatives](#17-decision-framework-webrtc-vs-alternatives)
18. [Interview Cheat Sheet](#18-interview-cheat-sheet)
19. [High-Quality Resources](#19-high-quality-resources)

---

## 1. What is WebRTC?

**WebRTC** (Web Real-Time Communication) is an open standard that enables **peer-to-peer** audio, video, and arbitrary data communication directly between browsers (or native apps) — without requiring a server in the media path.

```
Traditional video call (server-relayed):
Browser A ──► Your Server ──► Browser B
(server handles all media — expensive, high latency)

WebRTC (peer-to-peer):
Browser A ◄────────────────────────────► Browser B
(media travels directly — cheaper, lower latency)
Your server only helps them find each other (signaling)
```

### What makes WebRTC unique

- **Built into browsers** — no plugins, no SDKs needed on the client side
- **Uses UDP by default** — prioritizes speed over guaranteed delivery (right choice for media)
- **Encrypted by default** — DTLS + SRTP encryption is mandatory, not optional
- **Peer-to-peer** — your server doesn't see the media traffic (unless you add a relay)
- **Adaptive** — built-in congestion control adjusts quality to available bandwidth

### Who uses WebRTC in production?

|Company|Use Case|
|---|---|
|Google Meet|Video conferencing|
|Discord|Voice channels|
|Amazon Chime|Video calling SDK|
|Cloudflare Stream|Live streaming infrastructure|
|Twilio|Programmable video/voice|
|Whereby|Browser-based video calls|
|Facebook Messenger|Video calls|

---

## 2. The Core Architecture: Why WebRTC is Different

Most network protocols are **client-server**: one side is always the server with a known address. WebRTC is **peer-to-peer**: two clients (both behind routers, firewalls, NATs) need to connect directly to each other.

This creates the fundamental challenge WebRTC solves: **how do two devices that don't have public IP addresses find and connect to each other?**

```
The Problem:
┌────────────┐         ┌────────────┐         ┌────────────┐
│ Browser A  │         │            │         │ Browser B  │
│ 192.168.1.5│ ──NAT──►│  Internet  │◄──NAT──│ 10.0.0.42  │
│ (private)  │         │            │         │ (private)  │
└────────────┘         └────────────┘         └────────────┘

Neither knows the other's real public IP. Neither can accept incoming connections.

WebRTC's Solution:
1. Use a STUN server to discover public IPs/ports
2. Use ICE to try multiple connection paths
3. Use a TURN relay as last resort if P2P fails
4. Use a Signaling server to exchange this information
```

### The Two Phases of WebRTC

```
Phase 1: Signaling (needs your server)
─────────────────────────────────────
Both peers exchange: "who am I? what can I do? how can you reach me?"
This is just data — JSON over WebSocket, HTTP, or any transport you choose.

Phase 2: Media/Data (peer-to-peer, no server)
──────────────────────────────────────────────
Actual audio/video/data flows directly between peers.
Your server is NOT in this path.
```

---

## 3. The Four Key Components

### 3.1 Signaling Server

Your custom server. Exchanges metadata between peers before connection. WebRTC does not define this — you build it. Typically WebSocket.

### 3.2 STUN Server

**STUN** = Session Traversal Utilities for NAT. A lightweight server that tells a client: "your public IP is X, your public port is Y." Used to discover the peer's external address for P2P connection attempts.

Free public STUN servers: `stun.l.google.com:19302`

### 3.3 TURN Server

**TURN** = Traversal Using Relays around NAT. A relay server used when P2P fails (symmetric NAT, restrictive firewall). Media is relayed through TURN — **this is the expensive fallback**. In production, ~15–20% of calls need TURN.

You must run your own TURN server (Coturn is the standard open-source implementation).

### 3.4 ICE Framework

**ICE** = Interactive Connectivity Establishment. The algorithm that gathers all possible ways to reach a peer (**ICE candidates**), tries them in priority order, and picks the best working path.

ICE candidate types (in priority order):

```
1. Host candidate       — direct LAN IP (fastest, only works on same network)
2. Server Reflexive     — public IP via STUN (most P2P calls use this)
3. Relayed candidate    — TURN relay (fallback, always works, costs money)
```

---

## 4. How a WebRTC Connection is Established (Step by Step)

This is the most important sequence to understand for interviews.

```
Peer A                    Signaling Server              Peer B
──────                    ────────────────              ──────
1. Create RTCPeerConnection
2. Create offer (SDP)
3. setLocalDescription(offer)
4. ──────── send offer ────────────────────────────────────────►
                                                    5. setRemoteDescription(offer)
                                                    6. Create answer (SDP)
                                                    7. setLocalDescription(answer)
                          ◄──────── send answer ────────────────
5. setRemoteDescription(answer)

[ICE Candidate Exchange — happens in parallel with SDP exchange]
9. Gather ICE candidates ──── send candidates ───────────────────►
                          ◄─── send candidates ───────────────────
10. addIceCandidate() on each received candidate

[Connectivity Checks — ICE tries each candidate pair]
11. ════════ DTLS handshake (establishes encryption) ════════════
12. ════════ SRTP/SCTP established (media/data flows) ═══════════

[Connected — P2P link active]
13. Audio/video/data flows directly between peers (no server)
```

### Key Terms

- **SDP** (Session Description Protocol) — a text format describing media capabilities: codecs supported, resolution, bitrate, transport addresses
- **Offer** — Peer A's SDP saying "I want to call you, here's what I can do"
- **Answer** — Peer B's SDP saying "OK, here's what I can do back"
- **ICE candidate** — a potential network path (IP:port) to reach a peer

---

## 5. Signaling: The Part WebRTC Doesn't Define

WebRTC deliberately leaves signaling open. You choose the transport. The only requirement: both peers must receive each other's SDP and ICE candidates.

Common choices:

- **WebSocket** — most common, low latency, bidirectional
- **HTTP long-polling** — simpler, works everywhere
- **XMPP/SIP** — for telco/enterprise integrations

The signaling server is a **thin relay** — it doesn't process or understand the SDP/ICE data, it just routes it between the right peers.

```
What the signaling server receives and forwards:
{
    "type": "offer",
    "to": "user_b_id",
    "from": "user_a_id",
    "sdp": "v=0\r\no=- 123456 2 IN IP4 ...\r\n..."  // opaque to signaling server
}
```

---

## 6. Python: Building a Signaling Server

```python
import asyncio
import json
import websockets
from dataclasses import dataclass, field

# ─── Peer registry and signaling logic ───────────────────────────────────────
# Maps peer_id → WebSocket connection.
# Routes SDP offers/answers and ICE candidates between peers.
@dataclass
class SignalingServer:
    peers: dict = field(default_factory=dict)

    async def register(self, peer_id: str, websocket):
        self.peers[peer_id] = websocket
        print(f"Peer registered: {peer_id} ({len(self.peers)} total)")

    def unregister(self, peer_id: str):
        self.peers.pop(peer_id, None)
        print(f"Peer left: {peer_id}")

    async def relay(self, sender_id: str, message: dict):
        """Forward a signaling message to the intended recipient."""
        target_id = message.get("to")
        if not target_id:
            return

        target_ws = self.peers.get(target_id)
        if not target_ws:
            # Notify sender that target is not connected
            sender_ws = self.peers.get(sender_id)
            if sender_ws:
                await sender_ws.send(json.dumps({
                    "type": "error",
                    "reason": f"Peer '{target_id}' not found"
                }))
            return

        # Stamp the sender ID and forward
        message["from"] = sender_id
        await target_ws.send(json.dumps(message))


server = SignalingServer()


# ─── WebSocket handler: one coroutine per connected peer ──────────────────────
async def handle_peer(websocket):
    peer_id = None
    try:
        # First message must be a registration
        raw = await websocket.recv()
        data = json.loads(raw)

        if data.get("type") != "register":
            await websocket.close(1008, "First message must be register")
            return

        peer_id = data["peer_id"]
        await server.register(peer_id, websocket)

        # Send list of currently online peers
        await websocket.send(json.dumps({
            "type": "peers",
            "peers": [p for p in server.peers if p != peer_id]
        }))

        # Relay all subsequent messages
        async for raw_msg in websocket:
            try:
                msg = json.loads(raw_msg)
                # These message types are all just relayed transparently
                if msg["type"] in ("offer", "answer", "ice-candidate", "bye"):
                    await server.relay(peer_id, msg)
            except (json.JSONDecodeError, KeyError):
                pass  # ignore malformed messages

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        if peer_id:
            server.unregister(peer_id)
            # Notify other peers that this peer left
            for other_ws in server.peers.values():
                try:
                    await other_ws.send(json.dumps({
                        "type": "peer_left",
                        "peer_id": peer_id
                    }))
                except Exception:
                    pass


async def main():
    async with websockets.serve(handle_peer, "0.0.0.0", 8765):
        print("Signaling server running on ws://0.0.0.0:8765")
        await asyncio.Future()


asyncio.run(main())
```

---

## 7. Python: aiortc — WebRTC in Python

`aiortc` is the production-grade Python WebRTC library. It implements the full WebRTC stack: ICE, DTLS, SRTP, RTP, RTCP, and data channels.

```bash
pip install aiortc aiohttp
```

### What aiortc is used for (it's server-side)

Unlike browser WebRTC, aiortc runs on a **Python server** and acts as a WebRTC peer. Common uses:

- **Recording bots** — join a video call and record it server-side
- **AI media processing** — receive video frames, run inference (face detection, transcription), send back results
- **Testing infrastructure** — simulate WebRTC peers in automated tests
- **Selective Forwarding Units (SFU)** — receive and forward media tracks

### Basic RTCPeerConnection Setup

```python
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCIceCandidate
from aiortc.contrib.media import MediaBlackhole, MediaPlayer, MediaRecorder
import asyncio
import json


# ─── Create and configure a WebRTC peer connection ────────────────────────────
# RTCPeerConnection is the core object — represents one peer-to-peer connection.
# Pass ICE server config to enable STUN/TURN for NAT traversal.
def create_peer_connection():
    pc = RTCPeerConnection(configuration={
        "iceServers": [
            {"urls": "stun:stun.l.google.com:19302"},    # free Google STUN
            {
                "urls": "turn:your-turn-server.com:3478",  # your TURN server
                "username": "user",
                "credential": "password",
            }
        ]
    })
    return pc


# ─── Event handlers ────────────────────────────────────────────────────────────
def attach_handlers(pc: RTCPeerConnection):
    @pc.on("connectionstatechange")
    async def on_connection_state():
        print(f"Connection state: {pc.connectionState}")
        # States: new → connecting → connected → disconnected → failed → closed
        if pc.connectionState == "failed":
            await pc.close()

    @pc.on("iceconnectionstatechange")
    async def on_ice_state():
        print(f"ICE state: {pc.iceConnectionState}")
        # ICE states: new → checking → connected → completed → failed → disconnected

    @pc.on("icegatheringstatechange")
    async def on_ice_gathering():
        print(f"ICE gathering: {pc.iceGatheringState}")
        # gathering = collecting all possible candidate paths

    @pc.on("track")
    async def on_track(track):
        print(f"Received {track.kind} track")
        # Attach a sink — what to DO with the received media
        if track.kind == "audio":
            recorder = MediaRecorder("output.mp3")
            recorder.addTrack(track)
            await recorder.start()
        elif track.kind == "video":
            recorder = MediaRecorder("output.mp4")
            recorder.addTrack(track)
            await recorder.start()
```

---

## 8. Python: Peer-to-Peer Data Channel

A **data channel** is a bidirectional data pipe between two WebRTC peers — like a WebSocket but peer-to-peer. No server in the path after connection.

```python
from aiortc import RTCPeerConnection, RTCDataChannel
import asyncio


# ─── Python "offerer" side: creates the data channel ─────────────────────────
async def run_offerer(signaling_send, signaling_recv):
    pc = create_peer_connection()

    # Create data channel — this peer initiates
    channel = pc.createDataChannel("chat", ordered=True)
    # ordered=True: messages arrive in order (like TCP). ordered=False: like UDP.

    @channel.on("open")
    def on_open():
        print("Data channel open — sending message")
        channel.send("Hello from Python!")

    @channel.on("message")
    def on_message(message):
        print(f"Received: {message}")
        if isinstance(message, bytes):
            print(f"Binary data, {len(message)} bytes")

    @channel.on("close")
    def on_close():
        print("Data channel closed")

    # Create offer and send via signaling
    offer = await pc.createOffer()
    await pc.setLocalDescription(offer)
    await signaling_send({"type": "offer", "sdp": pc.localDescription.sdp})

    # Wait for answer
    answer_data = await signaling_recv()
    answer = RTCSessionDescription(sdp=answer_data["sdp"], type="answer")
    await pc.setRemoteDescription(answer)

    # Keep connection alive
    await asyncio.sleep(30)
    await pc.close()


# ─── Python "answerer" side: receives the data channel ────────────────────────
async def run_answerer(signaling_send, signaling_recv):
    pc = create_peer_connection()

    @pc.on("datachannel")
    def on_datachannel(channel: RTCDataChannel):
        print(f"Data channel received: {channel.label}")

        @channel.on("message")
        def on_message(message):
            print(f"Got: {message}")
            # Echo the message back
            channel.send(f"Echo: {message}")

    # Receive offer
    offer_data = await signaling_recv()
    offer = RTCSessionDescription(sdp=offer_data["sdp"], type="offer")
    await pc.setRemoteDescription(offer)

    # Create and send answer
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    await signaling_send({"type": "answer", "sdp": pc.localDescription.sdp})

    await asyncio.sleep(30)
    await pc.close()
```

### Sending Binary Data Over Data Channel

```python
import struct
import numpy as np


# ─── Send structured binary data over WebRTC data channel ─────────────────────
# Useful for real-time sensor data, game state, ML inference results.
def send_sensor_reading(channel: RTCDataChannel, sensor_id: int, values: list[float]):
    """
    Pack sensor data into binary: 4-byte sensor_id + N 4-byte floats.
    Binary is more efficient than JSON for high-frequency numeric data.
    """
    header = struct.pack(">I", sensor_id)           # unsigned 4-byte big-endian int
    body = struct.pack(f">{len(values)}f", *values) # N 4-byte floats
    channel.send(header + body)


def parse_sensor_reading(data: bytes):
    sensor_id = struct.unpack(">I", data[:4])[0]
    n_floats = (len(data) - 4) // 4
    values = struct.unpack(f">{n_floats}f", data[4:])
    return sensor_id, list(values)
```

---

## 9. Python: Receiving and Processing Media Streams

This is where aiortc shines — running AI/ML inference on real-time video from WebRTC peers.

```python
import asyncio
import cv2
import numpy as np
from aiortc import RTCPeerConnection, MediaStreamTrack
from aiortc.contrib.media import MediaRelay
from av import VideoFrame


# ─── Custom video track: transform incoming frames ────────────────────────────
# Subclass VideoStreamTrack to intercept and process each video frame.
# recv() is called once per frame (~30 fps). Return a modified frame.
class VideoProcessingTrack(MediaStreamTrack):
    kind = "video"

    def __init__(self, source_track, transform="grayscale"):
        super().__init__()
        self.source = source_track
        self.transform = transform

    async def recv(self):
        # Get the next frame from the source track
        frame = await self.source.recv()

        # Convert to numpy array for OpenCV processing
        img = frame.to_ndarray(format="bgr24")

        if self.transform == "grayscale":
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            img = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

        elif self.transform == "edge_detect":
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            edges = cv2.Canny(gray, 100, 200)
            img = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)

        # Rebuild an av VideoFrame with the same metadata (pts, time_base)
        new_frame = VideoFrame.from_ndarray(img, format="bgr24")
        new_frame.pts = frame.pts
        new_frame.time_base = frame.time_base
        return new_frame


# ─── ML inference on incoming video frames ────────────────────────────────────
class MLInferenceTrack(MediaStreamTrack):
    kind = "video"

    def __init__(self, source_track, model):
        super().__init__()
        self.source = source_track
        self.model = model   # any model: YOLO, MediaPipe, etc.

    async def recv(self):
        frame = await self.source.recv()
        img = frame.to_ndarray(format="rgb24")

        # Run inference (in production, offload to thread pool to avoid blocking)
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(None, self.model.predict, img)

        # Draw bounding boxes / annotations on the frame
        annotated = draw_detections(img, results)

        new_frame = VideoFrame.from_ndarray(annotated, format="rgb24")
        new_frame.pts = frame.pts
        new_frame.time_base = frame.time_base
        return new_frame


# ─── Server that receives video, processes it, and sends back ─────────────────
async def create_processing_server(offer_sdp: str) -> str:
    pc = RTCPeerConnection()

    @pc.on("track")
    async def on_track(track):
        if track.kind == "video":
            # Replace incoming track with processed version
            processed = VideoProcessingTrack(track, transform="edge_detect")
            pc.addTrack(processed)
        elif track.kind == "audio":
            # Pass audio through unchanged
            pc.addTrack(track)

    offer = RTCSessionDescription(sdp=offer_sdp, type="offer")
    await pc.setRemoteDescription(offer)

    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)

    return pc.localDescription.sdp
```

### Recording Incoming Media to Disk

```python
from aiortc.contrib.media import MediaRecorder


# ─── Record all incoming tracks from a WebRTC peer ────────────────────────────
async def record_peer(offer_sdp: str, output_path: str) -> str:
    pc = RTCPeerConnection()
    recorder = MediaRecorder(output_path)  # .mp4, .mkv, .mp3 etc.

    @pc.on("track")
    async def on_track(track):
        recorder.addTrack(track)
        # Start recording when first track arrives
        if pc.connectionState != "connected":
            await recorder.start()

    @pc.on("connectionstatechange")
    async def on_state():
        if pc.connectionState in ("failed", "closed"):
            await recorder.stop()

    offer = RTCSessionDescription(sdp=offer_sdp, type="offer")
    await pc.setRemoteDescription(offer)

    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    return pc.localDescription.sdp
```

---

## 10. NAT Traversal: STUN, TURN, and ICE

NAT traversal is the hardest part of WebRTC to understand but essential for production.

### Types of NAT (from easiest to hardest to traverse)

```
Full Cone NAT        — once a port is open, anyone can send to it
                       [easiest — P2P almost always works]

Address-Restricted   — only the server you contacted can send back
Cone NAT             [P2P usually works]

Port-Restricted      — only the exact IP:port you contacted can send back
Cone NAT             [P2P usually works]

Symmetric NAT        — different external port for every destination
                       [P2P often fails — needs TURN relay]
```

Corporate networks and mobile carriers often use Symmetric NAT. This is why ~15–20% of WebRTC calls need TURN.

### ICE Candidate Gathering

```python
from aiortc import RTCPeerConnection
import asyncio


# ─── Gather and inspect ICE candidates ────────────────────────────────────────
# In production you don't do this manually — aiortc handles it.
# This shows what candidates look like for debugging.
async def inspect_ice_candidates():
    pc = RTCPeerConnection(configuration={
        "iceServers": [
            {"urls": "stun:stun.l.google.com:19302"}
        ]
    })

    candidates = []

    @pc.on("icecandidate")
    async def on_candidate(candidate):
        if candidate:
            candidates.append(candidate)
            print(f"Candidate type: {candidate.type}")
            print(f"  IP: {candidate.ip}:{candidate.port}")
            print(f"  Protocol: {candidate.protocol}")  # udp or tcp
            # Candidate types: host, srflx (server reflexive), relay (TURN)

    # Creating an offer triggers ICE gathering
    offer = await pc.createOffer()
    await pc.setLocalDescription(offer)

    # Wait for gathering to complete
    while pc.iceGatheringState != "complete":
        await asyncio.sleep(0.1)

    print(f"\nTotal candidates gathered: {len(candidates)}")
    for c in candidates:
        print(f"  {c.type}: {c.ip}:{c.port} ({c.protocol})")

    await pc.close()
```

### Setting Up Coturn (TURN Server)

```bash
# Install coturn on Ubuntu
sudo apt install coturn

# /etc/turnserver.conf (minimal production config)
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=YOUR_PUBLIC_IP
realm=yourdomain.com
server-name=yourdomain.com

# Use time-limited credentials (don't use static username/password in production)
use-auth-secret
static-auth-secret=YOUR_RANDOM_SECRET_KEY

# TLS certificates
cert=/etc/letsencrypt/live/yourdomain.com/fullchain.pem
pkey=/etc/letsencrypt/live/yourdomain.com/privkey.pem

# Logging
log-file=/var/log/coturn/turnserver.log
```

```python
import hmac
import hashlib
import base64
import time


# ─── Generate time-limited TURN credentials ───────────────────────────────────
# Credentials expire after TTL seconds. This prevents credential abuse.
# The TURN server validates these using the same shared secret.
def generate_turn_credentials(username: str, ttl: int = 3600) -> dict:
    expiry = int(time.time()) + ttl
    turn_username = f"{expiry}:{username}"

    # HMAC-SHA1 of the username using the shared secret
    secret = "YOUR_RANDOM_SECRET_KEY"
    credential = base64.b64encode(
        hmac.new(secret.encode(), turn_username.encode(), hashlib.sha1).digest()
    ).decode()

    return {
        "urls": [
            "turn:yourdomain.com:3478",
            "turns:yourdomain.com:5349"  # TLS variant
        ],
        "username": turn_username,
        "credential": credential,
    }
```

---

## 11. SDP: The Session Description Protocol

SDP is the text format used to describe what each peer can do. It looks intimidating but has a clear structure.

```
v=0                          ← version
o=- 123456789 2 IN IP4 ...   ← origin/session ID
s=-                          ← session name
t=0 0                        ← timing (0 0 = no specific time range)
a=group:BUNDLE 0 1           ← bundle audio and video on same transport

m=audio 9 UDP/TLS/RTP/SAVPF 111  ← audio media section, codec 111
a=mid:0
a=rtpmap:111 opus/48000/2    ← codec 111 = Opus, 48kHz, stereo
a=fmtp:111 minptime=10;useinbandfec=1
a=ice-ufrag:abc123           ← ICE credentials
a=ice-pwd:longpassword...
a=fingerprint:sha-256 AB:CD... ← DTLS fingerprint for verification
a=setup:actpass
a=sendrecv                   ← this peer sends and receives audio

m=video 9 UDP/TLS/RTP/SAVPF 96  ← video media section, codec 96
a=mid:1
a=rtpmap:96 VP8/90000        ← codec 96 = VP8 at 90kHz clock
a=rtpmap:97 H264/90000       ← also supports H264
```

### Reading SDP in Python for Debugging

```python
# ─── Parse and inspect SDP fields for debugging ───────────────────────────────
def parse_sdp_summary(sdp: str) -> dict:
    summary = {"audio_codecs": [], "video_codecs": [], "ice_candidates": []}
    current_media = None

    for line in sdp.strip().split("\r\n"):
        if line.startswith("m=audio"):
            current_media = "audio"
        elif line.startswith("m=video"):
            current_media = "video"
        elif line.startswith("a=rtpmap:"):
            # e.g., "a=rtpmap:111 opus/48000/2"
            codec_info = line.split(" ", 1)[1] if " " in line else ""
            codec_name = codec_info.split("/")[0].lower()
            if current_media == "audio":
                summary["audio_codecs"].append(codec_name)
            elif current_media == "video":
                summary["video_codecs"].append(codec_name)
        elif line.startswith("a=candidate:"):
            summary["ice_candidates"].append(line[12:])

    return summary


# Usage
sdp_text = pc.localDescription.sdp
summary = parse_sdp_summary(sdp_text)
print(f"Audio codecs: {summary['audio_codecs']}")   # ['opus', 'g722']
print(f"Video codecs: {summary['video_codecs']}")   # ['vp8', 'vp9', 'h264']
print(f"ICE candidates: {len(summary['ice_candidates'])}")
```

---

## 12. Media: Codecs, Tracks, and Bandwidth

### Common Codecs

|Type|Codec|Notes|
|---|---|---|
|Audio|**Opus**|Default WebRTC audio codec. Excellent quality, adaptive bitrate (6–510 kbps), handles packet loss well|
|Audio|G.711 (PCMU/PCMA)|Legacy telephony codec, required for SIP/PSTN interop|
|Video|**VP8**|Google's codec, open source, always supported in WebRTC|
|Video|**VP9**|Better compression than VP8, ~30–50% bandwidth saving|
|Video|**H.264**|Required for iOS Safari, hardware acceleration on most devices|
|Video|**AV1**|Newest, best compression, but high CPU cost|

### Bandwidth and Quality Control

```python
# ─── Set maximum bitrate limits for a peer connection ─────────────────────────
# Without limits, WebRTC tries to use as much bandwidth as possible.
# In production, set limits based on user's plan tier or network conditions.
async def set_bitrate_limits(pc: RTCPeerConnection, video_kbps: int, audio_kbps: int):
    for sender in pc.getSenders():
        params = sender.getParameters()
        if not params.encodings:
            params.encodings = [{}]

        if sender.track and sender.track.kind == "video":
            params.encodings[0]["maxBitrate"] = video_kbps * 1000
        elif sender.track and sender.track.kind == "audio":
            params.encodings[0]["maxBitrate"] = audio_kbps * 1000

        await sender.setParameters(params)


# Typical tier settings:
# Low quality (mobile/slow network): video=200kbps, audio=32kbps
# Standard (1:1 call):               video=800kbps, audio=64kbps
# High quality (screen share):       video=2500kbps, audio=128kbps
```

---

## 13. Topology Patterns: Mesh, SFU, MCU

How you connect multiple participants in a group call is a critical architecture decision.

### Mesh (P2P, everyone to everyone)

```
         A
        /|\
       / | \
      B──┼──C
       \ | /
        \|/
         D
Each peer sends to every other peer directly.
```

- ✅ No media server needed — lowest infrastructure cost
- ✅ Lowest latency — direct P2P
- ❌ Upload bandwidth scales as O(N-1) — 5 participants = 4 upload streams
- ❌ Each peer encodes video N-1 times — CPU explosion
- **Use when**: 2–4 participants max

### SFU (Selective Forwarding Unit)

```
A ──► SFU ──► B
B ──► SFU ──► A, C, D
C ──► SFU ──► A, B, D
```

Each peer sends **one** stream to the SFU. The SFU forwards (not re-encodes) it to all subscribers.

- ✅ Each peer uploads once — manageable bandwidth
- ✅ SFU can selectively forward (e.g., only send active speaker's video)
- ✅ Scales to 100+ participants
- ❌ Media flows through your server — infrastructure cost
- ❌ SFU must be deployed and scaled
- **Use when**: 5–100+ participants. Industry standard (Jitsi, Mediasoup, LiveKit use SFU)

### MCU (Multipoint Control Unit)

```
A ──►           ──► B (composite: A+B+C in one stream)
B ──► MCU mixer ──► A (composite: A+B+C in one stream)
C ──►           ──► C (composite: A+B+C in one stream)
```

MCU decodes all streams, mixes them into one composite video, re-encodes, and sends one stream per participant.

- ✅ Each peer only receives one stream — ideal for low-bandwidth clients
- ❌ Extremely CPU-intensive on the server — re-encoding is expensive
- ❌ Higher latency due to decode-mix-encode pipeline
- **Use when**: very low-bandwidth participants, legacy SIP/PSTN integration

### Python: Simple SFU Concept with aiortc

```python
from aiortc import RTCPeerConnection, MediaStreamTrack
from aiortc.contrib.media import MediaRelay

# ─── MediaRelay acts as a simple SFU: one source, many subscribers ────────────
# One peer sends a track → relay → many peers receive it.
# No re-encoding — just forwarding (hence "selective forwarding").
relay = MediaRelay()


async def add_participant(offer_sdp: str, room_id: str) -> str:
    room = get_or_create_room(room_id)  # your room management logic
    pc = RTCPeerConnection()

    @pc.on("track")
    async def on_track(track: MediaStreamTrack):
        # Proxy this track through the relay for other participants
        relayed = relay.subscribe(track)
        room.add_track(relayed)

        # Send all existing tracks in the room to this new participant
        for existing_track in room.get_tracks():
            if existing_track != relayed:
                pc.addTrack(existing_track)

    offer = RTCSessionDescription(sdp=offer_sdp, type="offer")
    await pc.setRemoteDescription(offer)
    answer = await pc.createAnswer()
    await pc.setLocalDescription(answer)
    return pc.localDescription.sdp
```

---

## 14. Security: DTLS and SRTP

WebRTC security is **mandatory** — you cannot disable it.

### DTLS (Datagram TLS)

**DTLS** — TLS for UDP. Negotiates encryption keys and verifies peer identity via certificate fingerprints. The fingerprint is included in the SDP (exchanged via signaling), so if a man-in-the-middle alters the SDP, the DTLS handshake fails.

### SRTP (Secure RTP)

**SRTP** = Secure Real-time Transport Protocol. Encrypts and authenticates all media packets using keys derived from the DTLS handshake. Audio and video are always encrypted — even through TURN relays.

### Why This Matters for Your Signaling Server Security

The media is always encrypted end-to-end. But the **signaling channel** is where you need to be careful:

```python
# ─── Validate SDP fingerprints in signaling to prevent tampering ──────────────
# If an attacker intercepts and modifies the signaling, they could try
# to inject their own fingerprint for a MITM attack.
# Always use WSS (WebSocket over TLS) for signaling to prevent this.
import re

def extract_fingerprint(sdp: str) -> str | None:
    match = re.search(r"a=fingerprint:(\S+ \S+)", sdp)
    return match.group(1) if match else None

def validate_sdp_basic(sdp: str) -> bool:
    """Reject obviously malformed SDPs before processing."""
    if not sdp or len(sdp) > 64_000:  # reasonable size limit
        return False
    if not sdp.startswith("v=0"):
        return False
    if extract_fingerprint(sdp) is None:
        return False  # must have DTLS fingerprint
    return True
```

---

## 15. Observability and Debugging

### WebRTC Stats (getStats API equivalent in aiortc)

```python
# ─── Collect connection statistics for monitoring ─────────────────────────────
async def collect_stats(pc: RTCPeerConnection) -> dict:
    stats = await pc.getStats()
    summary = {
        "inbound_rtp": [],
        "outbound_rtp": [],
        "candidate_pair": None,
    }

    for report in stats.values():
        if report.type == "inbound-rtp":
            summary["inbound_rtp"].append({
                "kind": report.kind,             # "audio" or "video"
                "packets_received": report.packetsReceived,
                "packets_lost": report.packetsLost,
                "bytes_received": report.bytesReceived,
                "jitter": report.jitter,         # packet timing irregularity
            })
        elif report.type == "outbound-rtp":
            summary["outbound_rtp"].append({
                "kind": report.kind,
                "packets_sent": report.packetsSent,
                "bytes_sent": report.bytesSent,
            })
        elif report.type == "candidate-pair" and report.nominated:
            summary["candidate_pair"] = {
                "local_candidate_type": report.localCandidateId,
                "state": report.state,
                "current_rtt": report.currentRoundTripTime,  # latency in seconds
                "available_outgoing_bitrate": getattr(report, "availableOutgoingBitrate", None),
            }

    return summary


# ─── Log stats periodically for health monitoring ─────────────────────────────
async def monitor_connection(pc: RTCPeerConnection, interval: int = 5):
    while pc.connectionState == "connected":
        stats = await collect_stats(pc)
        for rtp in stats["inbound_rtp"]:
            loss_pct = (rtp["packets_lost"] / max(rtp["packets_received"], 1)) * 100
            print(f"{rtp['kind']} — loss: {loss_pct:.1f}%, jitter: {rtp['jitter']:.3f}s")

        if stats["candidate_pair"]:
            rtt_ms = (stats["candidate_pair"]["current_rtt"] or 0) * 1000
            print(f"RTT: {rtt_ms:.1f}ms")

        await asyncio.sleep(interval)
```

### Common Debugging Checklist

```
Connection fails immediately:
  □ Is the signaling server reachable? (check WSS connection)
  □ Is the SDP being relayed correctly? (log raw SDP at both ends)
  □ Are ICE credentials in the SDP correct?

Connection hangs in "checking":
  □ Is STUN server reachable? (test: stunclient stun.l.google.com 19302)
  □ Are both peers behind symmetric NAT? (need TURN)
  □ Is TURN server configured correctly? (test with turnutils_uclient)
  □ Check firewall: UDP 3478 open? TCP fallback on 443?

Audio/video works but quality is poor:
  □ Check packet loss % (> 5% = problems)
  □ Check RTT (> 200ms = noticeable delay)
  □ Check available bandwidth vs. bitrate settings
  □ Is the selected candidate type "relay"? (TURN relay adds latency)

Works locally, fails in production:
  □ TURN server has correct external-ip configured?
  □ Security groups allow UDP traffic on TURN port?
  □ TLS certificate valid for TURNS (port 5349)?
```

---

## 16. Common Pitfalls and How to Avoid Them

|Pitfall|What Happens|Fix|
|---|---|---|
|No TURN server|~15–20% of calls fail behind symmetric NAT|Deploy Coturn; always include TURN in iceServers config|
|Static TURN credentials|Credentials leak → anyone can abuse your TURN bandwidth|Use time-limited HMAC credentials (TTL 24h)|
|Signaling over plain WS (not WSS)|SDP interception → potential MITM attack|Always use WSS (TLS) for signaling in production|
|Not handling ICE failure|Call hangs silently when ICE fails|Listen to `iceconnectionstatechange`, surface "failed" to user|
|Mesh topology beyond 4 people|CPU/bandwidth explosion on clients|Switch to SFU (LiveKit, Mediasoup) for group calls|
|Not closing RTCPeerConnection|Resources (ports, threads) leak over time|Always call `await pc.close()` in a finally block|
|Forgetting renegotiation|Adding a track mid-call silently fails|Trigger `createOffer()` again after `addTrack()` — renegotiate|
|Blocking the event loop in recv()|Frame processing (ML inference) starves the RTP stack, causing packet loss|Use `run_in_executor()` for CPU-bound work in media tracks|
|Not handling reconnection|Transient network blip = permanent disconnect|Monitor `connectionState`, attempt ICE restart on "disconnected"|
|Large SDP with many codecs|Negotiation slow, unexpected codec selected|Filter SDP to only codecs you actually support|

---

## 17. Decision Framework: WebRTC vs Alternatives

```
Is this browser-to-browser communication?
├── Audio/video call? → WebRTC
├── File transfer between browsers? → WebRTC Data Channel
└── Game state sync between browser clients? → WebRTC Data Channel (low latency)

Is a server in the media path acceptable?
├── YES, and it's 1:1 or small group? → WebSocket (simpler) or WebRTC
└── NO (privacy, latency, cost) → WebRTC

Is this server-to-server or backend media processing?
└── WebSocket or gRPC (WebRTC overhead not justified without P2P benefit)

Do you need guaranteed message delivery and ordering?
├── YES, and latency-tolerant? → WebSocket (TCP-based, ordered)
└── YES, but need low latency? → WebRTC Data Channel with ordered=True

Do you need to process/record media server-side?
├── Use aiortc — Python WebRTC peer that joins the call
└── Or use SFU (LiveKit/Jitsi) with recording plugin
```

---

## 18. Interview Cheat Sheet

### "What is WebRTC and how is it different from WebSockets?"

> WebRTC is a peer-to-peer protocol for audio, video, and data — media flows directly between browsers without a server relay. WebSockets are a server-mediated full-duplex channel — all traffic flows through your server. WebRTC uses UDP for low-latency media; WebSockets use TCP.

### "Walk me through how a WebRTC call is established."

> (1) Both peers connect to your signaling server. (2) Peer A creates an SDP offer describing its media capabilities and sends it via signaling. (3) Peer B creates an SDP answer and sends it back. (4) In parallel, both gather ICE candidates (possible connection paths via STUN/TURN) and exchange them via signaling. (5) ICE checks all candidate pairs and picks the best working path. (6) DTLS handshake establishes encryption. (7) Media/data flows directly P2P.

### "What is the difference between STUN and TURN?"

> STUN discovers a peer's public IP:port so P2P connection can be attempted. TURN is a relay — when P2P fails (symmetric NAT), media is relayed through the TURN server. STUN is free, stateless, and cheap. TURN is expensive (it carries all media bandwidth) and needs to be deployed and scaled.

### "What is ICE and what are ICE candidates?"

> ICE (Interactive Connectivity Establishment) is the algorithm that finds the best network path between two peers. It gathers ICE candidates — possible connection paths: direct LAN (host), public IP via STUN (server reflexive), or TURN relay. ICE tries them in priority order and picks the one that works.

### "What is SDP?"

> SDP (Session Description Protocol) is a text format that describes a peer's capabilities: what codecs it supports, what tracks it has, its ICE credentials, and its DTLS fingerprint. The offer/answer exchange is just two SDPs being negotiated.

### "Mesh vs SFU — when would you use each for group video calls?"

> Mesh (P2P) works for up to 4 participants — each peer uploads N-1 streams, which becomes impractical quickly. SFU (Selective Forwarding Unit) has each peer upload once to a server that forwards streams to subscribers without re-encoding. SFU scales to 100+ participants and is the industry standard.

### "How is WebRTC encrypted?"

> WebRTC mandates encryption — it cannot be disabled. DTLS secures the control channel and exchanges keys. SRTP encrypts all audio/video using those keys. Even traffic going through a TURN relay is encrypted end-to-end between peers.

---

## 19. High-Quality Resources

| Resource                                                                    | Why It's Worth Your Time                                                                                                      |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| [WebRTC for the Curious](https://webrtcforthecurious.com/)                  | Free book by Pion (WebRTC library) authors — deep dive on protocols, NAT traversal, and internals. Best resource that exists. |
| [aiortc documentation](https://aiortc.readthedocs.io/)                      | Official Python WebRTC library docs with examples for media, data channels, and signaling                                     |
| [Coturn documentation](https://github.com/coturn/coturn/wiki)               | Complete TURN server setup guide — essential for production deployments                                                       |
| [RFC 8825 — WebRTC Overview](https://datatracker.ietf.org/doc/html/rfc8825) | Official spec overview — read to understand exactly what WebRTC is and is not                                                 |
| [LiveKit — open source SFU](https://livekit.io/docs)                        | Production SFU with Python SDK — best starting point for group calls                                                          |
| [WebRTC samples (Google)](https://webrtc.github.io/samples/)                | Browser-based interactive demos for every WebRTC concept — use for hands-on learning                                          |
