**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.5 - Resource Library]]

---

# Rapid Fire Question Bank

#backend #reference #assets #interview

> **In one line:** Questions the vault answers, with the shape of a strong reply — the pattern being a direct answer, a mechanism, and a number you measured.

---

## How To Use This

💡 **The strong answer has three parts:** what, why it works that way, and a measurement.

```
❌  "Use acks_late for reliability"
✅  "acks_late acks after execution rather than on accept, so a worker
     crash redelivers instead of losing the task. I measured it: 1,000
     tasks with a kill halfway lost 43 with the default and zero with
     acks_late. The tradeoff is you must be idempotent"
```

⚠️ **Do not memorise these.** Answer from the notes and the drills, and **the number is what makes it credible.**

---

## Python and Concurrency

**What does the GIL actually prevent?**
Two threads executing Python bytecode simultaneously. It does not prevent I/O concurrency — the GIL is released around blocking syscalls. **CPU-bound work needs processes; I/O-bound work does not.**

**Why is one blocking call in an async handler so damaging?**
It blocks the entire event loop, so *every* concurrent request stalls, not just that one. **Measure loop lag — anything above 10ms is visible in p99.**

**How do you find what is blocking the loop?**
Instrument loop lag, then `asyncio` debug mode or a sampling profiler. **The signature is "everything got slow at once".**

**When would you use threads in an async service?**
`run_in_executor` for a blocking library you cannot replace. **Bound the pool** — an unbounded executor is a way to run out of memory.

**What happens when a client disconnects mid-request?**
Uvicorn cancels the task; `CancelledError` is raised at the next `await`. **A multi-step operation can be left half-done — which is why you write a durable record first, then queue the rest.**

---

## Networking and HTTP

**Why is a slow dependency worse than a down one?**
Down fails fast and your breaker opens. **Slow holds a worker for the full timeout, so `concurrency = throughput × latency` means a 10× latency rise needs 10× the workers.** That is how one dependency takes down an unrelated endpoint.

**What is the pool timeout, and why does it matter?**
The time waiting for a connection *from your own pool*. **Without it, a saturated pool means unbounded waiting — the exact resource exhaustion the other timeouts exist to prevent.** It is the one people omit.

**Why does HTTP/2 break L4 load balancing?**
One connection multiplexes every request, so a connection-level balancer sends all of them to one backend. **For gRPC on Kubernetes: a headless Service plus client-side round-robin, no mesh required.**

**SSE or WebSocket?**
SSE for server-to-client push: automatic reconnection, `Last-Event-ID` replay, plain HTTP, no upgrade. **WebSocket only when the client sends messages too.** Most "realtime" requirements are one-way.

**What is head-of-line blocking, and where does it appear?**
One slow item blocking those behind it. **TCP (fixed by QUIC), HTTP/1.1 pipelining, a Kafka partition, and a shared task queue where one slow tenant starves the rest.**

---

## API Design

**Why is offset pagination wrong?**
It is `O(offset)` — deep pages scan and discard — and it **silently skips and duplicates rows when data changes underneath.** Keyset pagination with a unique tiebreaker fixes both.

**What actually counts as a breaking API change?**
Removing or renaming, changing a type, tightening validation, changing default sort order — **and adding an enum value**, which is the one people ship without thinking.

**How do you remove a field safely?**
Expand, migrate, verify usage is zero, contract. **The verify step is what people skip**, so nothing is ever removed. GraphQL makes it measurable; REST does not.

**Why can errors not be raised in a streaming response?**
Once `200 OK` is sent, the status is on the wire. **Errors must be in-band, and clients must be documented to check for them** — a client checking only the status treats a failed generation as a short successful one.

**When is GraphQL the wrong choice?**
One client. You inherit N+1, unbounded query cost, lost HTTP caching and per-endpoint observability, **for flexibility you are not using.**

---

## Databases

**Why is UUIDv4 a bad primary key?**
Random values scatter inserts across the index: page splits everywhere, rapid bloat, and a working set that will not stay in memory. **UUIDv7 is the same size and non-guessable, with sequential locality.**

**Explain the left-prefix rule.**
An index on `(a, b, c)` serves queries filtering `a`, then `a,b`, then `a,b,c`. **Equality conditions chain; the first range condition ends useful traversal.** So: equality columns, then the range column, then sort columns.

**What is write skew, and which isolation level stops it?**
Two transactions each read a set, each write based on it, and together break an invariant neither could see breaking. **Repeatable Read does not stop it** — the writes touch different rows. Serializable does. **Better: an exclusion constraint or a unique constraint.**

**What holds back vacuum?**
A long-running transaction, an inactive replication slot, a long query on a standby with feedback on, or an orphaned prepared transaction. **All four produce one small value from `GetOldestNonRemovableTransactionId`.**

