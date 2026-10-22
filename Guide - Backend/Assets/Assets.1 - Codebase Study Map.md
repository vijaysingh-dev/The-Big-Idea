**Up:** [[00 - Index (Backend)]] | **Prev:** [[16.10 - Phase 9 - RAG and the AI Handoff]]

---

# Codebase Study Map

#backend #reading #open-source

> **Why this file exists:** Tutorials teach you the happy path. Production code teaches you what actually happens. Every topic in this vault points here.
>
> **Rule:** You read code with a question in your hand. Never open a repo to "look around" — open it to answer one specific question. Every entry below gives you the question.

---

## How to Use This

For each topic you will find:

- **Repo** — what to clone
- **Why this one** — what makes it worth your time over the alternatives
- **Read** — the exact files or folders, in order
- **Question to answer** — what you must be able to explain afterwards
- **Size** — how long a real reading session takes

Do not try to understand a whole repo. Trace **one path** through it. See [[15.1 - How to Read a Large Codebase]].

---

## The Core Five

If you only ever read five codebases, read these. They cover 80% of what this vault teaches.

| Repo | Language | Teaches you |
|---|---|---|
| **redis/redis** | C | Event loops, TCP servers, single-threaded design, data structures |
| **encode/uvicorn** + **encode/starlette** | Python | How your own framework actually serves a request |
| **celery/celery** + **celery/kombu** | Python | Distributed workers, brokers, acks, retries |
| **saleor/saleor** | Python (Django) | A real large GraphQL + Postgres product |
| **GoogleCloudPlatform/microservices-demo** | Go/Python/Node | A real multi-service system with gRPC |

Everything else below is a supplement to these.

---

## 01 — Python Runtime and Concurrency

### asyncio itself (CPython)

- **Repo**: `python/cpython`
- **Why this one**: asyncio is pure Python. You can read the entire event loop. Almost nobody does, and that is exactly why it separates you.
- **Read**, in this order:
  - `Lib/selectors.py` — the thin wrapper over epoll. Start here, it is short.
  - `Lib/asyncio/events.py` — the loop interface and handles
  - `Lib/asyncio/base_events.py` — `run_forever`, `_run_once`. **This is the heart.** Read `_run_once` five times.
  - `Lib/asyncio/futures.py` then `Lib/asyncio/tasks.py` — how `await` is driven
  - `Lib/asyncio/selector_events.py` — how a socket read becomes a callback
- **Question to answer**: When you call `await reader.read()`, trace every step until the loop calls your callback back. Where exactly does control leave your function, and what wakes it up?
- **Size**: 3 sessions of 2 hours.

### uvicorn — the server

- **Repo**: `encode/uvicorn`
- **Why this one**: This is the thing running your FastAPI app right now.
- **Read**: `uvicorn/server.py` → `uvicorn/protocols/http/h11_impl.py` (also look at `httptools_impl.py` and compare) → `uvicorn/lifespan/on.py`
- **Question to answer**: How many bytes arrive before your endpoint function is called? Where does the request body get read, and what happens if you never read it?
- **Size**: 1 session.

### starlette — the framework

- **Repo**: `encode/starlette`
- **Read**: `starlette/applications.py` → `starlette/routing.py` → `starlette/middleware/base.py` → `starlette/responses.py` (look hard at `StreamingResponse`) → `starlette/concurrency.py`
- **Question to answer**: What does `run_in_threadpool` do for a `def` endpoint versus an `async def` one, and how does that change your throughput?
- **Size**: 1 session.

### uvloop — the fast path

- **Repo**: `MagicStack/uvloop`
- **Why**: Shows you the same interface implemented on libuv. Skim only — the point is to see that the event loop is swappable.
- **Read**: the README benchmarks and `uvloop/loop.pyx` signatures. Do not go deep into Cython.

---

## 02 — Networking Foundations

### Redis networking layer

- **Repo**: `redis/redis`
- **Why this one**: The most readable production TCP server in existence. Antirez wrote it to be read. It is only a few thousand lines for the whole networking core.
- **Read**, in this order:
  - `src/ae.c` and `src/ae.h` — a complete event loop in ~450 lines
  - `src/ae_epoll.c` — the epoll backend
  - `src/anet.c` — socket setup: `TCP_NODELAY`, backlog, non-blocking mode
  - `src/networking.c` — `createClient`, `readQueryFromClient`, `addReply`, the output buffer limits
- **Question to answer**: A client sends `GET key`. Trace from the epoll wakeup to the bytes going back out. Where is the read buffer? What happens if the client stops reading but Redis keeps writing?
- **Size**: 2 sessions. This is the single highest-value reading session in the vault.

### h11 — HTTP/1.1 with no I/O at all

