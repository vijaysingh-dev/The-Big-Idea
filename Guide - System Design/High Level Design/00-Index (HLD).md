# High Level Design — Master Index

> **Goal:** Design large-scale backend systems confidently, reason about tradeoffs, and perform at senior/staff level in HLD interviews.

---

## How to Use This Vault

- **Learning path:** Follow sections 01 → 07 in order the first time.
- **Revision:** Jump directly to any building block or case study.
- **Interview prep:** Start with [[07.1 - How HLD Interviews Work]] + skim [[Assets/Assets.2 - DB Selection and Checklists]].

---

## 01 — Fundamentals

| File | What It Covers |
|---|---|
| [[01.1 - What Is HLD]] | Definition, scope, purpose of HLD |
| [[01.2 - LLD vs HLD]] | Where each applies, how they differ |
| [[01.3 - Requirements]] | Functional vs Non-Functional requirements |
| [[01.4 - Core Properties]] | Scalability, Availability, Reliability, Durability, Latency, Throughput, Fault Tolerance, Resilience, Maintainability |
| [[01.5 - CAP and PACELC]] | CAP theorem, PACELC, what they actually mean |
| [[01.6 - Consistency Models]] | Strong vs Eventual consistency, ACID vs BASE |
| [[01.7 - System Patterns]] | Sync/Async, Push/Pull, Stateless/Stateful |
| [[01.8 - Scaling Strategies]] | Horizontal vs Vertical scaling |
| [[01.9 - Architecture Styles]] | Monolith, Microservices, Modular Monolith |
| [[01.10 - Advanced Patterns]] | Event-Driven, CQRS, SAGA, Idempotency, Backpressure |
| [[01.11 - Distributed Concepts]] | Sharding, Replication, Consensus, Failure Domains, Blast Radius |

---

## 02 — HLD Methodology

| File | What It Covers |
|---|---|
| [[02.1 - Framework Overview]] | The repeatable 10-step HLD solving framework |
| [[02.2 - Requirements Clarification]] | How to clarify scope in interviews and real projects |
| [[02.3 - Estimation and Capacity]] | QPS, storage, bandwidth, growth estimation math |
| [[02.4 - Architecture Decisions]] | Style selection, API design, data flow, DB selection |
| [[02.5 - Failure and Resilience]] | Retries, circuit breakers, graceful degradation, DR |
| [[02.6 - Observability Security Cost]] | Monitoring design, security boundaries, cost awareness |

---

## 03 — Building Blocks

| File | What It Covers |
|---|---|
| [[03.1 - Load Balancers]] | Algorithms, L4 vs L7, health checks, sticky sessions |
| [[03.2 - Reverse Proxies and API Gateways]] | Nginx, API gateway patterns, request routing |
| [[03.3 - CDN]] | Edge caching, push vs pull CDN, cache invalidation |
| [[03.4 - Caching Systems]] | Cache strategies, eviction policies, stampede |
| [[03.5 - Redis Patterns]] | Data structures, TTL, pub/sub, Lua scripts, cluster |
| [[03.6 - Databases SQL and NoSQL]] | When to use what, DB taxonomy, connection pooling |
| [[03.7 - Replication and Read Replicas]] | Sync/async replication, lag, failover |
| [[03.8 - Message Queues and Kafka]] | Kafka internals, RabbitMQ, ordering, consumer groups |
| [[03.9 - PubSub and Event Bus]] | Pub/Sub patterns, fan-out, event buses |
| [[03.10 - Search Systems]] | Inverted index, Elasticsearch, ranking basics |
| [[03.11 - Object Storage]] | S3 model, blob storage design, presigned URLs |
| [[03.12 - Distributed Locks]] | Fencing tokens, Redlock, ZooKeeper |
| [[03.13 - Service Discovery and Config]] | Consul, etcd, DNS-based discovery, config systems |
| [[03.14 - Rate Limiters]] | Token bucket, sliding window, distributed rate limiting |
| [[03.15 - Schedulers and Cron]] | Distributed cron, leader election, at-least-once execution |
| [[03.16 - Notification Systems]] | Push, email, SMS architecture, fan-out |
| [[03.17 - Auth and Sessions]] | JWT, OAuth2, session management, RBAC |
| [[03.18 - Feature Flags]] | Flag systems, rollout strategies, kill switches |
| [[03.19 - Observability Stack]] | Logging pipelines, metrics, distributed tracing |