**What is transaction ID wraparound?**
32-bit transaction IDs used circularly; vacuum freezes old rows. **At ~2 billion Postgres refuses new transactions and the database is down.** Alert on `age(datfrozenxid)` at 1 billion. Entirely preventable.

**Why does a "safe" `ALTER TABLE` cause an outage?**
It takes `ACCESS EXCLUSIVE` briefly — **and lock requests queue in order.** One long query plus one DDL statement means every subsequent query waits behind the DDL. **`lock_timeout` with retry is the fix.**

**Why are fewer database connections faster?**
Context switching, lock contention and buffer pool contention. **Throughput peaks near `(cores × 2)` active connections and declines beyond.** Queue in PgBouncer, not in Postgres.

**What breaks in PgBouncer transaction mode?**
Prepared statements (before 1.21), `SET` outside a transaction, `LISTEN/NOTIFY`, session advisory locks, temp tables. **And `SET` rather than `SET LOCAL` leaks the tenant to the next request.**

---

## Caching and Coordination

**What is a cache stampede, and how do you prevent it?**
A hot key expires and every concurrent request misses simultaneously. **Signature: periodic p99 spikes at exactly your TTL interval.** Fix with jittered TTLs plus single-flight or stale-while-revalidate.

**Why do you cache negative results?**
Otherwise a request for a non-existent ID hits the database every time — **a trivially exploitable amplification vector.** Shorter TTL than positives.

**Can a distributed lock guarantee mutual exclusion?**
No. **A paused process cannot know it was paused**, so its lease can expire while it believes it holds the lock. **Only a fencing token at the protected resource actually prevents concurrent writes.**

**When would you not use a lock?**
Almost always. **A unique constraint, an idempotency key, `FOR UPDATE SKIP LOCKED`, or an optimistic version check are all stronger and simpler.** Locks are for efficiency, not correctness.

**Why does a Redis outage take down your database?**
A 95% hit ratio means Redis absorbs 20× your database load. **Losing it is an instant 20× spike.** Survivable only with headroom, shedding, or a local fallback — **and it must be tested.**

---

## Queues and Events

**Is Celery at-least-once or at-most-once?**
**At-most-once by default.** `acks_late=False` acks on accept, so a crash mid-execution loses the task. `acks_late=True` gives at-least-once and requires idempotency.

**What is the Redis visibility timeout bug?**
Redis has no real ack; Celery redelivers anything not acked within `visibility_timeout`. **A task running longer than that is delivered to a second worker while the first is still running.** Default is one hour.

**Why does one worker sit idle while another is overloaded?**
Prefetch. `multiplier × concurrency` messages are reserved per worker, so one long task blocks the short ones queued behind it. **Set `prefetch_multiplier=1` for variable-duration work.**

**Why can you not just publish after the commit?**
There is no transaction spanning your database and the broker. **A crash between them loses the event permanently.** The outbox writes the event in the same transaction.

**Queue or log?**
Queue for commands with one handler. **Log when you need replay, multiple independent consumers, or an audit trail.** A queue consumes destructively.

**How do you make a consumer replayable?**
Idempotent effects (absolute, not relative writes), no external side effects or a separate consumer for those, event-time not wall-clock, and no dependency on current external state. **Test it: consume, snapshot, reset, re-consume, assert identical.**

---

## Microservices

**When should you split?**
When multiple teams are genuinely blocked by a shared deploy. **It is an organisational solution.** With one team you pay every cost and collect no benefit.

**What does a split actually cost?**
Transactions become sagas, joins become network calls, availability multiplies down, mean time to diagnose roughly doubles, and the operational surface multiplies by the service count. **Quantify it: our four-service split cost ~8ms per request and took effective availability from 99.9% to 99.7%.**

**How do you pick a boundary?**
Where no transaction spans it, few foreign keys cross it, the sides do not co-change, and the call volume is low. **Instrument cross-module calls in the monolith first — that traffic matrix is what the network would carry.**

**Why do you need a service mesh?**
Usually you do not. **One language and a handful of services: a shared client library gives retries, breakers and tracing with zero latency and zero sidecar memory.** A mesh earns its place for mTLS at scale or genuine polyglot uniformity.

**What is the biggest risk in a saga?**
That compensation also fails. **You need an explicit `compensation_failed` state, escalation with enough context to act, and reconciliation.** And order the steps so the irreversible one is last.

---

## Resilience

**Why is a retry budget better than a retry count?**
Per-call limits do not bound system-wide amplification. **At a 90% failure rate, three retries triple your load on a dependency that is already failing.** A budget caps retries at 10–20% of traffic regardless.

**Why full jitter rather than plain exponential backoff?**
Without jitter, every client retries in synchronised waves. **Full jitter measurably recovers faster despite spreading retries out**, because it eliminates contention.

**What is metastable failure?**
The trigger ends and the system does not recover, because the effort per request has risen — retries, stale queued work, cold caches. **Load shedding prevents it; nothing else reliably does.**