- **Repo**: `python-hyper/h11`
- **Why this one**: A "sans-IO" library — it parses HTTP without touching a socket. It is the cleanest possible separation between protocol and transport, and it is small.
- **Read**: `h11/_state.py` (the state machine — read the diagram in the comments first) → `h11/_readers.py` → `h11/_writers.py` → `h11/_connection.py`
- **Question to answer**: What states can an HTTP/1.1 connection be in, and which transitions are illegal? Why does keep-alive depend on framing?
- **Size**: 1 session.

### mitmproxy — seeing traffic

- **Repo**: `mitmproxy/mitmproxy`
- **Why**: Use it as a **tool** first, read it second. Intercept your own app's traffic and see raw HTTP/1.1, HTTP/2 and TLS.
- **Read** (optional): `mitmproxy/proxy/layers/` to see protocol layering done well.

### Tooling drill (not reading — doing)

- `tcpdump -i lo0 -A port 8000` while you curl your own server
- `ss -tan state time-wait | wc -l` on a box under load
- Wireshark: capture one TCP handshake and one TLS handshake, label every packet

---

## 03 — HTTP

### Caddy — a modern HTTP server in readable Go

- **Repo**: `caddyserver/caddy`
- **Why this one**: nginx is C and 20 years old; Envoy is C++ and enormous. Caddy is modern Go, does HTTP/1.1, 2 and 3, and automatic TLS.
- **Read**: `modules/caddyhttp/server.go` → `modules/caddyhttp/reverseproxy/reverseproxy.go` (look at the buffering and streaming logic) → `modules/caddyhttp/reverseproxy/healthchecks.go`
- **Question to answer**: When Caddy proxies a streaming response, what decides whether it buffers or flushes immediately? This is exactly the bug that breaks SSE.
- **Size**: 1 session.

### python-hyper/h2 — HTTP/2

- **Repo**: `python-hyper/h2`
- **Read**: `h2/connection.py` → `h2/stream.py` → look at `h2/windows.py` for flow control
- **Question to answer**: How do two streams share one TCP connection without one starving the other? What is the flow-control window doing?
- **Size**: 1 session.

### Envoy (docs, not source)

- **Repo**: `envoyproxy/envoy` — read `docs/root/intro/arch_overview/` rather than the C++.
- **Question to answer**: What does an L7 proxy do that an L4 one cannot, and why does gRPC need L7 load balancing?

---

## 04 — Realtime Transports

### vLLM — real SSE streaming at scale

- **Repo**: `vllm-project/vllm`
- **Why this one**: This is production LLM serving. Their SSE endpoint is the exact pattern you will use in AI work.
- **Read**: `vllm/entrypoints/openai/api_server.py` → `vllm/entrypoints/openai/serving_chat.py` (find the generator that yields chunks) → look for how they handle client disconnect
- **Question to answer**: What happens to the GPU work when the client closes the connection mid-stream? How do they detect it?
- **Size**: 1 session. Double value — it is also your entry point to the AI vault.

### Zulip — long polling and realtime done at scale

- **Repo**: `zulip/zulip`
- **Why this one**: Zulip's realtime layer is famously well-engineered and heavily documented in-repo. It is Django + Tornado, so it is close to your stack.
- **Read**: `zerver/tornado/event_queue.py` → `zerver/tornado/handlers.py` → `zerver/lib/queue.py`
- **Question to answer**: How does a client that was offline for 10 minutes catch up without missing or duplicating events?
- **Size**: 2 sessions.

### Centrifugo — a dedicated realtime server

- **Repo**: `centrifugal/centrifugo`
- **Why this one**: A production server that speaks WebSocket, SSE and HTTP-streaming with a Redis backplane. It shows you what "scaling connections" looks like as a product.
- **Read**: `internal/client/` (connection handling) and the Redis broker in `internal/` — plus the docs on presence and history
- **Question to answer**: How does a message published on node A reach a client connected to node B?

### Django Channels

- **Repo**: `django/channels` + `django/channels_redis`
- **Read**: `channels/consumer.py`, `channels_redis/core.py` (the group send implementation)
- **Question to answer**: What are the delivery guarantees of a channel layer group send? What happens when a consumer is slow?

---

## 05 — API Design and Styles

### graphql-core — the reference execution engine

- **Repo**: `graphql-python/graphql-core`
- **Why this one**: A direct port of the JS reference implementation. This is the actual GraphQL algorithm, not a framework wrapper.
- **Read**: `src/graphql/execution/execute.py` — specifically `execute_fields`, `resolve_field`, `complete_value`. Then `src/graphql/validation/rules/` to see how limits are enforced.
- **Question to answer**: Walk one query with three nested levels through `complete_value`. Where exactly does the N+1 problem get created?
- **Size**: 2 sessions.

### Saleor — GraphQL in a large real product

