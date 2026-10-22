**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.4 - Production Readiness Checklist]]

---

# Resource Library

#backend #reference #assets

> **In one line:** Every resource in the vault, deduplicated and grouped — with the handful marked that are worth reading even if you read nothing else.

---

## The Ten

💡 **If you read only ten things from this entire vault, read these.**

| Resource | Why |
|---|---|
| **[Designing Data-Intensive Applications — Kleppmann](https://dataintensive.net/)** | The book this vault orbits. Storage engines, replication, transactions, consensus |
| **[Postgres `nbtree/README` and `transam/README`](https://github.com/postgres/postgres/tree/master/src/backend/access)** | Production database internals, written better than most books |
| **[Postgres `README-SSI`](https://github.com/postgres/postgres/blob/master/src/backend/storage/lmgr/README-SSI)** | The best explanation of serializable isolation anywhere |
| **[AWS Builders' Library](https://aws.amazon.com/builders-library/)** | Timeouts, retries, load shedding, caching, fallbacks. Written by people who operate it |
| **[Google SRE Book](https://sre.google/sre-book/table-of-contents/)** + [Workbook](https://sre.google/workbook/table-of-contents/) | Cascading failures, SLOs, incident response, overload |
| **[Use The Index, Luke](https://use-the-index-luke.com/)** | Indexing and pagination from first principles. Free |
| **[High Performance Browser Networking — Grigorik](https://hpbn.co/)** | TCP, TLS, HTTP/2, WebSocket. Free, and the diagrams are excellent |
| **[Release It! — Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)** | The stability patterns. Still the best single book on resilience |
| **[Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)** | The most rigorous public API design document |
| **[How to do distributed locking — Kleppmann](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)** | Fencing tokens, and why locks are not a correctness mechanism |

---

## Books

| Book | Covers |
|---|---|
| [Designing Data-Intensive Applications](https://dataintensive.net/) | Everything. Re-read annually |
| [Database Internals — Petrov](https://www.databass.dev/) | Storage engines and distributed systems, in depth |
| [PostgreSQL 14 Internals — Rogov](https://postgrespro.com/community/books/internals) | **Free PDF.** The most thorough public Postgres explanation |
| [Release It! — Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/) | Stability patterns and antipatterns |
| [Building Microservices, 2nd ed. — Newman](https://samnewman.io/books/building_microservices_2nd_edition/) | Honest about when not to |
| [Production Ready GraphQL — Giroux](https://book.productionreadygraphql.com/) | Operating GraphQL, including when not to adopt it |
| [Systems Performance — Gregg](https://www.brendangregg.com/systems-performance-2nd-edition-book.html) | Finding bottlenecks systematically |
| [High Performance Browser Networking](https://hpbn.co/) | **Free.** Networking from TCP to WebRTC |
| [Relevant Search — Turnbull & Berryman](https://www.manning.com/books/relevant-search) | Measuring and improving search quality |
| [Observability Engineering](https://www.honeycomb.io/observability-engineering-oreilly-book-2022) | High-cardinality analysis |
| [Your Code as a Crime Scene — Tornhill](https://pragprog.com/titles/atcrime2/) | Using git history to find where complexity lives |
| [Kubernetes Patterns — Ibryam & Huß](https://k8spatterns.io/) | Application-level Kubernetes patterns |

---

## Papers

| Paper | Why |
|---|---|
| [Raft — In Search of an Understandable Consensus Algorithm](https://raft.github.io/raft.pdf) | Figure 2 is the whole algorithm on one page |
| [Google Zanzibar](https://research.google/pubs/pub48190/) | The reference design for relationship-based authorisation |
| [The Tail at Scale — Dean & Barroso](https://research.google/pubs/pub40801/) | Hedged requests and tail latency |
| [Metastable Failures in Distributed Systems](https://sigops.org/s/conferences/hotos/2021/papers/hotos21-s11-bronson.pdf) | Short. Names the failure mode that does not self-recover |
| [A Critique of ANSI SQL Isolation Levels](https://www.microsoft.com/en-us/research/publication/a-critique-of-ansi-sql-isolation-levels/) | Where write skew was named |
| [Optimal Probabilistic Cache Stampede Prevention](https://cseweb.ucsd.edu/~avattani/papers/cache_stampede.pdf) | The XFetch algorithm, in a few lines |
| [Life beyond Distributed Transactions — Helland](https://queue.acm.org/detail.cfm?id=3025012) | Why 2PC does not scale and what replaces it |
| [Scaling Memcache at Facebook](https://www.usenix.org/system/files/conference/nsdi13/nsdi13-final170_update.pdf) | Caching and invalidation at extreme scale |
| [The Log — Jay Kreps](https://engineering.linkedin.com/distributed-systems/log-what-every-software-engineer-should-know-about-real-time-datas-unifying-abstraction) | Why a log is a foundational abstraction |

---

## Specifications Worth Reading Directly

💡 **Reading the primary source once beats ten blog posts.** These are all short.

| Spec | Length |
|---|---|
| [ASGI](https://asgi.readthedocs.io/) | Short. Makes uvicorn and Starlette readable |
| [RESP (Redis protocol)](https://redis.io/docs/latest/develop/reference/protocol-spec/) | Very short |
| [graphql-ws PROTOCOL.md](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md) | Short and complete |
| [RFC 9457 — Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) | Short. A standard error shape |
| [RFC 7636 — PKCE](https://datatracker.ietf.org/doc/html/rfc7636) | Read the security considerations |
| [RFC 8594 — Sunset header](https://www.rfc-editor.org/rfc/rfc8594.html) | Two pages |
| [GraphQL spec, §6 Execution](https://spec.graphql.org/draft/#sec-Execution) | The algorithm, precisely |
| [OCI Runtime Specification](https://github.com/opencontainers/runtime-spec/blob/main/config.md) | What a container is, defined |
| [WHATWG — Server-Sent Events](https://html.spec.whatwg.org/multipage/server-sent-events.html) | Reconnection and `Last-Event-ID` semantics |
| [Apollo Federation spec](https://www.apollographql.com/docs/federation/federation-spec/) | The directives and `_entities` contract |

---

## Codebases

**Ordered by how much you learn per hour spent.**

| Repo | Read for |
|---|---|
| **[redis/redis](https://github.com/redis/redis)** | **The best C codebase for learning.** `ae.c`, `networking.c`, `t_string.c`, `evict.c` |
| **[postgres/postgres](https://github.com/postgres/postgres)** | The READMEs first. Then `nbtree`, `xlog.c`, `selfuncs.c`, `costsize.c` |
| [encode/uvicorn](https://github.com/encode/uvicorn) + [starlette](https://github.com/encode/starlette) | ~9,000 lines running every request you serve |
| [celery/celery](https://github.com/celery/celery) | `worker/request.py` and `worker/strategy.py` |
| [saleor/saleor](https://github.com/saleor/saleor) | A large commercial GraphQL schema and Django monolith |
| [GoogleCloudPlatform/microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) | The only complete deployable microservice system |
| [onyx-dot-app/onyx](https://github.com/onyx-dot-app/onyx) | Production RAG in Conduit's exact domain |
| [krallin/tini](https://github.com/krallin/tini) | 200 lines that explain PID 1 in containers |
| [graphql/dataloader](https://github.com/graphql/dataloader) | 400 lines. The batching trick |
| [golang/groupcache](https://github.com/golang/groupcache) | `singleflight.go` is 60 lines |
| [Shopify/toxiproxy](https://github.com/Shopify/toxiproxy) | The toxic list is a catalogue of failures worth simulating |
| [zalando/patroni](https://github.com/zalando/patroni) | `ha.py` — leader election with fencing, working |
| [debezium/debezium](https://github.com/debezium/debezium) | The outbox router and incremental snapshots |
| [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes) | `replica_set.go` for the reconcile pattern; `proxier.go` for Services |

---

## Documentation Worth Reading In Full

| Docs | Sections |
|---|---|
| [PostgreSQL](https://www.postgresql.org/docs/current/) | Indexes, Transaction Isolation, Routine Vacuuming, Server Configuration |
| [Redis](https://redis.io/docs/latest/) | Eviction, Streams, Distributed locks, Keyspace notifications |
| [Kubernetes](https://kubernetes.io/docs/concepts/) | Workloads, Services, Configuration, Pod lifecycle |
| [Celery](https://docs.celeryq.dev/) | Optimizing, Calling, Workers, and the **Redis caveats** |
| [Kafka](https://kafka.apache.org/documentation/) | Design, and the consumer configuration reference |
| [OpenTelemetry](https://opentelemetry.io/docs/) | Context propagation, and the trace data model |
| [PgBouncer](https://www.pgbouncer.org/config.html) | Every setting. Pool modes especially |

---

## Blogs and Article Series

| Source | Why |
|---|---|
| **[AWS Builders' Library](https://aws.amazon.com/builders-library/)** | Every article is worth reading. Start with timeouts, load shedding, fallbacks |
| [Martin Kleppmann](https://martin.kleppmann.com/) | Distributed locking, event sourcing, CRDTs |
| [Martin Fowler](https://martinfowler.com/) | Microservice trade-offs, feature toggles, contract testing |
| [Brandur Leach](https://brandur.org/) | Idempotency keys, Postgres, API design |
| [Explaining the unexplainable — depesz](https://www.depesz.com/tag/unexplainable/) | Every `EXPLAIN` node type |
| [pganalyze blog](https://pganalyze.com/blog) | Practical Postgres query and index analysis |
| [Cloudflare blog](https://blog.cloudflare.com/) | Networking and their unusually detailed postmortems |
| [Segment engineering](https://segment.com/blog/) | "Goodbye Microservices" in particular |

---

## Postmortems

💡 **The highest-leverage reliability reading available.** Each one is a failure mode you can check your own system against, for free.

| Source | |
|---|---|
| [Awesome Postmortems](https://github.com/danluu/post-mortems) | A curated collection. Read three |
| [GitLab database incident (2017)](https://about.gitlab.com/blog/2017/02/10/postmortem-of-database-outage-of-january-31/) | The clearest public example of blameless analysis |
| [Sentry — transaction ID wraparound](https://blog.sentry.io/transaction-id-wraparound-in-postgres/) | Read before you need to |
| [Cloudflare postmortems](https://blog.cloudflare.com/tag/postmortem/) | Consistently detailed and technical |

⚠️ **The pattern across almost all of them: the trigger is small and the severity comes from amplification** ([[11.1 - How Systems Fail]]). **Read with that lens.**

---

## Tools Worth Installing

| Tool | For |
|---|---|
| [pgvector](https://github.com/pgvector/pgvector) | Vectors in Postgres |
| [pg_partman](https://github.com/pgpartman/pg_partman) | Partition maintenance |
| [pg_repack](https://github.com/reorg/pg_repack) | Online bloat removal |
| [hypopg](https://github.com/HypoPG/hypopg) | Test index ideas without building them |
| [pgstattuple / pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html) | Bloat and query statistics |
| [Toxiproxy](https://github.com/Shopify/toxiproxy) | Failure injection in tests |
| [Testcontainers](https://testcontainers.com/) | Real dependencies in tests |
| [k6](https://grafana.com/docs/k6/) | Load testing with arrival-rate executors |
| [semgrep](https://semgrep.dev/) | Custom anti-pattern rules |
| [gitleaks](https://github.com/gitleaks/gitleaks) | Secret scanning |
| [strong_migrations](https://github.com/ankane/strong_migrations) | The dangerous-migration catalogue (read it even in Python) |
| [Sloth](https://github.com/slok/sloth) | Generates Prometheus rules from SLO definitions |
| [PEV2](https://explain.dalibo.com/) | Visualise `EXPLAIN` output |

---

## Reading Order, If Starting Fresh

```
1. Designing Data-Intensive Applications, Ch. 1–3
2. High Performance Browser Networking, Ch. 1–2
3. Use The Index, Luke — in full
4. AWS Builders' Library — timeouts, load shedding, caching
5. Google SRE Book — cascading failures, SLOs
6. Postgres transam/README and nbtree/README
7. Read Redis's ae.c and networking.c
8. Release It! — the stability patterns
9. Building Microservices, Ch. 1 and 4
10. Three postmortems
```

💡 **Items 6 and 7 are the shift** — from reading about systems to reading systems. **Everything after that is easier.**

---

**Next:** [[Assets.6 - Rapid Fire Question Bank]]
