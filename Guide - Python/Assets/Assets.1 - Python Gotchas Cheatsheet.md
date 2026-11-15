**Up:** [[00 - Index (Python)]] | **Prev:** [[07.6 - Logging Done Right]]

---

# Python Gotchas Cheatsheet

#python #cheatsheet #gotchas

> **The rule:** every item here should feel obvious after the guide. If one surprises you, reread the linked note.

---

## Objects and Memory

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 1 | `b = a` does not copy; mutating `b` mutates `a` | `a.copy()`, `copy.deepcopy(a)`, or immutable data | [[01.2 - Mutability Equality and Copying]] |
| 2 | `[[0] * 3] * 3` makes three references to one row | `[[0] * 3 for _ in range(3)]` | [[01.2 - Mutability Equality and Copying]] |
| 3 | `x is 257` / `s is "text"` sometimes true, sometimes not | Use `==`; `is` only for `None` and sentinels | [[01.2 - Mutability Equality and Copying]] |
| 4 | `a += [x]` mutates in place; `a = a + [x]` rebinds | Know which one you mean when aliases exist | [[01.2 - Mutability Equality and Copying]] |
| 5 | `t[0] += [1]` on a tuple both mutates the list and raises | Do not `+=` into tuple elements | [[01.2 - Mutability Equality and Copying]] |
| 6 | `0.1 + 0.2 != 0.3` | `math.isclose`; `Decimal` for money | [[01.3 - Numbers That Bite]] |
| 7 | `Decimal(0.1)` is not `Decimal("0.1")` | Build Decimals from strings | [[01.3 - Numbers That Bite]] |
| 8 | `round(2.5) == 2` (banker's rounding) | `Decimal.quantize(..., ROUND_HALF_UP)` | [[01.3 - Numbers That Bite]] |
| 9 | `-7 // 2 == -4` and `-7 % 2 == 1` | Know Python floors; other languages truncate | [[01.3 - Numbers That Bite]] |
| 10 | `isinstance(True, int)` is `True` | Check `bool` first, or use strict validation | [[01.3 - Numbers That Bite]] |

## Functions and Scope

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 11 | Mutable default `def f(x=[])` is shared across calls | `x=None`, then create inside | [[02.1 - Parameters and Arguments]] |
| 12 | `def f(t=datetime.now())` is the import time | Default to `None`, compute inside | [[02.1 - Parameters and Arguments]] |
| 13 | Assigning to a name anywhere makes it local everywhere → `UnboundLocalError` | `nonlocal` / `global`, or rename | [[02.3 - Scopes and Closures]] |
| 14 | Lambdas in a loop all see the last loop value | `lambda i=i: ...`, `partial`, or a factory | [[02.3 - Scopes and Closures]] |
| 15 | Decorator without `functools.wraps` renames every function `wrapper` | Always `@wraps(func)` | [[02.4 - Decorators]] |
| 16 | Sync wrapper around an `async def` never awaits it | Separate async wrapper (`iscoroutinefunction`) | [[02.4 - Decorators]] |
| 17 | `lru_cache` on a method keeps every `self` alive | Cache a module function, or use `cached_property` | [[02.4 - Decorators]] |

## Modules

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 18 | `from mod import x` copies the binding; later rebinds are invisible | `import mod; mod.x` | [[03.1 - How Imports Work]] |
| 19 | Running a file as a script **and** importing it creates two modules | `python -m package.module` | [[03.1 - How Imports Work]] |
| 20 | Circular import → "partially initialized module" | Move shared code down a layer | [[03.1 - How Imports Work]] |
| 21 | Patching where a function is defined instead of where it is used | `patch("user_module.name")` | [[07.5 - Testing With pytest]] |

## Iteration and Collections

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 22 | Iterating a generator twice gives nothing the second time | `list(...)` once, or accept `Sequence` | [[04.3 - Iterables and Iterators]] |
| 23 | `groupby` on unsorted data repeats keys; stored groups go empty | Sort by the same key first; `list(group)` | [[04.5 - The itertools Toolkit]] |
| 24 | `zip` silently truncates mismatched lengths | `zip(..., strict=True)` | [[04.2 - Comprehensions]] |
| 25 | `list.pop(0)` and `x in list` are O(n) | `deque`; convert to `set` for membership | [[04.1 - Sequences and Slicing]] |
| 26 | Mutating a dict while iterating → `RuntimeError` | Iterate over `list(d)` | [[05.1 - How Dicts Work]] |
| 27 | `dict.fromkeys(keys, [])` shares one list | `{k: [] for k in keys}` | [[05.1 - How Dicts Work]] |
| 28 | Reading a missing key on a `defaultdict` inserts it | `k in d` or `d.get(k)` | [[05.3 - The collections Module]] |
| 29 | Subclassing `dict` misses `update()` and `__init__` overrides | `collections.UserDict` | [[05.3 - The collections Module]] |
| 30 | `hash(str)` differs between processes | `hashlib` / `zlib.crc32` for anything persisted or shared | [[05.1 - How Dicts Work]] |

## Classes

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 31 | Mutable class attribute shared by all instances | Initialise in `__init__` or `field(default_factory=...)` | [[06.1 - Classes and Instances]] |
| 32 | Defining `__eq__` makes the class unhashable | Add a matching `__hash__`, or `frozen=True` | [[05.2 - Sets and Hashing Your Own Classes]] |
| 33 | Mutating an object used as a dict key loses it | Hash only immutable fields | [[05.2 - Sets and Hashing Your Own Classes]] |
| 34 | Returning `False` instead of `NotImplemented` from `__eq__`/`__add__` | Return `NotImplemented` for unknown types | [[06.2 - Special Methods and the Data Model]] |
| 35 | An empty custom collection is falsy (`if obj:`) | Write `is not None` when you mean it | [[06.2 - Special Methods and the Data Model]] |
| 36 | `super()` is the next class in the MRO, not the parent | Cooperative `super()` everywhere, accept `**kwargs` | [[06.3 - Inheritance Composition and Protocols]] |
| 37 | A subclass without `__slots__` gets a `__dict__` back | Declare `__slots__` (even `()`) at every level | [[06.4 - Slots]] |
| 38 | A descriptor storing state on itself shares it across instances | Store on the instance (`__set_name__` + private name) | [[06.5 - Descriptors]] |

## Errors, Pickling, Logging

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 39 | `except Exception: pass` hides bugs | Catch specific errors; log at boundaries | [[06.7 - Exceptions]] |
| 40 | `return` in `finally` swallows the exception | Never return from `finally` | [[06.7 - Exceptions]] |
| 41 | Raising inside `except` without `from` looks like a handler bug | `raise New(...) from e` | [[06.7 - Exceptions]] |
| 42 | `pickle.loads` on untrusted data runs arbitrary code | JSON, or a restricted `Unpickler` | [[05.4 - Serialization]] |
| 43 | JSON turns tuples to lists, int keys to strings, rejects datetime/Decimal | Validate into models at the boundary | [[05.4 - Serialization]] |
| 44 | 64-bit IDs as JSON numbers lose precision in JavaScript | Send IDs as strings | [[05.4 - Serialization]] |
| 45 | `log.error(f"... {e}")` loses the traceback and evaluates eagerly | `log.exception("...", extra=...)` | [[07.6 - Logging Done Right]] |

## Pydantic

| # | Gotcha | Fix | Note |
|---|---|---|---|
| 46 | `x: int \| None` without a default is **required** | Add `= None` if it may be missing | [[07.3 - Pydantic Fundamentals]] |
| 47 | Lax mode coerces `"42"` → `42` and `"true"` → `True` | `strict=True` where mismatches mean bugs | [[07.3 - Pydantic Fundamentals]] |
| 48 | `model_copy(update=...)` and assignment skip validation | `validate_assignment=True` or rebuild with `model_validate` | [[07.3 - Pydantic Fundamentals]] |
| 49 | One model for input and output enables mass assignment and leaks | Separate `In` / `Out` / `Patch` models | [[07.4 - Pydantic in Production]] |
| 50 | `TypeAdapter(...)` created per request | Create once at module level | [[07.4 - Pydantic in Production]] |

---

**Next:** [[Assets.2 - Python Rapid Fire Questions]]
