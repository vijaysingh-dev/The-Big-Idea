# Observability — Logging, Tracing & Metrics

#backend #observability #microservices #opentelemetry #grafana #production

> **Goal of this guide:** Understand how senior engineers instrument, monitor, and debug microservices in production. After this, you can design an observability stack from scratch, answer any interview question on this topic, and make real architectural decisions.
> 
> 📖 **One resource to go deep:** [OpenTelemetry Documentation](https://opentelemetry.io/docs/) — the industry standard. Pair it with [Grafana Labs YouTube channel](https://www.youtube.com/@grafana) for visual walkthroughs.

---

## Table of Contents

1. [[#The Core Problem — Why Observability Exists]]
2. [[#The Three Pillars]]
3. [[#Pillar 1 — Structured Logging]]
4. [[#Pillar 2 — Distributed Tracing]]
5. [[#Pillar 3 — Metrics]]
6. [[#OpenTelemetry — The Unifying Standard]]
7. [[#The Production Stack — How It All Fits Together]]
8. [[#Grafana — Visualization & Alerting]]
9. [[#Real Production Patterns]]
10. [[#Interview Questions Answered]]
11. [[#Decision Guide — What to Use When]]

---

## The Core Problem — Why Observability Exists

In a monolith, a bug is straightforward:

```
User reports: "Checkout is broken"
You: grep logs on one server → find the stack trace → fix
```

In microservices, the same request touches 8 services:

```
User → API Gateway → Auth Service → Order Service → Inventory Service
                                         │
                                         ├──► Payment Service → Payment Gateway (external)
                                         │
                                         └──► Notification Service → Email Provider
```

Now a user reports "checkout failed." Which service failed? Was it slow or erroring? Was it the Payment Gateway (external, not your fault) or your Order Service? Did it fail for all users or just this one? Was it happening 2 hours ago too?

Without observability, you're blind. You SSH into 8 servers, grep 8 log files, hope timestamps line up, and spend 4 hours finding a 3-line bug.

**Observability** is the ability to understand what's happening inside your systems by examining what they output — without needing to SSH in, add new code, or guess.

---

## The Three Pillars

**Observability = Logs + Traces + Metrics**

Think of debugging a car:

|Analogy|Observability Pillar|What it tells you|
|---|---|---|
|Warning lights on dashboard|**Metrics**|Something is wrong (CPU high, error rate spiked)|
|Black box / event recorder|**Logs**|What events happened and when|
|GPS track of the journey|**Traces**|The full path of a specific request across services|

Each pillar answers different questions:

|Question|Use|
|---|---|
|"Is something wrong right now?"|Metrics|
|"What happened during the 3pm incident?"|Logs|
|"Why is checkout slow for user #101?"|Traces|
|"Which service is the bottleneck?"|Traces + Metrics|
|"What was the exact error message?"|Logs|
|"Has error rate been growing for a week?"|Metrics|

They are **complementary**, not replacements. Senior engineers use all three together.

---

## Pillar 1 — Structured Logging

### The Problem With Regular Logs

Most beginners write logs like this:

```python
# Bad — unstructured log (plain text)
print(f"User {user_id} placed order {order_id} for amount {amount}")
# Output: "User 101 placed order 789 for amount 2499"
```

This looks fine until you have 50 million log lines and need to find all orders above ₹10,000 from users in Delhi that failed in the last hour. You can't query free text efficiently.

### Structured Logging

Structured logging = emit logs as **machine-readable JSON** instead of human-readable sentences. Every field is queryable.

```python
import structlog
import logging

# --- Configure structlog once at application startup ---
structlog.configure(
    processors=[
        structlog.stdlib.add_log_level,           # adds "level": "info"
        structlog.stdlib.add_logger_name,          # adds "logger": "order_service"
        structlog.processors.TimeStamper(fmt="iso"),  # adds "timestamp": "2024-01-15T14:23:01Z"
        structlog.processors.StackInfoRenderer(),
        structlog.processors.JSONRenderer()        # outputs JSON instead of plain text
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    logger_factory=structlog.stdlib.LoggerFactory(),
)

log = structlog.get_logger()
```

```python
# --- Good: structured log with queryable fields ---
log.info(
    "order_placed",                    # event name — describes what happened
    user_id=user_id,
    order_id=order_id,
    amount=amount,
    currency="INR",
    items_count=len(items),
    payment_method="upi"
)
```

**Output (what gets written to your log system):**

```json
{
  "timestamp": "2024-01-15T14:23:01.432Z",
  "level": "info",
  "logger": "order_service",
  "event": "order_placed",
  "user_id": "101",
  "order_id": "789",
  "amount": 2499,
  "currency": "INR",
  "items_count": 3,
  "payment_method": "upi",
  "trace_id": "abc123",         ← we'll get to this in tracing
  "span_id": "def456"
}
```

Now you can query: `amount > 10000 AND payment_method = "upi" AND level = "error"` — instantly, across 50 million logs.

### Context Binding — The Senior Engineer Trick

You don't want to pass `user_id`, `order_id`, `request_id` to every single log call. **Bind context once** and it automatically appears in all subsequent logs within that request.

```python
# --- Bind request-level context once at the entry point (middleware) ---
def logging_middleware(request, call_next):
    request_log = log.bind(
        request_id=str(uuid.uuid4()),
        user_id=request.headers.get("X-User-Id"),
        endpoint=request.url.path,
        method=request.method,
        ip=request.client.host
    )
    # Store in request context so all functions in this request can access it
    request.state.log = request_log
    
    start = time.time()
    response = call_next(request)
    
    request_log.info(
        "request_completed",
        status_code=response.status_code,
        duration_ms=round((time.time() - start) * 1000, 2)
    )
    return response
```

```python
# --- Any function in the request can log without repeating context ---
async def place_order(request, order_data):
    log = request.state.log.bind(order_id=new_order.id)  # Add more context

    log.info("order_processing_started")

    try:
        result = await charge_payment(order_data)
        log.info("payment_successful", transaction_id=result.id)
    except PaymentError as e:
        log.error("payment_failed", error_code=e.code, error_message=str(e))
        raise
```

Every log line in this request automatically has `request_id`, `user_id`, `endpoint`, `method`, `order_id` — without you passing them everywhere.

### Log Levels — How Senior Engineers Actually Use Them

Most junior engineers use `INFO` for everything. This is wrong.

|Level|When to use|Example|
|---|---|---|
|`DEBUG`|Detailed diagnostic info, off in production|"Entering payment validation, data: {...}"|
|`INFO`|Normal business events worth recording|"Order placed", "User logged in", "Cache miss"|
|`WARNING`|Something unexpected but handled|"Retrying payment (attempt 2/3)", "Cache hit rate below 80%"|
|`ERROR`|A specific operation failed, system still running|"Payment failed for order_id=789", "DB connection timed out"|
|`CRITICAL`|System-level failure, immediate attention needed|"Cannot connect to database", "Disk full"|

```python
# --- Good log level usage ---
log.debug("cache_lookup", key=cache_key)                     # Too noisy for prod — disable
log.info("order_placed", order_id=order_id)                  # Normal business event
log.warning("payment_retry", attempt=2, order_id=order_id)   # Unexpected but okay
log.error("payment_failed", order_id=order_id, error=str(e)) # Needs attention
log.critical("db_connection_lost", host=db_host)             # Wake someone up at 3am
```

**Production config:** Set log level to `WARNING` or `INFO`. Use `DEBUG` only when actively debugging — it generates enormous volume.

### What to ALWAYS Log

```python
# Every HTTP request (in middleware, automatically):
# method, path, status_code, duration_ms, user_id, request_id

# Every external call (DB query, API call, cache lookup):
log.info("db_query", table="orders", operation="SELECT", duration_ms=12, rows_returned=1)
log.info("external_api_call", service="payment_gateway", endpoint="/charge",
         duration_ms=340, status_code=200)
log.info("cache_lookup", key=cache_key, hit=True, duration_ms=1)

# Every error with full context:
log.error("order_failed", order_id=order_id, user_id=user_id,
          error_type=type(e).__name__, error_message=str(e),
          stack_trace=traceback.format_exc())

# Every background job:
log.info("job_started", job_type="email_digest", scheduled_at=scheduled_time)
log.info("job_completed", job_type="email_digest", duration_ms=2300, emails_sent=145)
```

### What to NEVER Log

```python
# NEVER log sensitive data — this is a compliance/security violation:
log.info("user_login", password=password)         # ❌ Never
log.info("payment", card_number=card_number)      # ❌ Never
log.info("user_data", ssn=user.ssn)               # ❌ Never
log.info("request_body", body=request.body)       # ❌ Might contain passwords/tokens

# Safe: log only identifiers and non-sensitive metadata
log.info("user_login", user_id=user.id, method="email")
log.info("payment", masked_card="****1234", amount=2499)
```

---

## Pillar 2 — Distributed Tracing

### The Core Concept

A **trace** is the complete journey of a single request across all services.

A trace is made up of **spans**. A span = one unit of work (one function call, one DB query, one HTTP call). Spans form a tree — child spans nest inside parent spans.

```
Trace ID: abc123  (one unique ID for the entire request)

[API Gateway          ] span: 0ms ──────────────────────── 450ms
  [Auth Service       ]   span: 5ms ──── 25ms
  [Order Service      ]   span: 30ms ───────────────────── 420ms
    [DB: SELECT orders]     span: 32ms ── 45ms
    [Payment Service  ]     span: 50ms ────────────────── 380ms
      [External API   ]       span: 55ms ──────────────── 375ms   ← bottleneck!
    [Cache: SET result]     span: 385ms─ 388ms
    [Notification Svc ]     span: 390ms─ 410ms (async)
```

By looking at this trace, you immediately know:

- Total request took 450ms
- The bottleneck is the External Payment API (320ms)
- Your own code added ~130ms of overhead
- Notification service ran in parallel (async)

Without tracing, you'd have 5 separate log files with no timeline connection.

### Trace ID and Span ID — The Mechanics

```python
# When a request enters your system at the API Gateway:
trace_id = generate_unique_id()   # "abc123" — stays THE SAME for all services
span_id  = generate_unique_id()   # "root001" — unique per service call

# Every log line in this entire request gets trace_id = "abc123"
# This is how you pull all logs for one request across all services

# When Order Service calls Payment Service:
# Order Service passes these headers:
headers = {
    "traceparent": f"00-{trace_id}-{span_id}-01"  # W3C standard header
}

# Payment Service reads this header, creates a new span:
parent_span_id = span_id          # "root001" from Order Service
new_span_id    = "pay001"         # Payment Service's own span ID
# Now the tree: root001 → pay001 (parent-child relationship)
```

**W3C Traceparent header format:**

```
traceparent: 00-{trace_id}-{parent_span_id}-{flags}
             00-abc123456789-root001-01
```

This is the standard. Every service that supports tracing reads and propagates this header. Your job: make sure no service drops this header.

### Implementing Tracing with OpenTelemetry (Python)

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# --- Initialize tracer once at startup ---
provider = TracerProvider()

# OTLPSpanExporter: sends spans to your collector (Jaeger, Tempo, etc.)
# OTLP = OpenTelemetry Protocol — the standard wire format for sending telemetry data
exporter = OTLPSpanExporter(endpoint="http://otel-collector:4317")

# BatchSpanProcessor: buffers spans and sends them in batches for efficiency
provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(provider)

tracer = trace.get_tracer("order-service")
```

```python
# --- Creating spans manually ---
async def place_order(order_data: dict):

    # Start a span for the entire order placement operation
    with tracer.start_as_current_span("place_order") as span:

        # Add attributes — searchable metadata on this span
        span.set_attribute("order.user_id", order_data["user_id"])
        span.set_attribute("order.amount", order_data["amount"])
        span.set_attribute("order.items_count", len(order_data["items"]))

        # Child span for DB operation
        with tracer.start_as_current_span("db.insert_order") as db_span:
            db_span.set_attribute("db.table", "orders")
            db_span.set_attribute("db.operation", "INSERT")
            order = await db.insert_order(order_data)

        # Child span for payment
        with tracer.start_as_current_span("payment.charge") as pay_span:
            pay_span.set_attribute("payment.method", order_data["payment_method"])
            pay_span.set_attribute("payment.amount", order_data["amount"])
            try:
                result = await payment_service.charge(order)
                pay_span.set_attribute("payment.transaction_id", result.id)
                pay_span.set_status(trace.StatusCode.OK)
            except PaymentError as e:
                # Record the error on the span — visible in trace UI
                pay_span.record_exception(e)
                pay_span.set_status(trace.StatusCode.ERROR, str(e))
                raise

        span.set_attribute("order.id", order.id)
        return order
```

### Auto-Instrumentation — The Production Shortcut

Manually wrapping every function is tedious. OpenTelemetry provides **auto-instrumentation** libraries that automatically trace common frameworks (FastAPI, Django, SQLAlchemy, Redis, requests, httpx, etc.) without changing your code.

```bash
pip install opentelemetry-instrumentation-fastapi
pip install opentelemetry-instrumentation-sqlalchemy
pip install opentelemetry-instrumentation-redis
pip install opentelemetry-instrumentation-httpx
```

```python
# --- Auto-instrument at startup — zero code changes to your routes/models ---
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

FastAPIInstrumentor.instrument_app(app)   # All FastAPI routes get spans automatically
SQLAlchemyInstrumentor().instrument()     # All DB queries get spans automatically
RedisInstrumentor().instrument()          # All Redis calls get spans automatically
HTTPXClientInstrumentor().instrument()    # All outgoing HTTP calls get spans
```

This automatically captures:

- Every HTTP request → span
- Every SQLAlchemy query → span with SQL string, table, duration
- Every Redis command → span with command type, key
- Every outgoing HTTP call → span with URL, method, status code

All with correct parent-child relationships. This is what most production systems use.

### Sampling — You Can't Trace Everything

At 10,000 requests/second, storing every trace = enormous storage cost. **Sampling** = only record a fraction of traces.

```python
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased, ParentBased

# --- Sample 10% of all traces ---
sampler = TraceIdRatioBased(0.1)   # 10% sampling rate

# --- ParentBased: if the upstream service sampled this request, we do too ---
# This ensures a trace is either complete (all services) or not sampled at all
sampler = ParentBased(root=TraceIdRatioBased(0.1))

provider = TracerProvider(sampler=sampler)
```

**Head sampling** (above): decide at the start of the request whether to sample it. Simple, but you might sample an uninteresting request and miss an important error.

**Tail sampling:** Collect all spans, then decide at the end whether to store the trace. This lets you always store error traces and slow traces, regardless of rate. More complex — requires a collector that buffers spans.

```yaml
# --- Tail sampling in OpenTelemetry Collector config ---
processors:
  tail_sampling:
    decision_wait: 10s      # Wait 10s for all spans before deciding
    policies:
      - name: always-sample-errors
        type: status_code
        status_code: {status_codes: [ERROR]}   # Always keep error traces

      - name: slow-requests
        type: latency
        latency: {threshold_ms: 1000}          # Always keep traces > 1 second

      - name: sample-rest
        type: probabilistic
        probabilistic: {sampling_percentage: 5} # Keep 5% of everything else
```

In production, tail sampling is the right answer — you keep 100% of errors and slow requests, and sample down the boring healthy traffic.

---

## Pillar 3 — Metrics

### What Metrics Are

A **metric** is a numeric measurement over time. Unlike logs (individual events) and traces (specific requests), metrics are **aggregated** — they tell you "what is the overall system doing right now."

```
HTTP error rate: 0.2%   ← a metric
P99 latency: 450ms      ← a metric
Active DB connections: 87 ← a metric
Orders placed per minute: 340 ← a metric
```

### The Four Core Metric Types

**Counter:** Only goes up. Measures total occurrences.

```python
# Total requests, total errors, total orders placed
http_requests_total = Counter("http_requests_total", "Total HTTP requests",
                               labelnames=["method", "endpoint", "status"])

# Increment on every request
http_requests_total.labels(method="POST", endpoint="/orders", status="200").inc()
```

**Gauge:** Can go up or down. Measures current state.

```python
# Current active connections, current queue size, current memory usage
active_connections = Gauge("db_active_connections", "Current DB connections")

active_connections.set(87)          # Set to current value
active_connections.inc()            # Increment by 1
active_connections.dec()            # Decrement by 1
```

**Histogram:** Measures the **distribution** of values. Tracks how many observations fell into each bucket.

```python
# Request duration, payment amount, response size
request_duration = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration",
    labelnames=["endpoint"],
    # Bucket boundaries — how many requests took < 0.05s, < 0.1s, < 0.5s, etc.
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5]
)

with request_duration.labels(endpoint="/orders").time():
    result = await process_order()
```

From a histogram, you can compute **percentiles**:

- P50 (median): 50% of requests were faster than this
- P95: 95% of requests were faster than this
- P99: 99% of requests were faster than this — the "worst normal" experience

> **Why percentiles matter more than averages:** If 99 requests take 10ms and 1 takes 10 seconds, the average is ~110ms. That looks fine. But P99 = 10 seconds — 1% of your users wait 10 seconds. Average hides outliers. Percentiles expose them.

**Summary:** Like Histogram but computes percentiles on the client side. Less accurate for aggregation across multiple instances — prefer Histogram in production.

### The Four Golden Signals

This is the framework Google SRE (Site Reliability Engineering) uses — monitor these four things for every service:

|Signal|What it measures|Example metric|
|---|---|---|
|**Latency**|How long requests take|P50, P95, P99 of `http_request_duration_seconds`|
|**Traffic**|How much demand there is|`http_requests_total` per second|
|**Errors**|Rate of failed requests|`http_requests_total{status="5xx"}` / total|
|**Saturation**|How full your resources are|CPU %, memory %, DB connection pool usage %|

If you only have time for four dashboards per service, these are them. Any other metric is secondary.

### RED Method for Services

A more practical framework for microservices:

- **R**ate: requests per second
- **E**rror rate: errors per second (or % of requests)
- **D**uration: latency distribution (P50, P95, P99)

```python
# --- All three RED metrics in one middleware ---
from prometheus_client import Counter, Histogram

request_count = Counter("requests_total", "Total requests",
                         ["service", "endpoint", "method", "status"])
request_duration = Histogram("request_duration_seconds", "Request duration",
                              ["service", "endpoint"])

async def metrics_middleware(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    # Rate — count every request
    request_count.labels(
        service="order-service",
        endpoint=request.url.path,
        method=request.method,
        status=str(response.status_code)
    ).inc()

    # Duration
    request_duration.labels(
        service="order-service",
        endpoint=request.url.path
    ).observe(duration)

    # Error Rate is derived from request_count where status starts with 5
    return response
```

### Prometheus — The Standard Metrics Backend

**Prometheus** is the most widely used metrics collection system. It works by **scraping** — periodically pulling metrics from your services via an HTTP endpoint.

```
Your Service → exposes /metrics endpoint (Prometheus format)
Prometheus   → scrapes /metrics every 15 seconds → stores time-series data
Grafana      → queries Prometheus → visualizes dashboards
```

```python
# --- Expose metrics endpoint (FastAPI + prometheus_client) ---
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
```

Prometheus then scrapes this endpoint on its schedule.

**PromQL** — Prometheus Query Language (how you query metrics):

```promql
# Rate of requests per second over last 5 minutes
rate(http_requests_total[5m])

# Error rate as a percentage
rate(http_requests_total{status=~"5.."}[5m])
  /
rate(http_requests_total[5m])
* 100

# P99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Is the error rate above 1%? (used in alerts)
rate(http_requests_total{status=~"5.."}[5m])
  /
rate(http_requests_total[5m])
> 0.01
```

---

## OpenTelemetry — The Unifying Standard

### The Problem Before OpenTelemetry

Before 2019, every vendor had their own instrumentation library:

```
Using Datadog?  → install Datadog agent, use Datadog SDK
Using Jaeger?   → install Jaeger client, use Jaeger SDK
Switching?      → rewrite all instrumentation code
```

This locked companies into vendors. Changing your monitoring tool meant changing your application code.

### What OpenTelemetry Is

**OpenTelemetry (OTel)** is an open standard and set of libraries for generating, collecting, and exporting telemetry data (logs, traces, metrics). It's **vendor-neutral** — instrument once, send to any backend.

```
Your App
  │ OpenTelemetry SDK (one instrumentation library)
  ▼
OTel Collector (receives, processes, exports)
  │
  ├──► Jaeger / Tempo   (traces)
  ├──► Prometheus       (metrics)
  └──► Loki / ELK       (logs)
```

Switch from Jaeger to Tempo? Change one line in the Collector config. Zero application code changes.

### OpenTelemetry Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Your Application                                         │
│                                                           │
│  OTel SDK                                                 │
│  ├── Tracer    → creates spans                            │
│  ├── Meter     → creates metrics                          │
│  └── Logger    → creates log records                      │
│           │                                               │
│           │ OTLP (OpenTelemetry Protocol) over gRPC/HTTP  │
└───────────┼───────────────────────────────────────────────┘
            ▼
┌─────────────────────────────────────────────────────────┐
│  OTel Collector                                           │
│                                                           │
│  Receivers   → accept data (OTLP, Jaeger, Prometheus...) │
│  Processors  → transform (filter, sample, enrich, batch) │
│  Exporters   → send to backends                          │
└─────────────────────────────────────────────────────────┘
            │
            ├──► Grafana Tempo    (traces)
            ├──► Prometheus       (metrics)
            └──► Grafana Loki     (logs)
```

### OTel Collector Config (Production Example)

```yaml
# otel-collector-config.yaml

receivers:
  # Accept telemetry from services via OTLP protocol
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # Also scrape Prometheus metrics from services that expose /metrics
  prometheus:
    config:
      scrape_configs:
        - job_name: 'order-service'
          scrape_interval: 15s
          static_configs:
            - targets: ['order-service:8000']

processors:
  # Batch spans before sending — reduces network overhead
  batch:
    timeout: 5s
    send_batch_size: 512

  # Add metadata to all spans (useful for multi-cluster setups)
  resource:
    attributes:
      - key: environment
        value: production
        action: upsert
      - key: region
        value: ap-south-1
        action: upsert

  # Tail sampling — decide after collecting all spans
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors-policy
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow-policy
        type: latency
        latency: {threshold_ms: 500}
      - name: default-policy
        type: probabilistic
        probabilistic: {sampling_percentage: 10}

exporters:
  # Send traces to Grafana Tempo
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Send metrics to Prometheus
  prometheus:
    endpoint: "0.0.0.0:8889"   # Prometheus scrapes the Collector too

  # Send logs to Grafana Loki
  loki:
    endpoint: http://loki:3100/loki/api/v1/push

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, resource, tail_sampling]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch, resource]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [loki]
```

---

## The Production Stack — How It All Fits Together

### The Grafana LGTM Stack (Most Common in 2024)

The most widely adopted open-source observability stack:

|Component|Role|What it does|
|---|---|---|
|**Loki**|Log storage|Stores logs, indexed by labels not content (cheap)|
|**Grafana**|Visualization|Dashboards, alerts, unified UI for all three pillars|
|**Tempo**|Trace storage|Stores distributed traces|
|**Mimir**|Metrics storage|Long-term Prometheus metrics storage|

```
Services → OTel Collector → Loki    (logs)
                          → Tempo   (traces)
                          → Mimir   (metrics)
                                ↑
                            Grafana (single UI for everything)
```

**Alternative commercial stacks:**

- **Datadog:** All-in-one (logs + traces + metrics), excellent UX, very expensive
- **New Relic:** Similar to Datadog
- **AWS CloudWatch:** If you're fully on AWS, lower ops overhead
- **ELK Stack (Elasticsearch + Logstash + Kibana):** Powerful for logs, but Elasticsearch is expensive to run and maintain

> **What most mid-sized companies use:** OTel SDK in services → OTel Collector → Grafana LGTM stack. It's free, battle-tested, and vendor-neutral. Large companies often use Datadog for convenience despite the cost.

### Correlation — The Key Superpower

The real power of observability is **correlation**: clicking from a log line → to the full trace → to the metrics at that moment.

This works through **Trace ID propagation**:

```python
# In your logging setup, inject trace ID into every log line
import structlog
from opentelemetry import trace

def add_trace_context(logger, method, event_dict):
    """Inject current span's trace_id and span_id into every log line."""
    span = trace.get_current_span()
    if span.is_recording():
        ctx = span.get_span_context()
        event_dict["trace_id"] = format(ctx.trace_id, "032x")
        event_dict["span_id"] = format(ctx.span_id, "016x")
    return event_dict

structlog.configure(
    processors=[
        add_trace_context,   # ← adds trace_id to every log
        structlog.processors.JSONRenderer()
    ]
)
```

Now in Grafana:

1. You see an error log: `trace_id: abc123`
2. Click → jump to that exact trace in Tempo
3. See which span was slowest → click into Order Service's span
4. Jump to Prometheus metrics at that exact timestamp
5. See CPU spiked at that moment → root cause found

Without trace ID in logs, you're manually correlating by timestamp — imprecise and slow.

---

## Grafana — Visualization & Alerting

### Dashboard Design

Don't create dashboards randomly. Layer from high-level to low-level:

```
Level 1: Business Dashboard (non-engineers can read)
─────────────────────────────────────────────────────
Orders per minute | Revenue per hour | Active users | Checkout success rate

Level 2: Service Health Dashboard (on-call engineer)
─────────────────────────────────────────────────────
Error rate per service | P99 latency per service | Requests per second

Level 3: Deep Dive Dashboard (per service)
─────────────────────────────────────────────────────
DB query durations | Cache hit rate | External API latency | Queue depth

Level 4: Infrastructure Dashboard
─────────────────────────────────────────────────────
CPU per pod | Memory per pod | Network I/O | Disk I/O
```

When an incident starts, you look at Level 1 (something is wrong), move to Level 2 (which service), then Level 3 (what specifically), then Level 4 (is it the machine itself).

### Alerting — SLOs and SLAs

**SLA (Service Level Agreement):** A contract with customers — "we guarantee 99.9% uptime." This is external.

**SLO (Service Level Objective):** An internal target — "we aim for P99 latency < 500ms and error rate < 0.1%." This is what you alert on.

**SLI (Service Level Indicator):** The actual measurement — "current error rate is 0.08%." This is the metric.

```yaml
# Grafana alert rule — alert when error rate exceeds SLO
apiVersion: 1
groups:
  - name: order-service-alerts
    rules:
      - alert: HighErrorRate
        # PromQL query — fires when error rate > 1% over 5 minutes
        expr: |
          rate(http_requests_total{service="order-service", status=~"5.."}[5m])
          /
          rate(http_requests_total{service="order-service"}[5m])
          > 0.01
        for: 2m          # Must be true for 2 minutes before alerting (avoids flaps)
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "Order service error rate above 1%"
          description: "Current error rate: {{ $value | humanizePercentage }}"
          runbook_url: "https://wiki.company.com/runbooks/order-service-high-errors"

      - alert: HighP99Latency
        expr: |
          histogram_quantile(0.99,
            rate(http_request_duration_seconds_bucket{service="order-service"}[5m])
          ) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Order service P99 latency above 1 second"
```

> Always include a **runbook URL** in your alert. A runbook is a step-by-step guide for on-call engineers: what this alert means, first 3 things to check, how to mitigate. Alerts without runbooks waste time at 3am.

### Grafana Explore — The Debugging Workflow

Grafana Explore is the ad-hoc debugging interface (no pre-built dashboard needed):

```
1. Alert fires: "Order service P99 latency high"
2. Open Grafana Explore → Tempo data source
   → Search traces by: service=order-service, duration>500ms, status=error
   → Find a slow trace

3. Click the trace → waterfall view
   → Payment Service span = 800ms out of 900ms total
   → Attribute: payment.gateway = "razorpay"

4. Click "Logs for this trace" → jumps to Loki
   → Filter by trace_id
   → See: "PaymentGateway timeout after 800ms, retrying... retry failed"

5. Click "Metrics" → jumps to Prometheus at that timestamp
   → razorpay_api_latency_p99 spiked from 200ms to 800ms at 14:23
   → Conclusion: Razorpay had an outage, not your code
```

This entire workflow: **< 5 minutes** with proper observability. Without it: **hours** of SSH + grep.

---

## Real Production Patterns

### Pattern 1: Correlation ID (Request ID)

Generate a unique ID at the very first entry point (API Gateway or Load Balancer). Propagate it through ALL services via HTTP headers. Log it everywhere.

```python
# API Gateway / First service
import uuid

async def correlation_middleware(request, call_next):
    # Accept if upstream sent it (e.g., from mobile app), else generate
    correlation_id = request.headers.get("X-Correlation-Id") or str(uuid.uuid4())

    # Store for use in this service
    request.state.correlation_id = correlation_id

    # Forward to all downstream calls (add to every outgoing HTTP request)
    response = await call_next(request)

    # Return in response so the client can include it in support tickets
    response.headers["X-Correlation-Id"] = correlation_id
    return response
```

When a user reports an issue, they give you the Correlation ID from their browser's network tab. You search Loki for `correlation_id = "abc-xyz"` and see the complete story across all services.

### Pattern 2: Health Checks — Three Levels

```python
# Level 1: Liveness — "is the process alive?"
# If this fails, Kubernetes restarts the pod
@app.get("/health/live")
async def liveness():
    return {"status": "alive"}

# Level 2: Readiness — "is the service ready to handle traffic?"
# If this fails, Kubernetes removes the pod from the load balancer (but doesn't restart)
@app.get("/health/ready")
async def readiness():
    checks = {}

    try:
        await db.execute("SELECT 1")
        checks["database"] = "ok"
    except Exception as e:
        checks["database"] = f"failed: {e}"

    try:
        await redis.ping()
        checks["cache"] = "ok"
    except Exception as e:
        checks["cache"] = f"failed: {e}"

    all_ok = all(v == "ok" for v in checks.values())
    return JSONResponse(
        {"status": "ready" if all_ok else "degraded", "checks": checks},
        status_code=200 if all_ok else 503
    )

# Level 3: Startup — "has the service finished initializing?"
# Kubernetes won't send traffic until this passes
@app.get("/health/startup")
async def startup():
    if app.state.initialized:
        return {"status": "started"}
    return JSONResponse({"status": "starting"}, status_code=503)
```

### Pattern 3: Circuit Breaker with Metrics

A **circuit breaker** is a pattern that stops calling a failing downstream service, instead returning an error immediately (failing fast) until the service recovers. Like a fuse in your house — if there's a short circuit, the fuse blows rather than burning down the house.

```python
from circuitbreaker import circuit
import prometheus_client

circuit_state = prometheus_client.Gauge(
    "circuit_breaker_state",
    "Circuit breaker state (0=closed/healthy, 1=open/failing)",
    ["service"]
)

@circuit(failure_threshold=5, recovery_timeout=30)
async def call_payment_service(order):
    return await httpx.post("http://payment-service/charge", json=order)

async def process_payment(order):
    try:
        result = await call_payment_service(order)
        circuit_state.labels(service="payment").set(0)   # Closed = healthy
        return result
    except CircuitBreakerError:
        # Circuit is open — payment service is known to be failing
        # Don't waste time trying — fail immediately
        circuit_state.labels(service="payment").set(1)   # Open = failing
        log.warning("circuit_breaker_open", service="payment", order_id=order.id)
        raise ServiceUnavailableError("Payment service is temporarily unavailable")
```

Now your Grafana dashboard shows circuit breaker state per service — you can see at a glance which dependencies are failing.

### Pattern 4: SLO-Based Alerting (Error Budgets)

**Error budget:** If your SLO is 99.9% uptime, you're allowed 0.1% downtime = ~43 minutes/month. This is your "error budget." When it's exhausted, freeze feature releases and focus on reliability.

```promql
# Error budget consumption rate
# If this is > 1.0, you're consuming budget faster than it refills
(
  1 - (
    rate(http_requests_total{status!~"5.."}[1h])
    /
    rate(http_requests_total[1h])
  )
) / (1 - 0.999)   # 0.999 = 99.9% SLO

# Alert when burning through budget 14x faster than allowed (will exhaust in ~2 days)
> 14
```

This is Google's SRE alerting philosophy — alert on budget burn rate, not just raw error rate. Prevents alert fatigue (doesn't fire for a 30-second blip) while ensuring real problems are caught.

### Pattern 5: Exemplars — Linking Metrics to Traces

**Exemplar:** A specific trace ID attached to a metric observation. When you see a P99 spike in Grafana, you can click the spike and jump directly to a real slow trace from that moment.

```python
from prometheus_client import Histogram
from opentelemetry import trace

request_duration = Histogram("http_request_duration_seconds", "Request duration",
                              labelnames=["endpoint"])

async def request_middleware(request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    # Attach current trace ID as an exemplar to this histogram observation
    span = trace.get_current_span()
    if span.is_recording():
        ctx = span.get_span_context()
        trace_id = format(ctx.trace_id, "032x")

        request_duration.labels(endpoint=request.url.path).observe(
            duration,
            exemplar={"trace_id": trace_id}   # ← the link
        )
    else:
        request_duration.labels(endpoint=request.url.path).observe(duration)
```

In Grafana: see P99 spike → click the spike → see the exemplar trace ID → click → jump to Tempo → see the slow trace. One-click root cause.

---

## Interview Questions Answered

**Q: What is the difference between logs, traces, and metrics?**

> Metrics tell you _something is wrong_ (aggregate numbers over time). Logs tell you _what happened_ (individual events with context). Traces tell you _where it went wrong_ (the full journey of a specific request across services). You need all three — they answer different questions.

**Q: What is distributed tracing and why do you need it?**

> In microservices, a single user request touches many services. Distributed tracing assigns a single Trace ID to the request and propagates it through every service. Each service records a span (its piece of work). You get a complete waterfall view showing timing and dependencies across all services — impossible to get from logs alone.

**Q: What is OpenTelemetry?**

> A vendor-neutral, open standard for instrumentation. You write instrumentation code once using the OTel SDK, and the OTel Collector routes data to any backend (Jaeger, Datadog, Prometheus, etc.). Prevents vendor lock-in. It's now the industry standard — most monitoring vendors accept OTLP (OpenTelemetry Protocol) directly.

**Q: What is sampling in tracing and what are the trade-offs?**

> At high traffic, storing every trace is too expensive. Sampling means only recording a fraction. Head sampling decides at request start (simple, but might miss important errors). Tail sampling collects all spans then decides at the end — lets you keep 100% of errors and slow traces while dropping routine healthy traffic. Tail sampling is the production-grade answer.

**Q: How do you set up alerting? What is an SLO?**

> An SLO (Service Level Objective) is an internal target (e.g., error rate < 0.1%, P99 < 500ms). You write PromQL queries that evaluate your metrics against these targets and fire alerts when breached. Good alerts include: severity label, for clause (prevent flaps), runbook URL, and clear description with current value.

**Q: What is structured logging and why does it matter?**

> Structured logging emits logs as JSON with named fields instead of plain text. This makes logs machine-queryable — you can filter by `user_id`, `order_id`, `error_code` instantly across millions of log lines. Plain text requires regex and is slow. At production scale, structured logging is non-negotiable.

**Q: How do you correlate logs and traces?**

> Inject the current span's `trace_id` and `span_id` into every log line via a logging middleware/processor. All logs for a request across all services share the same `trace_id`. In Grafana, search Loki logs by `trace_id` → click → jump to Tempo trace. The log and trace must be emitted by the same OTel SDK that manages the current span context.

**Q: What is a Dead Letter Queue / Topic in the context of observability?**

> When a message fails processing after N retries, send it to a DLT instead of blocking the queue. The DLT should emit an alert metric and generate a log with full context (original message, error details, retry count). This separates "messages we couldn't handle" from "messages we haven't processed yet" — critical for debugging data pipeline issues.

**Q: What are the four golden signals?**

> Latency (how long requests take), Traffic (request rate), Errors (error rate), Saturation (resource fullness). From Google SRE. If you monitor nothing else, monitor these four per service.

**Q: How do you handle PII (Personally Identifiable Information) in logs?**

> Never log raw PII. Mask at the source before logging: use the last 4 digits of card numbers, log user IDs not email/phone, hash or redact sensitive fields. Add automated scanning (e.g., Datadog's Sensitive Data Scanner, or a custom log processor) to detect and redact PII that slips through. Compliance regulations (GDPR, India's DPDP Act) make this a legal requirement, not just best practice.

---

## Decision Guide — What to Use When

### Choosing a Logging Backend

|Scale|Choice|Why|
|---|---|---|
|Small (< 1M logs/day)|**Grafana Loki**|Cheap, simple, integrates with Grafana|
|Medium|**Loki or Elasticsearch**|Elasticsearch is more powerful but expensive|
|Large (billions/day)|**Clickhouse + custom** or **Datadog**|Clickhouse handles enormous query throughput|
|Fully on AWS|**CloudWatch Logs**|Zero ops overhead|

### Choosing a Tracing Backend

|Choice|Best for|
|---|---|
|**Grafana Tempo**|Best open-source option, integrates with Loki/Grafana|
|**Jaeger**|Older, battle-tested, good UI|
|**AWS X-Ray**|If fully on AWS|
|**Datadog APM**|If using Datadog (expensive but excellent)|

### When to Start Caring About Each Pillar

```
1 service / 1 developer:
  → Basic logging (structured) + health check endpoint. That's it.

3-5 services / small team:
  → Structured logs in Loki + Grafana dashboards + basic alerting
  → Add tracing when debugging becomes painful

5-20 services / growing team:
  → Full LGTM stack (Loki + Grafana + Tempo + Mimir)
  → OTel auto-instrumentation
  → SLO-based alerting
  → Correlation ID propagation

20+ services / multiple teams:
  → Centralized OTel Collector fleet
  → Tail sampling
  → Per-team dashboards with shared infrastructure dashboards
  → Error budget tracking
  → Consider commercial solution (Datadog) for reduced ops burden
```

### The Minimum Viable Observability Checklist

Before going to production, every service should have:

- [ ] Structured JSON logging with request context
- [ ] Trace ID injected into every log line
- [ ] OTel auto-instrumentation (HTTP, DB, Redis, external calls)
- [ ] `/metrics` endpoint with RED metrics
- [ ] `/health/live` and `/health/ready` endpoints
- [ ] Correlation ID header accepted and forwarded
- [ ] PII scrubbed from logs
- [ ] Alert on error rate > threshold
- [ ] Alert on P99 latency > threshold
- [ ] Dashboard with four golden signals
- [ ] Runbook for each alert

---

_See also: [[Redis - Complete Guide]] | [[Kafka - Complete Guide]]_