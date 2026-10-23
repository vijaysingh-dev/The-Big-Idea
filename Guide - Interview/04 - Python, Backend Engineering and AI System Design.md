**Up:** [[00 - Index (Interview)]] | **Prev:** [[03 - Agentic AI and Production LLMOps]]

---

# 04 — Python, Backend Engineering and AI System Design

> Python internals and asyncio, the FastAPI request lifecycle, API and database design including pagination, resilience, testing, and AI system design.

---

## Section A: Python internals

### Q1. What is the GIL? How does it affect threads, processes and asyncio?

**Answer**
The **GIL (Global Interpreter Lock)** in CPython (the standard Python implementation) is a lock that lets only **one thread run Python bytecode at a time** in a process. It exists mainly to keep CPython's reference-counting memory management simple and safe.

Consequences:
- **I/O-bound work** (HTTP calls, database queries, LLM API calls): threads work fine, because the GIL is **released while waiting on I/O**. asyncio also works well here, with lower overhead.
- **CPU-bound pure-Python work** (heavy loops, parsing): threads don't run in parallel. Use **multiprocessing** or `ProcessPoolExecutor` (separate processes, each with its own GIL), or push the work into C-backed libraries. NumPy, PyTorch and many others release the GIL inside their heavy native code.
- **Choosing:**
  - **asyncio:** many concurrent I/O tasks (thousands of sockets) on one thread.
  - **Threads:** I/O with blocking libraries, or simpler code.
  - **Processes:** CPU-bound parallelism.

**Recent change:** PEP 703 added an optional **free-threaded (no-GIL) build**: experimental in Python 3.13, with official support continuing in 3.14. It isn't the default yet, and C extensions need to support it. Worth mentioning; don't overstate it.

**Likely follow-ups**
- *Does the GIL make my code thread-safe?* No. It protects the interpreter's internals, not your logic. `counter += 1` is several bytecode steps and can still race between threads. Use locks or thread-safe structures.

**What a strong answer shows:** You choose a concurrency model based on whether the work is I/O-bound or CPU-bound, and you know the GIL doesn't give you thread safety.

**Go deeper:** [[01.2 - The GIL]] · [[01.8 - Offloading Work]]

---

### Q2. How does asyncio work? What are the common pitfalls?

**Answer**
- **Event loop:** a single-threaded scheduler that runs tasks and watches I/O (sockets, timers).
- **Coroutine (`async def`):** a function that can pause at `await` points. When it awaits I/O, it yields control, and the loop runs other tasks until the I/O is ready.
- **Task:** a coroutine scheduled to run concurrently (`asyncio.create_task`).
- It's **cooperative multitasking:** tasks only switch at `await` points.

Common tools:
- `asyncio.gather(*coros)` runs coroutines concurrently and collects the results.
- `asyncio.TaskGroup` (3.11+) does the same with **structured concurrency**: if one task fails, the others are cancelled and the errors are raised together. Prefer it for new code.
- `asyncio.timeout(...)` (3.11+) or `wait_for` for timeouts.
- `asyncio.Semaphore(n)` limits concurrency (e.g. at most 10 LLM calls at once).
- `asyncio.Queue` for producer/consumer pipelines.
- `asyncio.to_thread(fn, ...)` runs a blocking function in a thread without blocking the loop.

**Pitfalls:**
- **Blocking the event loop:** calling `requests.get`, `time.sleep`, a sync database driver or heavy CPU work inside `async def` freezes *every* request on that worker. Use async libraries (`httpx`, `asyncpg`, async SDK clients) or `to_thread`.
- **Forgetting `await`:** the coroutine never runs, and you get a "coroutine was never awaited" warning.
- **Fire-and-forget tasks** that get garbage-collected or swallow exceptions. Keep references, or use TaskGroups.
- **Unbounded `gather`** over 10k items: hits rate limits and exhausts memory. Bound it with a Semaphore.
- **Cancellation:** `CancelledError` must be allowed to propagate. Clean up in `finally`, and don't swallow it with a bare `except`.

**Likely follow-ups**
- *How would you call an LLM for 5,000 documents efficiently?* An async client, a Semaphore sized to your rate limit, retries with backoff + jitter, batching where the API supports it, and progress checkpoints so you can resume. Or use the provider's batch API if latency doesn't matter.

**What a strong answer shows:** You understand cooperative scheduling, and you can name the blocking-call pitfall immediately.

**Go deeper:** [[01.3 - Threads Processes and Coroutines]] · [[01.6 - The Blocking Call Problem]] · [[01.7 - Cancellation and Structured Concurrency]] · [[01.11 - Backpressure Inside One Process]]

---

### Q3. What exactly are a coroutine, a Task, a Future and the event loop? What happens under the hood when you `await`?

**Answer**

Four pieces, each with one job:

| Piece | What it is | Job |
|---|---|---|
| **Coroutine function** | `async def fetch(): ...` | A factory. Calling it **runs nothing**. It returns a coroutine object |
| **Coroutine object** | `fetch()` | A **paused, resumable function frame**: local variables plus the position where it stopped. Built on the same machinery as generators |
| **Future** | `asyncio.Future` | A **placeholder for a result that doesn't exist yet**, plus a list of callbacks to run when it's set |
| **Task** | `asyncio.create_task(coro)` | A Future that **drives a coroutine**: it steps the coroutine forward until it pauses, and wakes it again when the thing it's waiting for is done |
| **Event loop** | `asyncio.get_running_loop()` | A single-threaded **scheduler**: a queue of ready callbacks, a heap of timers, and an OS **selector** (epoll/kqueue) watching sockets |

**What one `await` really does:**

```
1. Your coroutine hits:  data = await reader.read(1024)
2. No data yet, so the read creates a Future and the await chain YIELDS that Future
   up through every awaiting coroutine to the Task at the top.
3. The Task sees "waiting on Future F" → calls F.add_done_callback(task.__step) and returns.
   Your coroutine is now frozen, mid-function, holding no thread.
4. The loop registers the socket with epoll and goes on running OTHER ready tasks.
5. Bytes arrive → epoll says the socket is readable → the loop sets F's result.
6. F runs its callbacks → task.__step is scheduled on the ready queue.
7. Next loop iteration: the Task calls coro.send(result) → your coroutine resumes on the
   line after the await, with `data` filled in.
```

