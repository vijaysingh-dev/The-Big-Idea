**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.1 - Codebase Study Map]]

---

# Exercise Ladder

#backend #exercises #practice

> **The rule:** you have not learned a topic until you have built it. Reading gives you recognition. Building gives you recall.
>
> Every exercise below is **multi-file and runnable**. None of them are toys you delete after an hour — the drills feed into Conduit, the capstone project in section 16.

---

## How This Works

There are two tracks, done at the same time.

**Track A — Drills.** One per topic. Small, sharp, self-contained. Each takes 3–8 hours. You write every line.

**Track B — Conduit.** One real system, built in phases across the whole vault. Each phase uses what you just learned. By the end you have a system you can talk about in any interview and later turn into your AI project.

| | Track A | Track B |
|---|---|---|
| Purpose | Understand the mechanism | Understand the system |
| Size | 200–600 lines | 8k+ lines over months |
| Deleted after? | Kept in a `drills/` repo | No — it is your portfolio |

---

## Ground Rules

1. **No copy-paste, ever.** Type it. If you cannot type it from understanding, go back to the note.
2. **No frameworks in drills.** If the drill is "build a task queue", you may not import Celery.
3. **Every drill ships with tests.** Not full coverage — one test per behaviour that could break.
4. **Every drill ships with a README** that answers: what does this do, what does it deliberately not do, and what would break at 100x load.
5. **Write the failure case first.** Before the happy path works, decide what happens when the network dies mid-operation.

---

# Track A — The Drills

## Section 01 — Python Runtime and Concurrency

### Drill 1.1 — Build an event loop

Write an event loop from nothing, using only `selectors` and generators. No `asyncio` import allowed.

```
drills/01-event-loop/
├── loop.py          # the scheduler: ready queue, selector, timers
├── awaitables.py    # sleep(), sock_read(), sock_accept() as awaitables
├── echo_server.py   # a TCP echo server running on your loop
├── test_loop.py
└── README.md
```

**Must support**: scheduling coroutines, `await sleep(n)`, awaiting socket readability, running 1000 concurrent connections.

**Done when**: you can hold 1000 simultaneous echo connections on one thread, and you can draw the loop's state machine from memory.

**Stretch**: add cancellation. Now you understand why cancellation in asyncio is hard.

---

### Drill 1.2 — Find the blocking call

Build a small profiler that detects when the event loop is blocked.

```
drills/01-loop-monitor/
├── monitor.py       # a watchdog task measuring loop lag
├── app.py           # a FastAPI app with 3 endpoints, one secretly blocking
├── report.py        # prints which handler stalled the loop and for how long
└── README.md
```

**Done when**: you can point at the blocking endpoint without reading its source, using only your lag measurements.

---

### Drill 1.3 — Pool sizing experiment

Not code-heavy, but the numbers stick with you forever.

Run one FastAPI app against Postgres with pool sizes 1, 5, 20, 100, 500. Load test each. Chart p50, p99 and error rate.

**Done when**: you can explain the shape of the curve, and why 500 is worse than 20.

---

## Section 02 — Networking

### Drill 2.1 — A raw TCP server, three ways

Same protocol, three implementations, one benchmark harness.

```
drills/02-tcp-three-ways/
├── protocol.py       # a tiny length-prefixed binary protocol
├── server_thread.py  # thread per connection
├── server_select.py  # select/poll loop
├── server_async.py   # asyncio
├── bench.py          # opens N connections, measures throughput and memory
└── README.md
```

**Done when**: you have a table of connections vs memory vs throughput for all three, and you can explain the C10k problem from your own data.

---

### Drill 2.2 — Break TCP on purpose

```
drills/02-tcp-pathology/
├── slow_reader.py    # client that connects and never reads
├── half_open.py      # kill a client's network without closing the socket
├── observe.sh        # ss/tcpdump commands to watch what happens
└── FINDINGS.md
```

**Done when**: you have personally watched a server's send buffer fill, seen a connection sit in `ESTABLISHED` for 2 hours after the peer vanished, and can explain what keepalive would have done.

---

## Section 03 — HTTP

### Drill 3.1 — Write an HTTP/1.1 server

No `http.server`, no framework. Parse bytes yourself.

```
drills/03-http-server/
├── parser.py        # request line, headers, chunked body — a state machine
├── response.py      # serialization, content-length vs chunked
├── connection.py    # keep-alive, pipelining, timeouts
├── server.py
├── tests/
│   ├── test_parser.py       # include malformed and hostile inputs
│   └── test_keepalive.py
└── README.md
```

**Must handle**: keep-alive, chunked request bodies, `Expect: 100-continue`, request line size limits, and a header count limit.

**Done when**: `curl`, `ab` and a browser all work against it, and it survives a fuzzed input file without crashing.

---

### Drill 3.2 — Caching reverse proxy

```
drills/03-proxy/
├── proxy.py         # forwards requests upstream
├── cache.py         # respects Cache-Control, ETag, Vary
├── revalidate.py    # conditional requests, 304 handling
└── README.md
```

**Done when**: your proxy correctly serves from cache, revalidates, and never caches something it must not (`Authorization`, `Set-Cookie`, `no-store`).

