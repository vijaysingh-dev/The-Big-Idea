**Up:** [[00 - Index (Backend)]] | **Prev:** [[Assets.3 - Numbers To Know]]

---

# Production Readiness Checklist

#backend #reference #assets

> **In one line:** Everything the vault establishes, as a list you run against a service before it takes real traffic — and again quarterly, because systems drift.

---

## How To Use This

💡 **Run it as an audit, not a gate.** Every "no" is either fixed or gets a written justification with a reconsideration trigger.

⚠️ **Automate what you can.** A checklist a human runs is a checklist a human forgets ([[06.17 - Database Anti Patterns]]).

| Item | Automation |
|---|---|
| N+1 | Query-count assertions in tests |
| Dangerous migrations | CI linter |
| Missing timeouts | Startup assertion |
| Unused indexes | Weekly report |
| Missing tenant filter | RLS |
| Injection patterns | Custom semgrep rules |
| Degradation paths | Parameterised failure-injection tests |

---

## 1. Configuration and Startup

```
□  Typed config schema, validated at startup
□  Startup assertions for relationships (pool arithmetic, timeout budgets)
□  Secrets as SecretStr; never logged
□  One config source; no file hierarchy with overrides
□  Values identical in every environment are constants, not config
□  Environment-mismatch assertion (staging URL in production)
□  Config changes force a rollout (checksum annotation)
□  Debug endpoint showing effective config, admin-only
```

⚠️ **The startup assertion for pool arithmetic prevents one of the most common production incidents** ([[01.10 - Connection Pools and Limits]]):

```python
assert pool_size * worker_count * replica_count <= db_max_connections
```

---

## 2. Database

```
□  Every index used; verified against a full business cycle
□  No redundant left-prefix duplicates
□  Every ORDER BY has a unique tiebreaker
□  Keyset pagination, not offset
□  Every multi-row query has a limit
□  Filter and sort fields allow-listed
□  timestamptz, never timestamp
□  Money as integer minor units or numeric
□  Enums as text with CHECK
□  UUIDv7 or bigint keys, never UUIDv4
□  Constraints in the database, not just the application
□  statement_timeout, lock_timeout, idle_in_transaction_session_timeout set per role
□  No network calls inside transactions
□  Per-table autovacuum settings for large or hot tables
□  autovacuum_vacuum_cost_limit raised for SSD hardware
□  Tables with retention are time-partitioned
□  Queues use FOR UPDATE SKIP LOCKED
```

⚠️ **The three that cause the most incidents are all configuration:** missing timeouts, migrations without `lock_timeout`, and long transactions. **All three can be fixed this afternoon.**

---

## 3. Migrations

```
□  Every intermediate state works with both old and new code
□  lock_timeout set, with retry
□  CREATE INDEX CONCURRENTLY, outside a transaction
□  Invalid index check after every concurrent build
□  Backfills batched, resumable and throttled
□  Backfill throttling responds to replication lag
□  Migrations run as a separate job before the deploy
□  A failing migration blocks the deploy
□  N-1 test: the previous release's suite passes against the new schema
□  A CI linter rejects dangerous operations
```

💡 **The N-1 test is the one that makes rollback safe** ([[06.11 - Zero Downtime Migrations]]).

---

## 4. Caching

```
□  Tenant in every cache key, enforced by the helper's signature
□  Stampede protection (single-flight, or stale-while-revalidate)
□  Negative caching, with a shorter TTL than positives
□  TTLs jittered
□  Cache failure degrades, never fails the request
□  Permissions never cached with a long TTL
□  Hit ratio tracked per prefix, not globally
□  Redis outage survived at production load, tested
□  Locks not in a cache instance with allkeys-* eviction
```

⚠️ **The Redis-outage test is the one most likely to fail** and the most important ([[07.1 - Cache Layers Across One Request]]).

---

## 5. Background Work

```
□  acks_late=True, and every task idempotent
□  reject_on_worker_lost=True
□  prefetch_multiplier=1 for variable-duration tasks
□  visibility_timeout > longest task (Redis broker)
□  Hard and soft time limits set
□  max_tasks_per_child set
□  Retries with backoff and jitter
□  A dead letter path exists and is monitored
□  Tasks take org_id explicitly and scope every query
□  Queue oldest-message age monitored, not just depth
□  Job last-success timestamps, with absence alerting
```

💡 **`acks_late=True` is not the default**, and the default is at-most-once ([[15.4 - Reading the Celery Worker Loop]]).

---

## 6. Events and Messaging

```
□  Outbox pattern; no dual writes
□  max_slot_wal_keep_size bounds replication slot growth
□  Alert on any inactive replication slot
□  Every consumer idempotent, proven by a replay test
□  Offsets committed after the effect transaction
□  cooperative-sticky partition assignment
□  acks=all WITH min.insync.replicas ≥ 2
□  Event schema versioned, with upcasting
□  CI catches breaking schema changes
□  Consumers with side effects excluded from replay, structurally
□  Trace context propagated through the outbox and the broker
```

⚠️ **An inactive replication slot silently fills the primary's disk.** It is the highest-severity failure in this section ([[06.7 - MVCC Vacuum and Bloat]]).

---

## 7. Resilience

```
□  Every network call: connect, read, write AND pool timeouts
□  Deadline propagated; no hop works past the client's budget
□  Retries only for idempotent calls, with jitter
□  Retry budget, not just per-call limits
□  Retries at exactly one layer, documented
□  Bulkhead per dependency
□  Circuit breaker with a degradation path for every optional dependency
□  Degradation levels defined, tested, with a manual override
□  Read-only mode works; every write path found
□  Load shedding by priority, at the edge
□  Rate limits: global, per-tenant, per-endpoint, and outbound
□  Liveness checks ONLY the process
□  Readiness reflects real serving capability
□  Startup probe for slow starts
□  preStop drain covers endpoint propagation
□  Grace period > preStop + drain + longest operation
□  Replicas spread across zones; PDB set and satisfiable
```

