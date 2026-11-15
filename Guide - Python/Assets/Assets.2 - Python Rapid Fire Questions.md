**Up:** [[00 - Index (Python)]] | **Prev:** [[Assets.1 - Python Gotchas Cheatsheet]]

---

# Python Rapid Fire Questions

#python #interview #revision

> **How to use:** read the question, answer out loud in two sentences, then check. The **bold** part is what a strong answer must include. For longer interview-style answers, see [[04 - Python, Backend Engineering and AI System Design]] in the Interview guide.

---

## Objects and Memory

**What happens when you write `b = a` for a list?**
Both names are bound to the same object; nothing is copied. **Mutation through either name is visible through both.**

**`is` vs `==`?**
Identity vs value equality (`__eq__`). **Use `is` only for singletons like `None`; small-int and string interning make `is` on values unreliable.**

**How does CPython free memory?**
Reference counting frees objects immediately at zero; **a generational cycle collector handles reference cycles.**

**Shallow vs deep copy?**
Shallow copies the container and shares the elements; **deep copies recursively, with a memo dict for cycles, and is slow.**

**Why is `0.1 + 0.2 != 0.3`, and what do you use for money?**
Binary floats cannot represent 0.1 exactly. **`Decimal` built from strings, or integer minor units.**

## Functions

**Why is `def f(x=[])` a bug?**
Defaults are evaluated once, at `def` time, and stored on the function. **Every call shares the same list; use `None` and create inside.**

**What do `/` and `*` mean in a signature?**
Parameters before `/` are positional-only; after `*` are keyword-only. **Make flags keyword-only for readable call sites.**

**What is a closure, and what is the late-binding trap?**
A function that keeps variables from its enclosing scope, in cells. **It captures the variable, not the value, so closures made in a loop all see the final value.**

**What does `functools.wraps` do, and why does it matter?**
Copies `__name__`, `__doc__`, `__qualname__`, annotations and sets `__wrapped__`. **Without it, logging, routing, task naming and `inspect.signature` all break.**

**Write a decorator that takes arguments.**
Three layers: a factory returning a decorator returning a wrapper. **`@retry(3)` calls `retry(3)` first.**

**Why use `contextvars` instead of a global or a thread-local in async code?**
All coroutines share one thread; **each Task runs in its own copy of the context, so per-request values do not leak between requests.**

## Modules and Tooling

**What does `import x` do?**
Checks `sys.modules`; otherwise finds, creates, **inserts into `sys.modules`, then executes the module once**, and binds the name.

**Why do circular imports fail?**
The second import gets a partially executed module from `sys.modules`. **Fix the layering; or import the module rather than the name.**

**Why a `src/` layout?**
**Tests must import the installed package, not the working directory**, so packaging mistakes are caught.

**Library vs application dependency pinning?**
Libraries declare ranges; **applications lock exact versions** with a lockfile.

## Iteration

**Iterable vs iterator?**
An iterable returns a fresh iterator from `__iter__`; **an iterator has `__next__`, returns itself from `__iter__`, and is single-use.**

**What does a generator function return, and when does its body run?**
A generator object; **the body runs only on `next()`, pausing at each `yield`.**

**How do generators relate to async/await?**
`await` is built on the same suspend/resume machinery (`yield from`, `send`). **An event loop drives coroutines by sending values into them.**

**What does `with` guarantee, and how does `@contextmanager` work?**
`__exit__` runs even on exceptions. **Code before `yield` is enter, after is exit, and the body's exception is thrown in at the `yield`; wrap it in `try/finally`.**

## Hash Maps

**How does a dict look up a key?**
Hash → slot via mask → probe (open addressing) comparing **identity, then hash, then `==`**. Amortised O(1); resizes at about 2/3 full.

**Why are dicts ordered?**
The compact layout (3.6) stores entries densely in insertion order with a separate sparse index table. **Guaranteed since 3.7.**

**Why does defining `__eq__` make a class unhashable?**
Python sets `__hash__ = None` to protect the contract **equal objects must have equal hashes.**

**Why is `pickle` dangerous?**
`__reduce__` lets a pickle call any callable during loading. **Unpickling untrusted data is remote code execution.**

## Objects

**How does `obj.attr` lookup work?**
Data descriptor on the class, then instance `__dict__`, then non-data descriptors and class attributes along the MRO, then `__getattr__`. **That order explains properties, methods and `cached_property`.**

**classmethod vs staticmethod?**
A classmethod receives the class (alternative constructors that respect subclasses); **a staticmethod receives nothing.**

**What does `super()` do with multiple inheritance?**
It calls the next class in the instance's **MRO (C3 linearisation)**, not necessarily the parent.

**ABC vs Protocol?**
ABC: nominal, must inherit, enforced at instantiation. **Protocol: structural, checked by type checkers; any class with the methods matches.**

**What are `__slots__` for?**
Fixed attribute storage without a per-instance `__dict__`. **Less memory and typo protection, at the cost of flexibility.**

**What is a descriptor? Give three built-in examples.**
An object with `__get__`/`__set__`/`__delete__` on a class. **Functions (methods), `property`, `classmethod`; also slots and ORM columns.**

**`__init_subclass__` vs metaclass?**
`__init_subclass__` runs when a subclass is defined and covers registration and validation. **Metaclasses are needed only to control class creation itself (Enum, ORMs, Pydantic).**

**When do you use `raise ... from e`?**
When translating a low-level error into a domain error. **It keeps the original as `__cause__` in the traceback.**

**What is `except*` for?**
Handling parts of an `ExceptionGroup`, e.g. from `TaskGroup`. **Each clause takes the matching exceptions; the rest propagate.**

## Modern Python

**What do type hints do at runtime?**
Nothing, except being stored in `__annotations__`. **Checkers (mypy, pyright) use them statically; Pydantic and FastAPI read them to validate and generate schemas.**

**`Iterable` vs `Sequence` in a signature?**
`Iterable` promises one pass; **`Sequence` allows indexing, `len` and multiple passes.**

**Dataclass vs Pydantic model?**
Dataclass: generated boilerplate, no validation, for trusted internal data. **Pydantic: parses and validates untrusted input at boundaries.**

**What does "parse, don't validate" mean in Pydantic?**
Validation produces a typed object whose guarantees later code can trust. **Coercion happens once at the boundary.**

**Lax vs strict mode?**
Lax coerces sensible inputs (`"42"` → `42`); **strict rejects type mismatches. Use strict for internal messages where a mismatch is a bug.**

**What is a discriminated union, and why use it?**
A union with a literal tag field (`type`, `method`). **Pydantic validates against exactly one model: faster, clearer errors, `oneOf` in OpenAPI.**

**Why separate `OrderIn` and `OrderOut` models?**
**To prevent mass assignment on input and to filter sensitive fields on output.**

**How do you make a fixture that rolls back the database after each test?**
A session-scoped database plus a function-scoped fixture that **starts a transaction, yields, and rolls back.**

**What to mock?**
External services, time and randomness. **Not your own domain logic; prefer fakes implementing a Protocol over `MagicMock`.**

**Why can logging block an async service, and the fix?**
`StreamHandler` does a synchronous `write()` that blocks when the pipe is full. **`QueueHandler` plus `QueueListener` move writes to a thread.**

---

**Start again:** [[00 - Index (Python)]]
