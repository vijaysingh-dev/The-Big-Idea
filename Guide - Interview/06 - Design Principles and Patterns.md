**Up:** [[00 - Index (Interview)]] | **Prev:** [[05 - System Design and Distributed Systems]]

---

# 06 — Design Principles and Patterns

> SOLID with real Python, how principles and patterns relate, and how to stop confusing look-alike patterns (Adapter vs Strategy vs Factory, Strategy vs State, Decorator vs Proxy). The long-form material is in LLD. This file is the version you say out loud.

---

## The Mental Model, Before Any Question

People get stuck because principles and patterns seem to blur together. The examples for each principle *contain* patterns, and every pattern seems to illustrate three principles. The way out is to treat them as **different levels**:

```
GOAL         Code that is easy to change without breaking
                │
PRINCIPLES   Properties that code with that goal has
             (SOLID, DRY, KISS, composition over inheritance, …)
             "What should be true of the design?"
                │
PATTERNS     Named, reusable structures that give you those properties
             for one specific recurring problem
             (Strategy, Adapter, Factory, Decorator, …)
             "What shape solves THIS problem?"
                │
CODE         The actual classes and functions
```

- A **principle** is a *test you apply* to a design: "Can I add a new payment provider without editing checkout?" (OCP).
- A **pattern** is a *move you make* when a specific problem shows up: "Payment providers have different SDKs" → Adapter. "We choose the provider by country" → Factory.
- **One pattern usually satisfies several principles**, which is why examples overlap. That overlap is expected and doesn't mean you're confused.
- **Telling patterns apart is a separate skill.** Patterns share the same skeleton (an interface plus implementations), so you separate them by **intent**, not by shape. Q5–Q7 cover this, and [[02.25 - Telling Similar Patterns Apart]] is the long version.

---

## Section A: Principles

### Q1. Explain the SOLID principles with real examples.

**Answer**

SOLID is five principles for keeping object-oriented code **easy to change**. Each one targets a different kind of change pain.

#### S: Single Responsibility Principle

**"A module should have one reason to change"**, meaning one *actor* or stakeholder whose requests change it. It's not "a class should do one thing".

```python
# ❌ Three reasons to change: pricing rules (finance), persistence (DBA), emails (marketing)
class OrderService:
    def place(self, cart):
        total = sum(i.price * i.qty for i in cart.items) * (1 - cart.discount)
        if cart.country == "IN":
            total *= 1.18                                          # GST
        self.db.execute("INSERT INTO orders ...", total)
        smtp.send(cart.email, f"Thanks! You paid {total}")


# ✅ Each concern changes independently and can be tested alone
class PriceCalculator:
    def total(self, cart) -> Decimal: ...

class OrderRepository:
    def add(self, order) -> None: ...

class OrderNotifier:
    def confirmed(self, order) -> None: ...

class PlaceOrder:                       # orchestrates; owns no rules itself
    def __init__(self, prices: PriceCalculator, orders: OrderRepository, notify: OrderNotifier):
        self.prices, self.orders, self.notify = prices, orders, notify

    def __call__(self, cart) -> Order:
        order = Order.from_cart(cart, self.prices.total(cart))
        self.orders.add(order)
        self.notify.confirmed(order)
        return order
```

**Smell:** a class whose git history has commits from unrelated teams, or a test that needs a DB, an SMTP mock and a tax table to check one discount rule.

#### O: Open/Closed Principle

**"Open for extension, closed for modification."** Adding a new *variant* should mean adding code, not editing tested code.

```python
# ❌ Every new provider edits this function and risks breaking the others
def notify(user, msg, channel):
    if channel == "email":
        ...
    elif channel == "sms":
        ...
    elif channel == "whatsapp":     # new requirement → edit, retest everything
        ...


# ✅ New channel = new class + one registry line. Existing code untouched.
class Notifier(Protocol):
    def send(self, user, msg) -> None: ...

class EmailNotifier:
    def send(self, user, msg): ...

class SmsNotifier:
    def send(self, user, msg): ...

NOTIFIERS: dict[str, Notifier] = {"email": EmailNotifier(), "sms": SmsNotifier()}

def notify(user, msg, channel: str):
    NOTIFIERS[channel].send(user, msg)
```

