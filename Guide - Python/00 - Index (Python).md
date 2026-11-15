# Python — Master Index

> **Purpose**: The Python *language*, learned deeply enough that nothing in a production codebase surprises you. It follows the arc of Fred Baptiste's **Python 3: Deep Dive** (Parts 1–4), trims what a backend engineer does not need, and adds what the course does not cover: type hints, dataclasses, **Pydantic**, packaging, pytest and logging.
>
> **How to read**: Notes are linked in one chain with **Prev** / **Next**. Each note ends with a **Codebase** box (CPython or library source to read), an **Exercise** box, and a **Resources** table — the same three-pass method as the Backend guide.
>
> **What comes next**: The runtime (bytecode, the GIL, asyncio) lives in [[00 - Index (Backend)]] section 01. This guide stops where that one starts.

---

## Course Map

| Udemy: Python 3 Deep Dive | This guide | Kept, trimmed, or added |
| ---- | ----- | ----- |
| Part 1 — Variables and memory, numeric types | 01 | Kept. Complex numbers dropped |
| Part 1 — Function parameters, first-class functions, scopes, closures, decorators | 02 | Kept in full. The heart of Part 1 |
| Part 1 — Tuples and named tuples | [[05.3 - The collections Module]], [[07.2 - Dataclasses]] | Merged. Named tuples are compared with dataclasses and Pydantic |
| Part 1 — Modules, packages, namespaces | 03 | Kept, plus modern packaging (uv, pyproject) |
| Part 2 — Sequences, iterables, iterators, generators, itertools, context managers | 04 | Kept in full |
| Part 2 — Generators as coroutines (`send`, `yield from`) | [[04.4 - Generators]] (briefly) | Trimmed. Modern async lives in Backend [[01.5 - Coroutines Tasks and Futures]] |
| Part 3 — Dictionaries, sets, specialised dicts | 05 | Kept |
| Part 3 — Serialization (JSON, schemas, marshmallow, YAML) | [[05.4 - Serialization]], 07.3–07.4 | marshmallow replaced by **Pydantic** |
| Part 4 — Classes, special methods, inheritance, slots, descriptors, enums, exceptions, metaprogramming | 06 | Kept in full. Descriptors and metaprogramming are where Pydantic and ORMs come from |
| Not in the course | 07 | **Added**: type hints, dataclasses, Pydantic, pytest, logging |
| Basics refresher, course projects | — | Dropped. Each note's Exercise replaces the projects |

---

## Navigation

### 00 — Start Here

| File | Topic |
| ---- | ----- |
| [[00.1 - How To Use This Guide]] | Pairing the notes with the course, the drill repo, revision rhythm |

### 01 — Objects and Memory

| File | Topic |
| ---- | ----- |
| [[01.1 - Names Objects and References]] | Variables are labels, `id`, reference counting, garbage collection |
| [[01.2 - Mutability Equality and Copying]] | Mutable vs immutable, `is` vs `==`, interning, shallow and deep copy |
| [[01.3 - Numbers That Bite]] | Arbitrary-precision ints, float error, `Decimal` for money, rounding |

### 02 — Functions

| File | Topic |
| ---- | ----- |
| [[02.1 - Parameters and Arguments]] | Positional, keyword, `*args`, `**kwargs`, `/` and `*`, the mutable default trap |
| [[02.2 - First-Class Functions]] | Functions as objects, lambdas, `partial`, `operator`, introspection |
| [[02.3 - Scopes and Closures]] | LEGB, `global`, `nonlocal`, cells, the late-binding trap |
| [[02.4 - Decorators]] | `wraps`, parameterised decorators, class decorators, `lru_cache`, `singledispatch` |

### 03 — Modules Packages and Tooling

| File | Topic |
| ---- | ----- |
| [[03.1 - How Imports Work]] | `sys.modules`, finders and loaders, `__main__`, circular imports, namespace packages |
| [[03.2 - Packaging and Project Tooling]] | `pyproject.toml`, venvs, uv, src layout, lockfiles, ruff |

### 04 — Sequences and Iteration

