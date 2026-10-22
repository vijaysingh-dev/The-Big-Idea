**Up:** [[00-Index (HLD)]] | **Prev:** [[Assets.1 - Estimation Cheatsheet]]

---

# DB Selection Cheatsheet, CAP Reference & Interview Checklist

> **Revision tags:** #assets #cheatsheet #reference  
> **Related:** [[03.6 - Databases SQL and NoSQL]] | [[01.5 - CAP and PACELC]]

---

## Database Selection Matrix

| Use Case | Database | Why |
|---|---|---|
| Relational data, ACID transactions | PostgreSQL | Joins, FK constraints, ACID, rich query language |
| High-read web app | MySQL + read replicas | Fast reads, widely supported |
| Globally distributed ACID | CockroachDB / Google Spanner | Distributed SQL, external consistency |
| Key-value, low latency | Redis | In-memory, sub-ms, TTL support |
| Key-value, large scale | DynamoDB | Managed, auto-scaling, pay-per-use |
| Document store | MongoDB | Flexible schema, nested documents |
| High write throughput (time-series events) | Cassandra | LSM tree, linear write scale, partition by time |
| Full-text search + facets | Elasticsearch / OpenSearch | Inverted index, BM25, aggregations |
| Analytics / OLAP | ClickHouse / BigQuery | Columnar, fast aggregations over billions of rows |
| Time-series metrics | InfluxDB / TimescaleDB | Time-based compression, retention policies |
| Graph traversal | Neo4j / Amazon Neptune | Native graph, efficient multi-hop traversals |
| Object / blob storage | S3 / GCS / Azure Blob | Cheap, durable, unlimited scale, HTTP access |
| Config + leader election | etcd / Consul | Strongly consistent KV, watch API |
| Session store | Redis | TTL-native, sub-ms, Lua scripting |

---

## The 5-Question DB Selection Guide

```
1. What does the data look like?
   Relational (tables + FK) → SQL
   Hierarchical / document  → Document store
   Key → value only         → Key-value store
   Wide rows by time        → Column-family
   Graph nodes + edges      → Graph DB

2. What's the query pattern?
   Point lookup by key      → Redis, DynamoDB
   Range scan by time       → Cassandra, TimescaleDB
   Ad-hoc SQL joins         → PostgreSQL
   Full-text keyword search → Elasticsearch
   Aggregation over history → ClickHouse, BigQuery

3. What's the read:write ratio?
   Read-heavy (>10:1)   → Add replicas, caching
   Write-heavy (<1:1)   → LSM-tree stores (Cassandra, RocksDB)
   Balanced (1:1–10:1)  → Standard RDBMS + replica

4. What consistency level is required?
   ACID, no compromise  → PostgreSQL, CockroachDB
   Tunable consistency  → Cassandra (ONE/QUORUM/ALL)
   Eventual is fine     → DynamoDB, Cassandra default

5. What's the scale?
   < 1 TB, < 10K QPS   → Single PostgreSQL node is fine
   > 1 TB writes        → Shard or use distributed store
   > 100K QPS reads     → Caching + replicas first
```

---

## CAP / PACELC Quick Reference

```
CAP — during a network PARTITION, choose:
  C (Consistency): return error rather than stale data
  A (Availability): return stale data rather than error

PACELC — adds the ELSE (normal operation):
  E: Latency vs Consistency (even without partition)

System        | Partition | Normal  | Classification
--------------|-----------|---------|---------------
PostgreSQL    | CP        | EC      | CP/EC
DynamoDB def. | AP        | EL      | AP/EL
Cassandra def.| AP        | EL      | AP/EL
HBase         | CP        | EC      | CP/EC
MongoDB (def) | AP        | EC      | AP/EC
etcd          | CP        | EC      | CP/EC
ZooKeeper     | CP        | EC      | CP/EC
```

**Mnemonic:** "When a partition happens, would you rather tell the user 'sorry, try later' (CP) or 'here's possibly stale data' (AP)?"

---

## HLD Interview Checklist

### Before Drawing (First 10 Minutes)

```
□ Clarify 2–3 functional requirements (core use cases)
□ Clarify key non-functional requirements:
  □ Availability SLA (99.9%? 99.99%?)
  □ Latency target (p99?)
  □ Consistency requirement (strong vs eventual?)
  □ Scale (DAU, QPS, storage?)
  □ Global or single-region?
□ State out-of-scope explicitly
□ Write down assumptions (scale, ratios, constraints)
□ Do back-of-envelope estimation:
  □ QPS (read and write separately)
  □ Storage (data size × retention)
  □ Identify the bottleneck tier
```

### During Design (Next 20 Minutes)

```
□ Draw left to right: Client → LB → Services → Storage
□ Label every box and every arrow
□ Choose architecture style and justify it
□ Show data flow for the primary use case
□ Choose databases with justification (not just "use PostgreSQL")
□ Add cache layer and specify:
  □ What is cached?
  □ Cache strategy (cache-aside, write-through, etc.)?
  □ TTL / invalidation?
□ Show async vs sync boundaries explicitly
□ Check in with interviewer every 5–7 minutes
```

### Failure and Scale (Final 15 Minutes)

```
□ Identify failure modes for each major component:
  □ What if the cache is down?
  □ What if the DB primary fails?
  □ What if a downstream service is slow?
□ State the circuit breaker / retry / timeout strategy
□ Address: what breaks at 10× or 100× scale?
□ Identify the SPOF (Single Point of Failure — component whose failure kills everything)
  and how to eliminate it
□ Mention monitoring/alerting (even one sentence)
□ Mention deployment strategy if relevant (rolling, canary)
```

### Communication Checklist

```
□ Every major decision has a "because"
□ Every choice acknowledges the alternative
□ Assumptions are visible (written on board/doc)
□ Thinking is audible while drawing
□ No long silences (> 30s) without narration
□ Responded to at least one "why not X?" challenge
□ Addressed at least one failure scenario unprompted
```

---

## Common Patterns Quick Reference

```
Pattern                 | When to Use
------------------------|----------------------------------
Cache-aside             | Read-heavy, stale reads acceptable
Write-through           | Read-heavy, fresh reads required
Fan-out on write        | Social feed, few followers
Fan-out on read         | Social feed, many followers (celebrity)
CQRS                    | Different read vs write data shapes
SAGA (choreography)     | Simple distributed workflows
SAGA (orchestration)    | Complex distributed workflows
Outbox pattern          | Reliable event emission from DB write
Idempotency key         | Any retry-prone mutation
Token bucket            | Rate limiting with burst
Sliding window counter  | Precise rate limiting, distributed
Presigned URL           | User uploads to object storage
Strangler fig           | Incremental legacy migration
Cell-based architecture | Blast radius reduction
BFF (Backend for Frontend) | Multiple clients, different API shapes
```

---

*End of Assets. You now have everything in the vault.*

*Session tracker: ✅ Complete — all 7 sessions done.*
