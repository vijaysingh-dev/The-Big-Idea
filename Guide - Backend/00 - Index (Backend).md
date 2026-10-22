# Backend Engineering — Master Index

> **Purpose**: The missing half of the vault. Everything under and around the code you already write — the Python runtime, the network, the database, the queue, the log, and the way services fail. Depth-first, plain language, built around reading real production code and then writing your own.
>
> **How to read**: Notes are linked in a single chain with **Prev** / **Next**. The order below is the reading order. Every note ends with three things: a **Codebase** box (what real code to open), an **Exercise** box (what to build), and a **Resources** table.
>
> **Companion codebases**: See [[Assets.1 - Codebase Study Map]]. **Companion project**: Conduit, built in section 16.

---

## What This Vault Assumes You Already Have

| Vault                | What it covers                                   |
| -------------------- | ------------------------------------------------ |
| [[00 - Index (LLD)]] | Class design, patterns, single-service structure |
| [[00-Index (HLD)]]   | System design, building blocks, case studies     |
| [[00 - Index (AI)]]  | AI engineering, RAG, serving                     |
| [[Redis]]            | Redis data types and patterns                    |
| [[Kafka]]            | Kafka internals and usage                        |
| [[gRPC]]             | gRPC and Protobuf                                |
| [[WebSocket]]        | WebSocket protocol and scaling                   |
| [[WebRTC]]           | Peer-to-peer media                               |
| [[Observability]]    | Logs, metrics, traces                            |

This vault does not repeat them. It links to them at the right moment and fills every gap between them.

---

## The Method

Three passes on every topic, in this order:

1. **Read the note.** Get the mental model and the words for it.
2. **Read the real code.** Open the exact files listed in the Codebase box. Do not skim — trace one request or one message end to end.
3. **Build it yourself.** Do the exercise. Write the whole thing, multiple files, no copy-paste.

You have not learned a topic until step 3 is done. See [[00.2 - The Codebase First Method]] for how to actually do step 2 without drowning.

---

## Navigation

### 00 — Start Here

| File | Topic |
| ---- | ----- |
| [[00.1 - How To Use This Vault]] | Reading order, revision strategy, how the three passes work |
| [[00.2 - The Codebase First Method]] | How to read a 500k-line repo without getting lost |
| [[00.3 - The Conduit Project]] | The single project you build across the whole vault |
| [[00.4 - Setting Up Your Lab]] | Docker compose stack, tcpdump, pgcli, k6, and friends |

### 01 — The Python Runtime and Concurrency

> You write async Python every day. This section is why it behaves the way it does.

| File | Topic |
| ---- | ----- |
| [[01.1 - How Python Actually Runs Your Code]] | Bytecode, the eval loop, why Python is slow, where time goes |
| [[01.2 - The GIL]] | What it locks, what it does not, when it stops mattering |
| [[01.3 - Threads Processes and Coroutines]] | Three tools, three cost models, picking the right one |
| [[01.4 - Building an Event Loop From Scratch]] | selectors + generators = asyncio, in 150 lines |
| [[01.5 - Coroutines Tasks and Futures]] | What await does, how a Task drives a coroutine |
| [[01.6 - The Blocking Call Problem]] | The #1 async bug in production and how to find it |
| [[01.7 - Cancellation and Structured Concurrency]] | TaskGroup, timeouts, cleanup that actually runs |
| [[01.8 - Offloading Work]] | to_thread, executors, when to use a process |
| [[01.9 - ASGI and How Uvicorn Serves a Request]] | The full path from socket to your endpoint function |
| [[01.10 - Connection Pools and Limits]] | Pool sizing math for DB, HTTP clients and Redis |
| [[01.11 - Backpressure Inside One Process]] | Bounded queues, semaphores, why unbounded means outage |
| [[01.12 - Profiling and Debugging Async Services]] | py-spy, asyncio debug mode, finding the stalled loop |

### 02 — Networking Foundations

