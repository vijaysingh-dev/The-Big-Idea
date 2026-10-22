**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.2 - Exercise Ladder]]

---

# Numbers To Know

#backend #reference #assets

> **In one line:** Order-of-magnitude figures for back-of-envelope reasoning — memorise the ratios, not the digits, and measure your own system for anything that matters.

---

## Latency

| Operation | Time |
|---|---|
| L1 cache reference | 1 ns |
| Branch mispredict | 3 ns |
| L2 cache reference | 4 ns |
| Mutex lock/unlock | 17 ns |
| Main memory reference | 100 ns |
| Compress 1KB (Snappy) | 2 µs |
| **Send 1KB over 10 Gbps** | **~1 µs** |
| **SSD random read (NVMe)** | **~50 µs** |
| Read 1MB sequentially from memory | 3 µs |
| Read 1MB sequentially from NVMe | ~50 µs |
| **Round trip within a datacentre** | **~500 µs** |
| Read 1MB sequentially from disk (HDD) | 825 µs |
| **Cross-AZ round trip** | **~1 ms** |
| **Cross-region (same continent)** | **~30 ms** |
| **Cross-continent round trip** | **~150 ms** |

💡 **The ratios that matter:** memory is ~1,000× faster than SSD, SSD is ~10× faster than a datacentre round trip, and a cross-continent trip is ~300× a local one.

⚠️ **On network-attached cloud storage, random reads are 500 µs–2 ms, not 50 µs.** A database fine on local NVMe can be 10–20× slower on an equivalent-throughput cloud volume, because per-operation *latency* differs ([[06.1 - Storage Engines]]).

---

## Python and the Event Loop

| Operation | Time |
|---|---|
| Function call | ~50 ns |
| Dict lookup | ~40 ns |
| **`await` on a ready coroutine** | **~1 µs** |
| Creating a task | ~2 µs |
| **`json.dumps`, 50KB** | **~1.2 ms** |
| **`orjson.dumps`, 50KB** | **~0.25 ms** |
| `msgpack.packb`, 50KB | ~0.20 ms |
| Pydantic model validation | ~10–50 µs |
| **GIL switch interval (default)** | **5 ms** |

⚠️ **Serialisation frequently dominates a cache hit.** A 3ms deserialisation against a 5ms database query means the cache barely helps ([[07.2 - Cache Strategies and Invalidation]]).

💡 **`orjson` is roughly 5× faster than `json` and it is a one-line change.**

| Concurrency | Figure |
|---|---|
| Practical asyncio tasks per process | 10k–100k |
| **Event loop lag, healthy** | **< 10 ms** |
| Event loop lag, concerning | > 50 ms |
| uvloop throughput gain | 2–4× |

⚠️ **Anything blocking the loop for more than ~10ms is visible in p99** ([[01.12 - Profiling and Debugging Async Services]]).

---

## Postgres

| Operation | Time |
|---|---|
| Simple indexed lookup, cached | 0.1–0.5 ms |
| Simple indexed lookup, from disk | 1–5 ms |
| Sequential scan, 1M rows | 100–500 ms |
| **Commit (fsync, local NVMe)** | **~200 µs** |
| **Commit (cloud storage)** | **0.5–2 ms** |
| Connection establishment | 1–5 ms |

| Capacity | Figure |
|---|---|
| **`max_connections`, practical** | **100–200** |
| **Optimal active connections** | **(cores × 2) + spindles ≈ 20** |
| Rows per table before partitioning helps | 50–100M |
| Single-instance write throughput | 10k–50k/s |
| **B-tree depth for 100M rows** | **3–4 levels** |

💡 **The connection number is the one people get wrong.** Throughput *peaks* around 20 active connections on 8 cores and declines beyond it ([[06.9 - Connection Pooling and PgBouncer]]).

| Health threshold | Value |
|---|---|
| Cache hit ratio (OLTP) | **> 99%** |
| Dead tuple ratio | < 20% |
| **`age(datfrozenxid)`** | **Alert at 1 billion; shutdown at ~2 billion** |
| Index bloat (`avg_leaf_density`) | > 80% healthy |
| Replication lag | < 100MB, or your staleness budget |

⚠️ **`random_page_cost = 4.0` is the default and wrong on SSDs.** Use 1.1 for NVMe, 1.5 for cloud volumes ([[06.5 - The Query Planner]]).

---

## Redis

| Operation | Figure |
|---|---|
| GET/SET, same datacentre | 0.2–1 ms |
| **Throughput, single instance** | **~100k ops/s** |
| Pipelined throughput | 500k–1M ops/s |
| **Memory per key (small string)** | **~100 bytes overhead** |
| `KEYS` on 1M keys | ⚠️ **Blocks for seconds** |

⚠️ **Redis is single-threaded per shard.** One hot key means one CPU core, regardless of cluster size ([[07.3 - Stampede Hot Keys and Negative Caching]]).

---

## Kafka

| Metric | Figure |
|---|---|
| Producer throughput, single broker | 100k–1M msg/s |
| **End-to-end latency (`acks=all`)** | **5–20 ms** |
| Partitions per broker, practical | < 4,000 |
| **Consumer rebalance (eager)** | **Seconds to minutes** |
| **Consumer rebalance (cooperative-sticky)** | **Sub-second** |
| Retention storage, 1k msg/s × 1KB | ~86 GB/day |

💡 **The retention arithmetic is what decides Kafka versus Redis Streams.** 90 days at 1k msg/s is ~7.8TB — **which does not fit in memory** ([[09.8 - Kafka Recap and Where It Fits]]).