⚠️ **Test the "if slow" case for every dependency, not just "if down".** Most systems pass the second and fail the first ([[11.1 - How Systems Fail]]).

---

## 8. Security

```
□  Authentication at the edge; authorisation in the service
□  Every path to an object authorised, not just the obvious endpoint
□  Tenant boundary in the repository AND the database (RLS with FORCE)
□  Authorisation fails closed
□  404 not 403 for invisible objects, with no timing difference
□  Negative authorisation tests outnumber positive ones
□  A cross-tenant probe per resource type, with coverage enforcement
□  All SQL parameterised; identifiers allow-listed
□  No shell=True; no template source from user input
□  URL fetching: scheme checked, IP resolved and checked, no redirects
□  Delivery workers egress-restricted
□  No pickle or unsafe YAML on untrusted input
□  XML parsers with entities disabled
□  Uploads content-validated, stored by ID, served from another origin
□  Request models use extra="forbid"
□  No user-settable id, org_id, role or billing fields
□  Sessions: httponly, secure, samesite, regenerated on login
□  JWTs: explicit algorithms, audience and issuer verified
□  Refresh tokens rotated with reuse detection
□  Passwords: Argon2id or bcrypt, rehashed on parameter change
□  compare_digest for every secret comparison
□  Secrets support dual-value rotation
□  Secret scanning in pre-commit and CI
□  Dependencies pinned with hashes and scanned
□  Security headers, including CSP
□  Containers: non-root, read-only root, capabilities dropped
□  automountServiceAccountToken: false where unused
```

💡 **The cross-tenant probe with coverage enforcement is the highest-value security test in a multi-tenant product** ([[14.6 - Multi Tenant Isolation]]).

---

## 9. Observability

```
□  SLIs as recording rules, with precise "good" definitions
□  SLO targets derived from a measured baseline
□  Burn-rate alerting, two windows per tier
□  Metrics labelled by route, never by unbounded IDs
□  Version label on every metric
□  Event loop lag instrumented
□  All connection pools instrumented (app, pooler, database)
□  Queries-per-request tracked (N+1 detection)
□  Cache hit ratio per prefix
□  Queue depth AND oldest-message age
□  Circuit state, degraded responses, shed requests, retry budget
□  One trace across every service and queue boundary
□  Business IDs on every span
□  Exemplars on latency histograms
□  Trace ID in every log line
□  Structured logging; no content, only identifiers
□  Tail-based sampling keeping all errors and slow requests
□  Cost metrics: tokens, rows read, storage
□  Per-tenant attribution possible from logs
```

**The five questions must be answerable, timed:**

| Question | Target |
|---|---|
| Is the system healthy? | 5s |
| Where is entity X? | 30s |
| Why was this request slow? | 60s |
| Which tenant is causing this? | 2m |
| What did today cost? | 30s |

---

## 10. Delivery

```
□  Pipeline under 10 minutes to a verdict
□  Flakiness rate zero, and measured
□  Fastest checks first
□  Dependency and Docker layer caching
□  Test order randomised
□  No stage requires another service running
□  Deploy verified against error rate, with automatic rollback
□  Actions pinned by SHA; minimal permissions; OIDC not stored credentials
□  Images pinned by digest, scanned, signed, with an SBOM
□  One image, multiple roles
□  DORA metrics tracked
```

---

## 11. Operations

```
□  Severity levels and roles defined, on one page
□  On-call rotation with runbooks per alert
□  Runbooks tested by someone who did not write them
□  Symptom-based alerting; page list short (≤ 5)
□  Chaos experiments with hypotheses, run on a schedule
□  Every past incident has a permanent regression experiment
□  Postmortems for SEV1/2, with a "where we got lucky" section
□  Action item completion rate tracked (> 70%)
□  Capacity known, with the bottleneck named
□  Cost per unit of business value known
□  Tenant deletion verified per store
□  Backup restore tested, not assumed
```

⚠️ **"Backup restore tested" is the item most often marked yes without evidence.** A restore procedure that has never been executed does not work ([[11.10 - Incidents and Postmortems]]).

---

## The Short Version

**If you can only do ten things:**

```
1.  Timeouts on every network call, including the pool timeout
2.  acks_late=True with idempotent tasks
3.  RLS with FORCE, plus repository scoping
4.  Alert on age(datfrozenxid) and inactive replication slots
5.  Liveness checks only the process
6.  Grace period > longest operation, with a preStop drain
7.  Keyset pagination with a tiebreaker
8.  Queue oldest-age alerting, not depth
9.  One trace across the queue boundary
10. Test the "dependency is slow" case, not just "down"
```

💡 **These ten prevent the majority of the incidents this vault describes**, and most are configuration rather than code.

---

## High-Quality Resources

| Resource | Why It's Worth Your Time |
|---|---|
| [Google SRE Book — Launch Coordination](https://sre.google/sre-book/reliable-product-launches/) | The original production readiness review, and how to run one |
| [PostgreSQL — Don't Do This](https://wiki.postgresql.org/wiki/Don%27t_Do_This) | The database half of this list, from the source |
| [OWASP Application Security Verification Standard](https://owasp.org/www-project-application-security-verification-standard/) | The security half, at three rigour levels |
| [GitLab database guidelines](https://docs.gitlab.com/ee/development/database/) | What a large team automates rather than checks by hand |

---

**Next:** [[Assets.5 - Resource Library]]