| File | Topic |
| ---- | ----- |
| [[02.1 - The Stack in One Picture]] | What each layer actually adds, with a real packet |
| [[02.2 - Sockets From First Principles]] | bind, listen, accept, send, recv — write one by hand |
| [[02.3 - TCP Connection Lifecycle]] | Handshake, close, TIME_WAIT, half-open connections |
| [[02.4 - Flow Control and Congestion Control]] | Windows, slow start, why throughput collapses |
| [[02.5 - Head of Line Blocking]] | The one idea that explains HTTP/2, HTTP/3 and Kafka ordering |
| [[02.6 - TCP Settings That Matter]] | Backlog, keepalive, Nagle, buffer sizes, ephemeral ports |
| [[02.7 - UDP and Lossy Transport]] | When dropping data is correct, and who does it |
| [[02.8 - DNS]] | Resolution path, TTLs, the caching bugs that cause outages |
| [[02.9 - TLS]] | Handshake, certificates, mTLS, termination points, cost |
| [[02.10 - NAT Firewalls and Middleboxes]] | Why realtime is hard and why long connections die silently |
| [[02.11 - Reading Real Traffic]] | tcpdump, Wireshark, ss, netstat — a practical drill |
| [[02.12 - Event Driven Servers]] | select, poll, epoll, kqueue, io_uring — the C10k story |

### 03 — HTTP

| File | Topic |
| ---- | ----- |
| [[03.1 - HTTP1.1 Message Format]] | Bytes on the wire, framing, chunked encoding |
| [[03.2 - Connection Reuse and Keep Alive]] | Why your client pool config decides your p99 |
| [[03.3 - Methods Status Codes and Semantics]] | What the spec actually says vs what people do |
| [[03.4 - Idempotency and Safe Retries]] | Idempotency keys, retry storms, exactly-once fiction |
| [[03.5 - HTTP Caching]] | Cache-Control, ETag, revalidation, CDN behaviour |
| [[03.6 - Compression and Streaming Responses]] | gzip/br, chunked vs streaming, buffering proxies |
| [[03.7 - Cookies Sessions and CORS]] | SameSite, preflight, the rules people get wrong |
| [[03.8 - HTTP2]] | Streams, HPACK, multiplexing, priority, real gains |
| [[03.9 - HTTP3 and QUIC]] | Why UDP, connection migration, deployment reality |
| [[03.10 - Proxies and Load Balancers]] | L4 vs L7, what they rewrite, what they break |
| [[03.11 - Timeouts and Deadlines Across Hops]] | Deadline propagation, budget math, cascading failure |

### 04 — Realtime Transports

| File | Topic |
| ---- | ----- |
| [[04.1 - Choosing a Realtime Transport]] | Decision table: polling, SSE, WebSocket, gRPC, WebRTC |
| [[04.2 - Server Sent Events]] | Format, reconnect, Last-Event-ID, the whole protocol |
| [[04.3 - SSE in Production]] | Proxy buffering, heartbeats, timeouts, worker starvation |
| [[04.4 - Streaming LLM Responses]] | How token streaming actually works — your bridge to AI |
| [[04.5 - Long Polling]] | Why it still runs half the internet |
| [[04.6 - Scaling Long Lived Connections]] | Sticky sessions, pub/sub backplane, connection budgets |
| [[04.7 - Presence Fanout and Backpressure]] | Slow consumers, buffer limits, dropping messages on purpose |
| [[04.8 - WebSocket and WebRTC Recap]] | Links out to the existing guides + how they fit here |

### 05 — API Design and Styles

| File | Topic |
| ---- | ----- |
| [[05.1 - REST Done Properly]] | Resources, representations, the parts everyone skips |
| [[05.2 - Versioning Pagination and Filtering]] | Cursor vs offset, breaking changes, sane query APIs |
| [[05.3 - Error Design]] | Problem Details, error codes, retryable vs terminal |
| [[05.4 - GraphQL - The Core Model]] | Schema, types, resolvers, one request many fields |
| [[05.5 - How GraphQL Execution Works]] | The execution algorithm, field resolution, tracing it |
| [[05.6 - The N+1 Problem and DataLoader]] | Batching, per-request caching, writing your own loader |
| [[05.7 - GraphQL Caching]] | Why HTTP caching fails, persisted queries, normalized caches |
| [[05.8 - GraphQL Security and Limits]] | Depth, complexity, cost analysis, introspection, auth |
| [[05.9 - Subscriptions]] | Realtime GraphQL, transport choices, scaling |
| [[05.10 - Federation and Schema Composition]] | Multiple services, one graph, the real costs |
| [[05.11 - REST vs GraphQL vs gRPC]] | Honest comparison, mixed architectures, who uses what |
| [[05.12 - Webhooks and Callbacks]] | Delivery, signing, retries, being a good webhook sender |
| [[05.13 - Contract Testing and Schema Evolution]] | Breaking change rules across all three styles |

