**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.1 - Codebase Study Map]]

---

# Exercise Ladder

#backend #exercises #practice

> **The rule:** you have not learned a topic until you have built it. Reading gives you recognition. Building gives you recall.
>
> Every exercise below is **multi-file and runnable**. None of them are toys you delete after an hour — the drills feed into Conduit, the capstone project in section 17.

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

## Section 02 — Operating Systems

| Drill | Build | Done when |
|---|---|---|
| **2.1 — The cost of crossing the wall** | Syscall micro-benchmarks; write-size sweep under `strace -c` | Throughput-vs-bytes-per-write chart; you can predict syscall counts |
| **2.2 — A tiny shell and a reaper** | `fork`/`exec`/`wait` shell with `>` and `\|`; zombie reaper; copy-on-write demo | Two-stage pipeline works; chart of child private memory vs objects touched |
| **2.3 — Reproduce CPU throttling** | Same app with and without a cgroup CPU limit under k6 | Table showing ~30% average CPU with a much worse p99, and throttle counts proving why |
| **2.4 — Races, locks and a deadlock** | Own `Semaphore` and bounded queue from `Lock` + `Condition`; a deliberate deadlock | Queue passes concurrency tests; annotated `py-spy dump` of the deadlock |
| **2.5 — See laziness** | VSZ vs RSS vs faults as you touch memory; `mmap` vs `read` | VSZ/RSS/fault table; cold vs warm cache comparison |
| **2.6 — Fragment, leak, get OOM-killed** | Fragmentation demo, planted leak found with tracemalloc + memray, OOM kill | Exit 137 + `dmesg` + `memory.events` captured; leak found with tools only |
| **2.7 — Run out of fds** | fd leak under `ulimit -n 256`; blocking vs select vs asyncio echo servers | fd-count chart for leak and fix; three-server comparison table |
| **2.8 — Durability you can measure** | fsync strategy benchmark; atomic write; a mini WAL with CRCs | WAL survives 100 random truncations with zero corrupt records replayed |
| **2.9 — Make docker stop graceful** | Shell form vs exec form vs tini; asyncio drain on `SIGTERM` | Fixed versions stop in under 1 s with exit 0 and zero lost jobs |
| **2.10 — Four ways to talk** | Pipe/UDS/TCP/shared-memory ping-pong; a prefork master with heartbeats | Latency table; master survives `kill -9` of workers under load |
| **2.11 — Diagnose five planted problems** | A chaos-toggle stack and your own RUNBOOK.md | Each scenario identified in under 5 minutes |
| **2.12 — Trace one request through everything** | strace + perf + bpftrace timeline of one request | Timeline accounts for 90%+ of wall time, layer by layer |

Full specs live in each note's Exercise box.

---

## Section 03 — Networking

### Drill 3.1 — A raw TCP server, three ways

Same protocol, three implementations, one benchmark harness.

```
drills/03-tcp-three-ways/
├── protocol.py       # a tiny length-prefixed binary protocol
├── server_thread.py  # thread per connection
├── server_select.py  # select/poll loop
├── server_async.py   # asyncio
├── bench.py          # opens N connections, measures throughput and memory
└── README.md
```

**Done when**: you have a table of connections vs memory vs throughput for all three, and you can explain the C10k problem from your own data.

---

### Drill 3.2 — Break TCP on purpose

```
drills/03-tcp-pathology/
├── slow_reader.py    # client that connects and never reads
├── half_open.py      # kill a client's network without closing the socket
├── observe.sh        # ss/tcpdump commands to watch what happens
└── FINDINGS.md
```

**Done when**: you have personally watched a server's send buffer fill, seen a connection sit in `ESTABLISHED` for 2 hours after the peer vanished, and can explain what keepalive would have done.

---

## Section 04 — HTTP

### Drill 4.1 — Write an HTTP/1.1 server

No `http.server`, no framework. Parse bytes yourself.

```
drills/04-http-server/
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

### Drill 4.2 — Caching reverse proxy

```
drills/04-proxy/
├── proxy.py         # forwards requests upstream
├── cache.py         # respects Cache-Control, ETag, Vary
├── revalidate.py    # conditional requests, 304 handling
└── README.md
```

**Done when**: your proxy correctly serves from cache, revalidates, and never caches something it must not (`Authorization`, `Set-Cookie`, `no-store`).

---

## Section 05 — Realtime

### Drill 5.1 — SSE from scratch, both ends

```
drills/05-sse/
├── server.py        # raw SSE: event, data, id, retry fields
├── client.py        # a client that reconnects with Last-Event-ID
├── broker.py        # in-memory topic fanout with per-client bounded queues
├── slow_client.py   # a client that reads slowly on purpose
└── README.md
```

**Must handle**: reconnect with no missed and no duplicated events, heartbeats to defeat proxy timeouts, and a **slow consumer policy** — decide whether to buffer, drop or disconnect, and defend the choice in the README.

**Done when**: you can kill the client mid-stream, restart it, and lose nothing.

---

### Drill 5.2 — Multi-node chat backplane

```
drills/05-backplane/
├── node.py          # WebSocket server holding connections
├── backplane.py     # Redis pub/sub so node A reaches node B's clients
├── presence.py      # who is online, with TTL heartbeats
├── compose.yml      # 3 nodes + nginx + redis
└── README.md
```

**Done when**: you run three nodes behind a load balancer, a message sent to node 1 arrives at a client on node 3, and killing node 2 does not lose anyone else's messages.

---

## Section 06 — APIs

### Drill 6.1 — A GraphQL execution engine

Not a wrapper. The engine.

```
drills/06-graphql/
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