**The event loop, in essence** (this is what `asyncio`'s `_run_once` does):

```python
while True:
    timeout = time_until_next_timer() if not ready else 0
    for fd, event in selector.select(timeout):     # sleep in the OS until I/O or a timer
        ready.append(callback_for(fd, event))       # I/O is ready → its callback becomes runnable
    ready.extend(pop_expired_timers())              # asyncio.sleep / call_later
    for _ in range(len(ready)):
        ready.popleft()()                           # run each callback: usually task.__step
```

**Coroutines are generators underneath.** You can drive one by hand:

```python
class Wait:                        # a minimal awaitable: yields itself to whoever drives us
    def __await__(self):
        value = yield self         # pause here; resume with whatever send() passes in
        return value

async def worker():
    print("start")
    x = await Wait()               # suspends: control goes back to the driver
    print("got", x)
    return x * 2

coro = worker()                    # nothing printed yet: calling only creates the object
coro.send(None)                    # prints "start", runs until the first await, returns the Wait
try:
    coro.send(21)                  # resumes: prints "got 21"
except StopIteration as e:
    print("result", e.value)       # result 42: the return value rides on StopIteration
```

A Task is essentially that `send` loop, written to cooperate with Futures and the selector.

**`await` vs `create_task`: sequential vs concurrent**

```python
import asyncio, time

async def call(name, secs):
    await asyncio.sleep(secs)              # stands in for a network call
    return name

async def sequential():
    a = await call("a", 1)                 # waits 1 s
    b = await call("b", 1)                 # THEN waits 1 s → 2 s total
    return a, b

async def concurrent():
    async with asyncio.TaskGroup() as tg:  # 3.11+: structured, cancels siblings on error
        ta = tg.create_task(call("a", 1))  # both scheduled immediately
        tb = tg.create_task(call("b", 1))
    return ta.result(), tb.result()        # ~1 s total

start = time.perf_counter(); asyncio.run(sequential()); print(f"{time.perf_counter()-start:.1f}s")  # 2.0s
start = time.perf_counter(); asyncio.run(concurrent()); print(f"{time.perf_counter()-start:.1f}s")  # 1.0s
```

`await coro` runs the coroutine **inline**, as part of the current task. Only `create_task` (or `gather`, or a TaskGroup) creates **new concurrent work**.

**Concurrency, not parallelism:** one loop runs on one thread, so only one coroutine executes Python code at any instant. Thousands can be *waiting* at once, which is why asyncio suits I/O-bound work (sockets, DB, LLM APIs) and not CPU-bound work.

**Likely follow-ups**
- *What if a coroutine never awaits anything that actually suspends?* It never yields, so it hogs the loop until it finishes. The same thing happens with a long CPU loop or a blocking call. Cooperative means *you* must yield.
- *What's uvloop?* A drop-in event loop implemented on libuv (the library under Node.js). Same semantics, typically 2–4× faster loop overhead. `uvicorn[standard]` uses it.
- *How is state passed per request without globals?* `contextvars`. Each Task gets a copy of the context when it's created, so a request ID set in middleware is visible in that request's coroutines only.
- *Thread vs coroutine cost?* A thread: an OS-scheduled stack of around 8 MB virtual memory, with preemptive switching anywhere. A coroutine: a small heap-allocated frame (around 1–2 KB), switching only at `await`. That's why you can have 100k coroutines but not 100k threads.

**What a strong answer shows:** You can explain suspension mechanically (the Future yielded up to the Task, the callback, `send`), you know `await` vs `create_task`, and you connect it to why blocking calls are fatal.

**Go deeper:** [[01.4 - Building an Event Loop From Scratch]] (build exactly the loop above, in 150 lines) · [[01.5 - Coroutines Tasks and Futures]] · [[01.3 - Threads Processes and Coroutines]]

**Resource:** [Python docs — Coroutines and Tasks](https://docs.python.org/3/library/asyncio-task.html), plus David Beazley's PyCon talk *"Python Concurrency From the Ground Up: LIVE!"*, which builds an event loop from sockets and generators while you watch.

---

### Q4. Explain generators and why they matter for backend and AI work.

**Answer**
A **generator** (a function with `yield`) produces values **lazily**, one at a time, keeping its state between them. It's an iterator, so it doesn't build the whole result in memory.

Why it matters:
- **Memory:** process a 10 GB file line by line, or stream database rows, without loading everything.
- **Pipelines:** chain generators (read → parse → filter → batch) for clean, composable data processing.
- **Streaming responses:** FastAPI's `StreamingResponse` accepts a generator (or an async generator), which is how you stream LLM tokens to clients.
- **Async generators** (`async def` with `yield`) stream from async sources, e.g. relaying tokens from an LLM SDK.
- `yield from` delegates to a sub-generator.

Related: `itertools` (`islice`, `chain`, and `batched` in 3.12+) and generator expressions `(x for x in ...)`.

**What a strong answer shows:** You connect laziness to real memory and streaming use cases.

**Go deeper:** [[01.4 - Building an Event Loop From Scratch]] (generators are what coroutines are built on)

---

### Q5. How do decorators and context managers work? Give production examples.

**Answer**
- **Decorator:** a function that takes a function and returns a new function that wraps it. `@retry` is just `f = retry(f)`. Use `functools.wraps` to keep the name and docstring.
  - Decorators with arguments (`@retry(max_attempts=3)`) are a function that *returns* a decorator.
  - Examples: retry with backoff, timing and metrics, caching (`functools.lru_cache`), auth checks, tracing spans, FastAPI's `@app.get`.
- **Context manager:** an object with `__enter__`/`__exit__` (or `@contextlib.contextmanager` around a generator) that guarantees setup and teardown, even when an exception occurs.
  - `async with` uses `__aenter__`/`__aexit__`.
  - Examples: database transactions (commit or rollback), locks, files, temporary configuration, tracing spans, an `httpx.AsyncClient` lifecycle.

**What a strong answer shows:** Fluency with Python's tools for cross-cutting concerns.

**Go deeper:** [[02.7 - Decorator]] · [[01.7 - Cancellation and Structured Concurrency]] (context managers and cleanup)

---

### Q6. How does Python manage memory? What are the classic gotchas?

**Answer**
- **Reference counting:** each object counts the references to it, and is freed immediately when the count hits 0.
- **Cyclic garbage collector:** finds and frees reference cycles (A → B → A) that refcounting alone can't free.
- Memory released inside the process is often **not returned to the operating system** right away, so long-running workers can look like they're "leaking". Use worker recycling (e.g. a max-requests setting) for safety.

Gotchas:
- **Mutable default arguments:** `def f(items=[])` shares *one* list across all calls. Use `None` and create the list inside.
- **`is` vs. `==`:** `is` checks identity (the same object); `==` checks equality. Use `is` only for `None` and singletons.
- **Late-binding closures:** lambdas created in a loop all capture the *variable*, not its value at the time.
- **Caches that grow without bound** in global dicts: a real memory leak. Use LRU limits or TTLs.
- **Copying:** shallow `copy` vs. `deepcopy` for nested structures.

**What a strong answer shows:** Solid fundamentals, plus awareness of the issues that actually happen in long-running services.

**Go deeper:** [[01.1 - How Python Actually Runs Your Code]]

---

### Q7. Dataclasses vs. Pydantic vs. TypedDict. Protocol vs. ABC. When do you use each?

**Answer**
- **`dataclass`:** lightweight containers for internal data, with no runtime validation. Fast and simple. Use `frozen=True` for immutability.
- **Pydantic `BaseModel`:** **validates and converts at runtime**, serialises to and from JSON, and generates JSON Schema. Use it at **boundaries**: API requests and responses, configuration (`pydantic-settings`), LLM structured outputs, messages from queues.
  - Pydantic v2 has a Rust core and is fast.
  - Validators: `field_validator`, `model_validator`.
- **`TypedDict`:** type hints for plain dicts, with no runtime cost or validation. Good for JSON-like data passed between functions, and for LangGraph state.
- **`ABC` (abstract base class):** **nominal** typing. Classes must explicitly inherit, and abstract methods are enforced when you instantiate.
- **`Protocol`:** **structural** typing (static "duck typing"). Any class with matching methods satisfies it, without inheriting. Great for defining interfaces like `Embedder` or `LLMClient` that third-party classes or test fakes can satisfy.

**Likely follow-ups**
- *Do you use type hints everywhere?* Yes, at public interfaces at least. Run **mypy** or **pyright** in CI. Hints are documentation that tools can check, and they make refactoring safer.

**What a strong answer shows:** Picking tools by where validation and coupling are needed.

**Go deeper:** [[06 - Design Principles and Patterns#Q1. Explain the SOLID principles with real examples.]] (Protocol for ISP)

---

## Section B: FastAPI and APIs

### Q8. How does FastAPI work under the hood? What's the difference between `def` and `async def` endpoints?

**Answer**
- FastAPI is built on **Starlette**, an **ASGI** framework. ASGI (Asynchronous Server Gateway Interface) is the async successor to WSGI, the standard interface between Python web servers and apps.
- It uses **Pydantic** for request validation, response serialisation and automatic OpenAPI docs.
- It runs under an ASGI server like **Uvicorn**, often with multiple worker processes behind Gunicorn or in containers.

**`async def` vs. `def`:**
- `async def` endpoints run **on the event loop**. They must only use non-blocking (async) I/O. A blocking call inside one stalls *all* requests on that worker.
- Plain `def` endpoints run in a **threadpool**, so blocking code doesn't freeze the loop. But the threadpool is limited in size (around 40 threads by default), so it can become a bottleneck.
- **Rule:** use async libraries and `async def` for I/O-heavy endpoints (LLM calls, HTTP calls, async database drivers). Use `def` when you must call blocking libraries. Never call blocking code inside `async def`.

**Likely follow-ups**
- *How do you scale FastAPI?* Multiple worker processes (one event loop each) per container; horizontal scaling behind a load balancer; keep the app stateless (state in a database or Redis); move CPU-heavy work to background workers.

**What a strong answer shows:** A precise understanding of the blocking-call trap: the most common FastAPI production bug.

**Go deeper:** [[01.9 - ASGI and How Uvicorn Serves a Request]] · [[01.8 - Offloading Work]] · [[01.6 - The Blocking Call Problem]]

---

### Q9. Walk me through what happens to a request in a FastAPI service, from the client to the response.

**Answer**

Split it into three bands, and say that each hop has a **timeout**, a **queue** and a **failure mode**:

```
CLIENT → EDGE
  DNS → TCP handshake → TLS handshake (keep-alive skips these on reused connections)
  → CDN/WAF → load balancer / ingress: terminates TLS, picks a healthy pod,
    adds X-Forwarded-For/Proto → (optional) nginx: body limits, buffering, timeouts

SERVER (uvicorn)
  kernel accept queue (--backlog) → uvicorn worker's event loop accepts
  → parses HTTP (httptools/h11) → builds the ASGI scope dict
  → starts a Task running app(scope, receive, send)

FRAMEWORK (Starlette → FastAPI)
  ServerErrorMiddleware (outermost, → 500)
    → your middleware (last added = outermost)
      → ExceptionMiddleware (HTTPException → response)
        → Router: FULL match → handle · path-only match → 405 · none → 404
          → FastAPI route handler:
              1. read and parse the body           (malformed JSON → 422)
              2. solve the Depends() graph         (cached per request; yield deps opened)
              3. validate path/query/header/body with Pydantic (all errors → one 422)
              4. call the endpoint: async def → awaited on the loop
                                    def       → anyio threadpool (40 threads by default)
              5. validate + filter the return value against response_model (mismatch → 500)
              6. serialize to JSON → JSONResponse
  → send(http.response.start) + send(http.response.body) → uvicorn writes bytes
  → BackgroundTasks run (same worker, not durable) → yield-dependency teardown
  → keep-alive: the connection waits for the next request
```

**Code: one endpoint that touches every FastAPI step**

```python
from contextlib import asynccontextmanager

import asyncpg
from fastapi import BackgroundTasks, Depends, FastAPI, HTTPException, Request
from pydantic import BaseModel


@asynccontextmanager
async def lifespan(app: FastAPI):                     # startup: pools created ONCE per process
    app.state.pool = await asyncpg.create_pool(DSN, max_size=20)
    yield
    await app.state.pool.close()

app = FastAPI(lifespan=lifespan)


async def get_conn(request: Request):                 # yield dependency: setup + teardown
    async with request.app.state.pool.acquire() as conn:
        yield conn


async def current_user(request: Request, conn=Depends(get_conn)):   # nested dependency
    user = await conn.fetchrow("SELECT id, name FROM users WHERE token = $1",
                               request.headers.get("authorization", ""))
    if not user:
        raise HTTPException(401)                      # → ExceptionMiddleware → 401
    return user


class NoteIn(BaseModel):
    text: str

class NoteOut(BaseModel):                             # allow-list: only these fields leave
    id: int
    text: str


@app.post("/notes", response_model=NoteOut, status_code=201)
async def create_note(
    body: NoteIn,                                     # step 1 + 3: parsed and validated
    background: BackgroundTasks,
    user=Depends(current_user),                       # step 2: get_conn resolved once, shared
    conn=Depends(get_conn),
):
    row = await conn.fetchrow(                        # step 4: async I/O on the loop
        "INSERT INTO notes (user_id, text) VALUES ($1, $2) RETURNING id, text, internal_flag",
        user["id"], body.text)
    background.add_task(audit_log, user["id"], row["id"])   # runs after the response is sent
    return dict(row)                                  # step 5: internal_flag filtered out
```

**What bites in production (say two or three of these):**
- A **blocking call in `async def`** stalls every request on the worker, including health checks.
- **Threadpool saturation** with slow `def` endpoints: requests queue *before* your code runs, so your handler timers look fine.
- **Pool exhaustion**: pool size × workers × pods is more than the DB allows.
- **Keep-alive mismatch**: if the LB's idle timeout is longer than uvicorn's (5 s by default), you get random 502s. Set the app's keep-alive higher than the LB's.
- **Proxy buffering** breaks SSE and streaming. **Timeouts that don't shrink inward** mean the proxy returns a 504 while the handler keeps running.
- **Middleware order** is the reverse of `add_middleware`. Put CORS outermost.

**Likely follow-ups**
- *Where is the request body actually read?* Only when something awaits `request.body()`/`.json()`. FastAPI does it before dependencies run if a body parameter is declared. It isn't in `scope`. It arrives through ASGI `receive()`.
- *Is `BackgroundTasks` a job queue?* No. It runs in the same process after the response, with no retries or persistence. Anything that must happen goes to Celery, arq or a broker.
- *How many concurrent requests can one worker hold?* For async I/O, thousands, bounded by `--limit-concurrency`, memory and downstream pools. For `def` endpoints, about 40 at a time, set by the anyio limiter.

**What a strong answer shows:** You know the hops outside Python, the ASGI contract, and FastAPI's own steps (DI caching, 422 vs 500, the threadpool fork), and you can name where each one fails in production.

**Go deeper:** [[01.13 - FastAPI Request Lifecycle End to End]] (the full version, with a debugging map) · [[01.9 - ASGI and How Uvicorn Serves a Request]] · [[15.3 - Reading Uvicorn and Starlette]] · [[03.10 - Proxies and Load Balancers]] · [[03.11 - Timeouts and Deadlines Across Hops]]

**Resource:** [FastAPI source: `fastapi/routing.py`](https://github.com/fastapi/fastapi/blob/master/fastapi/routing.py). `get_request_handler` *is* the FastAPI part of the lifecycle, and it's short. See also the [ASGI spec](https://asgi.readthedocs.io/en/latest/specs/main.html).

---

### Q10. How does dependency injection work in FastAPI? What about app lifecycle?

**Answer**
- **`Depends`:** declare what an endpoint needs (a DB session, the current user, a settings object, an LLM client). FastAPI resolves it per request, caching it within that request. Dependencies can depend on other dependencies.
- **Generator dependencies with `yield`:** setup before the `yield`, teardown after. Perfect for DB sessions (commit or rollback, then close).
- **Testability:** override dependencies in tests with `app.dependency_overrides[get_llm] = fake_llm`.
- **Lifespan:** use the `lifespan` async context manager to create expensive shared resources once at startup and close them at shutdown: HTTP clients, connection pools, ML models loaded into memory, vector index handles. Don't create a new `httpx.AsyncClient` per request.

**What a strong answer shows:** Clean resource management and testable design.

**Go deeper:** [[01.13 - FastAPI Request Lifecycle End to End#Step 2 — Solve the dependency graph]] · [[01.10 - Connection Pools and Limits]]

---

### Q11. How would you stream LLM responses to a frontend? SSE vs. WebSockets?

**Answer**
- **SSE (Server-Sent Events):**
  - One-way, server → client, over plain HTTP (`text/event-stream`).
  - Simple, works with proxies and load balancers, and the browser reconnects automatically.
  - **The default for LLM token streaming** (it's what most LLM APIs use).
  - In FastAPI: `StreamingResponse` with an async generator yielding `data: ...\n\n` lines.
- **WebSockets:**
  - Full-duplex: both sides send at any time.
  - Use them when the client must send messages mid-stream (real-time collaboration, voice, interrupting the agent).
  - More complex: connection state, scaling with sticky sessions or pub/sub.

Practical concerns:
- **Detect client disconnects** and cancel the upstream LLM call, so you don't pay for tokens nobody reads.
- **Proxy buffering:** disable it (e.g. Nginx `X-Accel-Buffering: no`), or tokens arrive in bursts.
- **Error events mid-stream:** define an event type for errors and a final `done` event.
- **Frontend:** consume with `fetch` + `ReadableStream` (supports POST bodies and auth headers) or `EventSource` (GET only). Append tokens to the UI state efficiently.

**What a strong answer shows:** A clear choice with reasons, plus real-world issues like disconnects and buffering.

**Go deeper:** [[04.1 - Choosing a Realtime Transport]] · [[04.2 - Server Sent Events]] · [[04.4 - Streaming LLM Responses]] · [[WebSocket]]

---

### Q12. What makes a good REST API design?

**Answer**
- **Resource-oriented URLs** (`/users/{id}/orders`), with HTTP methods used correctly: GET is safe; PUT and DELETE are idempotent; POST creates.
- **Correct status codes:** 200/201/204; 400 (bad request), 401 (not authenticated), 403 (not allowed), 404, 409 (conflict), 422 (validation error), 429 (rate limited), 5xx (server errors).
- **A consistent error format:** e.g. `{code, message, details, request_id}` (RFC 9457 "Problem Details" is a standard).
- **Pagination:**
  - *Offset* (`?page=3`) is simple but slow on deep pages, and inconsistent when rows are inserted.
  - *Cursor/keyset* (`?after=<last_id>`) is stable and fast. Prefer it for large or changing data.
- **Idempotency keys** for unsafe POSTs (payments, order creation). The client sends a unique key; the server stores the result and returns the same response on retries.
- **Versioning:** URL (`/v1/`) or headers. Make additive, backward-compatible changes; deprecate with notice.
- **Validation at the edge** (Pydantic), explicit response models (never leak internal fields), and OpenAPI documentation.
- **Rate limiting, auth and request IDs** on every endpoint.
- **Long-running work:** return `202 Accepted` with a job ID, then poll or use a webhook. Don't hold HTTP connections open for minutes.

**What a strong answer shows:** Practical conventions, especially idempotency, pagination and async job patterns.

**Go deeper:** [[05.1 - REST Done Properly]] · [[05.3 - Error Design]] · [[03.4 - Idempotency and Safe Retries]]

---

### Q13. Explain authentication vs. authorisation. JWT vs. sessions. What is OAuth2?

**Answer**
- **Authentication (AuthN):** who are you? **Authorisation (AuthZ):** what are you allowed to do?
- **Server-side sessions:** the server stores session data and the client holds an opaque session ID cookie. Easy to revoke, but it needs a shared session store when scaling.
- **JWT (JSON Web Token):** a signed token that contains claims (user ID, roles, expiry). The server can verify it **without a database lookup**, so it's stateless and scales well.
  - Downsides: hard to revoke before expiry.
  - Mitigations: short-lived access tokens plus refresh tokens with rotation; keep tokens out of `localStorage` where XSS can read them (prefer httpOnly cookies, or memory plus a refresh cookie); never put secrets in the payload, since it's only encoded, not encrypted.
- **OAuth2:** a **delegation** framework that lets an app access resources *on a user's behalf* without their password.
  - The **Authorization Code flow with PKCE** is the standard for web and mobile apps. PKCE (Proof Key for Code Exchange) stops intercepted authorization codes from being reused.
  - **Client Credentials** is for service-to-service calls.
- **OpenID Connect (OIDC):** an identity layer on top of OAuth2 that provides an ID token: login with Google or Okta.
- **AuthZ models:** RBAC (role-based) and ABAC (attribute-based). Always enforce authorisation **on the server**, at the resource level. In RAG systems, enforce it at retrieval (Part 2).

**What a strong answer shows:** You don't mix up AuthN and AuthZ, and you know JWT's revocation tradeoff.

**Go deeper:** [[14.1 - AuthN vs AuthZ]] · [[14.2 - Sessions Tokens and Rotation]] · [[14.3 - OAuth2 and OIDC]]

---

## Section C: Data and storage

### Q14. What database fundamentals should a senior backend engineer know?

**Answer**
- **Indexes:**
  - A B-tree index speeds up equality and range lookups, at the cost of slower writes and extra storage.
  - **Composite index column order matters** (leftmost prefix rule): an index on (a, b) helps queries on `a` or `a, b`, not `b` alone.
  - Use `EXPLAIN ANALYZE` to check that queries actually use indexes.
- **The N+1 query problem:** fetching a list, then running one query per item. Fix it with joins or eager loading (`selectinload`/`joinedload` in SQLAlchemy).
- **Transactions and ACID:** Atomicity, Consistency, Isolation, Durability.
- **Isolation levels:** Read Committed (Postgres's default), Repeatable Read, Serializable. Higher levels prevent more anomalies (non-repeatable reads, phantoms, lost updates) at the cost of more conflicts and retries.
- **Locking:** `SELECT ... FOR UPDATE` (pessimistic) vs. optimistic locking with a version column.
- **Connection pooling:** opening database connections is expensive, so pool them (SQLAlchemy pool, PgBouncer). Size pools against the database's max connections × the number of workers.
- **Migrations:** Alembic. Make them backward-compatible for zero-downtime deploys (expand → migrate → contract). Add columns as nullable first; build big indexes `CONCURRENTLY`.
- **SQL vs. NoSQL:** SQL for relational integrity and flexible queries; document or key-value stores for specific access patterns, massive scale, or flexible schemas.

**What a strong answer shows:** Practical fluency with performance and correctness: indexes, N+1, transactions, pooling.

**Go deeper:** [[06.3 - Indexes Deep Dive]] · [[06.6 - Transactions and Isolation Levels]] · [[06.8 - Locking and Deadlocks]] · [[06.17 - Database Anti Patterns]] · for "optimize a DB at 10M req/s" see [[05 - System Design and Distributed Systems#Q7. Your DB-backed API serves 10M requests/second and responses take 5 seconds. How do you optimize it?]] and [[06.18 - Fixing a Slow Database at Scale]]

---

### Q15. How do you implement pagination, on both the API side and the database side?

**Answer**

**Two strategies, and the database is why one wins:**

| | Offset / limit | Cursor (keyset / seek) |
|---|---|---|
| API | `?page=500&size=20` or `?offset=9980&limit=20` | `?limit=20&cursor=eyJjIjoi...` |
| SQL | `ORDER BY created_at DESC LIMIT 20 OFFSET 9980` | `WHERE (created_at, id) < ($1, $2) ORDER BY created_at DESC, id DESC LIMIT 20` |
| DB work per page | Reads **offset + limit** rows and throws away the offset. Page 500 reads 10,000 rows | Index seek straight to the position, then reads **limit** rows. **Same cost on every page** |
| Consistency while data changes | Inserts and deletes shift every page: **duplicates and skipped rows** | Stable: the cursor is a position in the data, not a count |
| Jump to page N / total pages | Easy | Not possible (only next/previous) |
| Good for | Admin tables, small datasets, "page 3 of 12" UIs | Feeds, APIs, infinite scroll, exports, anything large or changing |

**Database side: the three things that make keyset pagination work**

1. **A deterministic sort with a unique tiebreaker.** `ORDER BY created_at DESC` alone is ambiguous when two rows share a timestamp, and rows get skipped or repeated at page boundaries. Always add `id`.
2. **An index matching the sort exactly**, including any equality filters first:
   ```sql
   CREATE INDEX CONCURRENTLY idx_posts_feed ON posts (author_id, created_at DESC, id DESC);
   ```
3. **A row-value comparison** so Postgres can seek in the index:
   ```sql
   SELECT id, title, created_at
   FROM posts
   WHERE author_id = $1
     AND (created_at, id) < ($2, $3)          -- strictly after the last row of the previous page
   ORDER BY created_at DESC, id DESC
   LIMIT 21;                                  -- limit + 1: the extra row tells you has_more
   ```

`EXPLAIN ANALYZE` shows the difference. Offset at page 5,000 is an `Index Scan` that reads 100k rows, taking tens or hundreds of ms and growing. Keyset at the same position reads 21 rows in under a millisecond.

**API side: opaque cursors and a stable contract**

```python
import base64
import json
from datetime import datetime

from fastapi import Depends, FastAPI, HTTPException, Query
from pydantic import BaseModel

MAX_LIMIT = 100


def encode_cursor(created_at: datetime, id_: int) -> str:
    raw = json.dumps({"c": created_at.isoformat(), "i": id_}).encode()
    return base64.urlsafe_b64encode(raw).decode()


def decode_cursor(cursor: str) -> tuple[datetime, int]:
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor.encode()))
        return datetime.fromisoformat(data["c"]), int(data["i"])
    except Exception:
        raise HTTPException(400, "invalid cursor")


class PostOut(BaseModel):
    id: int
    title: str
    created_at: datetime


class Page(BaseModel):
    items: list[PostOut]
    next_cursor: str | None                  # null = last page
    has_more: bool


@app.get("/authors/{author_id}/posts", response_model=Page)
async def list_posts(
    author_id: int,
    limit: int = Query(20, ge=1, le=MAX_LIMIT),     # always bounded: never let a client ask for 1M
    cursor: str | None = None,
    conn=Depends(get_conn),
):
    if cursor:
        c_at, c_id = decode_cursor(cursor)
        rows = await conn.fetch("""
            SELECT id, title, created_at FROM posts
            WHERE author_id = $1 AND (created_at, id) < ($2, $3)
            ORDER BY created_at DESC, id DESC LIMIT $4""",
            author_id, c_at, c_id, limit + 1)
    else:
        rows = await conn.fetch("""
            SELECT id, title, created_at FROM posts
            WHERE author_id = $1
            ORDER BY created_at DESC, id DESC LIMIT $2""",
            author_id, limit + 1)

    has_more = len(rows) > limit
    rows = rows[:limit]
    next_cursor = encode_cursor(rows[-1]["created_at"], rows[-1]["id"]) if has_more else None
    return Page(items=[dict(r) for r in rows], next_cursor=next_cursor, has_more=has_more)
```

**API design rules that interviewers probe:**
- **Opaque cursors** (base64, or signed/encrypted if they mustn't be tampered with). Clients must not build them, so you can change the encoding later.
- **Enforce a max `limit`** with a sensible default.
- **`limit + 1` for `has_more`** instead of a `COUNT(*)`, which is a full scan on big tables. If the UI needs a total, show an estimate (`pg_class.reltuples`) or "1,000+".
- **The cursor is tied to the sort and filters.** If the client changes the filter, it must start over. Encode the sort and filters in the cursor, or validate against them.
- **Backwards pagination:** flip the comparison and sort direction (`>` and `ASC`), then reverse the result.
- **Return links** (`next`, and `prev` if needed) in the body or an RFC 8288 `Link` header, so clients don't build URLs.
- **GraphQL** standardizes this as Relay "connections" (`edges`, `pageInfo { hasNextPage endCursor }`).

**Likely follow-ups**
- *When is offset fine?* Small tables, admin back-offices, and when the product needs "jump to page 7". Even then, cap the maximum offset.
- *Sorting by a non-unique, user-chosen column (price)?* Keyset on `(price, id)` with an index on `(price, id)`. One index per allowed sort, so limit which sorts you allow.
- *Pagination over search results (Elasticsearch)?* `from + size` has the same deep-offset problem (capped at 10k by default). Use `search_after` with a point-in-time (PIT), which is the same keyset idea.
- *Exporting a whole table?* Keyset batches (`WHERE id > last_id ORDER BY id LIMIT 5000`), or a server-side cursor / `COPY`. Never offset.

**What a strong answer shows:** You explain *why* offset degrades (rows read and discarded), you know the tiebreaker and index requirements, and you design the API contract around opaque, bounded, stable cursors.

**Go deeper:** [[05.2 - Versioning Pagination and Filtering]] (cursor design, cost, multiple sort columns, migrating from offset) · [[06.3 - Indexes Deep Dive]] · [[06.17 - Database Anti Patterns#3. Offset Pagination]] · [[02.18 - Iterator]]

**Resource:** [Use The Index, Luke — "We need tool support for keyset pagination"](https://use-the-index-luke.com/no-offset), the canonical explanation with benchmarks. Also [Slack Engineering — Evolving API Pagination at Slack](https://slack.engineering/evolving-api-pagination-at-slack/), a real migration from offset to cursors.

---

### Q16. Explain caching strategies and their pitfalls.

**Answer**
**Patterns:**
- **Cache-aside (lazy loading):** the app checks the cache; on a miss it reads the database and populates the cache. The most common pattern.
- **Write-through:** write to the cache and database together. The cache stays fresh, but writes get slower.
- **Write-behind:** write to the cache, and flush to the database asynchronously. Fast writes, with a risk of data loss.

**Invalidation** ("one of the two hard things in computer science"):
- TTL expiry; explicit deletes on writes; versioned keys (`user:42:v7`).

**Pitfalls:**
- **Cache stampede / thundering herd:** a popular key expires and thousands of requests hit the database at once. Fix with request coalescing (single-flight: one request rebuilds, the others wait), jittered TTLs, or refreshing early.
- **Stale data:** decide how stale each kind of data can be.
- **Hot keys:** spread the load or keep a local in-process cache in front.
- **Caching per-user data under a shared key:** a data leak.

**For LLM apps:** cache embeddings (by content hash), retrieval results, and full responses (exact or semantic caching), all keyed carefully by user and permissions.

**What a strong answer shows:** You know the patterns and the failure modes, especially stampedes and stale data.

**Go deeper:** Redis with working code in [[05 - System Design and Distributed Systems#Q6. How do you use Redis? Show me code.]] · [[07.2 - Cache Strategies and Invalidation]] · [[07.3 - Stampede Hot Keys and Negative Caching]] · [[Redis]]

---

### Q17. How do you design background jobs and message queues reliably?

**Answer**
- **Why use them:** move slow work (document ingestion, embedding, LLM batch jobs, emails) off the request path. The API returns quickly, and workers process the jobs.
- **Tools:** SQS, RabbitMQ, Kafka, Redis-based (Celery, RQ, Dramatiq, arq), cloud schedulers.
- **Delivery semantics:** most queues give **at-least-once** delivery. Messages can be delivered twice, so consumers **must be idempotent**: deduplicate by message ID, use upserts, or keep idempotency records. "Exactly-once" is usually at-least-once delivery plus idempotent processing.
- **Retries with backoff**, and a **DLQ (dead-letter queue)** for messages that keep failing, with alerting and a way to replay them.
- **Visibility timeouts / acknowledgements:** acknowledge only after successful processing. Set the timeout longer than the processing time, or extend it during long jobs.
- **Ordering:** most queues don't guarantee it. Use FIFO queues or Kafka partition keys when order matters.
- **The outbox pattern:** writing to the database *and* publishing an event can't be atomic across two systems.
  1. Write the event to an "outbox" table in the **same database transaction** as the data.
  2. A separate relay publishes it to the queue.
  - This prevents lost or phantom events.
- **Backpressure:** limit concurrency and throttle producers when consumers fall behind.

**What a strong answer shows:** Idempotency, DLQs and the outbox pattern: the hallmarks of someone who has run queues in production.

**Go deeper:** Kafka in microservices with producer, outbox and consumer code in [[05 - System Design and Distributed Systems#Q4. How do you use a message queue like Kafka in a microservices architecture?]] · [[08.2 - Queue Semantics]] · [[08.6 - Retries Backoff and Dead Letters]] · [[09.3 - The Outbox Pattern]]

---

## Section D: Resilience and quality

### Q18. What resilience patterns do you apply to calls between services?

**Answer**
- **Timeouts everywhere:** no network call without one. A missing timeout is how one slow dependency takes down a whole system.
- **Retries with exponential backoff + jitter:** retry only transient errors (timeouts, 5xx, 429), with a cap on attempts.
  - Jitter means randomising the delay. "Full jitter" picks a random wait between 0 and the current backoff.
  - It prevents synchronised retry waves.
  - Retry only **idempotent** operations, or use idempotency keys.
- **Circuit breaker:** after N failures, "open" the circuit and fail fast for a cooldown, then let a few test requests through ("half-open"). This protects both the caller and the failing service.
- **Bulkheads:** isolate resources (separate pools or concurrency limits per dependency), so one failing dependency can't use up all your threads or connections.
- **Rate limiting:** token bucket or sliding window, on inbound traffic (protect yourself) and outbound traffic (respect others' limits).
  - Token bucket: tokens refill at a fixed rate, each request spends one, and short bursts are allowed up to the bucket size.
- **Graceful degradation:** serve cached or partial results, and turn off non-critical features under load.
- **Health checks:** liveness (is it alive?) vs. readiness (can it take traffic?), so orchestrators route traffic correctly.

**Likely follow-ups**
- *Why can retries make an outage worse?* Every layer retrying multiplies the load: 3 layers × 3 retries = 27× the traffic on a struggling service. Retry at one layer, use **retry budgets** (e.g. retries may be at most 10% of requests), and add circuit breakers.

**What a strong answer shows:** You treat failure as normal and know how these patterns combine.

**Go deeper:** [[11.2 - Timeouts Retries and Jitter]] · [[11.3 - Circuit Breakers and Bulkheads]] · [[11.6 - Graceful Degradation]]

---

### Q19. What's your testing strategy for a Python backend?

**Answer**
- **The test pyramid:** many fast **unit** tests, fewer **integration** tests (real database via Testcontainers, real Redis), and a small number of **end-to-end** tests.
- **pytest essentials:**
  - **Fixtures**, with scopes (function, module, session), for setup and teardown.
  - `parametrize` for table-driven tests.
  - `pytest-asyncio` for async code.
  - Factories (`factory_boy`) for test data.
- **Mock at boundaries** (external APIs, LLMs, time), not your own internal logic. Over-mocking produces tests that pass while the code is broken.
- **FastAPI:** `TestClient` or `httpx.AsyncClient`, with `dependency_overrides`.
- **Contract tests** between services (e.g. Pact, or schema checks against OpenAPI).
- **Property-based testing** (Hypothesis) for parsers and data transforms: it generates many inputs and finds edge cases you wouldn't think of.
- **CI quality gates:** linting (ruff), type checks (mypy or pyright), tests, coverage as a *signal* (not a target), security scans.
- **For AI features:** deterministic unit tests plus eval suites (Part 3, Q22).

**What a strong answer shows:** A balanced, pragmatic strategy: what to mock, what to test for real.

**Go deeper:** [[10.9 - Testing Microservices]] · [[05.13 - Contract Testing and Schema Evolution]]

---

### Q20. Which design patterns and principles do you actually use in Python?

**Answer**
Python favours simple, pragmatic patterns:
- **Strategy:** swap algorithms behind one interface (`Embedder` → local or OpenAI; `Reranker` → cross-encoder or none). In Python, often just functions or Protocols.
- **Adapter:** wrap third-party APIs (LLM providers, vector databases) behind *your* interface, so you can swap them and mock them.
- **Factory:** build the right implementation from configuration (`get_llm(settings)`).
- **Repository:** hide data access behind an interface, so business logic doesn't depend on SQL details.
- **Dependency inversion / injection:** high-level code depends on abstractions, and concrete implementations are injected (FastAPI's `Depends` helps).
- **Decorator** (the pattern and the language feature) for cross-cutting concerns.
- **Observer / pub-sub** for decoupled events.
- **Pipeline / chain of responsibility:** guardrail chains and middleware.

**SOLID, briefly:**
- **S**ingle responsibility; **O**pen/closed (extend without modifying); **L**iskov substitution (subtypes must be usable in place of their parent); **I**nterface segregation (small interfaces); **D**ependency inversion.
- Apply them with judgement. Over-abstraction is a real cost too.

**What a strong answer shows:** Patterns used to solve real problems (swappability, testability), not as decoration.

**Go deeper:** SOLID with code and the look-alike patterns in [[06 - Design Principles and Patterns]] · [[02.25 - Telling Similar Patterns Apart]] · [[01.1 - SOLID Principles]]

---

### Q21. How do you approach refactoring a legacy system?

**Answer**
1. **Understand first:** read the code, the traces and the logs, and talk to the people who own it. Map the critical paths and the riskiest areas.
2. **Add safety nets:** **characterisation tests** that capture current behaviour (even the odd parts), plus monitoring, before changing anything.
3. **Make small, incremental steps** behind feature flags. Avoid big-bang rewrites, which are the classic failure.
4. **Strangler fig pattern:** build new components alongside the old system. Gradually route traffic or features to them (via a facade or proxy), then remove the old code piece by piece.
5. **Separate concerns:** pull configuration, I/O and business logic apart. For example, move partner-specific settings into a configuration store instead of code branches.
6. **Measure:** performance, error rates and cost, before and after.
7. **Communicate:** write down the plan, the risks and the rollback steps; align with stakeholders on priorities.

**What a strong answer shows:** Risk-managed, incremental change, with tests and observability first.

---

### Q22. What does good observability look like for a backend?

**Answer**
- **The three pillars:**
  - **Logs:** structured JSON, with a request ID or trace ID. No secrets or PII.
  - **Metrics:** counters, gauges and histograms.
  - **Traces:** a request's path across services, with timings.
  - OpenTelemetry is the standard way to produce all three.
- **Golden-signal frameworks:**
  - **RED** for services: Rate, Errors, Duration.
  - **USE** for resources: Utilisation, Saturation, Errors.
- **Watch p95/p99 latency, not averages:** averages hide tail latency.
- **SLOs and error budgets:** define targets (e.g. 99.9% of requests under 500 ms) and alert on how fast you're burning the budget, not on every blip.
- **Actionable alerts** with runbooks; dashboards per service; correlation from alert → trace → logs.

**What a strong answer shows:** Production experience. You'd know how to find the cause of an incident quickly.

**Go deeper:** [[Observability]] · [[12.2 - SLI SLO and Error Budgets]] · [[12.3 - Instrumenting Conduit End to End]]

---

### Q23. What does "clean code" mean to you? What do you look for in code review?

**Answer**
- **Readable before clever:** clear names, small focused functions, obvious control flow, consistent style (enforced by a formatter and linter, not debated in review).
- **Explicit boundaries:** validation at the edges, typed interfaces, clear error handling (no bare `except`, no silently swallowed errors).
- **Comments explain *why*, not *what*.**
- **Tests** for behaviour and edge cases.
- **In review I look for:**
  - Correctness and edge cases.
  - Security: injection, auth checks, secrets.
  - Performance traps: N+1 queries, blocking calls in async code, unbounded loops or memory.
  - Error handling and observability.
  - API and backward compatibility.
  - Whether it's small and focused enough to review at all.
- **Tone:** ask questions, explain your reasoning, separate blocking issues from nits, and praise good work. Reviews are also mentoring.

**What a strong answer shows:** Engineering judgement plus collaboration skills, which matter for the "mentor the team" part of senior roles.

---

## Section E: Frontend essentials (full-stack)

### Q24. What should a full-stack engineer know about React for AI-style apps?

**Answer**
- **Rendering model:** a component re-renders when its state or props change. Keep state as **local** as possible; lift it up only when siblings need it. Use context or a store (Zustand, Redux) for truly global state.
- **Server state vs. client state:** use a data-fetching library (TanStack Query, SWR) for caching, retries and invalidation of server data, instead of hand-rolled `useEffect` fetching.
- **Streaming chat UIs:**
  - Append tokens to state efficiently (batch updates, or keep a ref plus periodic re-renders) so the UI doesn't re-render on every token.
  - Render Markdown and code blocks progressively.
  - Support stop/cancel (an `AbortController` aborts the fetch).
- **Performance:** `useMemo` / `useCallback` / `React.memo` for expensive renders (but measure first); list virtualisation for long chat histories.
- **UX for AI:** loading and progress states for agent steps, showing sources and citations, error and retry states, feedback buttons, and an easy way to escalate to a human.
- **Security:** never render model output as raw HTML (XSS risk); sanitise Markdown rendering.

**What a strong answer shows:** You can build the user-facing side of AI features well, not just the backend.

---

## Section F: AI system design

### Q25. How do you approach a system design interview?

**Answer**
Use a consistent structure, and talk through your reasoning:
1. **Clarify requirements (5 min):** functional (what it does) and non-functional (scale, latency, availability, cost, security, compliance). Ask about users, volume and success metrics.
2. **Estimate (2–3 min):** requests per second, data size, tokens per request × price. Enough to drive decisions.
3. **High-level design:** the main components and the data flow. Draw the request path *and* the offline paths.
4. **Deep dives:** pick 2–3 hard parts (retrieval quality, the agent control loop, multi-tenancy, consistency) and go deep. Let the interviewer steer.
5. **Tradeoffs:** say what you chose, what you rejected, and why.
6. **Operations:** observability, evals, failure modes, deployment, cost controls.
7. **Evolution:** what you'd build for v1 vs. later.

**What a strong answer shows:** Structured thinking and collaboration. Good interviewers care more about *how* you reason than about one "right" design.

**Go deeper:** [[07.1 - How HLD Interviews Work]] · [[02.1 - Framework Overview]] · [[07.3 - Communicating Tradeoffs]] · [[05 - System Design and Distributed Systems]]

---

### Q26. Design: an enterprise knowledge assistant that answers questions over the company's docs, wikis and tickets.

**Answer outline**
- **Requirements:**
  - 10k employees; sources include Confluence, Google Drive, Jira and Slack.
  - Permission-correct answers, with citations.
  - p95 under 2 s to first token; freshness within 1 hour.
  - Answers "I don't know" when the docs don't cover the question.
- **Ingestion:**
  - Per-source connectors (webhooks plus periodic syncs) → a queue → parse/chunk/embed workers.
  - Idempotent upserts by content hash; ACLs copied onto chunks; a DLQ for failures.
- **Storage:** hybrid search engine (OpenSearch, or Postgres + pgvector + full-text search) with filtered HNSW; object storage for originals; metadata in Postgres.
- **Query path:**
  1. SSO auth resolves the user's groups.
  2. Rewrite the query (using the conversation) and extract filters.
  3. Hybrid retrieval with a **mandatory ACL filter** → RRF → reranker.
  4. Grounded generation with citations → output guards → SSE stream.
- **Agentic extension:** a router sends simple lookups down a fast path, and complex multi-hop questions to an agent that has retrieval, Jira search and people-directory tools, with step caps.
- **Quality:** golden sets per department; CI evals; feedback buttons; review queues for low-rated answers.
- **Operations:** tracing per request; cost per team; index versioning with blue/green; permission-sync monitoring.
- **Risks:** permission leaks (test them explicitly), stale documents (prefer recent, show dates), prompt injection via documents (mark content as untrusted).

**What a strong answer shows:** End-to-end design, with security and evaluation built in.

**Go deeper:** [[11.1 - Enterprise Search Assistant]] · [[11.2 - Internal Company Copilot]] · [[09.2 - Enterprise Search and Permission-Aware Retrieval]]

---

### Q27. Design: a customer-support agent that can look up orders, issue refunds and escalate to humans.

**Answer outline**
- **Requirements:** chat on web and mobile; actions on real systems; refund limits; auditability; 24/7; graceful hand-off to humans.
- **Architecture:**
  - Chat API (FastAPI + SSE) → a LangGraph agent with a checkpointer (Postgres) keyed by conversation.
  - Tools: `get_order`, `get_policy` (RAG over support policies), `create_refund`, `escalate`.
- **Tool safety:**
  - Tools call internal APIs **with the customer's identity**. The agent can only see that customer's orders, and authorisation is enforced by the API, not the prompt.
  - `create_refund` checks the limits in code. Above the threshold, it calls `interrupt()` for a human agent's approval.
  - Idempotency keys on refunds.
- **Guardrails:** injection detection on input; PII handling; policy-grounded answers with citations; an output check against forbidden promises.
- **Limits:** recursion limit, per-conversation budget, timeouts; fallback to "connecting you to a human".
- **Evals:** scripted scenarios with simulated customers (happy path, angry customer, policy edge cases, injection attempts); trajectory checks ("must verify the order before refunding"); resolution and escalation rates in production.
- **Operations:** a full audit log of tool calls; dashboards for refunds by the agent vs. humans; a human review queue.

**What a strong answer shows:** You design agents that take *actions* safely: permissions, limits, approvals and audit.

**Go deeper:** [[11.3 - AI Support Agent]] · [[08.4 - Observability Guardrails and Cost Control]]

---

### Q28. Design: an AI code-review assistant integrated into CI.

**Answer outline**
- **Trigger:** a PR webhook or a CI stage (e.g. Jenkins/GitHub Actions) on open or update.
- **Context building:**
  - Fetch the diff plus the surrounding code (changed functions, related files found via imports or code search), repo conventions (`CONTRIBUTING`, `AGENTS.md`-style files), and the linked ticket.
  - Respect the **token budget**: prioritise changed hunks, compress large files, skip generated and lock files.
- **Review:**
  - One LLM pass per file or concern (bugs, security, tests, style).
  - Structured output: `{file, line, severity, comment, suggestion}`.
  - **Validate** that line numbers exist in the diff.
- **Noise control:** severity thresholds; deduplication; don't repeat comments on unchanged code; limit comments per PR; learn from dismissed comments.
- **Posting:** inline PR comments plus a summary. Advisory, not blocking, at first. Humans stay the approvers.
- **Security:** never send secrets (scan diffs first); approved model/provider with appropriate data retention; repo-level opt-in.
- **Evaluation:** a set of historical PRs with known bugs (did it catch them?); the rate of comments developers accept vs. dismiss; review turnaround time; cost per PR.
- **Rollout:** pilot team → feedback → tune prompts and thresholds → wider rollout.

**What a strong answer shows:** Practical AI-in-the-SDLC thinking: context limits, noise control, trust and measurement.

---

### Q29. Design: a centralised LLM gateway for the whole organisation.

**Answer outline**
- **Why:** teams each call providers directly, with scattered keys, no cost visibility, no consistent retries or guardrails, and lock-in.
- **Features:**
  - One OpenAI-compatible API in front of multiple providers and models.
  - Auth per team or service; **budgets and rate limits** per team.
  - Routing (by model alias, cost or latency); **fallbacks**; retries with jitter; circuit breakers.
  - Caching (exact and semantic) and provider prompt caching passthrough.
  - Central guardrails (PII redaction, policy filters).
  - Logging, tracing and cost attribution; model allow-lists and data-residency rules.
- **Architecture:**
  - Stateless gateway service (FastAPI or an off-the-shelf option like LiteLLM) behind a load balancer.
  - Redis for rate limits and caches; Postgres for keys, budgets and configuration.
  - Async log shipping to the analytics and observability stack.
- **Critical concerns:**
  - **It sits on every AI request's path,** so it must be highly available and add very little latency: horizontal scaling, no blocking work, streaming passthrough.
  - A security boundary for keys.
  - Avoid becoming a bottleneck for teams adopting new provider features: pass through unknown parameters.

**What a strong answer shows:** Platform thinking: centralising cross-cutting concerns without blocking teams.

**Go deeper:** [[10.4 - Model Routing and Multi-Model Architecture]] · [[14.3 - Multi-Tenancy Patterns for AI SaaS]]

---

## Section G: Senior-level conversations

### Q30. How do you mentor engineers on AI best practices?

**Answer**
- **Make good practice the easy path:** shared templates, reusable libraries (an LLM client with retries and tracing, guardrail middleware, eval harnesses), and example repos.
- **Teach the mental models,** not just the tools: "the LLM is an unreliable dependency", "retrieval first, prompts later", "no change without an eval".
- **Pairing and design reviews** for the first AI features each engineer builds; short internal write-ups of lessons and failures.
- **Code review as teaching:** explain the *why* behind each comment.
- **Create safe ways to experiment:** sandboxes, budgets, demo days.

**What a strong answer shows:** You scale your impact through others, which is central to senior roles.

---

### Q31. A stakeholder wants "an AI agent that does X" by next month. How do you respond?

**Answer**
- **Understand the real goal** and success metric: what problem is this solving, and how will we know it worked?
- **Check feasibility quickly:** collect 20–50 real examples and prototype the simplest version (often a workflow, not an agent) in a few days, then measure it.
- **Propose a phased plan:** v1 is narrow, with human-in-the-loop and clear limits; later versions add scope based on evals and feedback.
- **Be upfront about risks:** accuracy limits, cost, data access and compliance, failure handling.
- **Agree on guardrails and on what "done" means** before building.

**What a strong answer shows:** Business alignment, honest expectation-setting and an incremental delivery mindset.

---

## Further reading
- [AWS Builders' Library: Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/): the classic article on resilience.
- [FastAPI docs: Concurrency and async/await](https://fastapi.tiangolo.com/async/): the official explanation of `def` vs. `async def` and the event loop.

---

**Next:** [[05 - System Design and Distributed Systems]]