### 06 — Databases

> The biggest gap between a good backend engineer and a top 1% one.

| File | Topic |
| ---- | ----- |
| [[06.1 - Storage Engines]] | B-tree vs LSM, read vs write amplification, who picks what |
| [[06.2 - Postgres Architecture]] | Processes, shared buffers, WAL, checkpoints, the fsync path |
| [[06.3 - Indexes Deep Dive]] | B-tree, partial, covering, GIN, BRIN, multi-column ordering |
| [[06.4 - Reading EXPLAIN ANALYZE]] | Node types, estimated vs actual, spotting the real problem |
| [[06.5 - The Query Planner]] | Statistics, selectivity, why the plan flipped last night |
| [[06.6 - Transactions and Isolation Levels]] | Read anomalies, what your ORM actually opens |
| [[06.7 - MVCC Vacuum and Bloat]] | Row versions, dead tuples, transaction ID wraparound |
| [[06.8 - Locking and Deadlocks]] | Lock modes, lock queues, DDL that takes your site down |
| [[06.9 - Connection Pooling and PgBouncer]] | Pool modes, prepared statement traps, sizing formula |
| [[06.10 - Schema Design]] | Normalization tradeoffs, constraints, enums, JSONB rules |
| [[06.11 - Zero Downtime Migrations]] | The expand/contract playbook, lock-safe DDL recipes |
| [[06.12 - Replication and Failover]] | Streaming replication, lag, read-your-writes, split brain |
| [[06.13 - Partitioning and Sharding]] | Native partitioning, shard keys, resharding pain |
| [[06.14 - Beyond Postgres]] | Document, wide-column, time-series, graph — when each wins |
| [[06.15 - Search - Postgres vs Elasticsearch]] | Full text search, inverted indexes, when to move out |
| [[06.16 - Multi Tenant Data Models]] | Row, schema, database isolation — cost and blast radius |
| [[06.17 - Database Anti Patterns]] | The 15 mistakes that show up in every code review |

### 07 — Caching and Coordination

| File | Topic |
| ---- | ----- |
| [[07.1 - Cache Layers Across One Request]] | Browser, CDN, gateway, app, DB — where to actually cache |
| [[07.2 - Cache Strategies and Invalidation]] | Aside, through, behind, refresh-ahead, TTL design |
| [[07.3 - Stampede Hot Keys and Negative Caching]] | The failure modes that only appear at scale |
| [[07.4 - Distributed Locks Done Right]] | Fencing tokens, lease renewal, why Redlock is argued about |
| [[07.5 - Idempotency Keys and Deduplication]] | Exactly-once effects on top of at-least-once delivery |
| [[07.6 - Leader Election and Coordination]] | Raft in plain words, etcd/ZooKeeper, when you need it |

### 08 — Background Work and Task Queues

| File | Topic |
| ---- | ----- |
| [[08.1 - Why Background Work Exists]] | Request path vs work path, latency budgets |
| [[08.2 - Queue Semantics]] | Acks, visibility timeout, at-least-once, ordering |
| [[08.3 - Celery Architecture]] | Producer, broker, worker, pool, result backend |
| [[08.4 - Brokers and Result Backends]] | Redis vs RabbitMQ vs SQS, what you lose with each |
| [[08.5 - Task Design Rules]] | Idempotent, small payload, no ORM objects, versioned |
| [[08.6 - Retries Backoff and Dead Letters]] | Autoretry, jitter, poison messages, replay tooling |
| [[08.7 - Routing Queues Priorities and Prefetch]] | Starvation, noisy neighbours, why prefetch bites you |
| [[08.8 - Periodic Tasks and Distributed Cron]] | Beat, single-scheduler problem, at-least-once execution |
| [[08.9 - Celery in Production]] | Memory leaks, stuck workers, visibility, graceful shutdown |
| [[08.10 - Celery vs Dramatiq vs arq vs Temporal]] | Honest comparison and migration paths |
| [[08.11 - Durable Workflows and Sagas]] | Long multi-step jobs, compensation, Temporal model |