---

## 04 — Build Your Own

> Simplified implementations to understand systems from the inside.

| File | System |
|---|---|
| [[04.1 - Rate Limiter]] | Token bucket + sliding window in Python |
| [[04.2 - Load Balancer]] | Round-robin + least-connections |
| [[04.3 - Message Queue]] | In-memory queue with ack/nack |
| [[04.4 - PubSub System]] | Topic-based pub/sub |
| [[04.5 - Retry Engine]] | Exponential backoff with jitter |
| [[04.6 - Job Scheduler]] | Cron-style task scheduler |
| [[04.7 - Distributed Lock]] | Redis-based lock with TTL + heartbeat |
| [[04.8 - Cache System]] | LRU cache with TTL |
| [[04.9 - Search Indexing]] | Inverted index builder |
| [[04.10 - Notification System]] | Fan-out notification dispatcher |
| [[04.11 - Feature Flag System]] | Rule-based flag evaluator |
| [[04.12 - Service Discovery]] | Registry + heartbeat system |

---

## 05 — Senior Engineer Thinking

| File | What It Covers |
|---|---|
| [[05.1 - Tradeoff Evaluation]] | How to reason about and communicate tradeoffs |
| [[05.2 - Failure First Thinking]] | Design from failure scenarios outward |
| [[05.3 - Design For Change]] | Avoiding premature optimization, extensible design |
| [[05.4 - Build vs Buy]] | Framework for make vs buy decisions |
| [[05.5 - Avoiding Mistakes]] | Common architectural mistakes and how to prevent them |

---

## 06 — Case Studies

| File | System |
|---|---|
| [[06.1 - URL Shortener]] | Classic starter — caching, hashing, redirects |
| [[06.2 - Social Feed]] | Instagram-style — fan-out, timelines, media |
| [[06.3 - Chat System]] | WhatsApp-style — WebSockets, message ordering |
| [[06.4 - Food Delivery]] | Real-time matching, geo-search, order lifecycle |
| [[06.5 - Ride Sharing]] | Uber-style — location tracking, matching, surge |
| [[06.6 - Payment Gateway]] | Idempotency, ledger design, compliance |
| [[06.7 - Notification Platform]] | Multi-channel fan-out at scale |
| [[06.8 - Job Scheduler Service]] | Distributed cron, at-least-once, deduplication |
| [[06.9 - Search System]] | Index pipeline, ranking, typeahead |
| [[06.10 - Video Streaming]] | Transcoding, CDN, adaptive bitrate |
| [[06.11 - Multi-Tenant SaaS]] | Isolation models, data partitioning |
| [[06.12 - Ecommerce Platform]] | Catalog, inventory, checkout, payments |
| [[06.13 - Logging Metrics Platform]] | Ingestion, storage, querying at scale |

---

## 07 — Interview Guide

| File | What It Covers |
|---|---|
| [[07.1 - How HLD Interviews Work]] | Evaluation criteria, what interviewers look for |
| [[07.2 - Common Mistakes]] | What kills otherwise good candidates |
| [[07.3 - Communicating Tradeoffs]] | How to defend decisions and handle 100x scale questions |

---

## Assets (Quick Reference)

| File | Contents |
|---|---|
| [[Assets.1 - Estimation Cheatsheet]] | Powers of 10, QPS formulas, latency numbers, storage math |
| [[Assets.2 - DB Selection and Checklists]] | DB selection matrix, CAP reference, full interview checklist |
