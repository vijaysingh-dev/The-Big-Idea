**Up:** [[00 - Index (LLD)]] | **Prev:** [[pattern-cheatsheet]]

---

# Interview Quick Reference

Cram sheet for the day before. Not for first-time learning — see individual files for depth.

---

## LLD Interview Structure (45 min)

```
00:00 – 05:00  Clarify requirements (ask 4-6 focused questions)
05:00 – 10:00  Identify entities, draw rough class map
10:00 – 15:00  Design core classes (attributes + key methods)
15:00 – 30:00  Implement 2-3 core classes in code
30:00 – 35:00  Name and justify patterns used
35:00 – 40:00  Walk through an end-to-end flow
40:00 – 45:00  Extensions, tradeoffs, failure handling
```

---

## Opening Questions (Say These First)

```
"Before I start designing, let me clarify a few things:
 1. What's the scale? (users, requests/sec)
 2. Single service or microservices?
 3. Strong or eventual consistency?
 4. What's in scope vs out of scope for today?
 5. Any specific tech constraints I should know about?"
```

---

## Common Problems → Immediate Pattern Mapping

|Problem Statement|Reach For|
|---|---|
|"Support multiple payment providers"|Strategy + Factory|
|"Add retry without modifying service"|Decorator|
|"Order has lifecycle (placed → paid → shipped)"|State|
|"After order placed: email + inventory + analytics"|Observer|
|"Create complex objects (query, HTTP request)"|Builder|
|"Decouple domain from database"|Repository|
|"Atomic save across 2 aggregates"|Unit of Work|
|"Multiple middleware checks (auth, rate limit, validation)"|Chain of Responsibility|
|"One DB, fast reads with denormalized model"|CQRS|
|"Full audit trail of every change"|Event Sourcing|
|"Payment spans 3 microservices — need rollback"|Saga|
|"Simplify complex subsystem for callers"|Facade|
|"Add caching/auth transparently to existing service"|Proxy|

---

## SOLID in 30 Seconds

```
S — One reason to change (no God classes)
O — Extend by adding, not modifying
L — Subtypes honor parent contracts (no throws NotImplemented)
I — Small focused interfaces (don't force unused methods)
D — Depend on abstractions (inject interfaces, not concretions)
```

---

## Entity Design Must-Haves

Every entity you design should have:

- `id: UUID` (not int — UUIDs are distributed-safe)
- Private fields, public behavior (encapsulation)
- State transitions enforced inside the entity
- Domain events emitted on meaningful state changes
- `__eq__` based on `id`, not attributes
- Value Objects for money, address, phone (frozen dataclass)

```python
# Canonical entity skeleton
class Order:
    def __init__(self, id: UUID, user_id: UUID):
        self.id = id
        self.user_id = user_id
        self._status = OrderStatus.DRAFT   # private
        self._events = []
    
    def confirm(self):                     # behavior, not setter
        self._assert_status(OrderStatus.DRAFT)
        self._status = OrderStatus.CONFIRMED
        self._events.append(OrderConfirmed(self.id))
    
    def _assert_status(self, expected):
        if self._status != expected:
            raise InvalidStateTransition(...)
    
    def __eq__(self, other): return self.id == other.id
```

---

## Repository Pattern Skeleton

```python
# Interface in domain layer
class OrderRepository(ABC):
    @abstractmethod
    def save(self, order: Order) -> Order: pass
    @abstractmethod
    def find_by_id(self, id: UUID) -> Optional[Order]: pass
    @abstractmethod
    def find_by_user(self, user_id: UUID) -> List[Order]: pass

# SQL implementation in infra layer
class SqlOrderRepository(OrderRepository):
    def __init__(self, session): self._session = session
    def save(self, order): ...    # ORM + mapping
    def find_by_id(self, id): ... # query + mapping

# InMemory for tests
class InMemoryOrderRepository(OrderRepository):
    def __init__(self): self._store = {}
    def save(self, order): self._store[order.id] = order; return order
    def find_by_id(self, id): return self._store.get(id)
```

---

## Strategy Pattern Skeleton

```python
class PaymentStrategy(ABC):
    @abstractmethod
    def process(self, request: PaymentRequest) -> PaymentResult: pass
    @abstractmethod
    def supports(self, currency: str) -> bool: pass

class StripeStrategy(PaymentStrategy):
    def process(self, request): ...
    def supports(self, currency): return currency in {"USD","INR","GBP"}

class RazorpayStrategy(PaymentStrategy):
    def process(self, request): ...
    def supports(self, currency): return currency == "INR"

class PaymentService:
    def __init__(self, strategies: List[PaymentStrategy]):
        self._strategies = strategies
    
    def process(self, request: PaymentRequest) -> PaymentResult:
        strategy = next((s for s in self._strategies
                         if s.supports(request.currency)), None)
        if not strategy:
            raise UnsupportedCurrencyError(request.currency)
        return strategy.process(request)
```

