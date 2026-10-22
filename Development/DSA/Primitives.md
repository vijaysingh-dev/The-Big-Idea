# DSA Primitive Pattern Recognition Cheat Sheet

> Goal:
> Learn to recognize what INFORMATION matters in a problem.
> Patterns are consequences of information compression.

---

# 1. Count / Frequency Pattern

## Core Idea
Only the NUMBER of occurrences matters.

You compress:
- positions
- ordering
- structure

into:
- frequency counts

Usually solved using:
- hashmap
- array frequency table
- Counter
- sliding window + counts

---

## Signals / Keywords

Questions involving:
- duplicates
- majority
- replacement
- anagram
- distinctness
- occurrence
- balance of symbols
- most frequent
- frequency
- repeated elements
- equal counts
- character distribution
- histogram-like reasoning

---

## Questions To Ask

### Elimination Questions
- Does exact position matter?
- Does ordering matter?
- Can two differently ordered inputs behave identically if counts match?
- Is the problem determined only by "how many"?

If YES:
→ count/frequency abstraction likely.

---

## Common Subpatterns

### A) Presence / Duplicate Detection
Examples:
- Contains Duplicate
- Happy Number

Typical DS:
- set
- hashmap

Question:
> Have I seen this before?

---

### B) Frequency Matching
Examples:
- Valid Anagram
- Permutation in String

Question:
> Do these two structures have same counts?

---

### C) Most Frequent / Majority
Examples:
- Majority Element
- Top K Frequent

Question:
> Which element dominates?

---

### D) Sliding Window + Counts
Examples:
- Longest Repeating Character Replacement
- Minimum Window Substring

Question:
> Can validity of a RANGE be expressed via counts?

---

### E) Balance Problems
Examples:
- Balanced parentheses count
- equal 0s and 1s

Question:
> Can I represent balance numerically?

---

# 2. Sum / Accumulation Pattern

## Core Idea
Maintain cumulative information incrementally.

Instead of recomputing:
- reuse previous totals

Usually solved using:
- prefix sum
- running total
- sliding window
- hashmap on prefix

---

## Signals / Keywords

Questions involving:
- sum
- total
- cumulative
- average
- target k
- subarray sum
- running value
- partial contribution

---

## Questions To Ask

- Can current answer be built from previous answer?
- Am I repeatedly adding same values?
- Can range info be derived from prefix info?

---

## Common Subpatterns

### A) Running Sum
Example:
- Maximum subarray

---

### B) Prefix Sum
Examples:
- Range Sum Query
- Subarray Sum Equals K

Question:
> Can range sum become:
prefix[j] - prefix[i] ?

---

### C) Prefix + Hashmap
Examples:
- Continuous Subarray Sum
- Equal 0s and 1s

Question:
> Have I seen this cumulative state before?

---

### D) Sliding Window Sum
Examples:
- Fixed-size max sum
- Average subarray

Question:
> Can I add right and remove left efficiently?

---

# 3. Min / Max Optimization Pattern

## Core Idea
Track best/worst candidate dynamically.

Usually solved using:
- greedy
- heap
- deque
- DP

---

## Signals / Keywords

Questions involving:
- maximum
- minimum
- best
- optimal
- largest
- smallest
- closest

---

## Questions To Ask

- Do I only care about the best-so-far?
- Can a bad candidate be discarded permanently?
- Is local optimality enough?

---

## Common Subpatterns

### A) Running Best
Examples:
- Best Time to Buy and Sell Stock

---

### B) Monotonic Queue
Examples:
- Sliding Window Maximum

Question:
> Can weaker candidates be eliminated forever?

---

### C) Heap Selection
Examples:
- K largest elements

Question:
> Do I only need top-k candidates?

---

# 4. Membership / Lookup Pattern

## Core Idea
Fast existence checking.

Usually solved using:
- set
- hashmap

---

## Signals / Keywords

Questions involving:
- exists
- lookup
- seen before
- complement
- pair existence

---

## Questions To Ask

- Am I repeatedly searching?
- Do I need O(1) existence checks?

---

## Common Subpatterns

### A) Complement Lookup
Examples:
- Two Sum

Question:
> If x exists, answer found?