---

## HTTP and Networking

| Item | Figure |
|---|---|
| TCP handshake | 1 RTT |
| **TLS 1.3 handshake** | **1 RTT (0-RTT on resume)** |
| TLS 1.2 handshake | 2 RTT |
| DNS lookup (uncached) | 20–120 ms |
| **Typical MTU** | **1500 bytes** |
| **TCP initial congestion window** | **10 packets ≈ 14 KB** |
| HTTP/1.1 connections per origin (browser) | 6 |
| **gzip ratio, JSON** | **~5–10×** |
| brotli ratio, JSON | ~10–15× |

💡 **The initial congestion window means the first ~14KB arrives in one round trip.** Keeping a critical response under that is a real latency win ([[02.3 - TCP Connection Lifecycle]]).

⚠️ **`ndots:5` in Kubernetes means four failed DNS lookups before an external hostname resolves** ([[13.3 - Kubernetes for Backend Engineers]]).

---

## Sizing Arithmetic

### Little's Law

```
L = λ × W        concurrency = throughput × latency
```

```
1,000 rps × 50 ms  =   50 concurrent
1,000 rps × 500 ms =  500 concurrent      ← 10× latency, 10× resources
```

⚠️ **Size on p99, not the mean.** A 20ms mean with a 300ms p99 means occasional requests occupy a worker 15× longer.

### Connections

```
pods × workers × pool_size ≤ max_connections
10   × 4       × 20        = 800  ⚠️  vs max_connections = 100
```

💡 **This multiplication is the most common Postgres production incident in Python backends** ([[01.10 - Connection Pools and Limits]]).

### Availability

```
Four services at 99.9%, synchronously chained → 99.6%
```

| SLO | Downtime/month |
|---|---|
| 99% | 7.2 hours |
| 99.5% | 3.6 hours |
| **99.9%** | **43 minutes** |
| 99.95% | 22 minutes |
| **99.99%** | **4.3 minutes** |

⚠️ **Zone redundancy: with N zones you need `N/(N−1)` capacity to survive losing one.** Three zones means 1.5×.

### Error budget burn

```
burn_rate = error_rate / (1 - SLO)

SLO 99.5%, current error rate 5% → 10× → the 28-day budget is gone in 2.8 days
```

| Burn rate | Consumes (30-day budget) | Alert |
|---|---|---|
| **14.4×** | 2% in 1 hour | **Page** |
| **6×** | 5% in 6 hours | **Page** |
| 3× | 10% in 1 day | Ticket |

---

## Storage and Cost

| Item | Figure |
|---|---|
| UUID | 16 bytes |
| timestamptz | 8 bytes |
| **Postgres row overhead** | **~24 bytes** |
| Postgres page | 8 KB |
| **B-tree index entry** | **~20–40 bytes** |
| **1536-dim float32 embedding** | **6 KB** |

💡 **Embeddings are large.** 1M documents × 20 chunks × 6KB = **120 GB** of vectors alone ([[16.10 - Phase 9 - RAG and the AI Handoff]]).

| Cost (indicative) | |
|---|---|
| Cross-AZ transfer | ~$0.01/GB each way |
| **Internet egress** | **~$0.09/GB** |
| Object storage | ~$0.023/GB/month |
| Managed Postgres (4 vCPU, 16GB) | ~$250/month |

⚠️ **Egress is where the largest surprises live.** Serving files from your application rather than a CDN is often the single biggest avoidable line item ([[13.6 - Cost Awareness]]).

---

## Thresholds Worth Memorising

| Signal | Threshold |
|---|---|
| Postgres cache hit ratio | < 95% → working set exceeds memory |
| Event loop lag | > 50 ms → something is blocking |
| **`age(datfrozenxid)`** | **> 1 billion → page** |
| Inactive replication slot | **Any → page** |
| Queue oldest-message age | > your staleness budget → page |
| Cache hit ratio | < 30–50% → the cache may not be worth it |
| **`nr_throttled` rising** | CPU limit is binding, invisible in average usage |
| Sequential scan returning | > 5–20% of a table → the planner is probably right |
| Batch size consistently 1 | DataLoader batching is broken |
| `cl_waiting` / `maxwait` > 0 | PgBouncer pool too small |

---

## Using These

⚠️ **These are order-of-magnitude figures for reasoning, not benchmarks.** Any number that matters to a decision must be measured on your own hardware, with your own data volume.

💡 **The value is in the ratios.** Knowing that a network round trip is ~1,000× a memory access, or that latency and required concurrency are directly proportional, **lets you sanity-check a design in your head before building it.**

**When a measurement disagrees with a figure here by more than an order of magnitude, investigate — one of them is wrong, and it is usually informative either way.**

---

## High-Quality Resources

| Resource | Why It's Worth Your Time |
|---|---|
| [Latency Numbers Every Programmer Should Know](https://colin-scott.github.io/personal_website/research/interactive_latency.html) | The canonical table, interactive by year |
| [Systems Performance — Brendan Gregg](https://www.brendangregg.com/systems-performance-2nd-edition-book.html) | Where these numbers come from, and how to measure your own |
| [Napkin Math — Simon Eskildsen](https://github.com/sirupsen/napkin-math) | Back-of-envelope estimation as a trainable skill, with exercises |
| [SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/) | Where the burn-rate thresholds come from |

---

**Next:** [[Assets.4 - Production Readiness Checklist]]
