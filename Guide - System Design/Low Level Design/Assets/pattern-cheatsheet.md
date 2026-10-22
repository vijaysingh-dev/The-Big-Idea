**Up:** [[00 - Index (LLD)]] | **Prev:** [[06.8 - Workflow Engine]]

---

# Pattern Cheatsheet

Quick-scan reference. Each pattern: one-liner, canonical use, key tradeoff, and the interview signal.

---

## Creational Patterns

|Pattern|One-liner|Use When|Tradeoff|Interview Signal|
|---|---|---|---|---|
|**[[02.1 - Singleton\|Singleton]]**|One instance globally|DB pool, config, logger|Global state → hard to test|"Make it thread-safe (double-checked lock)"|
|**[[02.2 - Factory Method\|Factory Method]]**|Subclass decides what to create|Pluggable providers (payment, storage)|More classes|"How do you add a new provider?"|
|**[[02.3 - Abstract Factory\|Abstract Factory]]**|Create families of related objects|Prod vs Test infra (DB+Cache+Queue)|Hard to extend product family|"How do you swap entire environment?"|
|**[[02.4 - Builder\|Builder]]**|Step-by-step complex construction|Query builder, HTTP request, test fixtures|More code than constructor|"Telescoping constructor problem"|
|**[[02.5 - Prototype\|Prototype]]**|Clone existing instead of new|Templates, config variants|Deep vs shallow copy subtlety|"Expensive init, need many variants"|

---

## Structural Patterns

|Pattern|One-liner|Use When|Tradeoff|Interview Signal|
|---|---|---|---|---|
|**[[02.6 - Adapter\|Adapter]]**|Convert incompatible interface|Third-party SDK wrapping, legacy integration|Extra layer|"How do you swap Stripe for Razorpay?"|
|**[[02.7 - Decorator\|Decorator]]**|Add behavior dynamically, same interface|Retry, logging, caching, auth middleware|Deep chains hard to debug|"Add retry without modifying the service"|
|**[[02.8 - Facade\|Facade]]**|Simplified entry point to subsystem|Service layer over complex domain|Can become God object|"Controller is too complex — extract"|
|**[[02.9 - Proxy\|Proxy]]**|Controlled access (cache, auth, lazy)|Cache proxy, auth guard, remote proxy|Adds indirection|"Add caching transparently to a repo"|
|**[[02.10 - Composite\|Composite]]**|Tree of objects, uniform treatment|Permission trees, category hierarchy|Overly general|"Recursive permission check"|
|**[[02.11 - Bridge\|Bridge]]**|Decouple abstraction from implementation|Report × format, transport × serializer|Upfront hierarchy design|"N×M class explosion → N+M"|

---

## Behavioral Patterns

|Pattern|One-liner|Use When|Tradeoff|Interview Signal|
|---|---|---|---|---|
|**[[02.12 - Strategy\|Strategy]]**|Swap algorithms at runtime|Payment methods, pricing, sort|More classes|"Add PayPal without changing PaymentService"|
|**[[02.13 - Observer\|Observer]]**|Notify many on change|Event systems, post-order side effects|Memory leaks, hard to trace|"Decouple order from email/analytics"|
|**[[02.14 - Command\|Command]]**|Encapsulate request as object|Job queues, undo/redo, saga steps|More classes per operation|"Retryable, serializable operations"|
|**[[02.15 - Chain of Responsibility\|Chain of Resp]]**|Pass request along handler chain|Middleware, auth pipeline, validation|No guarantee of processing|"Request must pass multiple independent checks"|
|**[[02.16 - State\|State]]**|Object changes behavior with state|Order lifecycle, subscription, FSM|Many state classes|"Enforce valid transitions (no cancel after ship)"|
|**[[02.17 - Template Method\|Template Method]]**|Skeleton algorithm, subclasses fill gaps|ETL pipelines, importers, report gen|Inheritance coupling|"Fixed process, variable steps"|
|**[[02.18 - Iterator\|Iterator]]**|Sequential access, hide structure|Cursor pagination, batch processing|Single-pass only|"Stream 10M rows without OOM"|
|**[[02.19 - Mediator\|Mediator]]**|Centralize communication|Command/query bus, event dispatcher|Mediator complexity|"Controller has too many service dependencies"|

---

## Backend-Specific Patterns

|Pattern|One-liner|Use When|Tradeoff|Interview Signal|
|---|---|---|---|---|
|**[[02.20 - Repository Pattern\|Repository]]**|Collection-like persistence abstraction|Any backend with domain logic|Mapping boilerplate|"Decouple domain from DB"|
|**[[02.21 - Unit of Work\|Unit of Work]]**|Coordinate multi-repo transactions|Order + inventory saved atomically|UoW scope must match request|"Atomic multi-aggregate save"|
|**[[02.22 - CQRS\|CQRS]]**|Separate read/write models|High read volume, complex domain|Eventual consistency|"Read model is too slow / complex"|
|**[[02.23 - Event Sourcing\|Event Sourcing]]**|State = sequence of events|Full audit trail, financial systems|Projection complexity|"Show me full history of this account"|
|**[[02.24 - Saga Pattern\|Saga]]**|Distributed transaction via compensation|Microservice workflows|Compensation complexity|"Order spans 3 services — how to rollback?"|

---

## Pattern Combinations That Appear Together

```
Order placement system:
  Strategy (payment) + Observer (post-order events) + Repository + Unit of Work

Event-driven microservices:
  Observer + Command (event as command) + Saga (compensation)

API gateway / middleware:
  Chain of Responsibility + Decorator + Proxy

CQRS system:
  CQRS + Event Sourcing + Observer (projections) + Repository (read + write)

Plugin system:
  Factory Method + Strategy + Observer (plugin lifecycle)

Retry infrastructure:
  Decorator (retry wraps client) + Command (retryable unit) + Observer (failure alert)
```

---

## The 5 Most-Used in Backend Interviews

```
1. Strategy     — "support multiple X" (payment, storage, notification)
2. Repository   — "decouple domain from DB"
3. Observer     — "decouple post-action side effects"
4. State        — "entity has a lifecycle with rules"
5. Decorator    — "add cross-cutting behavior (retry, log, cache)"
```

---

## Anti-Pattern Recognition

|You See|Pattern Smells Like|Reach For|
|---|---|---|
|`if type == "stripe" ... elif type == "paypal"`|OCP violation|Strategy + Factory|
|500-line service class|SRP violation|Split by responsibility|
|`order.user.address.city`|LoD violation|Tell don't ask|
|Same logic in 3 places|DRY violation|Extract shared abstraction|
|`new ConcreteService()` inside class|DIP violation|Inject via interface|
|6-level class hierarchy|Inheritance abuse|Composition|
|All state changes are `obj.status = "X"`|No state machine|State pattern|

---

**Next:** [[interview-quick-ref]]