---

### B) State Visited
Examples:
- Graph traversal
- cycle detection

Question:
> Have I processed this already?

---

# 5. Order / Monotonicity Pattern

## Core Idea
Relative ordering matters.

Usually solved using:
- stack
- monotonic stack
- binary search
- sorting

---

## Signals / Keywords

Questions involving:
- next greater
- increasing
- decreasing
- nearest larger
- previous smaller
- sorted property

---

## Questions To Ask

- Is relative order important?
- Can ordering eliminate possibilities?
- Is there monotonic behavior?

---

## Common Subpatterns

### A) Monotonic Stack
Examples:
- Daily Temperatures
- Next Greater Element

Question:
> Who is waiting for a better future element?

---

### B) Binary Search on Answer
Examples:
- Koko Eating Bananas

Question:
> If x works, do larger values also work?

(monotonic condition)

---

### C) Sorting-Based Reduction
Examples:
- Merge intervals
- meeting rooms

Question:
> Does sorting simplify relationships?

---

# 6. Pair Relationship Pattern

## Core Idea
Problem depends on interaction between two positions.

Usually solved using:
- two pointers
- nested loops optimization
- hashing

---

## Signals / Keywords

Questions involving:
- pair
- triplet
- difference
- distance
- relation between indices

---

## Questions To Ask

- Is answer defined by relationship between elements?
- Can sorted order help?

---

## Common Subpatterns

### A) Two Sum Style
Examples:
- Two Sum
- 3Sum

---

### B) Two Pointers
Examples:
- Container With Most Water

Question:
> Can one pointer movement eliminate possibilities?

---

# 7. Range / Window Validity Pattern

## Core Idea
Find largest/smallest contiguous range satisfying constraint.

Usually solved using:
- sliding window
- deque
- prefix structures

---

## Signals / Keywords

Questions involving:
- longest substring
- smallest subarray
- at most k
- no more than
- contiguous
- window validity

---

## Questions To Ask

- Is the structure contiguous?
- Can validity be updated incrementally?
- If invalid, can shrinking restore validity?

---

## Common Subpatterns

### A) Fixed Window
Examples:
- max sum of size k

---

### B) Dynamic Window
Examples:
- Longest substring without repeating chars
- Character Replacement

Question:
> Expand until invalid, shrink until valid?

---

### C) Monotonic Window
Examples:
- Sliding Window Maximum

---

# 8. Choice / Dependency Pattern

## Core Idea
Current decision affects future states.

Usually solved using:
- recursion
- memoization
- DP
- greedy

---

## Signals / Keywords

Questions involving:
- choose
- pick or skip
- ways
- combinations
- maximize choices
- future dependency

---

## Questions To Ask

- Does current action constrain future?
- Are subproblems repeated?
- Is brute force branching exponentially?

---

## Common Subpatterns

### A) Pick / Skip Recursion
Examples:
- House Robber
- Subset Sum

---

### B) Sequence DP
Examples:
- LIS
- Edit Distance

Question:
> Can state summarize the past sufficiently?

---

### C) Knapsack
Examples:
- 0/1 knapsack

Question:
> Resource constraint + choices?

---

# Meta Problem-Solving Flow

When solving ANY problem:

## Step 1
What is being searched?
- element?
- pair?
- range?
- subsequence?

---

## Step 2
Write brute force mentally.

---

## Step 3
Identify repeated work.

Repeated:
- sums
- counts
- comparisons
- searches
- transitions

---

## Step 4
Ask what information is ACTUALLY necessary.

Can you discard:
- positions?
- order?
- exact values?
- history?

---

## Step 5
Map reduced information to primitive.

| Information Needed | Primitive |
|---|---|
| Counts | Frequency |
| Running totals | Prefix Sum |
| Best candidate | Min/Max |
| Fast existence | Set/Hash |
| Relative order | Stack/Binary Search |
| Range validity | Sliding Window |
| Choices/future dependency | DP |
| Pair interaction | Two Pointers |

---

# Most Important Mindset

DO NOT ask:

> "Which pattern is this?"

Ask:

> "What information is sufficient to decide validity/answer?"

Patterns emerge from information compression.