### Drill 6.2 — Same API, three ways

One domain (orders). Three interfaces. One benchmark.

```
drills/06-three-apis/
├── domain/          # shared business logic — no protocol code here
├── rest/
├── graphql/
├── grpc/
├── bench/           # payload size, latency, N+1 behaviour
└── COMPARISON.md
```

**Done when**: `COMPARISON.md` contains your own measured numbers, not numbers from a blog post.

---

## Section 07 — Databases

### Drill 7.1 — Index detective

```
drills/07-index-lab/
├── seed.py          # generate 10M realistic rows
├── queries.sql      # 15 queries: some indexable, some not
├── plans/           # saved EXPLAIN ANALYZE output before and after
└── FINDINGS.md
```

**Done when**: for each query you can predict the plan before running it, and you were right at least 12 times out of 15.

---

### Drill 7.2 — Break isolation

```
drills/07-isolation/
├── anomalies.py     # reproduce dirty read, non-repeatable read, phantom, write skew
├── runner.py        # two sessions, controlled interleaving
└── FINDINGS.md      # which anomaly appears at which isolation level
```

**Done when**: you have personally produced write skew, then fixed it two different ways (`SELECT FOR UPDATE` and `SERIALIZABLE`) and measured the cost of each.

---

### Drill 7.3 — Zero downtime migration

```
drills/07-migration/
├── app_v1.py        # running app, taking constant write traffic
├── migrate/         # expand → backfill → switch → contract, four steps
├── load.py          # keeps writing throughout
└── README.md
```

**Task**: rename a column and change its type on a 50M-row table while `load.py` runs continuously, with zero failed writes.

**Done when**: the error count during migration is exactly zero.

---

## Section 08 — Caching

### Drill 8.1 — Cache with the hard parts included

```
drills/08-cache/
├── cache.py         # cache-aside with TTL and jitter
├── stampede.py      # single-flight lock + probabilistic early expiry
├── lock.py          # distributed lock with fencing tokens and lease renewal
├── chaos.py         # kills the lock holder mid-operation
└── README.md
```

**Done when**: 1000 concurrent requests for one expired key cause exactly one database query, and your chaos test proves the fencing token stops a zombie lock holder from corrupting data.

---

## Section 09 — Background Work

### Drill 9.1 — Build a task queue

No Celery.

```
drills/09-taskqueue/
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

### Drill 9.2 — Saga

```
drills/09-saga/
├── steps.py         # 4 steps, each with a compensating action
├── orchestrator.py  # state machine, persisted, resumable
├── failure_matrix/  # a test per failure point
└── README.md
```

**Done when**: killing the process at any of the 8 possible points leaves the system in a consistent state after restart. All 8 are tested.

---

## Section 10 — Event Streaming

### Drill 10.1 — Build a log

Kafka's core idea, minus the distribution.

```
drills/10-log/
├── segment.py       # append-only file, sparse index, offsets
├── log.py           # partitions, retention, compaction
├── consumer.py      # consumer groups, offset commits, rebalance
├── producer.py      # batching, keyed partitioning
└── README.md
```

**Done when**: two consumers in a group split partitions, one dies, the other takes over from the right offset, and a replay from offset 0 gives identical results.

---

### Drill 10.2 — Outbox + CDC

```
drills/10-outbox/
├── service.py       # writes business row + outbox row in one transaction
├── relay.py         # polls outbox, publishes, marks sent
├── cdc_relay.py     # same thing via logical replication instead
├── chaos.py         # kills the relay between publish and mark
└── COMPARISON.md
```

**Done when**: no event is ever lost, duplicates are possible but harmless, and you can explain when CDC beats polling.

---

## Sections 11–12 — Microservices and Reliability

### Drill 12.1 — A resilience toolkit

```
drills/12-resilience/
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
| [Designing Data-Intensive Applications — Kleppmann](https://dataintensive.net/) | The reference text for sections 07–12. Read it alongside, not before |
| [Architecture Decision Records — Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) | The original ADR post. Two pages, permanently useful |
| [k6 documentation](https://grafana.com/docs/k6/latest/) | The load testing tool used in every Conduit phase |

---

**Next:** [[Assets.3 - Numbers To Know]]
