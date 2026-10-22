**Up:** [[00-Index (HLD)]] | **Prev:** [[07.3 - Communicating Tradeoffs]]

---

# Estimation Cheatsheet

> **Revision tags:** #assets #estimation #cheatsheet  
> **Related:** [[02.3 - Estimation and Capacity]]

---

## Powers of 10 — Memorize These

```
1 thousand     = 10³    = 1K
1 million      = 10⁶    = 1M
1 billion      = 10⁹    = 1B
1 trillion     = 10¹²   = 1T

Storage:
  1 KB  = 10³  bytes
  1 MB  = 10⁶  bytes
  1 GB  = 10⁹  bytes
  1 TB  = 10¹² bytes
  1 PB  = 10¹⁵ bytes

Time:
  1 minute    = 60s
  1 hour      = 3,600s
  1 day       = 86,400s     ≈ 10⁵ s
  1 month     = 2,592,000s  ≈ 2.5 × 10⁶ s
  1 year      = 31,536,000s ≈ 3 × 10⁷ s
```

---

## Traffic Estimation Formulas

```
QPS (avg)  = DAU × requests_per_user_per_day / 86,400
QPS (peak) = QPS_avg × peak_factor  (typically 2–5×)

Read:write ratio drives your architecture:
  100:1  → optimize heavily for reads (cache, replicas)
  10:1   → standard web app pattern
  1:1    → write-heavy (Kafka, write-optimized store)
  1:10   → rare (logging, IoT sensor writes)
```

**QPS → Architecture tier:**

| QPS | Approach |
|---|---|
| < 100 | Single server + DB |
| 100–1K | LB + 2–3 servers + single DB |
| 1K–10K | LB + horizontal scaling + Redis + read replica |
| 10K–100K | Redis cluster + DB sharding starts |
| 100K–1M | Distributed cache + aggressive sharding + CDN |
| > 1M | Global distribution, custom infra |

---

## Storage Estimation Formula

```
Storage = records_per_day × record_size_bytes × retention_days

Record size rules of thumb:
  UUID:        16 bytes
  BIGINT ID:    8 bytes
  Timestamp:    8 bytes
  Short string (name, email): 50–100 bytes
  URL:         100–200 bytes
  JSON blob:   200–500 bytes
  Log line:    200–500 bytes
  Tweet/post:  140–500 bytes

Compression multipliers:
  JSON logs:      10:1 with gzip
  Columnar (Parquet): 5–20:1 depending on cardinality
  Binary data:    2–4:1
```

---

## Bandwidth Estimation

```
Inbound  = write_QPS × avg_request_size_bytes
Outbound = read_QPS  × avg_response_size_bytes

Typical values:
  API request body:    500 bytes – 5 KB
  API response (JSON): 1–10 KB
  Web page:            50–200 KB
  Image (thumbnail):   10–50 KB
  Image (full):        500 KB – 2 MB
  Video (1080p):       5 Mbps = 625 KB/s per stream
  Video segment (6s):  6s × 625 KB/s = ~3.75 MB per segment
```

---

## Latency Numbers Every Engineer Should Know

```
L1 cache access:              ~1 ns
L2 cache access:              ~4 ns
RAM access:                   ~100 ns
SSD sequential read (1 MB):   ~1 ms
SSD random read:              ~100 µs
HDD random read:              ~10 ms
Redis GET (same host):        ~0.1 ms
Redis GET (same DC, network): ~1 ms
DB query (simple, same DC):   ~1–5 ms
DB query (with index miss):   ~10–100 ms
HTTP round trip (same DC):    ~1–2 ms
HTTP round trip (cross-DC):   ~10–100 ms
HTTP round trip (global):     ~100–300 ms
```

**Latency budget rule:** Add up the latency of every component in your critical path. If it exceeds your SLA, something needs to be cached, parallelized, or eliminated.

---

## Memory / Cache Sizing

```
Cache size = hot_data_fraction × total_working_set

Rules of thumb:
  20% of data = 80% of requests (Pareto)
  Cache 1–20% of total data to get 80–95% cache hit rate

Redis capacity (rough):
  Simple string key-value:  ~100 bytes overhead per key
  Hash:                     ~200 bytes + field data
  Sorted set member:        ~120 bytes per member
  128 GB Redis node:        ~1 billion simple key-value pairs
```

---

## Database Throughput (Rough Maximums)

```
Single PostgreSQL node (8 vCPU, SSD):
  Reads (with index):   ~50,000 QPS
  Writes:               ~5,000–10,000 TPS
  Connections (safe):   ~200–400 (use PgBouncer)

Single Redis node:
  Simple GET/SET:       ~500,000 ops/s
  Complex Lua script:   ~50,000 ops/s

Single Kafka broker:
  Write throughput:     ~100–500 MB/s
  Topic partitions:     Up to ~1,000/broker (practical limit)

Single Elasticsearch node:
  Index throughput:     ~5,000–10,000 docs/s
  Search QPS:           ~500–2,000/s (depends on complexity)
```

---

## Common System Scale Reference Points

```
Twitter:    ~500M tweets/day = ~6,000/s avg; 150K QPS peak for timeline reads
Instagram:  ~100M photos/day = ~1,160 uploads/s
WhatsApp:   ~100B messages/day = ~1.16M/s avg
Netflix:    ~250M+ streaming hours/day; ~500 Tbps peak bandwidth
YouTube:    500 hours of video uploaded per minute
Uber:       ~20M trips/day = ~230/s; 100K location updates/s peak
Stripe:     ~1B API calls/day = ~11,600/s
```

---

## Availability and Error Budget

```
Availability → Annual downtime:
  99%      → 3.65 days
  99.9%    → 8.76 hours
  99.99%   → 52.6 minutes
  99.999%  → 5.26 minutes

Composite availability (services in series):
  A × B × C = system availability
  3 services at 99.9% each = 99.7% system availability

Error budget (monthly, for SRE):
  99.9%  → 43.2 minutes/month
  99.99% → 4.32 minutes/month
```

---

## Useful Derived Numbers

```
10M DAU, 10 requests/day → 1,157 QPS avg → ~3,500 QPS peak
100M DAU, 1 request/day  → 1,157 QPS avg → ~3,500 QPS peak
1B DAU, 1 session/day    → 11,574 QPS avg → ~35K QPS peak

1 million requests/day   → ~12 QPS
1 billion requests/day   → ~12K QPS
1 trillion requests/day  → ~12M QPS

1 TB/day ingest          → ~11.6 MB/s average
10 TB/day                → ~116 MB/s average
```

---

**Next:** [[Assets.2 - DB Selection and Checklists]]