**Pattern link:** this *is* Strategy (plus a registry). OCP is the property, and Strategy is one way to get it.
**Don't overdo it:** apply OCP where variation has **already happened** or is clearly coming. Two `if` branches that never change don't need a class hierarchy (YAGNI).

#### L: Liskov Substitution Principle

**"Subtypes must be usable anywhere the parent is expected, without the caller noticing."** A subclass may not strengthen preconditions (accept less), weaken postconditions (promise less), or throw surprises.

```python
# ❌ The classic: ReadOnlyRepository breaks callers that rely on save()
class Repository:
    def get(self, id): ...
    def save(self, obj): ...

class ReadOnlyRepository(Repository):
    def save(self, obj):
        raise NotImplementedError("read only")     # any caller of Repository.save now breaks


# ✅ Split the abstraction so nobody is promised something they won't get
class Reader(Protocol):
    def get(self, id): ...

class Writer(Protocol):
    def save(self, obj): ...

class SqlRepository:             # implements both
    def get(self, id): ...
    def save(self, obj): ...

class CacheReader:               # implements Reader only, and says so
    def get(self, id): ...
```

**Backend version:** an `S3Storage` and a `LocalStorage` that both implement `Storage`, but only one supports `presigned_url()`. Callers end up writing `isinstance` checks, and **an `isinstance` check against your own abstraction is the classic sign of an LSP violation.**

#### I: Interface Segregation Principle

**"Clients shouldn't depend on methods they don't use."** Prefer several small, role-based interfaces over one fat one.

```python
# ❌ A fat interface: a simple embedder must implement chat and streaming too
class LLMClient(ABC):
    @abstractmethod
    def chat(self, messages): ...
    @abstractmethod
    def stream(self, messages): ...
    @abstractmethod
    def embed(self, texts): ...


# ✅ Role interfaces. Code asks only for what it uses.
class ChatModel(Protocol):
    def chat(self, messages) -> str: ...

class Embedder(Protocol):
    def embed(self, texts: list[str]) -> list[list[float]]: ...

def index_documents(docs, embedder: Embedder): ...      # can't accidentally call chat()
```

In Python, `typing.Protocol` makes ISP nearly free: a class satisfies any protocol whose methods it has, without inheriting from it.

#### D: Dependency Inversion Principle

**"High-level policy shouldn't depend on low-level details. Both depend on abstractions,"** and the abstraction belongs to the **high-level** side.

```python
# ❌ Business logic welded to a vendor SDK and a database driver
import stripe, psycopg2

class Checkout:
    def pay(self, order):
        stripe.PaymentIntent.create(amount=order.cents, currency="usd")    # can't test, can't swap
        psycopg2.connect(DSN).cursor().execute("UPDATE orders ...")


# ✅ Checkout owns the interfaces it needs. Details plug in from outside.
class PaymentGateway(Protocol):
    def charge(self, money, token, idempotency_key) -> ChargeResult: ...

class OrderRepository(Protocol):
    def mark_paid(self, order_id, ref) -> None: ...

class Checkout:
    def __init__(self, gateway: PaymentGateway, orders: OrderRepository):
        self.gateway, self.orders = gateway, orders

    def pay(self, order, token):
        result = self.gateway.charge(order.total, token, order.id)
        if result.ok:
            self.orders.mark_paid(order.id, result.provider_ref)
        return result


# Wiring happens at the edge (the "composition root"), e.g. FastAPI dependencies:
def get_checkout(db=Depends(get_db)) -> Checkout:
    return Checkout(StripeAdapter(settings.stripe_key), SqlOrderRepository(db))

# In tests:
checkout = Checkout(FakeGateway(always_ok=True), InMemoryOrders())
```