### 09 — Event Streaming

| File | Topic |
| ---- | ----- |
| [[09.1 - Queue vs Log]] | The single distinction that makes Kafka make sense |
| [[09.2 - Event Modeling]] | Event types, payload shape, versioning, ownership |
| [[09.3 - The Outbox Pattern]] | Never lose an event when the DB commit and publish split |
| [[09.4 - Change Data Capture]] | Reading the WAL, Debezium, CDC as an integration strategy |
| [[09.5 - Stream Processing Basics]] | Windows, joins, state stores, when you need a framework |
| [[09.6 - Schema Registry and Compatibility]] | Forward, backward, full — with real breaking-change examples |
| [[09.7 - Replay Backfill and Reprocessing]] | Designing consumers you can safely re-run |
| [[09.8 - Kafka Recap and Where It Fits]] | Links out + choosing Kafka vs queue vs DB polling |

### 10 — Microservices in Practice

| File | Topic |
| ---- | ----- |
| [[10.1 - Monolith Modular Monolith Microservices]] | The honest tradeoff, including the case against splitting |
| [[10.2 - Finding Service Boundaries]] | Bounded contexts, data gravity, team topology |
| [[10.3 - Communication Patterns]] | Sync vs async, choreography vs orchestration |
| [[10.4 - Data Ownership]] | No shared DB, read models, duplication on purpose |
| [[10.5 - Distributed Transactions and Sagas]] | Compensation, state machines, idempotent steps |
| [[10.6 - API Gateway and BFF]] | What belongs at the edge and what does not |
| [[10.7 - Service Discovery and Service Mesh]] | DNS, registries, sidecars, what a mesh buys you |
| [[10.8 - Configuration and Secrets]] | 12-factor config, hot reload, secret rotation |
| [[10.9 - Testing Microservices]] | Test pyramid across services, contract tests, ephemeral envs |
| [[10.10 - Deployment Strategies]] | Rolling, blue-green, canary, feature flags |
| [[10.11 - The Real Cost of Microservices]] | What breaks, what it costs, what to do instead |

### 11 — Reliability Engineering

| File | Topic |
| ---- | ----- |
| [[11.1 - How Systems Fail]] | Failure taxonomy, correlated failure, gray failure |
| [[11.2 - Timeouts Retries and Jitter]] | Budgets, retry amplification, the math of retry storms |
| [[11.3 - Circuit Breakers and Bulkheads]] | States, thresholds, isolation pools, writing one |
| [[11.4 - Backpressure and Load Shedding]] | Queue depth as a signal, shedding the right requests |
| [[11.5 - Rate Limiting and Quotas]] | Token bucket, sliding window, distributed limiting |
| [[11.6 - Graceful Degradation]] | Feature-level fallbacks, static responses, stale data |
| [[11.7 - Graceful Shutdown and Draining]] | SIGTERM handling, in-flight requests, K8s lifecycle |
| [[11.8 - Capacity Planning and Load Testing]] | Little's Law, k6/Locust, finding the knee of the curve |
| [[11.9 - Chaos and Failure Injection]] | Practical experiments you can run on your own stack |
| [[11.10 - Incidents and Postmortems]] | On-call, severity, blameless writeups, action items |

### 12 — Observability and SLOs

| File | Topic |
| ---- | ----- |
| [[12.1 - Observability Recap and Gaps]] | Links out + what the existing guide does not cover |
| [[12.2 - SLI SLO and Error Budgets]] | Picking indicators, burn rate alerts, alerting on symptoms |
| [[12.3 - Instrumenting Conduit End to End]] | Trace one request across every service you built |

### 13 — Runtime and Delivery

| File | Topic |
| ---- | ----- |
| [[13.1 - Containers From First Principles]] | Namespaces, cgroups, layers, what an image really is |
| [[13.2 - Production Dockerfiles]] | Multi-stage, caching, non-root, signals, image size |
| [[13.3 - Kubernetes for Backend Engineers]] | Pods, services, deployments — only what you need |
| [[13.4 - Probes Resources and Autoscaling]] | Liveness vs readiness, requests/limits, HPA, OOMKills |
| [[13.5 - CI CD Pipelines]] | Build, test, migrate, deploy, rollback |
| [[13.6 - Cost Awareness]] | Where cloud money goes and how to argue about it |