**Why must liveness not check dependencies?**
A slow database fails every pod's liveness, every pod restarts, cold caches and reconnections increase database load, and it repeats. **A self-sustaining outage from a degraded dependency.**

**What is the point of a circuit breaker without a fallback?**
Very little. **It converts a slow failure into a fast one, which preserves your resources — but the value is in what you do when it is open.**

**Why does graceful shutdown need a sleep?**
Endpoint removal and `SIGTERM` are concurrent, not ordered. **For seconds after `SIGTERM`, traffic still arrives.** Fail readiness, sleep, then stop accepting.

---

## Observability and Operations

**What is the difference between an SLI and an SLO?**
The SLI is the measurement, the SLO the target. **The gap between the SLO and 100% is an error budget you are permitted to spend** — and the policy attached to exhausting it is what makes it real.

**Why alert on burn rate rather than error rate?**
It normalises across SLOs, so one rule works for 99.9% and 99%. **Two windows per tier stops flapping** — the short window means the alert resolves when the problem does.

**Why not label metrics by user ID?**
Unbounded cardinality. **One high-cardinality label can generate millions of series and take down your metrics backend.** High-cardinality dimensions belong in traces and logs; exemplars bridge them.

**Where do traces usually break?**
At the queue boundary. **Auto-instrumentation handles HTTP and gRPC; the outbox and the broker do not.** Inject the context into the outbox row and the message headers.

**What does a good postmortem contain that most lack?**
A "where we got lucky" section. **"This happened at 2pm; at 2am nobody would have noticed for hours" is the finding that prevents the next incident.**

**Why alert on queue oldest-age rather than depth?**
Depth tells you how much is waiting; **oldest-age tells you whether anything is stuck.** 10,000 messages seconds old is healthy; 5 messages three hours old is broken.

---

## Containers and Delivery

**Why does `docker stop` take ten seconds?**
Signals are not reaching PID 1. **Shell-form `CMD` makes the shell PID 1 and it does not forward.** And exec form alone is not enough — PID 1 has no default `SIGTERM` handler, so the process must install one.

**What does exit code 137 mean?**
OOM-killed. `128 + 9`. **No shutdown handler ran, nothing was logged**, because `SIGKILL` cannot be caught.

**Should you set CPU limits?**
Usually not. **They throttle rather than kill, and the throttling is invisible in average CPU usage** — "slow at 40% CPU" is almost always `nr_throttled`. Always set CPU *requests*, and always set memory requests and limits.

**Why is autoscaling not a substitute for headroom?**
Metric scrape, scheduling, image pull and startup take 30 seconds to two minutes. **A spike arrives in seconds.** Headroom covers the scaling delay.

**Why does scaling on latency create a feedback loop?**
If the bottleneck is downstream, more pods means more database connections, which makes it slower, which scales up further. **Scale on your own saturation — in-flight requests, or queue age for workers.**

---

## Security

**403 or 404?**
404 for objects the user cannot see, **and with no timing difference** — otherwise the 404 is decorative and you have built an enumeration oracle.

**Where does authorisation belong?**
On the type that owns the data, not the entry point. **Clients reach objects through paths you did not anticipate**, which is acute in GraphQL. Enforce in the loader and in the database, not just the handler.

**Why is `SET LOCAL` rather than `SET` critical with RLS?**
In transaction pooling, a plain `SET` persists on the server connection. **The next tenant to use it inherits your `org_id`** — a cross-tenant breach that only appears under load.

**Why are JWTs the wrong default for browser auth?**
You cannot revoke them. **Every mitigation — denylists, short expiry plus a validity check — reintroduces server-side state**, which is a session with extra steps and a larger token.

**What is refresh token reuse detection?**
Every refresh issues a new token and marks the old one used. **A used token presented again means theft or replay, and you cannot tell which — so you revoke the whole family.**

**Why does SSRF need more than URL validation?**
DNS rebinding: the hostname resolves public when you check and private when you connect. **Resolve once and connect to the IP, never follow redirects, and run delivery from an egress-restricted network** so a validation bypass reaches nothing.

---

## The Meta Questions

**How would you approach a system you have never seen?**
Pick one concrete question with a start and an end, find the entry point, trace that path with a debugger, and stop at the time budget. **The written trace is the artefact.**

**What is the biggest mistake you have made?**
⚠️ **Answer honestly and specifically**, with what you changed. A vague answer is worse than an embarrassing one.

**How do you decide between two technologies?**
Name the specific thing the incumbent cannot do, measure it, and write a reconsideration trigger for whichever you reject. **"We stayed on Postgres FTS; precision@10 was 0.72 against our golden set, and we move below 0.65."**

**What would you do differently?**
💡 **The strongest possible answer names something you built and would not build again, with the number that taught you.** "We split into services in phase 4. With one team, a second deployment of the same image would have given the same scaling for none of the cost — and I have the measurements."

---

**Next:** [[Docker]]