---

## Section 04 — Realtime

### Drill 4.1 — SSE from scratch, both ends

```
drills/04-sse/
├── server.py        # raw SSE: event, data, id, retry fields
├── client.py        # a client that reconnects with Last-Event-ID
├── broker.py        # in-memory topic fanout with per-client bounded queues
├── slow_client.py   # a client that reads slowly on purpose
└── README.md
```

**Must handle**: reconnect with no missed and no duplicated events, heartbeats to defeat proxy timeouts, and a **slow consumer policy** — decide whether to buffer, drop or disconnect, and defend the choice in the README.

**Done when**: you can kill the client mid-stream, restart it, and lose nothing.

---

### Drill 4.2 — Multi-node chat backplane

```
drills/04-backplane/
├── node.py          # WebSocket server holding connections
├── backplane.py     # Redis pub/sub so node A reaches node B's clients
├── presence.py      # who is online, with TTL heartbeats
├── compose.yml      # 3 nodes + nginx + redis
└── README.md
```

**Done when**: you run three nodes behind a load balancer, a message sent to node 1 arrives at a client on node 3, and killing node 2 does not lose anyone else's messages.

---

## Section 05 — APIs

### Drill 5.1 — A GraphQL execution engine

Not a wrapper. The engine.

```
drills/05-graphql/
├── lexer.py
├── parser.py        # query document → AST
├── schema.py        # type definitions, field resolvers
├── executor.py      # the execution algorithm, breadth-first per level
├── dataloader.py    # your own batching loader
├── limits.py        # depth and complexity analysis
├── tests/
└── README.md
```

**Done when**: a 3-level nested query resolves correctly, your DataLoader turns 100 database calls into 3, and a 20-level deep query is rejected before execution.

---

### Drill 5.2 — Same API, three ways

One domain (orders). Three interfaces. One benchmark.

```
drills/05-three-apis/
├── domain/          # shared business logic — no protocol code here
├── rest/
├── graphql/
├── grpc/
├── bench/           # payload size, latency, N+1 behaviour
└── COMPARISON.md
```

**Done when**: `COMPARISON.md` contains your own measured numbers, not numbers from a blog post.

---

## Section 06 — Databases

### Drill 6.1 — Index detective

```
drills/06-index-lab/
├── seed.py          # generate 10M realistic rows
├── queries.sql      # 15 queries: some indexable, some not
├── plans/           # saved EXPLAIN ANALYZE output before and after
└── FINDINGS.md
```

**Done when**: for each query you can predict the plan before running it, and you were right at least 12 times out of 15.

---

### Drill 6.2 — Break isolation

```
drills/06-isolation/
├── anomalies.py     # reproduce dirty read, non-repeatable read, phantom, write skew
├── runner.py        # two sessions, controlled interleaving
└── FINDINGS.md      # which anomaly appears at which isolation level
```

**Done when**: you have personally produced write skew, then fixed it two different ways (`SELECT FOR UPDATE` and `SERIALIZABLE`) and measured the cost of each.

---

### Drill 6.3 — Zero downtime migration

```
drills/06-migration/
├── app_v1.py        # running app, taking constant write traffic
├── migrate/         # expand → backfill → switch → contract, four steps
├── load.py          # keeps writing throughout
└── README.md
```

**Task**: rename a column and change its type on a 50M-row table while `load.py` runs continuously, with zero failed writes.

**Done when**: the error count during migration is exactly zero.

---

## Section 07 — Caching

### Drill 7.1 — Cache with the hard parts included

```
drills/07-cache/
├── cache.py         # cache-aside with TTL and jitter
├── stampede.py      # single-flight lock + probabilistic early expiry
├── lock.py          # distributed lock with fencing tokens and lease renewal
├── chaos.py         # kills the lock holder mid-operation
└── README.md
```

**Done when**: 1000 concurrent requests for one expired key cause exactly one database query, and your chaos test proves the fencing token stops a zombie lock holder from corrupting data.

---

## Section 08 — Background Work

### Drill 8.1 — Build a task queue

No Celery.

```
drills/08-taskqueue/
├── broker.py        # Redis-backed queue with visibility timeout
├── worker.py        # prefetch, ack after execution, graceful shutdown
├── task.py          # decorator, serialization, versioning
├── retry.py         # exponential backoff with jitter, max attempts
├── dlq.py           # dead letter queue + a replay CLI
├── beat.py          # periodic scheduler with leader election
├── tests/
└── README.md
```

**Done when**: `kill -9` on a worker mid-task results in the task running again (not being lost), and you can prove your task is idempotent so that is safe.

---

### Drill 8.2 — Saga

```
drills/08-saga/
├── steps.py         # 4 steps, each with a compensating action
├── orchestrator.py  # state machine, persisted, resumable
├── failure_matrix/  # a test per failure point
└── README.md
```

**Done when**: killing the process at any of the 8 possible points leaves the system in a consistent state after restart. All 8 are tested.

---

## Section 09 — Event Streaming

### Drill 9.1 — Build a log

Kafka's core idea, minus the distribution.

