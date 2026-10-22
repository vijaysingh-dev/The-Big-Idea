# Redis — Complete Guide

#backend #redis #cache #distributed-systems

> **Goal of this guide:** Take you from "I know Redis is a cache" to understanding every major Redis pattern used in real production systems — with code, mental models, and the _why_ behind each decision.
> 
> 📖 **One resource to go deep:** [Redis University — RU101 (Free)](https://university.redis.com/courses/ru101/) — official, hands-on, goes from basics to advanced data structures.

---

## Table of Contents

1. [[#What Redis Actually Is]]
2. [[#How Redis Works Internally]]
3. [[#Data Types — The Real Redis]]
4. [[#Pipelining]]
5. [[#Caching Patterns]]
6. [[#Distributed Locks]]
7. [[#Rate Limiting]]
8. [[#Pub/Sub vs Streams]]
9. [[#Redis in Microservices]]
10. [[#Production Checklist]]

---

## What Redis Actually Is

Redis stands for **Re**mote **Di**ctionary **S**erver. At its core, it's an **in-memory key-value store** — meaning all data lives in RAM, not on disk. This makes it extremely fast (sub-millisecond reads/writes).

But Redis is much more than a cache. Think of it as a Swiss Army knife:

|Role|What it means|
|---|---|
|Cache|Store expensive DB results temporarily|
|Distributed Lock|Coordinate between multiple servers|
|Rate Limiter|Count requests per user per second|
|Message Broker|Pass events between services|
|Session Store|Store user login sessions|
|Leaderboard|Sorted rankings in real-time|

---

## How Redis Works Internally

### Single-threaded Event Loop

Redis processes **one command at a time** on a single thread. This sounds like a weakness — it's actually a strength. Because there's no concurrency inside Redis, you never have race conditions within Redis itself. Commands are always atomic (indivisible — either the whole command runs or none of it does).

```
Client A: SET x 10  ─────┐
Client B: SET x 20  ──────┤──► Redis Queue ──► Execute one by one
Client C: GET x     ─────┘
```

> **Implication:** A slow command (like scanning 1 million keys) blocks ALL other clients. This is why certain commands like `KEYS *` are banned in production.

### Persistence (How data survives restarts)

Redis is in-memory, but it optionally saves to disk:

- **RDB (Redis Database Backup):** Takes a snapshot of all data every N seconds. Fast to restore, but you lose changes since the last snapshot.
- **AOF (Append Only File):** Logs every write command. Slower, but near-zero data loss.
- **No persistence:** Pure cache mode. Fastest. Data gone on restart.

For a cache, no persistence is fine. For a distributed lock or rate limiter, you need at least AOF.

### Memory and Eviction

When Redis runs out of memory, it needs to delete something. You configure the **eviction policy**:

|Policy|Behaviour|
|---|---|
|`noeviction`|Reject new writes. Safe but your app breaks.|
|`allkeys-lru`|Delete the least recently used key. Best for caches.|
|`volatile-lru`|Delete LRU key, but only among keys that have a TTL set.|
|`allkeys-random`|Delete a random key. Rarely useful.|

```bash
# Set in redis.conf or at runtime
CONFIG SET maxmemory 2gb
CONFIG SET maxmemory-policy allkeys-lru
```

---

## Data Types — The Real Redis

This is where most tutorials fail you. Redis has 8+ data types and each solves a different problem. Picking the wrong one is like using a hammer to cut wood.

### 1. String

The simplest type. A key maps to a single value. The value can be text, numbers, or binary (images, serialized objects).

```python
# Basic set/get
redis.set("username:101", "vijay")
redis.get("username:101")           # "vijay"

# Set with expiry (TTL = Time To Live — how long before Redis auto-deletes the key)
redis.setex("session:abc", 3600, "user_data_json")  # expires in 1 hour

# Atomic increment — useful for counters, no race conditions
redis.set("page_views", 0)
redis.incr("page_views")            # 1
redis.incrby("page_views", 5)       # 6
```

> **NX flag:** `SET key value NX` means "only set if the key does NOT exist." This is the foundation of distributed locks — only one process can win the race to create the key.

---

### 2. Hash

A key maps to a **mini dictionary** (field → value pairs). Think of it as a row in a database table.

```python
# Store a user object — each field is stored separately
redis.hset("user:101", mapping={
    "name": "Vijay",
    "email": "vijay@example.com",
    "age": "26"
})

# Get one field (cheaper than fetching the whole object)
redis.hget("user:101", "name")          # "Vijay"

# Get all fields
redis.hgetall("user:101")               # {"name": "Vijay", "email": "...", "age": "26"}

# Increment a numeric field atomically
redis.hincrby("user:101", "login_count", 1)
```

**When to use Hash vs String:**

- Use **String** when you always fetch the whole object (serialize to JSON)
- Use **Hash** when you frequently update/read individual fields (avoids deserializing the whole object)

---

### 3. List

An ordered sequence of strings. Elements are added/removed from the **head or tail**. Think of it as a deque (double-ended queue).

```python
# RPUSH = push to Right (tail), LPUSH = push to Left (head)
redis.rpush("job_queue", "job1", "job2", "job3")

# LPOP = pop from Left (head) — FIFO queue behaviour
redis.lpop("job_queue")                 # "job1"

# Blocking pop — waits up to 10 seconds for an item if queue is empty
# Used in worker processes so they don't spin in a busy loop
redis.blpop("job_queue", timeout=10)

# Get elements by range (0 = first, -1 = last)
redis.lrange("job_queue", 0, -1)        # All items
```

**Common use case:** Simple task queues where order matters and you don't need acknowledgement (i.e., you don't need to confirm the job was processed before removing it).

---

### 4. Set

An **unordered collection of unique strings**. Duplicates are automatically ignored.

```python
# SADD = Set ADD
redis.sadd("online_users", "vijay", "rahul", "priya")
redis.sadd("online_users", "vijay")     # Ignored — already exists

# Check membership — O(1) time (instant, regardless of set size)
redis.sismember("online_users", "vijay")    # True

# Set operations — very powerful
redis.sunion("premium_users", "trial_users")        # All users in either set
redis.sinter("india_users", "premium_users")        # Users in BOTH sets
redis.sdiff("all_users", "banned_users")            # Users NOT in banned set

redis.scard("online_users")             # Count of members
```

**When to use:** Tags, unique visitors, permission groups, "who liked this post."

---

### 5. Sorted Set (ZSet) — The Most Powerful Type

A sorted set is like a Set, but every member has a **score** (a floating-point number). Redis keeps members **sorted by score at all times**, automatically.

This is what powers leaderboards, priority queues, rate limiters, and time-series indexes.

```python
# ZADD = Sorted set ADD (key, score, member)
redis.zadd("leaderboard", {"vijay": 1500, "rahul": 2300, "priya": 1800})

# Get rank (0-indexed, lowest score first)
redis.zrank("leaderboard", "vijay")         # 0 (lowest score)

# ZREVRANK = rank from highest score
redis.zrevrank("leaderboard", "rahul")      # 0 (highest score)

# Get top 3 (highest scores) with their scores
redis.zrevrange("leaderboard", 0, 2, withscores=True)
# [("rahul", 2300), ("priya", 1800), ("vijay", 1500)]

# ZRANGEBYSCORE = get members with score in a range
redis.zrangebyscore("leaderboard", 1600, 2500)
# ["priya", "rahul"]

# Remove members with score below a value
redis.zremrangebyscore("inactive_sessions", 0, time.time() - 3600)

# ZCARD = count of members
redis.zcard("leaderboard")              # 3
```

**Why ZSet is special:** The score can be a timestamp. Store `(user_id, timestamp)` and you instantly have a time-ordered index you can query by time range. This is how rate limiters work (see below).

---

### 6. Bitmap

Not a separate data type — it's a String where Redis lets you operate on individual **bits**. 1 bit per user = ultra-compact storage.

```python
# Mark user 1001 as having logged in today
redis.setbit("daily_active:2024-01-15", 1001, 1)

# Check if user logged in
redis.getbit("daily_active:2024-01-15", 1001)   # 1 (yes) or 0 (no)

# Count all active users today — single O(n) operation
redis.bitcount("daily_active:2024-01-15")
```

10 million users = 10 million bits = **1.25 MB**. A database query for the same would be gigabytes.

---

### 7. HyperLogLog

A probabilistic data structure (uses math/statistics internally, not exact counting) that estimates the **count of unique items** using very little memory — fixed at 12 KB regardless of input size. Has ~0.81% error rate.

```python
# Track unique page visitors
redis.pfadd("visitors:page_home", "user_a", "user_b", "user_c")
redis.pfadd("visitors:page_home", "user_a")     # Duplicate ignored

# Approximate count
redis.pfcount("visitors:page_home")             # ~3

# Merge multiple HyperLogLogs
redis.pfmerge("visitors:all", "visitors:page_home", "visitors:page_about")
```

Use when you need "how many unique X" and a small error margin is acceptable. Never use when you need exact counts or need to retrieve the actual items.

---

## Pipelining

By default, every Redis command is a **round trip**:

```
Your App ──► [NETWORK] ──► Redis ──► [NETWORK] ──► Your App
```

If you need to run 100 commands, that's 100 round trips. On a network with 1ms latency, that's 100ms just in transit.

**Pipeline** batches multiple commands into one network round trip:

```python
# Without pipeline — 3 network round trips
redis.set("a", 1)
redis.set("b", 2)
redis.set("c", 3)

# With pipeline — 1 network round trip, all 3 commands sent together
pipe = redis.pipeline()
pipe.set("a", 1)
pipe.set("b", 2)
pipe.set("c", 3)
results = pipe.execute()    # ["OK", "OK", "OK"]
```

**Important distinctions:**

||Pipeline|Transaction (MULTI/EXEC)|
|---|---|---|
|Atomic?|❌ No — commands can interleave with other clients|✅ Yes — all run as one unit|
|Rollback on error?|❌ No|❌ No (Redis transactions don't roll back)|
|Use case|Bulk reads/writes for speed|Atomic multi-step operations|

```python
# Transaction — all commands run atomically, no other client can interleave
pipe = redis.pipeline(transaction=True)
pipe.multi()
pipe.decr("inventory:item_42")
pipe.incr("sold:item_42")
pipe.execute()
```

> **Note:** Redis transactions don't support rollback on logic errors (only syntax errors). If `decr` runs and then `incr` fails (for a non-syntax reason), the decrement is NOT undone. For true rollback, use **Lua scripts** (which are also atomic).

---

## Caching Patterns

### Cache-Aside (Lazy Loading)

The app checks the cache first. On a miss, it fetches from DB and populates the cache.

```
Read:  Check Redis → Miss → Read DB → Write to Redis → Return
Write: Write to DB → Delete from Redis (invalidate)
```

```python
async def get_user(user_id: str):
    cache_key = f"user:{user_id}"

    # Check cache first
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # Cache miss — fetch from DB, then populate cache
    user = await db.fetch_user(user_id)
    await redis.setex(cache_key, ttl=3600, value=json.dumps(user))
    return user

async def update_user(user_id: str, data: dict):
    await db.update_user(user_id, data)
    # Invalidate (delete) the stale cache entry rather than updating it
    # Updating is risky under concurrent writes; deletion is always safe
    await redis.delete(f"user:{user_id}")
```

**Thundering herd problem:** When a popular cache key expires, hundreds of requests all miss simultaneously and all hit the DB at once. Solution: use a **distributed lock** during cache rebuild so only one process fetches from DB, others wait.

```python
async def get_user_safe(user_id: str):
    cache_key = f"user:{user_id}"
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # Only one process rebuilds the cache — others wait behind the lock
    async with redis.lock(f"lock:{cache_key}", timeout=5):
        # Re-check after acquiring lock — the first process may have already populated it
        cached = await redis.get(cache_key)
        if cached:
            return json.loads(cached)

        user = await db.fetch_user(user_id)
        await redis.setex(cache_key, 3600, json.dumps(user))
        return user
```

### Write-Through

Every write goes to cache AND DB simultaneously. No stale data. Higher write cost.

```python
async def update_user(user_id: str, data: dict):
    async with db.transaction():
        user = await db.update_user(user_id, data)
        # Write to cache inside the DB transaction.
        # If DB rolls back, the cache write is also abandoned.
        await redis.setex(f"user:{user_id}", 3600, json.dumps(user))
    return user
```

### TTL Strategy

Always set a TTL (expiry time). A key without TTL lives forever, fills memory, and serves stale data.

```python
# Short TTL for frequently changing data
redis.setex("stock_price:INFY", 5, price)       # 5 seconds

# Medium TTL for user profiles
redis.setex("user:101", 3600, user_json)        # 1 hour

# Long TTL for static reference data
redis.setex("countries_list", 86400, data)      # 24 hours
```

---

## Distributed Locks

### The Problem

Imagine two servers both trying to process the same order simultaneously:

```
Server A: reads order → status is "pending" → starts processing
Server B: reads order → status is "pending" → starts processing   ← same order!
Server A: charges customer ₹500
Server B: charges customer ₹500   ← double charge!
```

A distributed lock ensures only **one process at a time** can work on a resource, across multiple servers.

### SPOF and Redlock (Terms Explained)

- **SPOF (Single Point of Failure):** A component whose failure brings down the entire system. If you use one Redis instance for locks and that instance crashes, all locking breaks.
- **Redlock:** An algorithm by Redis's creator that uses **5 Redis instances** to avoid SPOF. A lock is considered acquired only if you get it on 3 out of 5 instances. More complex to operate. Most teams skip it and accept one Redis instance as a calculated risk.
- **Split-brain:** A situation where a network partition (network cut between servers) causes two nodes to both think they are the primary/leader, leading to conflicting decisions. In locking: two processes both think they hold the lock simultaneously.

### Implementation

```python
import uuid

async def process_order(order_id: str):
    lock_key = f"order:lock:{order_id}"
    # Unique token so we only release OUR lock, not someone else's
    # (if our lock expired and another process acquired it)
    lock_token = str(uuid.uuid4())

    # NX = only set if Not eXists (atomic — only one process wins this race)
    # EX = expire after 30 seconds (auto-release if process crashes)
    acquired = await redis.set(lock_key, lock_token, nx=True, ex=30)
    if not acquired:
        raise Exception("Order already being processed by another server")

    try:
        await _do_process_order(order_id)
    finally:
        # Must release lock when done.
        # Lua script = atomic check-then-delete.
        # Without atomicity: our lock expires → another process acquires it →
        # we wake up and accidentally delete THEIR lock.
        lua_script = """
        if redis.call('get', KEYS[1]) == ARGV[1] then
            return redis.call('del', KEYS[1])
        else
            return 0
        end
        """
        await redis.eval(lua_script, 1, lock_key, lock_token)
```

**What is a Lua script here?** Redis can run Lua scripts (a lightweight scripting language) atomically — the entire script runs as one uninterruptible unit. Here we use it to "check if the token matches, then delete" as a single atomic operation.

---

## Rate Limiting

### Fixed Window (Simple but flawed)

```python
async def is_rate_limited_fixed(user_id: str, limit: int = 100) -> bool:
    key = f"rate:fixed:{user_id}:{int(time.time() // 60)}"  # New key every minute
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, 60)     # Set TTL only on first request
    return count > limit
```

**Problem:** A user can make 100 requests at 00:59 and 100 more at 01:01 — 200 requests in 2 seconds, even though the limit is 100/minute.

### Sliding Window (Production-grade)

Uses a **Sorted Set** where the score is the timestamp of each request. We keep only requests within the last 60 seconds.

```python
async def is_rate_limited(user_id: str, limit: int = 100, window_sec: int = 60) -> bool:
    now = time.time()
    window_start = now - window_sec
    key = f"rate:{user_id}"

    pipe = redis.pipeline()
    # Remove all requests older than the window (score < window_start)
    pipe.zremrangebyscore(key, 0, window_start)
    # Add this request with current timestamp as score
    pipe.zadd(key, {str(now): now})
    # Count how many requests exist in the window
    pipe.zcard(key)
    # Reset TTL so the key auto-deletes when the user goes quiet
    pipe.expire(key, window_sec)
    results = await pipe.execute()

    request_count = results[2]  # zcard result
    return request_count > limit
```

**Why sorted set?** Because `zremrangebyscore` lets you instantly delete all items outside the time window, and `zcard` counts the remaining ones — both O(log N) operations.

---

## Pub/Sub vs Streams

### Pub/Sub

Publisher sends a message to a **channel**. All current subscribers receive it. Messages are not stored — if no one is listening, the message is gone.

```python
# Publisher
await redis.publish("notifications", json.dumps({"user": "vijay", "msg": "Order shipped"}))

# Subscriber (runs in a loop, listening)
pubsub = redis.pubsub()
await pubsub.subscribe("notifications")
async for message in pubsub.listen():
    if message["type"] == "message":
        data = json.loads(message["data"])
        print(data)
```

**Limitation:** Fire-and-forget. If your subscriber crashes and restarts, it misses all messages sent during downtime. No replay, no acknowledgement.

### Redis Streams

Streams are like a **persistent log** of messages. Each message gets an ID. Consumers can read from any point, and can acknowledge processing. Much closer to Kafka (covered in the Kafka guide).

```python
# Producer: append a message to the stream
# '*' = auto-generate ID (timestamp-based)
await redis.xadd("orders_stream", {"order_id": "123", "status": "placed"})

# Consumer Group setup
# A consumer group lets multiple workers share the work without duplicate processing
await redis.xgroup_create("orders_stream", "order_processors", id="0", mkstream=True)

# Worker: read messages assigned to this consumer
messages = await redis.xreadgroup(
    "order_processors",     # group name
    "worker_1",             # this worker's name (for tracking)
    {"orders_stream": ">"},  # ">" means only new, undelivered messages
    count=10,
    block=2000              # wait up to 2 seconds if queue is empty
)

for stream_name, entries in messages:
    for msg_id, data in entries:
        await process(data)
        # ACK = acknowledge. Tells Redis this message was processed successfully.
        # Until ACK'd, the message stays in a "pending" list for recovery.
        await redis.xack("orders_stream", "order_processors", msg_id)
```

### When to use what

|Need|Use|
|---|---|
|Broadcast notifications (real-time, loss ok)|Pub/Sub|
|Task queue with retries and acknowledgement|Streams|
|High volume, multi-team, long retention|Kafka|

---

## Redis in Microservices

### Session Storage

Instead of storing sessions in your DB (slow) or in-memory per server (breaks with multiple servers), store in Redis — fast and shared across all servers.

```python
# On login
session_id = str(uuid.uuid4())
await redis.setex(f"session:{session_id}", 86400, json.dumps({
    "user_id": user.id,
    "role": user.role,
    "login_at": datetime.utcnow().isoformat()
}))

# On every request
session_data = await redis.get(f"session:{request.session_id}")
if not session_data:
    raise UnauthorizedException()
```

### Idempotency Keys

**Idempotency:** If the same operation is performed multiple times, the result should be the same as if it was done once. Critical for payment APIs — a network timeout might cause a retry, and you don't want to charge twice.

```python
async def charge_user(payment_id: str, amount: float):
    idempotency_key = f"payment:done:{payment_id}"

    # NX = only set if not exists. If it already exists, payment was already processed.
    already_done = not await redis.set(idempotency_key, 1, nx=True, ex=86400)
    if already_done:
        return {"status": "already_processed"}

    result = await payment_gateway.charge(amount)
    return result
```

### Cache-aside + Distributed Lock Together (Full Pattern)

```python
async def get_report(report_id: str):
    cache_key = f"report:{report_id}"

    # Fast path: cache hit
    cached = await redis.get(cache_key)
    if cached:
        return json.loads(cached)

    # Slow path: only one process generates the report
    async with redis.lock(f"lock:report:{report_id}", timeout=60):
        # Re-check — another worker may have generated it while we waited for the lock
        cached = await redis.get(cache_key)
        if cached:
            return json.loads(cached)

        report = await db.generate_expensive_report(report_id)
        await redis.setex(cache_key, 3600, json.dumps(report))
        return report
```

---

## Production Checklist

|Item|Why|
|---|---|
|Always set TTLs|Unbounded memory growth → eviction surprises|
|Use `SCAN` not `KEYS *`|`KEYS *` blocks all clients while it runs|
|Set `maxmemory` + eviction policy|Prevents OOM (Out of Memory) crash|
|Use pipelining for bulk operations|10-100x throughput improvement|
|Monitor **hit rate**|< 80% hit rate = your caching strategy is wrong|
|Use connection pooling|Creating a new connection per request is expensive|
|Never store sensitive data unencrypted|Redis has no column-level encryption|
|Use Lua scripts for atomic multi-step ops|Transactions don't roll back; Lua is safer|
|Version your cache keys|`user:v2:101` allows safe schema migrations|
|Monitor **memory fragmentation ratio**|> 1.5 = Redis is using much more RAM than data size|

---

## Quick Reference — Commands Cheat Sheet

```bash
# String
SET key value EX 3600 NX     # Set with TTL + only-if-not-exists
GET key
INCR key / INCRBY key 5

# Hash
HSET key field value
HGET key field
HGETALL key
HINCRBY key field 1

# List
RPUSH key val1 val2           # Push to tail
LPOP key                       # Pop from head (FIFO)
LRANGE key 0 -1               # Get all elements

# Set
SADD key member
SISMEMBER key member
SINTER key1 key2              # Intersection
SUNION key1 key2              # Union

# Sorted Set
ZADD key score member
ZRANK key member              # Rank (low to high)
ZREVRANK key member           # Rank (high to low)
ZRANGE key 0 -1 WITHSCORES
ZREMRANGEBYSCORE key min max

# Streams
XADD stream * field value
XREADGROUP group consumer STREAMS stream >
XACK stream group msg_id

# Utility
TTL key                        # Remaining TTL in seconds
PERSIST key                    # Remove TTL (make permanent)
SCAN 0 MATCH pattern COUNT 100 # Safe key scan
DEBUG SLEEP 0                  # Don't ever run this in prod
```

---

_Next: [[Kafka - Complete Guide]]_