- **Repo**: `saleor/saleor`
- **Why this one**: A big commercial e-commerce backend, Django + Postgres + GraphQL, fully open. This is what a real GraphQL API looks like after years of pressure.
- **Read**:
  - `saleor/graphql/` — start at `api.py` and the schema assembly
  - any `dataloaders.py` file (e.g. under `saleor/graphql/product/`) — real batching
  - `saleor/graphql/core/` — permissions, mutations base classes, error handling
  - `saleor/graphql/core/validators/` and their query cost limits
- **Question to answer**: How do they stop one query from doing 500 database round trips? How is permission checked — per resolver or per field?
- **Size**: 3 sessions.

### strawberry-graphql

- **Repo**: `strawberry-graphql/strawberry`
- **Why**: The modern Python-typed GraphQL layer, likely what you would use. Read `strawberry/schema/schema.py` and `strawberry/extensions/` to see where you can hook in cost analysis and tracing.

### Online Boutique — gRPC across services

- **Repo**: `GoogleCloudPlatform/microservices-demo`
- **Why this one**: 11 services, 5 languages, one `.proto` file, deployable in one command. The best small real microservice system in the open.
- **Read**: `protos/demo.proto` first (the whole system contract in one file) → `src/checkoutservice/main.go` (it calls five other services — look at deadlines and error handling) → `src/frontend/handlers.go`
- **Question to answer**: The checkout service calls payment, shipping, email, cart and product. What happens if the email service is down? Is that the right behaviour?
- **Size**: 2 sessions.

---

## 06 — Databases

### PgBouncer — a connection pooler you can actually read

- **Repo**: `pgbouncer/pgbouncer`
- **Why this one**: Small, C, and it forces you to understand the Postgres wire protocol and session state.
- **Read**: `src/client.c` → `src/server.c` → `src/objects.c` (pool and connection lifecycle)
- **Question to answer**: In transaction pooling mode, why do prepared statements and `SET` break? What state lives on a server connection?
- **Size**: 1 session.

### Postgres itself (targeted, not whole)

- **Repo**: `postgres/postgres`
- **Why**: You are not reading 1.5M lines of C. You are reading the comments, which are extraordinary.
- **Read**: the README files, which are essays:
  - `src/backend/access/nbtree/README` — the B-tree implementation explained
  - `src/backend/storage/lmgr/README` — locking
  - `src/backend/access/transam/README` — transactions and WAL
- **Question to answer**: Why can Postgres readers never block writers?
- **Size**: 2 sessions, README only.

### GitLab — migrations at scale

- **Repo**: `gitlabhq/gitlabhq`
- **Why this one**: GitLab runs one of the largest Rails+Postgres deployments in the open and documents its migration rules publicly and rigorously.
- **Read**: `doc/development/database/` — especially the docs on avoiding downtime, batched background migrations, and index creation
- **Question to answer**: Write down the exact steps to rename a column in a table with 500 million rows with zero downtime.
- **Size**: 1 session. Highest practical payoff per hour in this whole file.

### Sentry — a huge Django + Postgres codebase

- **Repo**: `getsentry/sentry`
- **Read**: `src/sentry/models/` (schema design under real pressure), `migrations/` folders, and their `src/sentry/db/` helpers
- **Question to answer**: Find a model with a denormalized column. Why did they denormalize it?

---

## 07 — Caching and Coordination

### Redis (again, different files)

- **Read**: `src/expire.c` (how TTL expiry actually works — it is lazy plus sampled, not exact) → `src/evict.c` (approximate LRU) → `src/t_zset.c` (skip lists)
- **Question to answer**: If you set a TTL of 60s on a million keys, when are they actually deleted, and what does that do to your memory graph?

### etcd — Raft you can read

- **Repo**: `etcd-io/etcd` and `etcd-io/raft`
- **Read**: `raft/raft.go` — the state machine (follower, candidate, leader) and `raft/log.go`
- **Question to answer**: What exactly does a quorum guarantee, and what does it not?
- **Size**: 2 sessions. Pair with the Raft paper.

---

## 08 — Background Work

### Celery + Kombu

- **Repo**: `celery/celery` and `celery/kombu`
- **Why this one**: You will use it, and its failure modes are the ones that will page you.
- **Read**, in this order:
  - `celery/app/task.py` — what a task object actually is
  - `celery/app/amqp.py` — how a task becomes a message
  - `celery/worker/consumer/consumer.py` — the worker's main loop
  - `celery/worker/request.py` — ack timing, this is where at-least-once lives
  - `kombu/transport/redis.py` — how Redis fakes a message broker, including the visibility timeout
- **Question to answer**: Exactly when is a message acknowledged relative to your task function running? Now explain why a worker being SIGKILLed can run a task twice.
- **Size**: 3 sessions.

### Onyx — Celery in a real AI product