### 14 — Security

| File | Topic |
| ---- | ----- |
| [[14.1 - AuthN vs AuthZ]] | Identity, permissions, RBAC vs ABAC vs ReBAC |
| [[14.2 - Sessions Tokens and Rotation]] | JWT tradeoffs, refresh flows, revocation, logout everywhere |
| [[14.3 - OAuth2 and OIDC]] | Every grant type, PKCE, what your SaaS integration needs |
| [[14.4 - Common Vulnerabilities]] | Injection, SSRF, IDOR, mass assignment, path traversal |
| [[14.5 - Secrets and Key Management]] | Rotation, envelope encryption, KMS, per-tenant keys |
| [[14.6 - Multi Tenant Isolation]] | RLS, context propagation, the leak scenarios to test for |

### 15 — Reading Production Code

| File | Topic |
| ---- | ----- |
| [[15.1 - How to Read a Large Codebase]] | The trace-one-path technique, tooling, note taking |
| [[15.2 - Reading Redis Networking]] | Walk `ae.c` and `networking.c` line by line |
| [[15.3 - Reading Uvicorn and Starlette]] | Socket to endpoint, one full request |
| [[15.4 - Reading the Celery Worker Loop]] | Broker message to task execution |
| [[15.5 - Reading Saleor GraphQL]] | Schema, resolvers, dataloaders in a real product |
| [[15.6 - Reading Online Boutique]] | A real 11-service system, gRPC everywhere |

### 16 — Capstone: Conduit

> One project, built in phases. Each phase depends on the sections above it.

| File | Phase |
| ---- | ----- |
| [[16.1 - Conduit - Overview and Architecture]] | What you are building and why this shape |
| [[16.2 - Phase 1 - The Monolith]] | FastAPI + Postgres, clean LLD, migrations, tests |
| [[16.3 - Phase 2 - Async and Realtime]] | Celery workers, retries, idempotency, outbox |
| [[16.4 - Phase 3 - Caching and Coordination]] | SSE progress stream + WebSocket collaboration |
| [[16.5 - Phase 4 - The Service Split]] | gRPC internal calls, GraphQL gateway |
| [[16.6 - Phase 5 - Events and the Outbox]] | Kafka, CDC, replayable consumers |
| [[16.7 - Phase 6 - Resilience]] | Limits, breakers, shedding, graceful shutdown |
| [[16.8 - Phase 7 - Observability and SLOs]] | Traces, metrics, SLOs, a real dashboard |
| [[16.9 - Phase 8 - Delivery and Security]] | k6 runs, chaos, a written postmortem |
| [[16.10 - Phase 9 - RAG and the AI Handoff]] | Where the AI vault picks Conduit up as a RAG platform |

---

## Assets (Quick Reference)

| File | Contents |
| ---- | ----- |
| [[Assets.1 - Codebase Study Map]] | Every topic → which real repo, which files, what to look for |
| [[Assets.2 - Exercise Ladder]] | Every exercise, in order, with acceptance criteria |
| [[Assets.3 - Numbers To Know]] | Latency numbers, sizing formulas, capacity math |
| [[Assets.4 - Production Readiness Checklist]] | What a service needs before it takes real traffic |
| [[Assets.5 - Resource Library]] | Books, papers, docs and talks, ranked, by section |
| [[Assets.6 - Rapid Fire Question Bank]] | Interview drills across all 14 sections |

---

## Suggested Pace

| Block | Sections | Rough time |
| ---- | ----- | ----- |
| Foundations | 01, 02, 03 | 6–8 weeks |
| Interfaces | 04, 05 | 4 weeks |
| State | 06, 07 | 6 weeks |
| Work and events | 08, 09 | 4 weeks |
| Systems | 10, 11, 12 | 5 weeks |
| Delivery and security | 13, 14 | 3 weeks |
| Capstone | 16 (built alongside from week 1) | ongoing |

Section 15 is not a block. Do one reading session every week, forever.

---

**Start here:** [[00.1 - How To Use This Vault]]
