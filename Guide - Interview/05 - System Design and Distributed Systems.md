**Up:** [[00 - Index (Interview)]] | **Prev:** [[04 - Python, Backend Engineering and AI System Design]]

---

# 05 — System Design and Distributed Systems

> Distributed-systems theory (CAP, consistency, partitioning), messaging (Kafka in microservices), Redis with working code, and scaling a database. Each answer is written the way you'd say it, followed by the code to put on the whiteboard, the likely follow-ups, and links to the notes that go deeper.

---

## Section A: Distributed Systems Theory

### Q1. What is the CAP theorem? What does it actually mean in practice?

**Answer**

**The statement:** in a distributed data store, when a **network partition** happens (nodes can't talk to each other), each operation must choose between:
- **Consistency (C):** every read sees the most recent write, *or* gets an error. "Consistency" here specifically means **linearizability**: the system behaves as if there were one copy of the data.
- **Availability (A):** every request to a non-failed node gets a non-error response, *possibly with stale data*.

**Partition tolerance (P) isn't optional.** Networks *do* partition (a switch dies, a cross-region link drops, a GC pause makes a node look dead). So "pick 2 of 3" is misleading. The real statement is **"when a partition happens, choose C or A."** A "CA" system is really a single-node system, or one that hopes partitions never happen.

**What each choice looks like during a partition:**

| | The minority side of the partition… | Examples | Good for |
|---|---|---|---|
| **CP** | **Refuses** reads and/or writes (errors or timeouts) rather than serve possibly stale data | ZooKeeper, etcd, Consul, HBase, Spanner, MongoDB with majority writes and reads | Locks, leader election, config, money balances, inventory counts |
| **AP** | **Keeps answering** with whatever it has. Replicas diverge and reconcile later | Cassandra, DynamoDB (default reads), Riak, CouchDB, DNS | Shopping carts, feeds, likes, catalogues, session data |

**The part people forget, PACELC:** CAP only talks about the partition case, which is rare. **PACELC** adds: *"**E**lse (no partition), choose between **L**atency and **C**onsistency."* Even with a perfect network, a strongly consistent write must wait for replicas to acknowledge it, and that costs latency on every request. This tradeoff is the one you pay *every day*:

| System | Partition → | Else → |
|---|---|---|
| DynamoDB, Cassandra (default) | A | L (fast, eventually consistent) |
| Spanner, CockroachDB | C | C (pays latency for consistency) |
| MongoDB (typical config) | C | L or C, depending on read/write concern |
| Postgres primary + async replicas | C on the primary | L: replica reads are fast but may be stale |

**In practice:**
1. CAP is chosen **per operation, not per system.** Many databases let you tune it per query: Cassandra consistency levels, DynamoDB `ConsistentRead`, MongoDB read/write concerns.
2. Most real systems are **mixed**. Payments are CP and the product catalogue is AP, inside the same company and often the same request.
3. The question to ask product is **"what's the cost of a stale read here?"** versus **"what's the cost of an error here?"**

**Code: the same choice, made per request**

```python
# DynamoDB: AP by default. Opt in to a strongly consistent (CP-ish) read per call.
import boto3

table = boto3.resource("dynamodb").Table("accounts")
stale_ok  = table.get_item(Key={"id": "acc-42"})                         # eventually consistent, cheaper
must_know = table.get_item(Key={"id": "acc-42"}, ConsistentRead=True)    # reads the leader, 2× cost
```

```python
# Cassandra: tunable consistency per statement
from cassandra import ConsistencyLevel
from cassandra.query import SimpleStatement

feed = SimpleStatement("SELECT * FROM feed WHERE user_id = %s",
                       consistency_level=ConsistencyLevel.ONE)      # AP: any replica answers
balance = SimpleStatement("SELECT balance FROM wallets WHERE id = %s",
                          consistency_level=ConsistencyLevel.QUORUM) # majority must agree
```

```sql
-- Postgres: choose how consistent a commit is with its replicas, per transaction
SET LOCAL synchronous_commit = 'remote_apply';  -- wait until the sync replica has APPLIED it: replica reads see it
SET LOCAL synchronous_commit = 'local';         -- don't wait for replicas: faster, replicas may lag
```

**Likely follow-ups**
- *Is Postgres CP or AP?* A single Postgres primary isn't a distributed system, so CAP doesn't really apply. With async replicas, reads from replicas are AP-ish (stale), and failover can lose the last few writes. With synchronous replication, writes block if the sync replica is unreachable, which is CP.
- *Is Kafka CP or AP?* Configurable. `acks=all` + `min.insync.replicas=2` + `unclean.leader.election.enable=false` means writes fail rather than risk loss (CP-leaning). Unclean leader election allows a stale replica to lead (AP, can lose data).
- *Give a real example where you chose AP.* "A like counter. A user seeing 1,203 likes instead of 1,204 for two seconds costs nothing. A 500 error on the feed costs engagement."
- *And CP?* "Seat booking. Two people buying the same seat is worse than one of them seeing 'try again'."

**What a strong answer shows:** You know P isn't optional, you know CAP's "consistency" means linearizability (not the C in ACID), you bring up PACELC unprompted, and you treat it as a per-operation business decision.

**Go deeper:** [[01.5 - CAP and PACELC]] · [[01.6 - Consistency Models]] · [[06.12 - Replication and Failover]]

**Resource:** [Martin Kleppmann — "Please stop calling databases CP or AP"](https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html): the clearest critique of how CAP gets misused, from the author of DDIA.

---

### Q2. Explain consistency, availability and partitioning. What do the words actually mean?

**Answer**

All three words are **overloaded**, and interviewers often test whether you know which meaning is in play.

#### Consistency: four different meanings

| Where you hear it | Means |
|---|---|
| **ACID** "C" | The database moves from one *valid* state to another: constraints, foreign keys, invariants hold. An application and schema property. Nothing to do with replicas |
| **CAP** "C" | **Linearizability**: all clients see one up-to-date copy |
| **Consistency models** | A spectrum of guarantees about what reads can return (below) |
| **"Eventually consistent"** | If writes stop, all replicas *eventually* converge. No promise about *when* or what you see meanwhile |

**The consistency spectrum**, strongest first:

| Model | Guarantee | Example / cost |
|---|---|---|
| **Linearizable (strong)** | Every read sees the latest completed write, globally, in real-time order | etcd, Spanner. Costs a round trip to a quorum or the leader on every operation |
| **Sequential** | Everyone sees the same order of operations, but not necessarily real-time | Rarely chosen explicitly |
| **Causal** | If A caused B (a reply after a post), everyone sees A before B. Unrelated writes may appear in any order | Comment threads, chat. Much cheaper than linearizable |
| **Read-your-writes** | *You* always see your own writes. Others may not yet | "I updated my profile and it reverted!" is the bug this prevents |
| **Monotonic reads** | You never see time go backwards (newer, then older) | Achieved by sticking a user to one replica |
| **Eventual** | Replicas converge eventually | DNS, Cassandra at `ONE`, async replicas |

> The useful middle ground for most product features is **read-your-writes + monotonic reads**. Users don't notice that *others* see their update 500 ms late, but they absolutely notice when *their own* change disappears.

#### Availability: a percentage, and a design property

- **As a number:** the fraction of time (or of requests) that succeed.

| Availability | Downtime / year | Downtime / month |
|---|---|---|
| 99% ("two nines") | 3.65 days | 7.3 hours |
| 99.9% | 8.76 hours | 43.8 minutes |
| 99.99% | 52.6 minutes | 4.4 minutes |
| 99.999% | 5.3 minutes | 26 seconds |

- **Serial dependencies multiply:** a request that needs 3 services, each at 99.9%, is at best 0.999³ ≈ **99.7%**. That's why each extra synchronous hop in a microservice call chain lowers your ceiling.
- **Redundancy adds:** two independent replicas at 99% each → 1 − 0.01² = **99.99%**, *if* their failures really are independent (different racks or zones, no shared dependency).
- **As a design property (CAP's A):** does a node answer even when it can't reach the others?
- **How you build it:** redundancy (no single point of failure), health checks + failover, timeouts + retries, graceful degradation, and isolation (bulkheads, cells) so a failure has a small blast radius.

#### Partitioning: two unrelated meanings

| Meaning | What it is | Where it appears |
|---|---|---|
| **Network partition** | A failure: nodes can't communicate, but each is still running | CAP's "P" |
| **Data partitioning (sharding)** | A design choice: split data across nodes or tables so each holds a subset | Scaling, Kafka partitions, Postgres declarative partitioning |

**Data partitioning strategies:**

| Strategy | How | Good | Bad |
|---|---|---|---|
| **Range** | `user_id 1–1M → shard A`, or by date | Range scans, time-based retention | Hot spots (all new writes go to the latest range) |
| **Hash** | `hash(key) % N` | Even spread | No range scans. Changing N moves almost every key |
| **Consistent hashing** | Keys and nodes on a ring, with virtual nodes | Adding a node moves only ~1/N of the keys | More complex. Still needs virtual nodes for balance |
| **Directory / lookup** | A table maps key → shard | Flexible, can move tenants | An extra hop, and the directory is critical |

**Quorums tie the three together.** With N replicas, write to W and read from R:

```
N = 3 replicas
W = 2  (write succeeds when 2 acknowledge)
R = 2  (read asks 2 and takes the newest)
R + W > N  →  every read set overlaps every write set → you read the latest acknowledged write
```

```python
def quorum_ok(n: int, w: int, r: int) -> dict:
    return {
        "reads_see_latest_write": r + w > n,
        "write_tolerates_down":   n - w,     # nodes that can be down and writes still succeed
        "read_tolerates_down":    n - r,
    }

quorum_ok(3, 2, 2)  # {'reads_see_latest_write': True,  'write_tolerates_down': 1, 'read_tolerates_down': 1}
quorum_ok(3, 1, 1)  # {'reads_see_latest_write': False, 'write_tolerates_down': 2, 'read_tolerates_down': 2}  ← AP
quorum_ok(3, 3, 1)  # {'reads_see_latest_write': True,  'write_tolerates_down': 0, 'read_tolerates_down': 2}  ← fast reads, fragile writes
```

That's CAP turned into numbers: lower W and R → more available and faster, but stale reads are possible. Higher → consistent, but fewer node failures tolerated.

**Likely follow-ups**
- *How do you give read-your-writes with async replicas?* After a user writes, route *their* reads to the primary for a few seconds (store "last write time" in the session), or read from a replica only once it has replayed past the write's LSN.
- *Does R + W > N make it linearizable?* Not on its own. Sloppy quorums, concurrent writes with last-write-wins clocks, and read repair timing can all break it. Say "it gives the overlap property; true linearizability needs more."
- *What's a split brain?* During a partition, two nodes both believe they're the leader and both accept writes. You prevent it with a majority quorum (only the side with more than N/2 can elect a leader) and fencing tokens.

**What a strong answer shows:** You disambiguate the overloaded words without being asked, you can do availability arithmetic, and you connect quorums to the CAP tradeoff.

**Go deeper:** [[01.6 - Consistency Models]] · [[01.4 - Core Properties]] · [[01.11 - Distributed Concepts]] · [[06.13 - Partitioning and Sharding]] · [[07.6 - Leader Election and Coordination]]

**Resource:** [Jepsen — Consistency Models](https://jepsen.io/consistency): a clickable map of every consistency model and how they relate, from the team that tests real databases against them.

---

### Q3. How do you keep data consistent across microservices without a distributed transaction?

**Answer**

Each service owns its database ([[10.4 - Data Ownership]]), so a single ACID transaction can't span "create order" in one service and "charge card" in another. Two-phase commit (2PC) exists, but it blocks when the coordinator fails, couples every service's availability together, and most brokers and NoSQL stores don't support it. The practical toolkit:

1. **Saga.** A sequence of local transactions, each with a **compensating action** that undoes it if a later step fails.
   - **Choreography:** services react to each other's events. No central brain. Works for 2–4 steps, and gets hard to follow beyond that.
   - **Orchestration:** one orchestrator (a workflow engine such as Temporal, or a state machine) tells each service what to do next. Easier to reason about, retry and observe.
2. **Transactional outbox.** Never "write to DB, then publish to Kafka" as two steps: a crash between them loses or duplicates the event. Write the event to an `outbox` table **in the same transaction** as the data, and have a relay (or CDC with Debezium) publish it.
3. **Idempotent consumers.** Delivery is at-least-once, so every handler must survive duplicates (see Q4's code).
4. **Accept eventual consistency in the UX.** "Order received, confirming payment…" is a status, not a bug.

```
Order saga (orchestrated):

  CreateOrder(PENDING) ──▶ ReserveStock ──▶ ChargeCard ──▶ ConfirmOrder
         ▲                     │ fail           │ fail
         │                     ▼                ▼
         └──── CancelOrder ◀── (nothing to undo)  ReleaseStock ◀── RefundCard (if partially charged)
```

**Likely follow-ups**
- *Compensation isn't a rollback, so why not?* Because other people may have already seen the intermediate state (an email was sent, stock was shown as reserved). A compensation is a *new* business action (refund, release), not undoing history.
- *What if the compensation fails?* Retry it (it must be idempotent), then alert a human through a dead-letter queue. Sagas need a "stuck" state that someone looks at.

**What a strong answer shows:** You know why 2PC is avoided, you can name outbox + saga + idempotency together, and you treat compensations as business operations.

**Go deeper:** [[10.5 - Distributed Transactions and Sagas]] · [[09.3 - The Outbox Pattern]] · [[02.24 - Saga Pattern]] · [[08.11 - Durable Workflows and Sagas]]

**Resource:** [microservices.io — Saga pattern](https://microservices.io/patterns/data/saga.html) and [Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html), from Chris Richardson.

---

## Section B: Messaging

### Q4. How do you use a message queue like Kafka in a microservices architecture?

**Answer**

**Why put a queue between services at all:**

| Without a queue (sync HTTP) | With a queue/log |
|---|---|
| Caller waits for every downstream service | Producer publishes and returns. Consumers work at their own pace |
| A downstream outage = upstream errors | Messages wait in the log until the consumer recovers |
| Traffic spike hits every service at once | The log **absorbs** the spike (buffering, backpressure) |
| Caller must know every consumer | **Fan-out**: billing, email, analytics and search all subscribe independently |
| Hard to replay history | Kafka retains events. A new consumer can **replay** from the start |

**Kafka's model in four sentences:**
1. A **topic** is split into **partitions**. Each partition is an ordered, append-only log stored on disk and replicated across brokers.
2. Producers choose a partition by **message key** (`hash(key) % partitions`), so **all events for one key are ordered**. Order across keys isn't guaranteed.
3. A **consumer group** shares the partitions: each partition is read by exactly one consumer in the group. Parallelism therefore tops out at the **number of partitions**.
4. Consumers track their position with **offsets** that they **commit**. Different groups (billing, analytics) read the same topic independently.

**How to design it for a real system (orders example):**

| Decision | Choice | Why |
|---|---|---|
| Topic | `orders.events`, one topic per aggregate | All events for an order (created, paid, shipped) in one place, in order |
| Key | `order_id` | Per-order ordering. Spreads load across partitions |
| Partitions | e.g. 12–48 | Upper bound on consumer parallelism. Hard to change later without breaking key → partition mapping |
| Producer | `acks=all`, idempotence on | No loss on broker failure. No duplicates from producer retries |
| Consumer | Manual commit **after** processing | At-least-once: never lose a message, might see one twice |
| Handler | **Idempotent** (dedupe by event ID) | Because of at-least-once |
| Failures | Retry with backoff → **dead-letter topic** | One poison message mustn't block the partition forever |
| Publishing from a service | **Outbox** table + relay | DB write and event publish must not diverge |
| Schemas | Avro/Protobuf/JSON Schema + registry, backward-compatible | Producers and consumers deploy independently ([[09.6 - Schema Registry and Compatibility]]) |

**Code: producer (inside a FastAPI service)**

```python
# pip install aiokafka
import json
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone

from aiokafka import AIOKafkaProducer
from fastapi import FastAPI


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.producer = AIOKafkaProducer(
        bootstrap_servers="kafka:9092",
        acks="all",                        # wait for all in-sync replicas: no loss on broker failure
        enable_idempotence=True,           # broker de-dupes producer retries
        linger_ms=5,                       # small batching window: big throughput win
        key_serializer=str.encode,
        value_serializer=lambda v: json.dumps(v).encode(),
    )
    await app.state.producer.start()       # one producer per process, reused
    yield
    await app.state.producer.stop()        # flushes pending batches


app = FastAPI(lifespan=lifespan)


def make_event(event_type: str, order_id: str, data: dict) -> dict:
    return {
        "event_id": str(uuid.uuid4()),     # consumers dedupe on this
        "type": event_type,
        "order_id": order_id,
        "occurred_at": datetime.now(timezone.utc).isoformat(),
        "version": 1,
        "data": data,
    }


async def publish(producer: AIOKafkaProducer, event: dict) -> None:
    # key = order_id → every event for this order lands on the same partition → ordered
    await producer.send_and_wait("orders.events", key=event["order_id"], value=event)
```

> ⚠️ Calling `publish()` straight after a DB commit in the request handler is the **dual-write bug**: if the process dies between the commit and the send, the order exists and nobody hears about it. In production the handler writes to an **outbox** table in the same transaction, and a relay publishes it:

```python
# Outbox: same transaction as the business write
async with pool.acquire() as conn, conn.transaction():
    await conn.execute("INSERT INTO orders (id, status, total) VALUES ($1, 'PENDING', $2)", oid, total)
    await conn.execute(
        "INSERT INTO outbox (event_id, topic, key, payload) VALUES ($1, $2, $3, $4)",
        event["event_id"], "orders.events", oid, json.dumps(event),
    )

# Relay: a separate loop/worker. SKIP LOCKED lets several relays run safely.
async def relay_outbox(pool, producer):
    while True:
        async with pool.acquire() as conn, conn.transaction():
            rows = await conn.fetch("""
                SELECT id, topic, key, payload FROM outbox
                WHERE published_at IS NULL ORDER BY id LIMIT 100
                FOR UPDATE SKIP LOCKED""")
            for row in rows:
                await producer.send_and_wait(row["topic"], key=row["key"],
                                             value=json.loads(row["payload"]))
            if rows:
                await conn.execute("UPDATE outbox SET published_at = now() WHERE id = ANY($1)",
                                   [r["id"] for r in rows])
        if not rows:
            await asyncio.sleep(0.2)
```

(A crash after publishing but before marking means the event is published **again**. That's fine, because consumers are idempotent.)

**Code: idempotent consumer with retries and a dead-letter topic**

```python
import asyncio
import json
import logging

from aiokafka import AIOKafkaConsumer, AIOKafkaProducer

log = logging.getLogger("billing")
MAX_ATTEMPTS = 5


async def handle_order_paid(conn, event: dict) -> None:
    await conn.execute("INSERT INTO invoices (order_id, amount) VALUES ($1, $2)",
                       event["order_id"], event["data"]["amount"])


async def process(pool, event: dict) -> None:
    async with pool.acquire() as conn, conn.transaction():
        # Dedupe and side effect in ONE transaction: either both happen or neither does
        first_time = await conn.fetchval(
            "INSERT INTO processed_events (event_id) VALUES ($1) "
            "ON CONFLICT DO NOTHING RETURNING event_id", event["event_id"])
        if first_time is None:
            return                                          # duplicate delivery: already handled
        if event["type"] == "OrderPaid":
            await handle_order_paid(conn, event)


async def consume(pool):
    consumer = AIOKafkaConsumer(
        "orders.events",
        bootstrap_servers="kafka:9092",
        group_id="billing-service",              # each service = its own group = gets every event
        enable_auto_commit=False,                # commit only after successful processing
        auto_offset_reset="earliest",
        value_deserializer=lambda b: json.loads(b),
    )
    dlq = AIOKafkaProducer(bootstrap_servers="kafka:9092",
                           value_serializer=lambda v: json.dumps(v).encode())
    await consumer.start()
    await dlq.start()
    try:
        async for msg in consumer:
            for attempt in range(1, MAX_ATTEMPTS + 1):
                try:
                    await process(pool, msg.value)
                    break
                except Exception as e:
                    if attempt == MAX_ATTEMPTS:          # poison message: park it, move on
                        await dlq.send_and_wait("orders.events.dlq", value={
                            "original": msg.value, "error": repr(e),
                            "partition": msg.partition, "offset": msg.offset})
                        log.error("sent to DLQ offset=%s", msg.offset)
                    else:
                        await asyncio.sleep(min(2 ** attempt, 30))   # backoff
            await consumer.commit()                      # at-least-once: commit AFTER work
    finally:
        await consumer.stop()
        await dlq.stop()
```

**Delivery semantics to state clearly:**

| Semantics | How | Risk |
|---|---|---|
| At-most-once | Commit offset **before** processing | Crash = message lost |
| **At-least-once** (default choice) | Commit **after** processing | Crash = message reprocessed, so the handler must be idempotent |
| Exactly-once | Kafka transactions (`read → process → write` back to Kafka), **or** at-least-once + idempotent handler | Kafka EOS only covers Kafka-to-Kafka. Side effects in your DB still need idempotency |

**Likely follow-ups**
- *How do you preserve ordering?* Same key → same partition → ordered. Process one partition sequentially. Retrying in place keeps order. Sending a message to a separate retry topic breaks order for that key, so decide whether that's acceptable.
- *A consumer is slow and lag is growing. What do you do?* Check whether it's one hot partition (skewed key) or all of them. Add consumers up to the partition count, speed up the handler (batching, async I/O), and only then add partitions, which changes the key → partition mapping.
- *What's a rebalance and why does it hurt?* When consumers join or leave, partitions are reassigned. Eager rebalancing stops the whole group. Use the cooperative-sticky assignor, static membership for rolling deploys, and keep processing time well under `max.poll.interval.ms`.
- *Kafka vs RabbitMQ vs SQS?* See Q5.
- *Event vs command?* An event is a fact in the past tense ("OrderPaid") with many possible listeners. A command is a request ("ChargeCard") with one intended handler. Prefer events between services. Commands couple the sender to the receiver.

**What a strong answer shows:** Partition keys for ordering, consumer groups for scale, at-least-once + idempotency, the outbox for the dual-write problem, and DLQs, all in one coherent design.

**Go deeper:** [[Kafka]] (internals, producer and consumer configs, rebalancing) · [[03.8 - Message Queues and Kafka]] · [[09.1 - Queue vs Log]] · [[09.2 - Event Modeling]] · [[09.3 - The Outbox Pattern]] · [[09.8 - Kafka Recap and Where It Fits]] · [[10.3 - Communication Patterns]] · [[08.6 - Retries Backoff and Dead Letters]]

**Resource:** [Confluent — Kafka Design (official docs)](https://docs.confluent.io/kafka/design/index.html) and [Jay Kreps — "The Log: What every software engineer should know"](https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying), the essay that explains why Kafka is a log and not a queue.

---

### Q5. Kafka vs RabbitMQ vs SQS vs Redis Streams: how do you choose?

**Answer**

The core split is **queue** vs **log**:
- A **queue** (RabbitMQ, SQS) **removes** a message once it's acknowledged. Work is distributed: each job goes to one worker.
- A **log** (Kafka, Redis Streams) **keeps** messages for a retention period. Each consumer group tracks its own position. Many independent readers, plus replay.

| | Kafka | RabbitMQ | SQS | Redis Streams |
|---|---|---|---|---|
| Model | Partitioned log | Broker with exchanges → queues | Managed queue | In-memory log |
| Retention / replay | Days to forever. Replay any time | Gone after ack | Gone after delete (max 14 days) | Until trimmed. Bounded by RAM |
| Ordering | Per partition (key) | Per queue, with a single consumer | FIFO queues only (per group) | Per stream |
| Throughput | Very high (100k–1M+/s per broker) | High (tens of thousands/s) | Effectively unlimited (standard) | High, limited by memory |
| Routing | By topic + key | Rich: direct, topic, fanout, headers | None (use SNS for fanout) | By stream |
| Ops burden | High (unless managed: MSK, Confluent) | Medium | None | Low if you already run Redis |
| Pick when | Event streaming, many consumers, replay, CDC, analytics pipelines | Task queues with complex routing, priorities, per-message TTL | AWS shop, simple job queue, zero ops | Lightweight streams, small retention, already on Redis |

**Rule of thumb:** "do this job once" → a queue (SQS, RabbitMQ, Celery on top). "This happened, and whoever cares can react, now or later" → a log (Kafka).

**Go deeper:** [[09.1 - Queue vs Log]] · [[08.4 - Brokers and Result Backends]] · [[Kafka#Kafka vs Redis Streams vs RabbitMQ]] · [[03.9 - PubSub and Event Bus]]

**Resource:** [AWS — The difference between RabbitMQ and Kafka](https://aws.amazon.com/compare/the-difference-between-rabbitmq-and-kafka/): a fairly neutral side-by-side of the queue model and the log model.

---

## Section C: Caching and Redis

### Q6. How do you use Redis? Show me code.

**Answer**

Redis is an **in-memory data-structure server**. It's single-threaded for command execution (so every command is atomic), with optional persistence (RDB snapshots, AOF log) and replication or clustering. Its value comes from picking the **right data structure** for the problem:

| Problem | Structure | Commands |
|---|---|---|
| Cache an object / JSON blob | String | `SET key val EX 300`, `GET` |
| Counters, rate limits | String (integer) | `INCR`, `EXPIRE` |
| An object with fields you update separately | Hash | `HSET`, `HGET`, `HINCRBY` |
| Leaderboards, top-N, time-ordered sets, sliding windows | Sorted set | `ZADD`, `ZINCRBY`, `ZREVRANGE`, `ZREMRANGEBYSCORE` |
| Membership, dedupe, tags | Set | `SADD`, `SISMEMBER`, `SINTER` |
| Simple queue | List | `LPUSH`, `BRPOP` |
| Durable-ish event stream with consumer groups | Stream | `XADD`, `XREADGROUP`, `XACK` |
| Count unique visitors cheaply | HyperLogLog | `PFADD`, `PFCOUNT` (~0.8% error, 12 KB) |
| Locks, idempotency keys | String with `NX` | `SET key val NX PX 10000` |

**Code: the patterns you'll be asked about, with async `redis-py` in FastAPI**

```python
# pip install "redis>=5"
import json
import random
import time
import uuid
from contextlib import asynccontextmanager

import redis.asyncio as redis
from fastapi import Depends, FastAPI, HTTPException, Request


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.redis = redis.from_url(
        "redis://cache:6379/0",
        decode_responses=True,
        max_connections=50,              # pool size per process
        socket_timeout=0.5,              # never let a cache call hang a request
    )
    yield
    await app.state.redis.aclose()


app = FastAPI(lifespan=lifespan)


def get_redis(request: Request) -> redis.Redis:
    return request.app.state.redis
```

**1. Cache-aside with TTL jitter**

```python
async def get_user_profile(r: redis.Redis, user_id: int) -> dict:
    key = f"user:v1:{user_id}"                          # bump v1→v2 to invalidate everything
    if (hit := await r.get(key)) is not None:
        return json.loads(hit)
    profile = await db_load_profile(user_id)            # miss → DB
    await r.set(key, json.dumps(profile), ex=600 + random.randint(0, 120))   # jitter vs stampede
    return profile


async def update_user_profile(r: redis.Redis, user_id: int, data: dict) -> None:
    await db_update_profile(user_id, data)
    await r.delete(f"user:v1:{user_id}")                # invalidate AFTER the DB commit
```

**2. Sliding-window rate limiter (sorted set)**

```python
async def allow_request(r: redis.Redis, client_id: str, limit: int = 100, window_s: int = 60) -> bool:
    key = f"ratelimit:{client_id}"
    now = time.time()
    async with r.pipeline(transaction=True) as pipe:    # MULTI/EXEC: atomic, one round trip
        pipe.zremrangebyscore(key, 0, now - window_s)   # drop entries outside the window
        pipe.zadd(key, {f"{now}:{uuid.uuid4().hex}": now})
        pipe.zcard(key)
        pipe.expire(key, window_s)
        _, _, count, _ = await pipe.execute()
    return count <= limit


@app.get("/api/search")
async def search(request: Request, r: redis.Redis = Depends(get_redis)):
    if not await allow_request(r, request.client.host):
        raise HTTPException(429, "rate limit exceeded", headers={"Retry-After": "60"})
    ...
```

(This one counts rejected requests too. For strict accounting or very high rates, use a Lua token bucket. See [[04.1 - Rate Limiter]].)

**3. Distributed lock with a safe release**

```python
RELEASE = """
if redis.call('get', KEYS[1]) == ARGV[1] then
    return redis.call('del', KEYS[1])
end
return 0
"""

async def with_lock(r: redis.Redis, name: str, ttl_ms: int, fn):
    token = uuid.uuid4().hex                             # identifies THIS holder
    if not await r.set(f"lock:{name}", token, nx=True, px=ttl_ms):
        raise RuntimeError("lock busy")
    try:
        return await fn()
    finally:
        # Only delete if it's still OUR lock. Without this check, a holder whose TTL
        # expired would delete the next holder's lock.
        await r.eval(RELEASE, 1, f"lock:{name}", token)
```

> ⚠️ A Redis lock is fine for **efficiency** (avoid duplicate work). For **correctness** (never two writers), add a **fencing token** that the storage layer checks, because a GC pause can outlive the TTL. See [[07.4 - Distributed Locks Done Right]].

**4. Idempotency key for a POST**

```python
@app.post("/payments")
async def create_payment(body: PaymentIn, request: Request, r: redis.Redis = Depends(get_redis)):
    idem = request.headers.get("Idempotency-Key")
    if not idem:
        raise HTTPException(400, "Idempotency-Key header required")
    key = f"idem:{idem}"
    if not await r.set(key, "IN_PROGRESS", nx=True, ex=86400):   # first one wins
        stored = await r.get(key)
        if stored == "IN_PROGRESS":
            raise HTTPException(409, "request already in progress")
        return json.loads(stored)                                 # replay the original response
    result = await charge(body)
    await r.set(key, json.dumps(result), ex=86400)
    return result
```

**5. Leaderboard (sorted set)**

```python
async def add_score(r, game: str, player: str, points: int):
    await r.zincrby(f"lb:{game}", points, player)

async def top(r, game: str, n: int = 10):
    return await r.zrevrange(f"lb:{game}", 0, n - 1, withscores=True)   # [(player, score), ...]

async def rank(r, game: str, player: str):
    pos = await r.zrevrank(f"lb:{game}", player)
    return None if pos is None else pos + 1
```

**6. Pub/Sub vs Streams**

```python
# Pub/Sub: fire-and-forget. Subscribers that are offline MISS messages.
await r.publish("cache-invalidate", "user:42")

# Streams: persisted, consumer groups, ack. Survives consumer restarts.
await r.xadd("events:orders", {"type": "OrderPaid", "order_id": "o-1"}, maxlen=100_000)
await r.xgroup_create("events:orders", "billing", id="0", mkstream=True)   # once
msgs = await r.xreadgroup("billing", "worker-1", {"events:orders": ">"}, count=10, block=5000)
for _stream, entries in msgs:
    for msg_id, fields in entries:
        ...                                     # process
        await r.xack("events:orders", "billing", msg_id)
```

**Production concerns to mention:**
- **Memory is the limit.** Set `maxmemory` and an eviction policy (`allkeys-lru` for a pure cache, `noeviction` for data you can't lose).
- **Persistence:** RDB (periodic snapshots, can lose minutes) vs AOF (`everysec`, can lose about 1 s). A cache may need neither. A queue or lock store needs AOF.
- **Never** run `KEYS *` in production. It blocks the single thread. Use `SCAN`.
- **Hot keys:** one key = one shard = one CPU core. Spread with key suffixes or a local cache in front.
- **Big keys:** a 50 MB hash blocks the server on `DEL`. Use `UNLINK` and keep values small.
- **Pipelining** batches commands into one round trip, giving 5–10× throughput for bulk operations.
- **Cluster:** 16,384 hash slots spread across shards. Multi-key operations need the keys in the same slot (use hash tags like `{user:42}:cart`).

**Likely follow-ups**
- *Why is Redis fast if it's single-threaded?* Everything is in memory, it uses an event loop with non-blocking I/O (epoll), there are no locks to contend on, and the data structures are tight. Redis 6+ also uses I/O threads for network reads and writes.
- *Redis as the primary database?* Only for data you can rebuild or afford to lose a second of, or with AOF `always` and replicas, accepting the cost. Usually it's a cache or coordination layer in front of a real database.
- *Cache stampede?* Single-flight (one rebuilder, enforced with a lock), jittered TTLs, early probabilistic refresh, and serving stale while revalidating.

**What a strong answer shows:** You pick data structures by problem, you write atomic patterns (pipelines, `NX`, Lua), and you know the operational traps: memory, persistence, hot keys, `KEYS`.

**Go deeper:** [[Redis]] (every data type with code, locks, rate limiting, streams) · [[03.5 - Redis Patterns]] · [[07.2 - Cache Strategies and Invalidation]] · [[07.3 - Stampede Hot Keys and Negative Caching]] · [[07.5 - Idempotency Keys and Deduplication]] · [[15.2 - Reading Redis Networking]]

**Resource:** [Redis docs — Data types](https://redis.io/docs/latest/develop/data-types/) and [redis-py asyncio examples](https://redis.readthedocs.io/en/stable/examples/asyncio_examples.html).

---

## Section D: Databases at Scale

### Q7. Your DB-backed API serves 10M requests/second and responses take 5 seconds. How do you optimize it?

**Answer (structure to say out loud)**

1. **Sanity-check the number.** 10M req/s is the scale of the largest internet services. No database serves that directly. If it's 10M/day (≈116/s), this is a query bug, not a scale problem. Ask about the read/write ratio, p50 vs p99, whether it "was always slow or got slow", and the staleness tolerance.
2. **Measure where the 5 s goes:** pool wait vs query execution vs serialization. Use `pg_stat_statements` sorted by **total** time, `pg_stat_activity` for lock and IO waits, and `EXPLAIN (ANALYZE, BUFFERS)` on the top queries.
3. **Fix the queries:** composite and covering indexes matching `WHERE` + `ORDER BY`, kill N+1s, select only the needed columns, keyset pagination, `ANALYZE` for stale stats, fix bloat and lock contention.
4. **Fix connections:** by **Little's law**, connections needed = throughput × query time. Slow queries exhaust the pool and the *queue* becomes the 5 seconds. Fix with PgBouncer in transaction mode, pools sized from the math, `statement_timeout`, and acquire timeouts.
5. **Take load off the DB:** CDN → in-process cache → Redis (cache-aside, jitter, single-flight) → read replicas → primary. Each layer absorbs most of what reaches it. Precompute with materialized views or denormalized read models.
6. **Writes:** batching, async via a queue, partition by time, avoid hot rows.
7. **Scale out last:** vertical first, then sharding by a key on every query (tenant or user ID), or move the workload to a purpose-built store.
8. **Protect:** timeouts, load shedding, circuit breakers, per-tenant rate limits, and a separate pool or replica for batch jobs.

**Code: the three things you'd actually run first**

```sql
-- 1. Which queries cost the most in total?
SELECT calls, round(total_exec_time) AS total_ms, round(mean_exec_time, 1) AS mean_ms,
       rows / NULLIF(calls, 0) AS rows_per_call, left(query, 100)
FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;

-- 2. What is waiting right now, and on what?
SELECT wait_event_type, wait_event, count(*) FROM pg_stat_activity
WHERE state <> 'idle' GROUP BY 1, 2 ORDER BY 3 DESC;

-- 3. Why is the top query slow?
EXPLAIN (ANALYZE, BUFFERS) SELECT ... ;
-- then typically:
CREATE INDEX CONCURRENTLY idx_orders_cust_created ON orders (customer_id, created_at DESC) INCLUDE (total, status);
```

**The caching arithmetic (the slide that answers "10M"):**

```
10M req/s → CDN 95% hit → 500k → in-process 80% → 100k → Redis 95% → 5k → 3 replicas ≈ 1.7k/s each
```

**Likely follow-ups**
- *Replicas or sharding?* Replicas scale reads only. All writes still hit one primary. Shard when writes or data size exceed one primary.
- *How do you keep the cache correct?* Invalidate after commit, short TTL as a safety net, versioned keys, CDC-driven invalidation for critical data.
- *What if the slowness is lock contention on one row (a counter)?* Move the counter to Redis `INCR` and flush periodically, or shard the counter across N rows and sum on read.

**What a strong answer shows:** You challenge the premise with arithmetic, measure before fixing, fix cheapest-first, and understand that the database's job at scale is to serve only cache misses.

**Go deeper:** [[06.18 - Fixing a Slow Database at Scale]] (the full playbook with code) · [[06.3 - Indexes Deep Dive]] · [[06.4 - Reading EXPLAIN ANALYZE]] · [[06.9 - Connection Pooling and PgBouncer]] · [[06.13 - Partitioning and Sharding]] · [[Assets.3 - Numbers To Know]] · [[02.3 - Estimation and Capacity]]

**Resource:** [Use The Index, Luke](https://use-the-index-luke.com/) for indexing, and [Figma's database scaling story](https://www.figma.com/blog/how-figmas-databases-team-lived-to-tell-the-scale/) for what the whole journey looks like for real.

---

### Q8. SQL or NoSQL? Replication or sharding? How do you choose a database?

**Answer**
- **Start from access patterns, not technology.** Write down the top 5 queries and the read/write ratio.
- **Default to relational (Postgres)** when you need transactions, constraints, joins and ad-hoc queries. It also does JSONB, full-text search, and vectors (pgvector) well enough for many products.
- **Choose NoSQL for a specific reason:**
  - **Key-value / wide-column** (DynamoDB, Cassandra): known access patterns, huge scale, predictable single-digit-ms latency, multi-region writes.
  - **Document** (MongoDB): nested, schema-varying data read as a whole.
  - **Search** (Elasticsearch): relevance-ranked text search and faceting.
  - **Time series** / **analytics** (ClickHouse): aggregations over billions of rows.
  - **Graph**: deep relationship traversal.
- **Replication** copies the same data for **read scale and availability**. **Sharding** splits data for **write scale and size.** They're complementary: each shard is usually replicated.

**Go deeper:** [[03.6 - Databases SQL and NoSQL]] · [[Assets.2 - DB Selection and Checklists]] · [[06.14 - Beyond Postgres]] · [[03.7 - Replication and Read Replicas]]

**Resource:** *Designing Data-Intensive Applications* (Kleppmann), chapters 2 (data models), 5 (replication) and 6 (partitioning).

---

## Section E: More System Design Questions, Mapped

These come up constantly. The answers already live in the vault, so drill from the note.

| Question | Answer lives in |
|---|---|
| How do you approach an HLD interview? | [[07.1 - How HLD Interviews Work]] · [[02.1 - Framework Overview]] |
| Back-of-envelope estimation (QPS, storage, bandwidth) | [[02.3 - Estimation and Capacity]] · [[Assets.1 - Estimation Cheatsheet]] |
| Design a rate limiter | [[04.1 - Rate Limiter]] · [[03.14 - Rate Limiters]] · [[11.5 - Rate Limiting and Quotas]] |
| Design a URL shortener | [[06.1 - URL Shortener]] |
| Design a news feed | [[06.2 - Social Feed]] |
| Design a chat system | [[06.3 - Chat System]] · [[WebSocket]] |
| Design a notification system | [[06.7 - Notification Platform]] · [[04.10 - Notification System]] |
| Design a payment system | [[06.6 - Payment Gateway]] |
| Consistent hashing | [[01.11 - Distributed Concepts]] · [[03.1 - Load Balancers]] |
| L4 vs L7 load balancing | [[03.1 - Load Balancers]] · [[03.10 - Proxies and Load Balancers]] |
| Idempotency and safe retries | [[03.4 - Idempotency and Safe Retries]] · [[07.5 - Idempotency Keys and Deduplication]] |
| Timeouts, retries, circuit breakers | [[11.2 - Timeouts Retries and Jitter]] · [[11.3 - Circuit Breakers and Bulkheads]] |
| CQRS and event sourcing | [[02.22 - CQRS]] · [[02.23 - Event Sourcing]] |
| Leader election and consensus | [[07.6 - Leader Election and Coordination]] · [[01.11 - Distributed Concepts]] |
| Communicating tradeoffs | [[07.3 - Communicating Tradeoffs]] · [[05.1 - Tradeoff Evaluation]] |

---

## Further reading
- [Martin Kleppmann — *Designing Data-Intensive Applications*](https://dataintensive.net/): the book behind most good answers in this file.
- [ByteByteGo — System Design 101](https://github.com/ByteByteGoHq/system-design-101): visual one-pagers for revising quickly.
- [The System Design Primer](https://github.com/donnemartin/system-design-primer): broad and free, good for filling gaps.
- [AWS Builders' Library](https://aws.amazon.com/builders-library/): how Amazon actually builds for availability, with essays on caching, retries, and shuffle sharding.

---

**Next:** [[06 - Design Principles and Patterns]]