**DIP vs DI:** *Dependency Inversion* is the principle (depend on abstractions you own). *Dependency Injection* is the technique (pass dependencies in rather than constructing them inside). FastAPI's `Depends` is a DI mechanism.

**How SOLID fits together, in one sentence:** SRP decides **where the seams are**, ISP keeps each seam **small**, DIP makes your code depend on the seam rather than the detail, OCP is what you get (**new behaviour = new class behind the seam**), and LSP keeps every class behind the seam **honest**.

**Likely follow-ups**
- *Which principle do you use most?* "DIP, because it's what makes code testable. Every external system (LLM provider, payment gateway, vector DB) sits behind an interface I own, with a fake for tests."
- *Can you overapply SOLID?* Yes. One-implementation interfaces "just in case", factories for objects that never vary, and ten-file features for a CRUD endpoint. Apply the principles where change is actually happening.
- *Does SOLID apply to Python, which has no interfaces?* Yes. `Protocol` gives structural interfaces, functions can serve as single-method strategies, and modules are natural SRP boundaries. The principles are about dependencies and change, not about the `interface` keyword.

**What a strong answer shows:** Correct definitions (SRP is about *reasons to change*, DIP is about who *owns* the abstraction), real backend examples, and judgement about when *not* to apply them.

**Go deeper:** [[01.1 - SOLID Principles]] · [[01.3 - OOP Design Thinking]] · [[04.1 - Senior Engineer Thinking]]

**Resource:** [Robert C. Martin — "The Single Responsibility Principle"](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html), where the author clarifies the "reason to change = actor" definition.

---

### Q2. What other design principles do you apply, beyond SOLID?

**Answer**

| Principle | One line | The trap |
|---|---|---|
| **DRY** | Every piece of *knowledge* has one source of truth | Merging code that merely *looks* alike but changes for different reasons. Duplication is cheaper than the wrong abstraction |
| **KISS** | The simplest design that works | "Simple" means few concepts, not few lines |
| **YAGNI** | Don't build for requirements you don't have | Fine for features. Don't apply it to security, data integrity or observability |
| **Composition over inheritance** | Assemble behaviour from parts rather than deep class trees | Inheritance is still right for genuine is-a relationships and framework hooks |
| **Separation of concerns** | Transport, business logic and persistence in different layers | Over-layering a 50-line service |
| **Law of Demeter** | Talk to your direct collaborators, not their internals (`order.customer.address.city` is a smell) | Applying it to data objects and DTOs, where chaining is fine |
| **High cohesion, low coupling** | Things that change together live together, and modules depend on each other minimally | The underlying goal that all the others serve |
| **Fail fast** | Validate at the boundary and crash loudly on impossible states | Swallowing exceptions "to be safe" |

**Tension worth naming:** DRY vs decoupling. Two services sharing a "common" library for their domain models couples their deploys. Duplicating a small DTO is often the better choice.

**Go deeper:** [[01.2 - Other Design Principles]] · [[04.2 - Tradeoff Decision Framework]]

**Resource:** [Sandi Metz — "The Wrong Abstraction"](https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction), the best short essay on when DRY hurts.

---

### Q3. How do principles and design patterns relate? Aren't the examples the same thing?

**Answer**

Principles are **properties**. Patterns are **recipes** that produce those properties for one recurring problem. So any pattern example will "contain" principles. The table shows which ones each common pattern delivers:

| Pattern | The problem it solves | Principles it puts into practice |
|---|---|---|
| **Strategy** | Several interchangeable algorithms for one job | **OCP** (new algorithm = new class), **DIP** (context depends on an interface), composition over inheritance |
| **Adapter** | A foreign interface doesn't match ours | **DIP** (we own the interface, the vendor is a detail), **SRP** (translation lives in one place) |
| **Factory** | Choosing which concrete class to build | **SRP** (construction logic in one place), **DIP** (callers get an abstraction) |
| **Decorator** | Adding cross-cutting behaviour (logging, retry, cache) | **OCP** (add behaviour without editing the class), **SRP** (each wrapper does one thing) |
| **Facade** | A complicated subsystem that callers find hard to use | **Law of Demeter**, low coupling |
| **Repository** | Business logic tangled with SQL | **DIP**, **SRP**, separation of concerns |
| **Observer** | Many parts need to react to one event | **OCP** (new listener without touching the subject), low coupling |
| **Template Method** | Same skeleton, different steps | **DRY** (the skeleton isn't duplicated) |

**How to use this in an interview:** name the problem, then the pattern, then the principle. *"Providers have different SDKs, so I'd put each behind an adapter implementing our `PaymentGateway`. That's dependency inversion, because checkout depends on our interface and not on Stripe."*

**What a strong answer shows:** You treat principles as the *why* and patterns as the *how*, and you can move between the two levels fluently.

**Go deeper:** [[02.0 - Patterns Overview]] · [[pattern-cheatsheet]]

---

## Section B: Patterns

### Q4. What design patterns do you actually use in backend code?

**Answer**

The ones that earn their place in real Python services:

| Pattern | Where it shows up | Python form |
|---|---|---|
| **Adapter** | Every third-party integration: LLM providers, payment SDKs, vector DBs, legacy SOAP | A class implementing your `Protocol` |
| **Strategy** | Retrieval mode, pricing rules, retry/backoff policy, routing | Very often **just a function** passed in |
| **Factory** | Building the right client from config (`get_llm(settings)`) | A function or `@classmethod` alternative constructor |
| **Decorator** | Retry, caching, timing, auth | `@decorator` functions, or wrapper classes for objects |
| **Repository + Unit of Work** | Persistence behind an interface, one transaction per use case | SQLAlchemy session as the UoW |
| **Facade / service layer** | One use-case entry point over several collaborators | A plain class or function |
| **Chain of Responsibility** | Middleware, guardrail pipelines, validation chains | ASGI middleware, a list of handlers |
| **Observer / events** | Domain events, signals, webhooks | Callbacks, Django signals, or a message bus across services |
| **Builder** | Query construction, complex request objects | SQLAlchemy `select()`, fluent APIs |
| **State** | Order, payment and job lifecycles | Usually an `Enum` + transition table. Full State classes only when the per-state behaviour is large |

**Patterns Python mostly makes unnecessary:**
- **Singleton**: a module is already a singleton. Create one instance at import time or in `lifespan`.
- **Iterator**: generators.
- **Command** for simple cases: a `functools.partial` or a closure.
- **Strategy** with one method: a function.

**What a strong answer shows:** Patterns tied to real problems (testability, swappability, cross-cutting concerns), and an idiomatic Python form rather than Java transliterated into Python.

**Go deeper:** [[02.0 - Patterns Overview]] · [[02.20 - Repository Pattern]] · [[02.21 - Unit of Work]]

**Resource:** [Brandon Rhodes — Python Design Patterns](https://python-patterns.guide/), on which GoF patterns still matter in Python and which the language absorbed.

---

### Q5. How do you tell Adapter, Strategy and Factory apart?

**Answer**

They all involve "an interface with several implementations", which is why they blur. Separate them by **what the extra layer is for**, and **when it runs**:

| | Factory | Adapter | Strategy |
|---|---|---|---|
| **Question it answers** | *Which* class do I build? | How do I make *this foreign thing* fit *my* interface? | *How* should this job be done? |
| **When it runs** | **Once, at construction**, then it's out of the picture | **On every call**, translating | **On every call**, doing the work |
| **What's inside** | `if`/registry lookup + constructor call | Translation: field names, units, error types | The algorithm itself |
| **Does it change the interface?** | N/A (returns an object) | **Yes**: foreign → ours | No, all strategies share one interface |
| **Exists because…** | Construction logic shouldn't be scattered | An interface **mismatch** | The **behaviour varies** |

**One system, all three:**

```python
# ADAPTER: Stripe's SDK → our PaymentGateway interface (translation only)
class StripeAdapter:
    def charge(self, money: Money, token: str, key: str) -> ChargeResult:
        intent = stripe.PaymentIntent.create(
            amount=int(money.amount * 100), currency=money.currency.lower(),
            payment_method=token, confirm=True, idempotency_key=key)
        return ChargeResult(ok=intent.status == "succeeded", provider_ref=intent.id)


# FACTORY: decide WHICH adapter to construct. Runs once, then done.
def gateway_for(country: str) -> PaymentGateway:
    return RazorpayAdapter(...) if country == "IN" else StripeAdapter(...)


# STRATEGY: HOW to order gateways when several are available. Runs on every payment.
def cheapest_first(gateways):       return sorted(gateways, key=lambda g: g.fee_bps)
def most_reliable_first(gateways):  return sorted(gateways, key=lambda g: -g.success_rate)

class Checkout:
    def __init__(self, route=most_reliable_first):     # strategy injected from outside
        self.route = route
    def pay(self, money, token, key, gateways):
        for g in self.route(gateways):                  # used every time
            if (r := g.charge(money, token, key)).ok:
                return r
```

**Three one-line tests:**
- Delete the class. If the code **can't talk to the vendor** any more → **Adapter**.
- If it **can't decide what to construct** → **Factory**.
- If it **can't do the job a different way** → **Strategy**.

**Likely follow-ups**
- *Isn't the factory choosing a strategy?* Often, yes. Patterns compose. The factory is the *moment of choice*, and the strategy is the *thing chosen*. "Factory returns a Strategy" and "Factory returns an Adapter" are both normal.
- *Adapter vs Facade?* An adapter wraps **one** object to match an interface that **already exists**. A facade wraps **several** objects behind a **new, simpler** interface.

**What a strong answer shows:** You separate patterns by intent and timing, not by class diagram, and you show them composing.

**Go deeper:** [[02.25 - Telling Similar Patterns Apart]] (the full mental model, a labelled end-to-end example, real-library examples, and a practice quiz) · [[02.6 - Adapter]] · [[02.12 - Strategy]] · [[02.2 - Factory Method]]

**Resource:** [Refactoring.Guru — Adapter](https://refactoring.guru/design-patterns/adapter), [Strategy](https://refactoring.guru/design-patterns/strategy), [Factory Method](https://refactoring.guru/design-patterns/factory-method). Read the **"Relations with Other Patterns"** section at the bottom of each.

---

### Q6. What's the difference between Strategy and State?

**Answer**

Structurally they're **identical**: a context object holds a reference to an interface and delegates to it. The difference is **who swaps the implementation, and whether the implementations know about each other.**

| | Strategy | State |
|---|---|---|
| Who changes it | The **client**, from **outside** | The **object itself / the current state**, from **inside** |
| How often | Rarely, often once at construction | Every time the lifecycle moves |
| Implementations know each other? | **No**, they're strangers | **Yes**: each state knows which states can come next |
| Models | Interchangeable **algorithms** for one job | **Modes** of one object, with legal and illegal transitions |
| Example | Sort comparator, retry policy, pricing rule | Order: Draft → Placed → Shipped → Delivered / Cancelled |

```python
# STATE: the state object moves the order to its successor
class Placed:
    def ship(self, order):   order.state = Shipped()
    def cancel(self, order): order.refund(); order.state = Cancelled()

class Shipped:
    def ship(self, order):   raise InvalidTransition("already shipped")
    def cancel(self, order): raise InvalidTransition("can't cancel after shipping")
```

**The quick test:** if `Placed` mentions `Shipped`, it's State. If `CheapestFirst` has never heard of `MostReliableFirst`, it's Strategy.

**Pragmatic note:** in most Python services, a lifecycle is an `Enum` plus an allowed-transitions table (`ALLOWED = {Placed: {Shipped, Cancelled}, ...}`) enforced in one method, with a DB `CHECK` constraint or a conditional `UPDATE ... WHERE status = 'PLACED'` for concurrency. The full State pattern only pays off when each state has substantial behaviour.

**Go deeper:** [[02.25 - Telling Similar Patterns Apart#State — the object changes its own behaviour as its lifecycle moves]] · [[02.16 - State]] · [[02.12 - Strategy]]

**Resource:** [Refactoring.Guru — State](https://refactoring.guru/design-patterns/state), which compares itself to Strategy explicitly.

---

### Q7. Adapter vs Decorator vs Proxy vs Facade: what's the difference?

**Answer**

All four **wrap** something. Ask two questions: **how many objects are wrapped**, and **what happens to the interface**?

| Pattern | Wraps | Interface the client sees | Purpose | Always delegates? |
|---|---|---|---|---|
| **Adapter** | One | **Different** (translated to ours) | Fix a mismatch | Yes, after translating |
| **Decorator** | One | **Same** | **Add** behaviour; stackable | **Yes** |
| **Proxy** | One | **Same** | **Control access**: lazy, remote, cache, auth | **Not necessarily**: may defer, deny or answer from cache |
| **Facade** | **Many** | **New, simpler** | Hide a complicated subsystem | Orchestrates several calls |

```python
gateway = LoggingGateway(          # DECORATOR: same interface, adds logging
    RetryingGateway(               # DECORATOR: same interface, adds retry
        KillSwitchGateway(         # PROXY: same interface, may refuse the call
            StripeAdapter(key))))  # ADAPTER: Stripe SDK → our interface

checkout = CheckoutFacade(inventory, gateway, orders, emails)   # FACADE: one place_order() over many
```

**Decorator vs Proxy** can be the exact same code. Name it by intent: **adding** behaviour (decorator) vs **gating access** (proxy). Saying "structurally identical, so I'd call this a proxy because it gates access" is a better answer than a confident guess.

**Real-library check:** `functools.lru_cache` (decorator / caching proxy), `requests.get` (facade over urllib3), LangChain's `ChatOpenAI` / `ChatAnthropic` (adapters to `BaseChatModel`), Django's lazy `request.user` (virtual proxy), a gRPC stub (remote proxy).

**Go deeper:** [[02.25 - Telling Similar Patterns Apart#Cheat Table — The Look-Alike Pairs]] · [[02.6 - Adapter]] · [[02.7 - Decorator]] · [[02.8 - Facade]] · [[02.9 - Proxy]]

---

### Q8. What's wrong with Singleton? How do you do it in Python?

**Answer**

**The problems:** it's **global mutable state** in disguise. It hides dependencies (a function silently reaches for `Config.instance()`), makes tests share state and leak into each other, is awkward with concurrency (lazy init races), and breaks when you actually need two (two DBs, or a test DB).

**What you actually want** is usually "**one instance per process, created at startup, passed to whoever needs it**":

```python
# A module is already a singleton: imported once per process
# settings.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    redis_url: str

settings = Settings()                  # one instance, created at import


# Or cached construction, with an easy override in tests
from functools import lru_cache

@lru_cache
def get_settings() -> Settings:
    return Settings()

# FastAPI: app.dependency_overrides[get_settings] = lambda: Settings(database_url="sqlite://")


# Expensive shared resources: create in lifespan, store on app.state, inject with Depends
```

**Legitimate uses:** connection pools, a process-wide logger or tracer, a loaded ML model. Even then, *create one and inject it* rather than writing a class that enforces its own uniqueness.

**Go deeper:** [[02.1 - Singleton]]

---

### Q9. How do Repository, Unit of Work and dependency injection fit together in a FastAPI service?

**Answer**

- **Repository:** a collection-like interface for one aggregate (`orders.get(id)`, `orders.add(order)`) that hides SQL from business logic.
- **Unit of Work:** one transaction per use case. Everything the use case changed is committed together, or rolled back together.
- **DI:** the endpoint receives a ready-made use case. Tests swap in in-memory fakes.

```python
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession


class OrderRepository(Protocol):
    async def get(self, order_id: int) -> Order | None: ...
    def add(self, order: Order) -> None: ...


class SqlOrderRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get(self, order_id):
        return await self.session.get(Order, order_id)

    def add(self, order):
        self.session.add(order)


class UnitOfWork:
    """One transaction per use case. SQLAlchemy's session already IS a unit of work. This names it."""

    def __init__(self, session_factory):
        self.session_factory = session_factory

    async def __aenter__(self):
        self.session = self.session_factory()
        self.orders = SqlOrderRepository(self.session)
        return self

    async def __aexit__(self, exc_type, *_):
        if exc_type:
            await self.session.rollback()
        else:
            await self.session.commit()
        await self.session.close()


async def cancel_order(uow: UnitOfWork, order_id: int) -> Order:     # business logic: no SQL, no HTTP
    async with uow:
        order = await uow.orders.get(order_id)
        if order is None:
            raise OrderNotFound(order_id)
        order.cancel()                         # domain rule lives on the entity
        return order


# FastAPI wiring (composition root)
def get_uow() -> UnitOfWork:
    return UnitOfWork(async_session_factory)

@app.post("/orders/{order_id}/cancel")
async def cancel(order_id: int, uow: UnitOfWork = Depends(get_uow)):
    return OrderOut.model_validate(await cancel_order(uow, order_id))

# Tests: app.dependency_overrides[get_uow] = lambda: FakeUnitOfWork()
```

**When it's overkill:** CRUD-only services with no real business rules. There, using the ORM directly in a thin service layer is fine.

**Go deeper:** [[02.20 - Repository Pattern]] · [[02.21 - Unit of Work]] · [[01.4 - Domain Modeling]]

**Resource:** [Cosmic Python (*Architecture Patterns with Python*)](https://www.cosmicpython.com/book/preface.html), free online. Chapters 2 (Repository) and 6 (Unit of Work) are this answer in full.

---

### Q10. When should you *not* use a design pattern?

**Answer**
- **When there's no variation yet.** One payment provider doesn't need a Strategy hierarchy. Add the seam when the second provider arrives (the "rule of three").
- **When a function will do.** A one-method class with no state is a function.
- **When it obscures the flow.** Five stacked decorators and an event bus for something a reader could follow as ten straight lines of code.
- **When the language already does it**: modules as singletons, generators as iterators, `with` as a resource-management template.
- **When the team won't recognise it.** A pattern is shared vocabulary. If nobody shares it, it's just indirection.

**The senior answer:** *"Patterns are a cost I pay for flexibility. I pay it where change has already happened or is clearly coming, and I can delete the abstraction when it stops earning its keep."*

**Go deeper:** [[02.0 - Patterns Overview#Common Pattern Mistakes]] · [[04.1 - Senior Engineer Thinking]] · [[05.5 - Avoiding Mistakes]]

---

## Further reading
- [Refactoring.Guru — Design Patterns](https://refactoring.guru/design-patterns): clear diagrams, and each page lists relations to other patterns.
- [Cosmic Python](https://www.cosmicpython.com/): Repository, Unit of Work, service layer, events and DI in idiomatic Python.
- [Python Design Patterns — Brandon Rhodes](https://python-patterns.guide/): which patterns Python makes unnecessary.
- *Head First Design Patterns* (2nd ed.): the clearest book on intent over structure.

