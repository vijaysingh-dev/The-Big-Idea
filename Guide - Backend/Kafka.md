# Kafka — Complete Guide

#backend #kafka #message-queue #distributed-systems #event-driven

> **Goal of this guide:** Understand Kafka from zero — what it is, why it exists, how it works internally, and how real production systems use it. With code.
> 
> 📖 **One resource to go deep:** [Confluent Kafka Tutorials](https://developer.confluent.io/courses/) — free, video + code, covers everything from basics to advanced internals. Start with "Apache Kafka Fundamentals."

---

## Table of Contents

1. [[#Why Kafka Exists — The Problem First]]
2. [[#What Kafka Actually Is]]
3. [[#Core Concepts (Build the Mental Model)]]
4. [[#How Kafka Works Internally]]
5. [[#Producers — Sending Messages]]
6. [[#Consumers — Reading Messages]]
7. [[#Consumer Groups — Scaling Reads]]
8. [[#Delivery Guarantees]]
9. [[#Topic Design — Where Teams Go Wrong]]
10. [[#Key Patterns in Production]]
11. [[#Kafka vs Redis Streams vs RabbitMQ]]
12. [[#Production Checklist]]

---

## Why Kafka Exists — The Problem First

Before Kafka, microservices talked to each other **directly** (HTTP calls):

```
Order Service ──HTTP──► Inventory Service
Order Service ──HTTP──► Email Service
Order Service ──HTTP──► Analytics Service
Order Service ──HTTP──► Billing Service
```

**Problems with direct calls:**

1. **Tight coupling:** Order Service must know the address of every other service. If Email Service goes down, the order might fail.
2. **No retry:** If Email Service is slow, Order Service waits. If Email Service crashes, the event is lost.
3. **No history:** You can't replay "what orders were placed last Tuesday" — the call happened and is gone.
4. **Backpressure:** If Analytics is slow, it can't tell Order Service to slow down — it just gets overwhelmed.

Kafka solves all of this with **one central idea: write events to a log, let consumers read at their own pace.**

```
Order Service ──► [Kafka: orders topic] ◄──── Inventory Service (reads when ready)
                                         ◄──── Email Service    (reads when ready)
                                         ◄──── Analytics        (reads when ready)
```

Order Service doesn't know or care who's reading. It just writes. Everyone else reads independently.

---

## What Kafka Actually Is

Kafka is a **distributed commit log** — not a message queue in the traditional sense.

The key difference:

|Traditional Queue (e.g., RabbitMQ)|Kafka|
|---|---|
|Message deleted after consumption|Message stays on disk for days/weeks|
|One consumer per message|Many consumers, each reads independently|
|No replay|Can re-read from any point in time|
|Push-based (broker pushes to consumer)|Pull-based (consumer pulls from broker)|
|For task distribution|For event streaming + audit log|

Think of Kafka like a **newspaper printing press:** it prints (publishes) the paper once. Millions of readers (consumers) each get their own copy and read at their own pace. Old papers are kept in the archive (retention) so late readers can catch up.

---

## Core Concepts (Build the Mental Model)

### Event / Message / Record

The atomic unit in Kafka. Every event has:

- **Key:** Optional. Used for partitioning and ordering (e.g., `user_id`, `order_id`)
- **Value:** The actual payload (usually JSON or Avro-encoded data)
- **Timestamp:** When the event occurred
- **Headers:** Optional metadata (e.g., source service name, correlation ID)

```json
{
  "key": "order_789",
  "value": {
    "event": "OrderPlaced",
    "user_id": "101",
    "amount": 2499,
    "items": ["item_42", "item_7"]
  },
  "timestamp": 1705123456789
}
```

---

### Topic

A **named category/feed** of events. Like a table in a database, but append-only (you can only add to the end, never update or delete a specific row).

```
Topic: "orders"
─────────────────────────────────────────────────────────►
  [order placed] [order shipped] [order cancelled] [order placed] ...
  offset: 0       offset: 1       offset: 2          offset: 3
```

**Offset:** A sequential number assigned to each event in a topic. Think of it as a line number in a file. Consumers track which offset they've read up to.

---

### Partition

Topics are split into **partitions** — physical files stored on disk. This is how Kafka scales.

```
Topic: "orders" with 3 partitions

Partition 0: [event] [event] [event] [event] ───►
Partition 1: [event] [event] [event]          ───►
Partition 2: [event] [event] [event] [event]  ───►
```

**Key rule:** Within a single partition, events are **strictly ordered**. Across partitions, there is **no ordering guarantee**.

**How is an event assigned to a partition?**

- If the event has a **key**: `partition = hash(key) % num_partitions`. Same key always goes to same partition.
- If no key: events are distributed round-robin across partitions.

> **Why does this matter?** If you key your events by `order_id`, all events for order #789 always go to Partition 0. This means a single consumer always processes all events for that order — giving you ordering per order. Without a key, `order.placed` and `order.cancelled` for the same order could go to different partitions and be processed out of order.

---

### Broker

A Kafka **broker** is a single Kafka server. In production, you run a **cluster** of 3+ brokers for redundancy. Each partition is stored on one broker, with copies (**replicas**) on others.

- **Leader replica:** The broker that handles all reads and writes for a partition
- **Follower replica:** Copies that stay in sync with the leader; take over if leader fails

```
Cluster of 3 Brokers:

Broker 1: Partition 0 (Leader), Partition 1 (Follower), Partition 2 (Follower)
Broker 2: Partition 0 (Follower), Partition 1 (Leader), Partition 2 (Follower)
Broker 3: Partition 0 (Follower), Partition 1 (Follower), Partition 2 (Leader)
```

If Broker 1 crashes, Partition 0's follower on Broker 2 becomes the new leader automatically.

---

### Retention

Kafka stores events on disk for a configurable period. **This is not a bug — it's a feature.**

```bash
# Keep events for 7 days (default)
retention.ms=604800000

# Or keep until the topic reaches 10 GB
retention.bytes=10737418240
```

After retention expires, old events are deleted. Within the retention window, **any consumer can re-read from any point** — reprocess old data, recover from bugs, onboard new services.

---

## How Kafka Works Internally

### Write Path

```
Producer
  │
  ▼
Leader Broker (for that partition)
  │  Writes to local log
  │
  ├──► Follower Broker 1 (copies the write)
  └──► Follower Broker 2 (copies the write)
  │
  ▼
Acknowledges to Producer (after N replicas confirm)
```

### ISR (In-Sync Replicas)

**ISR** = the set of replicas that are caught up to the leader. If a follower falls behind (e.g., slow network), it's removed from ISR.

The producer config `acks=all` means: "only tell me success after ALL ISR replicas have written it." This prevents data loss on leader failure.

### ZooKeeper / KRaft

Historically, Kafka used **ZooKeeper** (a separate coordination service) to manage cluster state — which broker is leader, which consumers are in which group, etc. This was operationally painful.

Since Kafka 3.x, Kafka uses **KRaft** (Kafka Raft) — its own built-in coordination. No more separate ZooKeeper cluster. If you see ZooKeeper in older tutorials, that's why.

---

## Producers — Sending Messages

### Basic Setup

```python
from confluent_kafka import Producer

producer = Producer({
    'bootstrap.servers': 'kafka-broker-1:9092,kafka-broker-2:9092',

    # acks = acknowledgement mode:
    # '0' = fire and forget (fastest, can lose messages)
    # '1' = wait for leader to write (middle ground)
    # 'all' = wait for ALL in-sync replicas (safest, slowest)
    'acks': 'all',

    # Idempotence = if Kafka gets the same message twice (due to retry),
    # it de-duplicates and stores it only once. Prevents duplicates on producer retry.
    'enable.idempotence': True,

    'retries': 10,
    'retry.backoff.ms': 200,

    # Snappy compression — reduces network and disk usage
    'compression.type': 'snappy',
})
```

### Sending Messages

```python
# Delivery callback — called when Kafka confirms (or rejects) the message
def on_delivery(err, msg):
    if err:
        # Message was NOT stored — handle this! Alert, retry, write to DB.
        print(f"Delivery FAILED: {err}")
    else:
        print(f"Delivered to {msg.topic()} partition {msg.partition()} offset {msg.offset()}")

# Produce a message
# key= ensures all events for this order go to the same partition (ordering)
producer.produce(
    topic='orders',
    key='order_789',
    value=json.dumps({
        "event": "OrderPlaced",
        "order_id": "789",
        "amount": 2499
    }),
    callback=on_delivery
)

# poll() triggers delivery callbacks. Call it periodically.
# Doesn't block — just processes any pending callbacks.
producer.poll(0)

# At end of batch or program: flush() waits until all messages are delivered
producer.flush()
```

### Batching

Kafka producers don't send one message at a time — they batch messages before sending. Two configs control this:

```python
{
    # Wait up to 10ms to accumulate messages before sending a batch
    # Higher = better throughput, higher latency
    'linger.ms': 10,

    # Maximum batch size in bytes
    # Producer sends when batch is full OR linger.ms expires, whichever comes first
    'batch.size': 65536,   # 64 KB
}
```

---

## Consumers — Reading Messages

### Basic Setup

```python
from confluent_kafka import Consumer

consumer = Consumer({
    'bootstrap.servers': 'kafka-broker-1:9092',

    # group.id: identifies which consumer group this belongs to.
    # All consumers with the same group.id share the work (each reads different partitions).
    'group.id': 'order-processor-v1',

    # auto.offset.reset: what to do when a new consumer group starts
    # 'earliest' = read from the very beginning of the topic
    # 'latest'   = only read new messages from now
    'auto.offset.reset': 'earliest',

    # CRITICAL: Never use auto-commit in production.
    # Auto-commit advances the offset on a timer, not after successful processing.
    # A crash between auto-commit and actual processing = silently lost message.
    'enable.auto.commit': False,
})

consumer.subscribe(['orders'])
```

### Processing Loop

```python
while True:
    # poll() fetches the next batch of messages
    # timeout=1.0 = wait up to 1 second if no messages available
    msg = consumer.poll(timeout=1.0)

    if msg is None:
        continue  # No message yet, loop again

    if msg.error():
        print(f"Consumer error: {msg.error()}")
        continue

    # Process the message
    event = json.loads(msg.value().decode('utf-8'))

    try:
        process_order(event)

        # Manually commit offset AFTER successful processing.
        # This tells Kafka: "I've processed up to this point."
        # On restart, consumer resumes from here.
        consumer.commit(message=msg, asynchronous=False)

    except Exception as e:
        # Don't commit — Kafka will re-deliver this message on restart.
        # But if it keeps failing, it blocks the entire partition!
        # Solution: Dead Letter Topic (see below)
        print(f"Processing failed: {e}")
        send_to_dead_letter_topic(msg)
        consumer.commit(message=msg, asynchronous=False)  # Commit to unblock

consumer.close()  # Cleanly leave the consumer group on shutdown
```

### Dead Letter Topic (DLT)

**DLT** = a separate topic where messages that repeatedly fail to process are sent. Prevents one bad message from blocking all others.

```
Normal flow:    [orders topic] ──► consumer ──► process ──► ✅ commit
Failure flow:   [orders topic] ──► consumer ──► process fails 3 times
                                                    │
                                                    ▼
                                            [orders.DLT topic]   ← alert team
```

```python
async def handle_with_retry(msg, max_retries=3):
    retry_count = int(msg.headers().get('retry_count', 0))

    try:
        await process(json.loads(msg.value()))
        consumer.commit(message=msg)
    except Exception as e:
        if retry_count >= max_retries:
            # Give up — send to DLT for manual inspection
            producer.produce(
                topic=f"{msg.topic()}.DLT",
                key=msg.key(),
                value=msg.value(),
                headers={'error': str(e), 'original_topic': msg.topic()}
            )
            consumer.commit(message=msg)  # Commit so we move on
        else:
            # Retry: produce back to original topic with incremented retry count
            producer.produce(
                topic=msg.topic(),
                key=msg.key(),
                value=msg.value(),
                headers={'retry_count': str(retry_count + 1)}
            )
            consumer.commit(message=msg)
```

---

## Consumer Groups — Scaling Reads

This is one of Kafka's most important features.

### How It Works

A **consumer group** is a set of consumers that cooperate to read a topic. Kafka assigns each partition to exactly one consumer in the group. No two consumers in the same group read the same partition simultaneously.

```
Topic "orders" with 4 partitions:

Consumer Group "order-processors" with 2 consumers:
  Consumer A reads: Partition 0, Partition 1
  Consumer B reads: Partition 2, Partition 3

Consumer Group "analytics" with 1 consumer:
  Consumer C reads: ALL 4 partitions  (independent from the first group)
```

> **Key insight:** Different consumer groups are completely independent. Adding a new service (new consumer group) doesn't affect existing services — they all read from the same topic at their own pace.

### Scaling

```
Add more consumers → each gets fewer partitions → higher throughput

But: max useful consumers = number of partitions.
     A 4-partition topic with 5 consumers → 1 consumer sits idle.

So: partition count = your max parallelism ceiling.
    Plan this upfront — increasing partitions is possible but complex.
```

### Rebalancing

**Rebalance:** When the consumer group membership changes (consumer added, removed, crashed), Kafka redistributes partitions among the remaining consumers.

**Rebalance triggers:**

- New consumer joins the group
- Consumer crashes or times out
- Consumer takes too long processing a message (`max.poll.interval.ms` exceeded)
- Rolling deployment of your service

**During rebalance, ALL consumers in the group pause briefly.** This is called **stop-the-world rebalancing** and is a significant latency spike in production. Modern Kafka (2.4+) has incremental cooperative rebalancing which reduces this pause.

```python
from confluent_kafka import ConsumerRebalanceListener

class MyRebalanceListener(ConsumerRebalanceListener):

    def on_partitions_revoked(self, revoked_partitions):
        # Called BEFORE partitions are taken away from this consumer.
        # Commit current offsets so the new owner doesn't re-process.
        print(f"Partitions being taken: {revoked_partitions}")
        consumer.commit(asynchronous=False)   # Synchronous = wait for confirmation

    def on_partitions_assigned(self, assigned_partitions):
        print(f"Partitions given: {assigned_partitions}")

consumer.subscribe(['orders'], on_assign=MyRebalanceListener().on_partitions_assigned,
                                on_revoke=MyRebalanceListener().on_partitions_revoked)
```

---

## Delivery Guarantees

Kafka offers three levels of guarantee, controlled by producer AND consumer settings together:

### At-most-once (can lose messages, never duplicates)

```python
# Producer: fire and forget
producer.produce(topic, value)
# No callback check, no retry

# Consumer: commit before processing
consumer.commit(message=msg)   # Commit first
process(msg)                    # Then process — if crash here, message is lost
```

### At-least-once (no loss, but may get duplicates)

```python
# Producer: acks=all + retries
{'acks': 'all', 'retries': 10}

# Consumer: commit after processing
process(msg)                    # Process first
consumer.commit(message=msg)   # Then commit — if crash here, message replayed
```

> This is the **right default** for most systems. Your consumer must be **idempotent** — processing the same message twice should produce the same result as processing it once.

### Exactly-once (no loss, no duplicates — most complex)

```python
# Requires: idempotent producer + transactional API + transactional consumer
producer = Producer({'enable.idempotence': True, 'transactional.id': 'my-producer-1'})
producer.init_transactions()

producer.begin_transaction()
producer.produce(topic, value)
producer.send_offsets_to_transaction(offsets, consumer_group)
producer.commit_transaction()   # Atomic: produce + offset commit happen together or neither does
```

Exactly-once is expensive (latency + complexity). Use it only for financial transactions where duplicates cause real harm.

---

## Topic Design — Where Teams Go Wrong

### Bad: One topic per event type

```
user.created
user.updated
user.deleted
order.placed
order.shipped
order.cancelled
payment.processed
payment.failed
```

Problems: too many topics to manage, can't guarantee ordering across related events easily.

### Good: One topic per aggregate (business entity)

```
users           → all user lifecycle events, keyed by user_id
orders          → all order events, keyed by order_id
payments        → all payment events, keyed by payment_id
```

Keying by entity ID guarantees all events for that entity land in the same partition → same consumer → strict ordering per entity.

### Naming Convention

```
{environment}.{domain}.{entity}.{version}

prod.commerce.orders.v1
prod.commerce.payments.v1
prod.notifications.emails.v1
staging.commerce.orders.v1
```

Version topics when you change the schema. Old consumers can keep reading `v1` while new ones migrate to `v2`.

### Partition Count Guidelines

|Messages/day|Recommended partitions|
|---|---|
|< 1 million|3 (minimum for redundancy)|
|1M – 10M|6–12|
|10M – 100M|12–30|
|100M+|30+|

Start with more than you think you need — you can increase partitions but the rebalancing is painful and ordering guarantees break for existing keys.

---

## Key Patterns in Production

### 1. Event Sourcing

Instead of storing the current state of an entity, store every event that changed it. Reconstruct current state by replaying events.

```
Instead of:  users table: {id: 101, balance: 1500}

Store:
  [UserCreated:  {id: 101, initial_balance: 2000}]
  [MoneySpent:   {id: 101, amount: 300}]
  [MoneyEarned:  {id: 101, amount: 100}]
  [MoneySpent:   {id: 101, amount: 300}]

Replay → 2000 - 300 + 100 - 300 = 1500 ✓
```

Benefit: Full audit log. Can reconstruct state at any point in time. Can replay to fix bugs.

### 2. CQRS (Command Query Responsibility Segregation)

**CQRS** = separate models for writing data (commands) and reading data (queries). Kafka is the bridge.

```
Write path: API ──► Order Service ──► Kafka ──► events
Read path:  Kafka ──► Read Model Builder ──► ElasticSearch/Redis ──► fast queries
```

The read model can be a completely different database optimized for reads (Elasticsearch, Redis, DynamoDB). When you want to change your read model, just replay Kafka events into the new model.

### 3. The Outbox Pattern — Solving the Dual Write Problem

**The problem:** You need to write to your DB AND publish to Kafka. What if one fails?

```python
# WRONG — these two operations are not atomic:
await db.save_order(order)          # succeeds
await kafka.publish("orders", order) # network timeout → event lost, DB has orphaned order
```

**The Outbox Pattern solution:**

```python
# CORRECT — write event to DB table in the SAME transaction as the business data
async def place_order(order_data):
    async with db.transaction():
        order = await db.save_order(order_data)

        # Outbox table is in the same DB as your business data.
        # If the transaction rolls back, the outbox entry also rolls back.
        await db.execute("""
            INSERT INTO outbox (aggregate_id, event_type, payload, published)
            VALUES ($1, $2, $3, false)
        """, order.id, 'OrderPlaced', json.dumps(order_data))

    # Transaction committed. A separate process reads outbox and publishes to Kafka.
```

```python
# Outbox relay — runs as a separate background job or sidecar service
async def outbox_relay():
    while True:
        events = await db.fetch("SELECT * FROM outbox WHERE published = false LIMIT 100")
        for event in events:
            producer.produce(topic='orders', key=str(event.aggregate_id), value=event.payload)
        producer.flush()
        await db.execute("UPDATE outbox SET published = true WHERE id = ANY($1)",
                          [e.id for e in events])
        await asyncio.sleep(0.5)
```

> In mature systems, replace the polling relay with **Debezium** — a tool that reads the DB's change log (WAL in PostgreSQL) directly and publishes to Kafka. Near-zero latency, no polling overhead.

### 4. Saga Pattern — Distributed Transactions

**Problem:** A business operation spans multiple services (order → payment → inventory → shipping). How do you ensure all or none succeed without a distributed transaction (which Kafka doesn't support)?

**Saga:** Break the operation into a sequence of local transactions. Each step publishes an event. If any step fails, it publishes a **compensating event** to undo previous steps.

```
1. Order Service:      OrderPlaced event       ──►  payment topic
2. Payment Service:    PaymentProcessed event  ──►  inventory topic
3. Inventory Service:  ItemsReserved event     ──►  shipping topic
4. Shipping Service:   ShipmentScheduled event ──►  order topic (saga complete)

Failure at step 3 (item out of stock):
3. Inventory Service:  InsufficientStock event  ──►  payment topic (compensate)
   Payment Service:    RefundProcessed event    ──►  order topic   (compensate)
   Order Service:      OrderCancelled event     (saga rolled back)
```

### 5. Stream Processing with Kafka Streams

Kafka Streams is a library (part of Kafka) that lets you process and transform events in real-time — filter, aggregate, join streams, detect patterns.

```python
# Conceptual — Kafka Streams is Java-native; use Faust for Python
import faust

app = faust.App('order-analytics', broker='kafka://localhost:9092')

orders_topic = app.topic('orders', value_type=dict)
high_value_topic = app.topic('high_value_orders', value_type=dict)

# Stream processor: filter orders above ₹10,000 into a separate topic
@app.agent(orders_topic)
async def filter_high_value(orders):
    async for order in orders:
        if order['amount'] > 10000:
            await high_value_topic.send(value=order)
```

---

## Kafka vs Redis Streams vs RabbitMQ

|Feature|Kafka|Redis Streams|RabbitMQ|
|---|---|---|---|
|**Throughput**|Millions/sec|Hundreds of thousands/sec|Tens of thousands/sec|
|**Retention**|Days/weeks on disk|Configurable, in-memory|Until consumed|
|**Replay**|✅ Any point in time|✅ Limited by memory|❌|
|**Consumer groups**|✅|✅|✅|
|**Ordering**|Per partition|Per stream|Per queue|
|**Operational complexity**|High|Low (piggybacks Redis)|Medium|
|**Use when**|High volume, audit log, multi-team|Low volume, already using Redis|Simple task queue, routing logic|

**Rule of thumb:**

- Already using Redis, volume < 1M events/day → **Redis Streams**
- Need high throughput, replay, multi-team event sharing → **Kafka**
- Simple background job queue, complex routing → **RabbitMQ** or **Celery**

---

## Production Checklist

|Item|Why|
|---|---|
|Set `enable.auto.commit=False`|Auto-commit loses messages on crash|
|Implement `RebalanceListener` and commit on revoke|Prevents duplicates after rebalance|
|Make consumers idempotent|At-least-once delivery = you WILL get duplicates|
|Implement Dead Letter Topic|One bad message shouldn't block the entire partition|
|Key messages by entity ID|Guarantees ordering per entity|
|Monitor **consumer group lag**|Lag = how far behind consumers are. Your #1 health metric.|
|Set retention to 7+ days|Enables replay for recovery and new service onboarding|
|Don't delete topics in production|Topics have data. Deleting is permanent.|
|Version consumer group IDs|`order-processor-v2` when changing processing logic|
|Use schema registry (Avro/Protobuf)|Prevents schema changes from breaking consumers silently|

### Consumer Lag Explained

**Consumer lag** = the difference between the latest offset in a partition and the last offset your consumer committed.

```
Latest offset in topic:     1000
Your consumer's committed:   850
Lag:                         150 messages

Lag = 0 → consumer is caught up
Lag growing → consumer is falling behind (processing too slow)
Sudden lag spike → consumer crashed or rebalancing
```

Monitor with:

```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group order-processors
```

---

## Quick Reference — Core Kafka Concepts

```
Event        → the message you send (key + value + timestamp)
Topic        → named category of events (like a table, but append-only)
Partition    → a topic is split into partitions for parallelism
Offset       → sequential ID of an event within a partition
Broker       → a Kafka server; you run 3+ in a cluster
Producer     → sends events to topics
Consumer     → reads events from topics
Consumer Group → a set of consumers sharing the work of reading a topic
Rebalance    → redistribution of partitions when consumer group changes
ISR          → In-Sync Replicas: copies of a partition that are fully up-to-date
DLT          → Dead Letter Topic: where failed messages go for inspection
Lag          → how far behind a consumer is from the latest events
Retention    → how long Kafka keeps events before deleting them
Outbox       → pattern to atomically write to DB and publish to Kafka
Saga         → pattern for distributed transactions across microservices
```

---

_See also: [[Redis - Complete Guide]]_