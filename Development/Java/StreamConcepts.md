## Key Stream Concepts
| Operation Type | Java Stream                     | Python Equivalent               |
| -------------- | ------------------------------- | ------------------------------- |
| Create stream  | `list.stream()`                 | `iter(list)` or just list       |
| Filter         | `.filter(x -> x > 0)`           | `filter(lambda x: x > 0, list)` |
| Map            | `.map(x -> x * 2)`              | `map(lambda x: x * 2, list)`    |
| Reduce         | `.reduce(0, Integer::sum)`      | `sum(list)` or `reduce()`       |
| Collect        | `.collect(Collectors.toList())` | `list()`                        |
| Terminal op    | `.forEach(...)`                 | `for x in ...:`                 |
<br>
## Python Built-ins vs Java Equivalents
| Python Function   | Java Equivalent                                                       | Notes                                  |
| ----------------- | --------------------------------------------------------------------- | -------------------------------------- |
| `len(list)`       | `list.size()`                                                         | For arrays: `array.length`             |
| `range(n)`        | `IntStream.range(0, n)`                                               | Exclusive of end like Python           |
| `range(a, b)`     | `IntStream.range(a, b)`                                               | Just like Python                       |
| `iter(list)`      | `list.iterator()`                                                     | Returns an `Iterator`                  |
| `map(f, list)`    | `list.stream().map(f).toList()`                                       | Use `Collectors.toList()` in Java 8–15 |
| `filter(f, list)` | `list.stream().filter(f).toList()`                                    | Functional filtering                   |
| `sum(list)`       | `list.stream().mapToInt(i -> i).sum()`                                | Or `.reduce(0, Integer::sum)`          |
| `min(list)`       | `Collections.min(list)` or `list.stream().min(...)`                   | With comparator if needed              |
| `max(list)`       | `Collections.max(list)` or `list.stream().max(...)`                   | Same as min                            |
| `sorted(list)`    | `list.stream().sorted().toList()`                                     | Default sort                           |
| `reversed(list)`  | `Collections.reverse(list)`                                           | Modifies list in-place                 |
| `any(list)`       | `list.stream().anyMatch(f)`                                           | Returns boolean                        |
| `all(list)`       | `list.stream().allMatch(f)`                                           | Returns boolean                        |
| `' '.join(list)`  | `String.join(" ", list)`                                              | Works on lists of strings              |
| `enumerate(list)` | `IntStream.range(0, list.size())`                                     | Pair index with element                |
| `zip(a, b)`       | Custom logic using `IntStream.range(0, Math.min(a.size(), b.size()))` | Java has no built-in zip               |
<br>
## Java Cheatsheet (for Pythonistas)
| Goal            | Python                     | Java Stream/Lib Equivalent       |
| --------------- | -------------------------- | -------------------------------- |
| Iterable        | `iter(lst)`                | `lst.iterator()`                 |
| Indexing loop   | `for i in range(len(lst))` | `IntStream.range(0, lst.size())` |
| Apply function  | `map(f, lst)`              | `lst.stream().map(f)`            |
| Filter          | `filter(f, lst)`           | `lst.stream().filter(f)`         |
| Combine strings | `''.join(lst)`             | `String.join("", lst)`           |
| Accumulate      | `reduce(f, lst)`           | `lst.stream().reduce(f)`         |
| Count           | `len(lst)`                 | `lst.size()`                     |
| Sort            | `sorted(lst)`              | `lst.stream().sorted().toList()` |
| All match       | `all(f(x) for x in lst)`   | `lst.stream().allMatch(f)`       |
| Any match       | `any(f(x) for x in lst)`   | `lst.stream().anyMatch(f)`       |