```
drills/09-log/
├── segment.py       # append-only file, sparse index, offsets
├── log.py           # partitions, retention, compaction
├── consumer.py      # consumer groups, offset commits, rebalance
├── producer.py      # batching, keyed partitioning
└── README.md
```

**Done when**: two consumers in a group split partitions, one dies, the other takes over from the right offset, and a replay from offset 0 gives identical results.

---

### Drill 9.2 — Outbox + CDC

```
drills/09-outbox/
├── service.py       # writes business row + outbox row in one transaction
├── relay.py         # polls outbox, publishes, marks sent
├── cdc_relay.py     # same thing via logical replication instead
├── chaos.py         # kills the relay between publish and mark
└── COMPARISON.md
```

**Done when**: no event is ever lost, duplicates are possible but harmless, and you can explain when CDC beats polling.

---

## Sections 10–11 — Microservices and Reliability

### Drill 11.1 — A resilience toolkit

```
drills/11-resilience/
├── breaker.py       # closed/open/half-open, sliding window
├── bulkhead.py      # isolated concurrency pools per dependency
├── shed.py          # load shedding based on queue depth and latency
├── limiter.py       # token bucket + sliding window, distributed
├── deadline.py      # budget propagation across calls
├── sim/             # a simulated flaky dependency + failure scenarios
└── README.md
```

**Done when**: in your simulation, a dependency going to 100% failure does **not** take down the caller, and the caller's latency stays flat instead of climbing.

---

# Track B — Conduit

## What It Is

**Conduit** is a document ingestion and search platform. Users connect sources, documents get pulled in and processed, and users search and collaborate on the results in real time.

Pick this shape deliberately for three reasons:

1. It naturally needs **every** topic in this vault — no artificial bolt-ons.
2. It is a real product shape, so the design conversations are real.
3. In Phase 9 it becomes a RAG platform, which is exactly the [[00 - Index (AI)]] vault's territory. **Your backend capstone becomes your AI capstone.**

---

## The Phases

| Phase | Build | Depends on |
|---|---|---|
| **1. Core service** | FastAPI + Postgres, users, sources, documents. Clean layering, migrations, tests. | 01, 06, LLD vault |
| **2. Ingestion** | Celery workers pull documents, parse, store. Retries, idempotency, outbox. | 08, 07 |
| **3. Realtime** | SSE stream of ingestion progress. WebSocket for collaborative annotation. | 04 |
| **4. Split** | Extract the ingestion service. gRPC between services. GraphQL gateway for clients. | 05, 10 |
| **5. Events** | Kafka backbone. CDC from Postgres. Replayable consumers, a search index built from the log. | 09 |
| **6. Hardening** | Rate limits, circuit breakers, load shedding, graceful shutdown, deadline propagation. | 11 |
| **7. Visibility** | Traces across all services, RED metrics, SLOs, error budget alerting. | 12 |
| **8. Prove it** | k6 load test to the breaking point. Chaos experiments. A written postmortem. | 11 |
| **9. Handover** | Embeddings, hybrid retrieval, streaming answers over the SSE layer you already built. | AI vault |

---

## Rules for Conduit

- **One commit per meaningful change**, with a real message. Your git history is part of the deliverable.
- **An ADR for every significant decision** — one page: what you chose, what you rejected, why. This is the single habit that most separates senior from mid-level.
- **Every phase ends with a load test.** You must know your numbers at every stage, not just at the end.
- **Never move to the next phase before the current one has tests and a README.**
- **Keep a `docs/` folder** with architecture diagrams that you actually update.

---

## Definition of "Top 1%" for This Project

You are done with a phase when you can answer all of these without hedging:

1. What is the throughput ceiling, and what is the bottleneck?
2. What happens when each dependency fails — every one, individually?
3. Where is data duplicated, and how does it become consistent again?
4. What is the p99 latency, and what makes it different from p50?
5. If traffic went up 100x tomorrow, what breaks first and what is the fix?
6. What did you choose *not* to build, and why was that correct?

---

## Suggested Order

Do drills and Conduit in parallel. A realistic week:

| Day | Work |
|---|---|
| Mon–Tue | Read notes for the current topic |
| Wed | Codebase reading session ([[Assets.1 - Codebase Study Map]]) |
| Thu–Fri | The drill |
| Weekend | Conduit phase work |

That is roughly one topic a week. Twelve months gets you through everything with the capstone finished.

---

## High-Quality Resources

| Resource | Why It's Worth Your Time |
|---|---|
| [Build Your Own X](https://github.com/codecrafters-io/build-your-own-x) | Curated build-from-scratch guides for almost every drill above |
| [CodeCrafters](https://codecrafters.io/) | Paid, but the Redis / HTTP server / Kafka / SQLite tracks are graded and rigorous |
| [Designing Data-Intensive Applications — Kleppmann](https://dataintensive.net/) | The reference text for sections 06–11. Read it alongside, not before |
| [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) | The original ADR post. Two pages, permanently useful |
| [k6 documentation](https://grafana.com/docs/k6/latest/) | The load testing tool used in every Conduit phase |

---

**Next:** [[Assets.3 - Numbers To Know]]
