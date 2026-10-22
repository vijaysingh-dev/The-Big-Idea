# The Ultimate gRPC Guide

> For interviews, system design, and real-world production engineering

---

## Table of Contents

1. [What is gRPC?](#1-what-is-grpc)
2. [The Technology Stack Behind gRPC](#2-the-technology-stack-behind-grpc)
3. [The Four Communication Patterns](#3-the-four-communication-patterns)
4. [gRPC vs REST vs WebSockets vs WebRTC](#4-grpc-vs-rest-vs-websockets-vs-webrtc)
5. [Defining a Service: The .proto File](#5-defining-a-service-the-proto-file)
6. [How gRPC Works Internally (Request Lifecycle)](#6-how-grpc-works-internally-request-lifecycle)
7. [gRPC in Production: How Senior Engineers Use It](#7-grpc-in-production-how-senior-engineers-use-it)
8. [Load Balancing with gRPC](#8-load-balancing-with-grpc)
9. [Error Handling](#9-error-handling)
10. [Authentication & Security](#10-authentication--security)
11. [Interceptors (Middleware for gRPC)](#11-interceptors-middleware-for-grpc)
12. [Schema Evolution: Safely Changing Your API](#12-schema-evolution-safely-changing-your-api)
13. [Observability: Logging, Metrics, Tracing](#13-observability-logging-metrics-tracing)
14. [gRPC in the Browser: grpc-web](#14-grpc-in-the-browser-grpc-web)
15. [Common Pitfalls and How to Avoid Them](#15-common-pitfalls-and-how-to-avoid-them)
16. [Decision Framework: When to Use What](#16-decision-framework-when-to-use-what)
17. [Interview Cheat Sheet](#17-interview-cheat-sheet)
18. [High-Quality Resources](#18-high-quality-resources)

---

## 1. What is gRPC?

**gRPC** (Google Remote Procedure Call) is a high-performance, open-source framework for calling functions on a remote service as if they were local function calls.

Instead of manually crafting HTTP requests with JSON, you define a **contract** (what functions exist, what they take, what they return), and gRPC auto-generates client and server code in your language of choice. You just call the function.

```
Client Service A                        Server Service B
─────────────────                       ─────────────────
orderService.GetOrder(req)   ──────►    func GetOrder(req) → res
                             ◄──────    returns OrderResponse
```

### The core idea in one line

> gRPC lets microservices talk to each other with **strongly typed, auto-generated, binary-serialized function calls** over a persistent HTTP/2 connection.

### Who created it and who uses it?

- Created by **Google** in 2015, open-sourced under CNCF (Cloud Native Computing Foundation — the same org behind Kubernetes and Prometheus)
- Used in production by: **Google**, **Netflix**, **Uber**, **Dropbox**, **Square**, **Cloudflare**, **Cisco**
- The internal predecessor (Stubby) handled **10 billion RPC calls per second** inside Google

---

## 2. The Technology Stack Behind gRPC

gRPC is built on two key technologies. Understanding these is critical for both interviews and debugging in production.

### 2.1 HTTP/2 — The Transport Layer

HTTP/1.1 (what most REST APIs use) has a fundamental inefficiency: **head-of-line blocking** — if one request is slow, it blocks everything behind it on the same connection. You work around this by opening multiple parallel TCP connections, which is wasteful.

**HTTP/2** solves this with **multiplexing**: multiple requests and responses can travel over a _single_ TCP connection simultaneously, interleaved, with no blocking.

|Feature|HTTP/1.1|HTTP/2|
|---|---|---|
|Connections per host|Multiple (6–8 typical)|One|
|Request multiplexing|❌|✅|
|Header compression|❌|✅ (HPACK)|
|Server push|❌|✅|
|Binary protocol|❌ (text)|✅|

For gRPC specifically, HTTP/2 enables:

- **Streaming** in all four modes (unary, server, client, bidirectional)
- **Persistent connections** — no TCP handshake overhead per call
- **Flow control** — neither side can overwhelm the other with data

### 2.2 Protocol Buffers (Protobuf) — The Serialization Layer

**Serialization** means converting an in-memory data structure (like a Python dict or Java object) into bytes you can send over a network. JSON is text-based serialization. Protobuf is binary.

You define your data schema in a `.proto` file, and Protobuf generates code to encode/decode it.

**Why is binary better than JSON for service-to-service?**

```
JSON:   {"order_id": "abc123", "amount": 99.50, "status": "PENDING"}
        → 55 bytes, parsed character-by-character as text

Protobuf: [binary]
        → ~15 bytes, parsed directly into memory structures
```

- **3–10x smaller** payload size
- **5–10x faster** serialization/deserialization
- **Strongly typed** — no "this field is sometimes a string and sometimes a number"
- **Schema-enforced** — both sides must agree on the contract

**The tradeoff**: Binary is not human-readable. You can't `curl` a gRPC endpoint and read the response in your terminal without tooling.

---

## 3. The Four Communication Patterns

This is one of gRPC's biggest advantages over REST, and a very common interview topic.

### 3.1 Unary RPC

The simplest pattern. Client sends one request, server returns one response. Just like a regular REST call.

```
Client ──[request]──► Server
Client ◄──[response]── Server
```

```proto
rpc GetOrder (OrderRequest) returns (OrderResponse);
```

**Use case**: Fetching a user profile, creating a record, any standard CRUD operation.

---

### 3.2 Server-Side Streaming RPC

Client sends one request, server responds with a **stream** of messages. The client reads from the stream until it's done.

```
Client ──[one request]──► Server
Client ◄──[response 1]──
Client ◄──[response 2]──
Client ◄──[response 3]──
Client ◄──[stream end]──
```

```proto
rpc StreamPriceUpdates (SymbolRequest) returns (stream PriceUpdate);
```

**Use cases**:

- Streaming real-time stock price updates
- Downloading a large dataset in chunks
- Log tailing (streaming new log lines as they appear)
- Progress updates for a long-running job

---

### 3.3 Client-Side Streaming RPC

Client sends a **stream** of messages, server responds once after processing all of them.

```
Client ──[data chunk 1]──►
Client ──[data chunk 2]──►  Server
Client ──[data chunk 3]──►
Client ◄──[one response]──
```

```proto
rpc UploadSensorData (stream SensorReading) returns (UploadSummary);
```

**Use cases**:

- Uploading large files in chunks
- Sending a batch of IoT sensor readings
- Aggregating metrics from an edge device

---

### 3.4 Bidirectional Streaming RPC

Both client and server can send a stream of messages simultaneously. Neither side has to wait for the other to finish.

```
Client ──[msg 1]──►         Server
Client ◄──[response A]──
Client ──[msg 2]──►
Client ──[msg 3]──►
Client ◄──[response B]──
```

```proto
rpc ChatSession (stream ChatMessage) returns (stream ChatMessage);
```

**Use cases**:

- Real-time fraud scoring (stream transactions in, stream scores out)
- Collaborative editing (stream changes in both directions)
- Bidirectional telemetry between devices and servers

---

## 4. gRPC vs REST vs WebSockets vs WebRTC

These are often confused. The key is understanding **what problem each was designed to solve**.

### Mental Model First

|Protocol|Designed For|Who talks to whom|
|---|---|---|
|**gRPC**|Service-to-service function calls|Backend ↔ Backend|
|**REST**|Resource-based APIs, public or internal|Anyone ↔ Server|
|**WebSockets**|Real-time browser ↔ server messaging|Browser ↔ Server|
|**WebRTC**|Peer-to-peer media/data|Browser ↔ Browser|

### Detailed Comparison

||**gRPC**|**REST**|**WebSockets**|**WebRTC**|
|---|---|---|---|---|
|**Transport**|HTTP/2|HTTP/1.1 or HTTP/2|TCP (upgraded from HTTP)|UDP (mostly)|
|**Data format**|Protobuf (binary)|JSON/XML (text)|Any (text or binary)|Binary (media frames, raw data)|
|**Communication style**|RPC (function call)|Resource-based (CRUD)|Event-based messaging|Peer-to-peer streams|
|**Streaming**|4 modes built-in|Limited (SSE for server push)|Full-duplex persistent|Full-duplex peer-to-peer|
|**Schema / Contract**|Strongly typed (.proto)|Optional (OpenAPI/Swagger)|None built-in|None built-in|
|**Browser support**|Needs grpc-web proxy|Native|Native|Native|
|**Human readable**|❌ (binary)|✅ (JSON)|Depends|❌|
|**Code generation**|✅ Auto-generated clients|Optional|❌|❌|
|**Performance**|⚡⚡⚡ Very high|⚡⚡ Medium|⚡⚡ Medium|⚡⚡⚡ Very high|

### When REST beats gRPC

REST is not "worse" than gRPC — it's better in specific scenarios:

- **Public APIs**: Developers can use `curl`, Postman, any HTTP client. No special tooling needed.
- **Simple CRUD services**: The contract overhead of Protobuf isn't worth it for a simple CRUD app.
- **Cache-ability**: HTTP GET responses are cache-able at every layer (CDN, browser, proxy). gRPC has no standard caching model.
- **Browser-first apps**: REST works natively in browsers; gRPC needs grpc-web.

### When WebSockets beats gRPC

- **Browser clients** that need to receive real-time pushes from a server
- **Flexible message schemas** — you don't want to lock down a Protobuf schema and regenerate code every time the message shape changes
- **Fan-out broadcasting** — push the same event to thousands of connected browser clients

### When WebRTC beats gRPC

- **Peer-to-peer media**: Video calls, screen sharing. You want the media to travel _directly_ between browsers, not relay through your servers (latency + cost)
- **NAT traversal needed**: WebRTC handles punching through routers automatically via STUN/TURN servers (STUN = Session Traversal Utilities for NAT — a protocol that lets a device discover its public IP/port from behind a NAT)

---

## 5. Defining a Service: The .proto File

The `.proto` file is the single source of truth for a gRPC service. From it, gRPC generates client and server code in any supported language.

```proto
syntax = "proto3";

package orders;

// ─── Service Definition ───────────────────────────────────────────────────
// Defines the available RPC methods for the Order service.
service OrderService {
  rpc GetOrder           (OrderRequest)           returns (OrderResponse);
  rpc ListOrders         (ListOrdersRequest)       returns (stream OrderResponse);
  rpc CreateOrder        (stream OrderItem)        returns (OrderResponse);
  rpc OrderUpdates       (OrderRequest)            returns (stream OrderEvent);
}

// ─── Request / Response Message Types ────────────────────────────────────
// Protobuf messages are like typed structs. Field numbers (= 1, = 2)
// are used in binary encoding — never reuse or delete them.
message OrderRequest {
  string order_id = 1;
}

message OrderItem {
  string product_id = 1;
  int32  quantity   = 2;
  float  price      = 3;
}

message OrderResponse {
  string order_id   = 1;
  string status     = 2;
  float  total      = 3;
  int64  created_at = 4; // Unix timestamp
}

message ListOrdersRequest {
  string customer_id = 1;
  int32  page_size   = 2;
}

message OrderEvent {
  string event_type = 1; // e.g., "SHIPPED", "DELIVERED"
  string order_id   = 2;
  int64  timestamp  = 3;
}
```

### Key proto3 Rules

- **Field numbers** (e.g., `= 1`, `= 2`) are used in binary encoding, **not field names**. The name can change; the number must not.
- **Never delete or reuse a field number.** Mark old fields as `reserved` instead.
- All fields are optional by default in proto3 — missing fields get zero values (`""`, `0`, `false`).
- Use `repeated` for arrays: `repeated string tags = 5;`

---

## 6. How gRPC Works Internally (Request Lifecycle)

Understanding the request lifecycle helps you debug production issues and reason about performance.

```
┌────────────────┐                          ┌────────────────┐
│  Client Code   │                          │  Server Code   │
│                │                          │                │
│ stub.GetOrder()│                          │ GetOrder(req)  │
└───────┬────────┘                          └───────▲────────┘
        │                                           │
        ▼                                           │
┌───────────────┐     ┌──────────────┐    ┌────────┴───────┐
│  gRPC Client  │     │              │    │  gRPC Server   │
│  Stub         │     │   HTTP/2     │    │  Handler       │
│               │────►│   Network    │───►│                │
│  Serialize    │     │   Transport  │    │  Deserialize   │
│  (Protobuf)   │◄────│              │◄───│  (Protobuf)    │
└───────────────┘     └──────────────┘    └────────────────┘
```

**Step by step:**

1. Your code calls a method on the generated **stub** (client-side proxy object)
2. The stub **serializes** the request into Protobuf binary
3. The gRPC framework wraps it in an **HTTP/2 frame** with headers (method, content-type, metadata)
4. Sent over an **existing persistent HTTP/2 connection** (no new TCP handshake)
5. Server receives the HTTP/2 frame, **deserializes** Protobuf into the request object
6. Server calls your **handler function**
7. Response is serialized and sent back over the same HTTP/2 stream
8. Client stub deserializes response, returns it to your calling code

**Key insight for interviews**: Steps 1–3 and 6–8 happen entirely inside the generated code. You only write the handler (step 6) and the call (step 1). Everything else is gRPC's responsibility.

---

## 7. gRPC in Production: How Senior Engineers Use It

### 7.1 Service Mesh Integration

In large companies, gRPC doesn't run alone — it runs inside a **service mesh** (a dedicated infrastructure layer that handles all service-to-service traffic, including retries, timeouts, mTLS, and observability). The most common is **Istio** with **Envoy** as the sidecar proxy (a proxy running alongside every service container, intercepting all traffic).

```
[Service A] → [Envoy sidecar] → [network] → [Envoy sidecar] → [Service B]
```

The sidecars handle TLS, retries, circuit breaking, and metrics — your service code doesn't need to implement any of that.

### 7.2 Deadlines and Timeouts

Every gRPC call should have a **deadline** — an absolute point in time by which the entire call (including retries) must complete. Without deadlines, a slow downstream service can cascade failures across your entire system.

```python
# Always pass a deadline/timeout — never make an open-ended gRPC call in production
response = stub.GetOrder(request, timeout=2.0)  # 2 second deadline
```

The deadline is propagated automatically to downstream calls in the same request chain. If Service A gives Service B a 2s deadline, and B calls C, C also knows it must finish within the remaining time.

### 7.3 Retries with Backoff

gRPC has built-in retry policies you configure in the service config:

```json
{
  "retryPolicy": {
    "maxAttempts": 3,
    "initialBackoff": "0.1s",
    "maxBackoff": "1s",
    "backoffMultiplier": 2,
    "retryableStatusCodes": ["UNAVAILABLE", "DEADLINE_EXCEEDED"]
  }
}
```

**Only retry idempotent operations** — idempotent means calling the same operation multiple times produces the same result as calling it once (e.g., `GetOrder` is idempotent; `ChargeCard` is not).

### 7.4 Circuit Breaking

A **circuit breaker** is a pattern that stops sending requests to a failing service, giving it time to recover, instead of hammering it with retries and cascading the failure.

States: **Closed** (normal) → **Open** (failing, reject all calls fast) → **Half-Open** (testing recovery)

In gRPC + Envoy/Istio setups, circuit breaking is typically configured at the proxy level, not in your application code.

---

## 8. Load Balancing with gRPC

This is one of the most misunderstood gRPC topics and a **frequent interview question**.

### The Problem

Traditional HTTP/1.1 load balancers (like AWS ALB in layer 4 mode) work by distributing **TCP connections**. With REST, each HTTP request opens a new (or briefly reused) connection, so connection-level load balancing ≈ request-level load balancing.

With gRPC's persistent HTTP/2 connections, a single TCP connection carries **all requests** from that client. If your load balancer distributes connections, all traffic from Client A always goes to the same server instance — effectively no load balancing.

```
❌ Problem:
Client → [TCP connection] → Server Instance 1 (100% load)
                          → Server Instance 2 (0% load)
                          → Server Instance 3 (0% load)
```

### The Solution: L7 Load Balancing

You need **Layer 7 load balancing** — the load balancer understands HTTP/2 and distributes individual **HTTP/2 streams** (which map to individual RPC calls), not TCP connections.

```
✅ Solution:
Client → [TCP connection] → L7 Load Balancer → Server Instance 1 (33%)
                                              → Server Instance 2 (33%)
                                              → Server Instance 3 (33%)
```

Options:

- **Envoy Proxy** — the industry standard, used by Istio, AWS App Mesh
- **nginx** (with gRPC support)
- **Client-side load balancing** — the client gets a list of server IPs and load balances itself (used in some internal systems)

---

## 9. Error Handling

gRPC uses its own **status codes** instead of HTTP status codes. These are standardized across all languages.

|gRPC Status|HTTP Equivalent|Meaning|
|---|---|---|
|`OK`|200|Success|
|`INVALID_ARGUMENT`|400|Bad request (client's fault)|
|`NOT_FOUND`|404|Resource doesn't exist|
|`ALREADY_EXISTS`|409|Conflict|
|`PERMISSION_DENIED`|403|Forbidden|
|`UNAUTHENTICATED`|401|Missing/invalid auth|
|`RESOURCE_EXHAUSTED`|429|Rate limited or quota exceeded|
|`UNAVAILABLE`|503|Server down, safe to retry|
|`DEADLINE_EXCEEDED`|504|Timeout|
|`INTERNAL`|500|Server bug|

### Rich Error Details

For production APIs, raw status codes aren't enough. gRPC supports structured error details via **google.rpc.Status** — you can attach machine-readable error metadata (field violations, retry info, debug info) to any error response.

```python
# Server side: returning a rich error
from grpc_status import rpc_status
from google.rpc import error_details_pb2, status_pb2

detail = error_details_pb2.BadRequest()
detail.field_violations.add(field="order_id", description="Must be a valid UUID")

rich_status = status_pb2.Status(
    code=grpc.StatusCode.INVALID_ARGUMENT.value[0],
    message="Invalid request",
    details=[Any(type_url="...", value=detail.SerializeToString())]
)
```

---

## 10. Authentication & Security

### TLS by Default

gRPC is designed to use **TLS** (Transport Layer Security — encrypts traffic in transit, verifying server identity) by default. Unlike HTTP APIs where TLS is sometimes optional, gRPC treats it as standard.

```python
# Secure channel with TLS
credentials = grpc.ssl_channel_credentials()
channel = grpc.secure_channel('api.example.com:443', credentials)
```

### Mutual TLS (mTLS)

In internal microservice communication, companies use **mTLS** (mutual TLS) — both the client and server verify each other's certificates. This ensures only authorized services can call your gRPC endpoint.

mTLS is typically handled by the service mesh (Istio/Envoy), not your application code.

### Token-Based Auth with Metadata

gRPC passes auth tokens via **metadata** — key-value pairs attached to every call, analogous to HTTP headers:

```python
# Client: attach JWT token to every call
metadata = [('authorization', f'Bearer {token}')]
response = stub.GetOrder(request, metadata=metadata)

# Server: extract and verify the token in an interceptor
def intercept_service(continuation, handler_call_details):
    metadata = dict(handler_call_details.invocation_metadata)
    token = metadata.get('authorization', '').replace('Bearer ', '')
    if not verify_token(token):
        raise grpc.RpcError(grpc.StatusCode.UNAUTHENTICATED)
    return continuation(handler_call_details)
```

---

## 11. Interceptors (Middleware for gRPC)

**Interceptors** are the gRPC equivalent of middleware in Express.js or Django. They let you execute code before/after every RPC call without modifying your handler logic.

Common production uses:

- **Authentication**: Verify JWT on every incoming call
- **Logging**: Log every request with method name, duration, status
- **Metrics**: Record latency and error rate to Prometheus
- **Tracing**: Inject/extract trace context (more below)
- **Rate limiting**: Reject calls that exceed quotas

```python
# A server-side logging interceptor
class LoggingInterceptor(grpc.ServerInterceptor):
    def intercept_service(self, continuation, handler_call_details):
        start = time.time()
        result = continuation(handler_call_details)
        duration = time.time() - start
        print(f"{handler_call_details.method} completed in {duration:.3f}s")
        return result
```

Interceptors can be chained — each one wraps the next, forming a pipeline.

---

## 12. Schema Evolution: Safely Changing Your API

This is a major operational concern in production. Services deploy independently — your server may be on v2 while some clients are still on v1. Your Protobuf schema must handle this gracefully.

### Safe Changes (backward compatible)

- ✅ Adding a new field (old clients ignore unknown fields)
- ✅ Adding a new RPC method to the service
- ✅ Renaming a field (field numbers, not names, are used in binary encoding)
- ✅ Adding a value to an enum

### Unsafe Changes (breaking)

- ❌ Deleting a field number (mark it `reserved` instead)
- ❌ Changing a field's type (e.g., `int32` to `string`)
- ❌ Reusing a field number for a different field
- ❌ Renaming an RPC method
- ❌ Changing a unary RPC to streaming (or vice versa)

### The `reserved` Keyword

```proto
message OrderResponse {
  reserved 3, 4;           // Field numbers 3 and 4 are retired — do not reuse
  reserved "legacy_field"; // Field name is retired

  string order_id = 1;
  string status   = 2;
  // Fields 3 and 4 were removed — now reserved to prevent reuse
  float  total    = 5;
}
```

---

## 13. Observability: Logging, Metrics, Tracing

In production, you need **observability** — the ability to understand what your system is doing from the outside, without modifying code.

The three pillars:

### Logs

Use interceptors to log every call with: method name, request ID, status code, duration, error message.

### Metrics

Standard gRPC metrics (exposed to Prometheus, a popular metrics collection system):

- `grpc_server_started_total` — total RPCs started
- `grpc_server_handled_total` — total RPCs completed, labelled by status
- `grpc_server_handling_seconds` — latency histogram

Use the `go-grpc-prometheus` or `py-grpc-prometheus` libraries — they auto-instrument your server with these metrics.

### Distributed Tracing

**Distributed tracing** means tracking a single request as it flows through multiple services. Each service adds its own "span" (unit of work with start/end time) to a **trace** (the full journey of one request).

gRPC integrates with **OpenTelemetry** (the CNCF standard for tracing) via interceptors that automatically propagate trace context in gRPC metadata.

```
Request → Service A (span 1) → Service B (span 2) → Service C (span 3)
                └──────────────────── trace ──────────────────────┘
```

Visualization tools: **Jaeger**, **Zipkin**, **Tempo** (Grafana)

---

## 14. gRPC in the Browser: grpc-web

Browsers cannot speak raw HTTP/2 gRPC (they don't support the HTTP/2 trailers gRPC uses for status codes). To use gRPC from a browser, you need **grpc-web**.

```
Browser ──[grpc-web/HTTP1.1]──► Envoy Proxy ──[gRPC/HTTP2]──► Backend Service
```

The Envoy proxy translates between grpc-web (a slightly modified protocol that works over HTTP/1.1) and native gRPC.

**Limitations of grpc-web**:

- Client-side streaming is not supported
- Bidirectional streaming is not supported
- For these, use WebSockets alongside gRPC

**Alternative**: **Connect-RPC** (from Buf.build) — a newer protocol that is fully compatible with gRPC servers but also supports plain HTTP/1.1, making browser use much simpler without a proxy.

---

## 15. Common Pitfalls and How to Avoid Them

|Pitfall|What Happens|Fix|
|---|---|---|
|No deadline on calls|Slow downstream cascades into full system hang|Always set `timeout` on every call|
|Reusing field numbers|Old and new clients silently corrupt each other's data|Mark removed fields as `reserved`|
|L4 load balancer with gRPC|All traffic sticks to one server instance|Use L7 load balancer (Envoy)|
|Retrying non-idempotent RPCs|Double charges, duplicate records|Only retry on `UNAVAILABLE` / `DEADLINE_EXCEEDED` for safe operations|
|Streaming without flow control|Fast producer overwhelms slow consumer|Use gRPC's built-in flow control; don't send faster than the other side can read|
|Not using TLS internally|Internal traffic is plaintext|Use mTLS via service mesh|
|Too-large Protobuf messages|Default 4MB message limit hit|Stream large data; don't put files in messages|
|Forgetting to close streams|Connection leak|Always `close()` or `cancel()` streams in finally blocks|

---

## 16. Decision Framework: When to Use What

```
Is this internal service-to-service communication?
    └── YES → gRPC
              (unless you need extreme simplicity or public docs → REST)

Is this a browser client talking to a server?
    ├── Needs real-time push / chat / live data?
    │       └── WebSockets
    └── Standard API calls?
            └── REST (or grpc-web if your backend is already gRPC)

Is this browser-to-browser communication?
    └── YES → WebRTC
              (video, audio, peer-to-peer file transfer)

Is this a public API consumed by external developers?
    └── YES → REST
              (human-readable, curl-friendly, no tooling required)

Do you need cache-ability at CDN/browser level?
    └── YES → REST (GET requests are natively cacheable)

Do you need 4 streaming modes + strong typing + codegen?
    └── YES → gRPC
```

---

## 17. Interview Cheat Sheet

### "What is gRPC?"

> gRPC is an RPC framework built on HTTP/2 and Protobuf. It lets services call each other's functions with strongly typed contracts, auto-generated code, binary serialization, and support for four communication patterns including bidirectional streaming.

### "Why gRPC over REST for microservices?"

> Three reasons: (1) Protobuf is 3–10x smaller and faster than JSON. (2) HTTP/2 multiplexing reduces connection overhead. (3) Strongly typed contracts catch API mismatches at compile time, not at 2am in production.

### "What are the four gRPC patterns?"

> Unary (1 req → 1 res), Server streaming (1 req → many res), Client streaming (many req → 1 res), Bidirectional streaming (many req ↔ many res simultaneously).

### "How does gRPC load balancing work?"

> gRPC uses persistent HTTP/2 connections, so L4 (connection-level) load balancers don't distribute traffic across server instances. You need L7 load balancing (e.g., Envoy) which distributes individual HTTP/2 streams, not TCP connections.

### "How do you handle backward compatibility in gRPC?"

> Never delete or reuse field numbers — mark them `reserved`. New fields are safe to add because old clients ignore unknown fields. Never change field types or rename RPC methods.

### "Can gRPC work in browsers?"

> Not natively. Browsers can't send HTTP/2 trailers which gRPC requires. grpc-web adds a proxy (Envoy) that translates, but it doesn't support client or bidirectional streaming. Connect-RPC is a modern alternative.

### "What's the difference between gRPC and WebSockets?"

> gRPC is designed for typed service-to-service function calls with a schema contract. WebSockets are a persistent full-duplex channel for browser↔server messaging with no built-in schema. Both support bidirectional streaming but serve different audiences and use cases.

### "How do you secure gRPC?"

> TLS for encryption in transit. mTLS for mutual service identity verification (usually via Istio). JWT tokens passed in metadata headers, validated in server interceptors.

---

## 18. High-Quality Resources

| Resource                                                                                                            | Why It's Worth Your Time                                                                     |
| ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| [grpc.io — Core Concepts](https://grpc.io/docs/what-is-grpc/core-concepts/)                                         | Official docs — covers all four patterns with diagrams. Start here.                          |
| [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)                                  | Complete proto3 reference including field rules, reserved fields, best practices             |
| [Cindy Sridharan — On gRPC](https://medium.com/@copyconstruct/on-grpc-f4f2fa7e0c79)                                 | Honest senior-engineer take: what's good, what's hard, what you need in production           |
| [Envoy gRPC Bridge](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/grpc_bridge_filter) | How the industry-standard proxy handles gRPC routing and load balancing                      |
| [Google API Design Guide](https://cloud.google.com/apis/design)                                                     | How Google designs gRPC + REST APIs at scale — the closest thing to a production style guide |
| [Connect-RPC](https://connectrpc.com/docs/introduction)                                                             | The modern alternative to grpc-web — worth knowing for interviews about browser gRPC         |