---

## State Pattern Skeleton

```python
TRANSITIONS = {
    OrderStatus.DRAFT:     {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
    OrderStatus.CONFIRMED: {OrderStatus.PAID, OrderStatus.CANCELLED},
    OrderStatus.PAID:      {OrderStatus.SHIPPED},
    OrderStatus.SHIPPED:   {OrderStatus.DELIVERED},
    OrderStatus.DELIVERED: set(),     # terminal
    OrderStatus.CANCELLED: set(),     # terminal
}

class Order:
    def _transition(self, new_status):
        if new_status not in TRANSITIONS.get(self._status, set()):
            raise InvalidStateTransition(
                f"{self._status} → {new_status} not allowed"
            )
        self._status = new_status
```

---

## Observer Pattern Skeleton

```python
class EventBus:
    def __init__(self): self._handlers = {}
    
    def subscribe(self, event_type, handler):
        self._handlers.setdefault(event_type, []).append(handler)
    
    def publish(self, event):
        for h in self._handlers.get(type(event), []):
            try: h(event)
            except Exception as e: logger.error(e)  # don't block other handlers

# Usage
bus = EventBus()
bus.subscribe(OrderConfirmed, email_handler.handle)
bus.subscribe(OrderConfirmed, inventory_handler.handle)
bus.subscribe(OrderConfirmed, analytics_handler.handle)

# In OrderService:
for event in order.get_events():
    bus.publish(event)   # all 3 handlers notified
```

---

## Tradeoff Phrases to Know

```
"I chose X over Y because [benefit] matters more than [cost] in this context.
 The downside is [honest cost], which we mitigate by [mitigation]."

Common tradeoff pairs:
  Sync vs Async          → immediate feedback vs decoupling
  SQL vs NoSQL           → flexibility vs scale
  Strong vs Eventual     → correctness vs availability/latency
  Monolith vs Services   → simplicity vs independent scaling
  Cache-Aside vs Write-Through → memory efficiency vs freshness
  Optimistic vs Pessimistic lock → throughput vs correctness under contention
```

---

## Idempotency (Always Mention for Payments/Orders)

```python
def place_order(self, cmd: PlaceOrderCommand) -> Order:
    # Always check idempotency key first
    existing = self._repo.find_by_idempotency_key(cmd.idempotency_key)
    if existing:
        return existing   # same result, no reprocessing
    
    order = Order.create(cmd)
    order.idempotency_key = cmd.idempotency_key
    return self._repo.save(order)   # key saved atomically with order
```

---

## Error Handling Template

```python
# Domain exception hierarchy
class DomainError(Exception): pass
class OrderNotFoundError(DomainError): pass
class InvalidStateTransition(DomainError): pass
class InsufficientStockError(DomainError):
    def __init__(self, sku, available, requested):
        super().__init__(f"{sku}: available={available}, requested={requested}")

# API layer maps to HTTP
@app.exception_handler(OrderNotFoundError)
def handle(req, exc): return JSONResponse(404, {"error": str(exc)})

@app.exception_handler(InsufficientStockError)
def handle(req, exc): return JSONResponse(409, {"error": str(exc)})
```

---

## Red Flags Interviewers Watch For

```
❌ No interfaces — all concrete classes                → No DIP, not testable
❌ Business logic in controller/route handler           → SoC violation
❌ db.execute() inside domain entity                   → Leaky abstraction
❌ if status == "pending": ... elif status == "paid"   → Missing state machine
❌ No mention of failure handling                       → Naive design
❌ New requirement → modify existing class             → OCP violation
❌ Testing requires real DB                            → DIP violation
❌ "We can add that later" (no plan)                   → Not senior thinking
```

---

## Green Flags That Impress

```
✅ Ask clarifying questions before designing
✅ Name the patterns you're using and WHY
✅ Mention InMemory repo for testing
✅ Talk about domain events for decoupling
✅ Bring up idempotency for mutations
✅ Mention transaction boundaries explicitly
✅ Say "the downside of this is..." (honest tradeoffs)
✅ Extend your design when asked ("easy, just add X implementing Y interface")
```

---

## Case Study Cheat Map

|Case Study|Patterns to Lead With|
|---|---|
|Parking Lot|State (spot), Strategy (pricing), Factory (lot builder)|
|Payment Gateway|Strategy (provider), State (payment), Saga (multi-step)|
|Notification Platform|Strategy (channel), Observer (events), Chain (filters)|
|Rate Limiter|Strategy (algorithm), Proxy (middleware)|
|Job Scheduler|Command (job payload), State (job status), Strategy (executor)|
|Ride-Sharing|State (ride + driver), Strategy (matching + pricing)|
|Inventory + Orders|Repository, Unit of Work, Observer (low stock alert)|
|Workflow Engine|State, Command (step), Strategy (executor), Template Method|