| File | Topic |
| ---- | ----- |
| [[04.1 - Sequences and Slicing]] | The sequence protocol, slicing, in-place ops, sorting, custom sequences |
| [[04.2 - Comprehensions]] | List, dict, set comprehensions, their scope, when not to use them |
| [[04.3 - Iterables and Iterators]] | `__iter__` vs `__next__`, exhaustion, lazy evaluation |
| [[04.4 - Generators]] | `yield`, generator state, pipelines, `yield from`, `send` |
| [[04.5 - The itertools Toolkit]] | `islice`, `chain`, `groupby`, `batched`, `tee`, and friends |
| [[04.6 - Context Managers]] | The `with` protocol, `contextlib`, `ExitStack`, async context managers |

### 05 — Hash Maps and Collections

| File | Topic |
| ---- | ----- |
| [[05.1 - How Dicts Work]] | Hashing, open addressing, the compact dict, ordering, cost |
| [[05.2 - Sets and Hashing Your Own Classes]] | Set algebra, the `__hash__`/`__eq__` contract, frozen objects |
| [[05.3 - The collections Module]] | `defaultdict`, `Counter`, `deque`, `ChainMap`, `namedtuple`, `OrderedDict` |
| [[05.4 - Serialization]] | JSON and its limits, custom encoders, pickle's danger, orjson, msgpack |

### 06 — Object-Oriented Python

| File | Topic |
| ---- | ----- |
| [[06.1 - Classes and Instances]] | Class vs instance attributes, binding, `classmethod`, `staticmethod`, `property` |
| [[06.2 - Special Methods and the Data Model]] | `__repr__`, comparisons, operators, `__call__`, containers, `__bool__` |
| [[06.3 - Inheritance Composition and Protocols]] | `super()`, the MRO, mixins, ABCs, `typing.Protocol`, composition first |
| [[06.4 - Slots]] | `__slots__`, memory savings, what you give up |
| [[06.5 - Descriptors]] | `__get__`/`__set__`, data vs non-data, `__set_name__`, how `property` works |
| [[06.6 - Enums]] | `Enum`, `IntEnum`, `StrEnum`, `Flag`, enums in APIs and databases |
| [[06.7 - Exceptions]] | The hierarchy, `raise from`, custom hierarchies, `ExceptionGroup`, `except*` |
| [[06.8 - Metaprogramming]] | Class decorators, `__init_subclass__`, metaclasses, when not to |

### 07 — Modern Python in Production

| File | Topic |
| ---- | ----- |
| [[07.1 - Type Hints and Static Checking]] | Annotations, generics, `Protocol`, `TypedDict`, mypy and pyright |
| [[07.2 - Dataclasses]] | `@dataclass`, `field`, `frozen`, `slots`, vs namedtuple, attrs and Pydantic |
| [[07.3 - Pydantic Fundamentals]] | `BaseModel`, parsing vs validating, fields, validators, serialization |
| [[07.4 - Pydantic in Production]] | Settings, discriminated unions, `TypeAdapter`, FastAPI, performance, v1 → v2 |
| [[07.5 - Testing With pytest]] | Fixtures, parametrize, mocking, async tests, property-based testing |
| [[07.6 - Logging Done Right]] | The logging tree, handlers, structured JSON logs, async-safe logging |

---

## Assets (Quick Reference)

| File | Contents |
| ---- | ----- |
| [[Assets.1 - Python Gotchas Cheatsheet]] | The 30 behaviours that surprise experienced developers, with one-line fixes |
| [[Assets.2 - Python Rapid Fire Questions]] | Interview drills for every section |

---

## Suggested Pace

| Block | Sections | Rough time | Alongside |
| ---- | ----- | ----- | ----- |
| Foundations | 01, 02, 03 | 3 weeks | Deep Dive Part 1 |
| Iteration | 04 | 2 weeks | Deep Dive Part 2 |
| Data | 05 | 1–2 weeks | Deep Dive Part 3 |
| Objects | 06 | 3 weeks | Deep Dive Part 4 |
| Production | 07 | 2 weeks | Your own projects. Start using Pydantic and pytest everywhere |

Then go straight into Backend section 01: [[01.1 - How Python Actually Runs Your Code]].

---

**Start here:** [[00.1 - How To Use This Guide]]