- **Repo**: `onyx-dot-app/onyx`
- **Why this one**: You already use it as your AI companion codebase. Its indexing pipeline is a serious Celery deployment with multiple queues, beat schedules and long-running jobs.
- **Read**: `backend/onyx/background/celery/` — the app setup, task definitions, and queue routing
- **Question to answer**: How do they stop two workers from indexing the same document at the same time?

### Dramatiq — the contrast

- **Repo**: `Bogdanp/dramatiq`
- **Why**: A third the size of Celery, deliberately different defaults. Reading it makes Celery's design choices visible.
- **Read**: `dramatiq/worker.py`, `dramatiq/middleware/retries.py`

### Temporal — durable workflows

- **Repo**: `temporalio/samples-python`
- **Read**: the saga and long-running workflow samples
- **Question to answer**: What does Temporal give you that a Celery chain does not?

---

## 09 — Event Streaming

### Kafka

- **Repo**: `apache/kafka`
- **Read** (Java client side is more approachable than the Scala core):
  - `clients/src/main/java/org/apache/kafka/clients/producer/internals/RecordAccumulator.java` — batching
  - `.../producer/internals/Sender.java` — the send loop, retries, in-flight requests
  - `.../consumer/internals/ConsumerCoordinator.java` — group membership and rebalancing
  - Then the Scala core: `core/src/main/scala/kafka/log/` for the log segment layout
- **Question to answer**: With `acks=all` and `max.in.flight.requests=5`, how can retries reorder your messages? What setting prevents it?
- **Size**: 3 sessions.

### Debezium — CDC in practice

- **Repo**: `debezium/debezium`
- **Read**: `debezium-connector-postgres/` — the snapshot phase versus the streaming phase
- **Question to answer**: How does Debezium avoid missing or duplicating rows during the switch from initial snapshot to live WAL streaming?

---

## 10–11 — Microservices and Reliability

### Online Boutique (again, reliability lens)

- **Read**: retry and timeout configuration in the Kubernetes manifests and the Istio config in `istio-manifests/`
- **Question to answer**: Where are timeouts set, and do they add up correctly across the call chain?

### resilience4j

- **Repo**: `resilience4j/resilience4j`
- **Why**: Hystrix is archived; this is the modern reference for circuit breakers, bulkheads and rate limiters.
- **Read**: `resilience4j-circuitbreaker/src/main/java/.../internal/CircuitBreakerStateMachine.java`
- **Question to answer**: List every state and every transition trigger. Then implement it in Python from memory.

### Envoy / Istio config

- **Read**: outlier detection and retry policy docs
- **Question to answer**: What is the difference between a retry at the mesh layer and a retry in your application code? When does doing both cause an outage?

---

## 12 — Observability

### OpenTelemetry Python

- **Repo**: `open-telemetry/opentelemetry-python`
- **Read**: `opentelemetry-sdk/src/opentelemetry/sdk/trace/__init__.py` (span lifecycle) and the batch span processor
- **Question to answer**: How does trace context travel from your FastAPI service, through a Celery task, to a gRPC call? What breaks it?

### Prometheus

- **Repo**: `prometheus/prometheus` — read the docs on histograms and the client library `prometheus/client_python`
- **Question to answer**: Why is averaging a histogram's average across pods wrong, and what do you do instead?

---

## 13–14 — Delivery and Security

### Authlib

- **Repo**: `lepture/authlib`
- **Read**: `authlib/oauth2/rfc6749/grants/` — one file per grant type
- **Question to answer**: Trace the authorization code + PKCE flow through the actual code.

### Ory Hydra

- **Repo**: `ory/hydra`
- **Why**: A production OAuth2/OIDC server. Read the docs and the flow diagrams even if you skip the Go.

---

## Reading Log Template

Keep one file per session. This is what turns reading into retention.

```markdown
## Session: <repo> / <topic> — <date>

**Question I opened this to answer:**

**Path I traced:** file → function → file → function

**Three things that surprised me:**
1.
2.
3.

**Something I would have built differently, and why:**

**Answer to my question (in my own words, no jargon):**

**Follow-up question this created:**
```

---

## High-Quality Resources

| Resource | Why It's Worth Your Time |
|---|---|
| [The Architecture of Open Source Applications](https://aosabook.org/en/index.html) | Authors of major projects explaining their own design. Free, and there is nothing else like it. |
| [Redis source walkthrough by antirez](http://antirez.com/news/126) | The author telling you how to read his own codebase |
| [CPython Internals (Anthony Shaw)](https://realpython.com/products/cpython-internals-book/) | The only guided tour of the CPython source that is actually readable |
| [GitLab Database Development docs](https://docs.gitlab.com/ee/development/database/) | Free, specific, battle-tested migration rules from a huge Postgres deployment |
| [sans-io.readthedocs.io](https://sans-io.readthedocs.io/) | The design idea behind h11 and h2 — protocol logic separated from I/O |

---

**Next:** [[Assets.2 - Exercise Ladder]]
