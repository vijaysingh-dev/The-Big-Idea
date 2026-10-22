# Low Level Design — Master Index

> **Goal:** Design any backend system confidently, solve LLD interviews, think like a senior engineer. **Usage:** Start here. Each section links to deep-dive files. Use this for quick orientation before diving in.

---

## Learning Path

```
Foundations → Design Patterns → LLD Methodology → Mindset → Building Blocks → Case Studies
```

---

## 01 — Foundations

> First-principles thinking. Read before anything else.

| File                               | What's Inside                                                   |
| ---------------------------------- | --------------------------------------------------------------- |
| [[01.1 - SOLID Principles]]        | SRP, OCP, LSP, ISP, DIP — deep with anti-patterns               |
| [[01.2 - Other Design Principles]] | DRY, KISS, YAGNI, SoC, Law of Demeter, Cohesion vs Coupling     |
| [[01.3 - OOP Design Thinking]]     | Encapsulation, Composition vs Inheritance, Abstraction thinking |
| [[01.4 - Domain Modeling]]         | Entities, Value Objects, Aggregates, Bounded Contexts           |

---

## 02 — Design Patterns

### Overview

- [[02.0 - Patterns Overview]] ← **Start here before individual patterns**

### Creational

> How objects are created

|Pattern|Core Idea|When|
|---|---|---|
|[[02.1 - Singleton]]|One instance globally|Config, DB pool, Logger|
|[[02.2 - Factory Method]]|Subclass decides instantiation|Pluggable providers|
|[[02.3 - Abstract Factory]]|Family of related objects|Multi-DB support|
|[[02.4 - Builder]]|Step-by-step complex construction|HTTP request, Query builder|
|[[02.5 - Prototype]]|Clone existing instances|Config variants, test fixtures|

### Structural

> How objects are composed

|Pattern|Core Idea|When|
|---|---|---|
|[[02.6 - Adapter]]|Convert incompatible interfaces|Third-party SDK wrapping|
|[[02.7 - Decorator]]|Add behavior without subclassing|Middleware, logging, retry|
|[[02.8 - Facade]]|Simplified interface to subsystem|Service layer over complex domain|
|[[02.9 - Proxy]]|Controlled access to object|Lazy load, auth guard, cache proxy|
|[[02.10 - Composite]]|Tree structure, uniform treatment|Permissions, menu trees|
|[[02.11 - Bridge]]|Decouple abstraction from impl|Multi-DB + multi-cache combos|

### Behavioral

> How objects communicate

|Pattern|Core Idea|When|
|---|---|---|
|[[02.12 - Strategy]]|Swap algorithms at runtime|Payment methods, sort strategies|
|[[02.13 - Observer]]|Notify dependents on change|Event system, pub/sub|
|[[02.14 - Command]]|Encapsulate request as object|Undo/redo, job queues|
|[[02.15 - Chain of Responsibility]]|Pass request along handler chain|Middleware pipelines, auth|
|[[02.16 - State]]|Behavior changes with state|Order lifecycle, FSM|
|[[02.17 - Template Method]]|Skeleton algorithm, fill in steps|Data pipelines, ETL|
|[[02.18 - Iterator]]|Sequential access abstraction|Cursor pagination, stream|
|[[02.19 - Mediator]]|Centralize object communication|Chat server, event bus|

### Backend-Specific / Enterprise

|Pattern|Core Idea|When|
|---|---|---|
|[[02.20 - Repository Pattern]]|Decouple data access from domain|Any persistence layer|
|[[02.21 - Unit of Work]]|Group DB ops into one transaction|Complex multi-repo saves|
|[[02.22 - CQRS]]|Separate read/write models|High-scale read-heavy systems|
|[[02.23 - Event Sourcing]]|State = sequence of events|Audit trail, financial systems|
|[[02.24 - Saga Pattern]]|Distributed transaction management|Microservice workflows|

---

## 03 — LLD Methodology

> The systematic approach to any LLD problem

|File|What's Inside|
|---|---|
|[[03.1 - LLD Approach Framework]]|End-to-end process: requirements → class design|
|[[03.2 - Requirement Clarification]]|Questions to ask, FRs vs NFRs, scope bounding|
|[[03.3 - Class Design Checklist]]|Validation, error handling, idempotency, state, transactions|

---

## 04 — Backend Engineering Mindset

> How senior engineers actually think

|File|What's Inside|
|---|---|
|[[04.1 - Senior Engineer Thinking]]|Abstractions, boundaries, evolution, avoiding overengineering|
|[[04.2 - Tradeoff Decision Framework]]|How to make and communicate design decisions|

---

## 05 — Building Blocks

> Practical backend components every system uses

|File|What's Inside|
|---|---|
|[[05.1 - Databases]]|SQL vs NoSQL, schema design, indexing, transactions, migrations|
|[[05.2 - Caching]]|Strategies, invalidation, cache stampede, Redis patterns|
|[[05.3 - Queues and Events]]|Message queues, event-driven design, ordering, idempotency|
|[[05.4 - Auth and AuthZ]]|AuthN vs AuthZ, JWT, RBAC, ABAC, OAuth2|
|[[05.5 - API Design]]|REST, versioning, pagination, rate limiting, webhooks|
|[[05.6 - Background Jobs and Schedulers]]|Job queues, cron, distributed scheduling, retries|

---

## 06 — Case Studies

> Full end-to-end LLD problems with thought process

|File|Patterns Used|
|---|---|
|[[06.1 - Parking Lot]]|State, Strategy, Factory|
|[[06.2 - Payment Gateway]]|Strategy, Facade, Chain of Responsibility, Saga|
|[[06.3 - Notification Platform]]|Observer, Strategy, Builder, Factory|
|[[06.4 - Rate Limiter]]|Strategy, Decorator, Proxy|
|[[06.5 - Job Scheduler]]|Command, Observer, State|
|[[06.6 - Ride-Sharing Dispatch]]|State, Strategy, Observer|
|[[06.7 - Inventory & Order Management]]|Saga, Repository, Unit of Work, State|
|[[06.8 - Workflow Engine]]|State, Chain of Responsibility, Command, Observer|

---

## Assets

|File|What's Inside|
|---|---|
|[[pattern-cheatsheet]]|All patterns — 1-liner summary, when to use, key tradeoff|
|[[interview-quick-ref]]|Interview-day cram sheet: questions, red flags, structure|

---

## Revision Strategy

|Stage|Focus|
|---|---|
|**First pass**|Read 01 Foundations fully, then 02.0 Overview|
|**Pattern learning**|One pattern/day: read → draw → code from memory|
|**Pre-interview**|Assets cheatsheet → 1 case study end-to-end|
|**Quick revision**|Index tables above + cheatsheet only|
