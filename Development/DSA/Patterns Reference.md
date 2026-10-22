## What is a Pattern?

A DSA pattern is a reusable way of thinking about problems.

Instead of memorizing solutions, identify:

1. What information must be remembered?
    
2. What structure is repeating?
    
3. What constraint kills brute force?
    
4. Is the problem:
    
    - contiguous?
        
    - ordered?
        
    - hierarchical?
        
    - graph-like?
        
    - dependency-based?
        
    - optimization-based?
        

---

# 1. Frequency / Counting Pattern

> Remember occurrences of things.

### Common Data Structures

- HashMap / Dictionary
    
- Counter
    
- Array frequency table
    

### Used For

- Duplicates
    
- Frequency counting
    
- Pair sums
    
- Anagrams
    
- Tracking seen elements
    

### Examples

- Two Sum
    
- Valid Anagram
    
- Majority Element
    

### Core Idea

```python
freq[x] += 1
```

### Mental Trigger

> Need fast lookup or counting.

---

# 2. Prefix Sum Pattern

> Precompute cumulative information.

### Used For

- Range sums
    
- Subarray problems
    
- Balance calculations
    
- Difference tracking
    

### Core Idea

```python
prefix[i] = prefix[i - 1] + arr[i]
```

### Examples

- Subarray Sum Equals K
    
- Range Sum Query
    

### Mental Trigger

> Repeated range/sum calculations.

---

# 3. Sliding Window Pattern

> Maintain a moving range.

### Used For

- Subarrays
    
- Substrings
    
- Continuous sequences
    
- Window optimization
    

### Types

- Fixed-size window
    
- Dynamic window
    

### Examples

- Longest substring without repeating characters
    
- Maximum sum subarray of size K
    

### Mental Trigger

> Contiguous segment optimization.

---

# 4. Two Pointers Pattern

> Use two indices moving strategically.

### Used For

- Sorted arrays
    
- Pair searching
    
- Palindromes
    
- Partitioning
    

### Variants

- Opposite ends
    
- Fast/slow
    
- Merge-style
    

### Examples

- Container With Most Water
    
- Remove Duplicates from Sorted Array
    

### Mental Trigger

> Need O(n) instead of nested loops.

---

# 5. Fast & Slow Pointer Pattern

> Move pointers at different speeds.

### Used For

- Cycle detection
    
- Middle element finding
    
- Repeated transformations
    

### Examples

- Floyd Cycle Detection
    
- Happy Number
    

### Mental Trigger

> Repeated movement/process.

---

# 6. Binary Search Pattern

> Search efficiently in monotonic space.

### Used For

- Sorted arrays
    
- Answer search
    
- Capacity/time optimization
    
- Feasibility checking
    

### Types

- Exact search
    
- Lower bound
    
- Upper bound
    
- Binary search on answer
    

### Examples

- Search Insert Position
    
- Koko Eating Bananas
    
- Capacity to Ship Packages
    

### Mental Trigger

> Monotonic behavior exists.

---

# 7. Monotonic Stack Pattern

> Maintain increasing/decreasing order.

### Used For

- Next greater/smaller element
    
- Span problems
    
- Histogram area problems
    
- Visibility problems
    

### Examples

- Daily Temperatures
    
- Largest Rectangle in Histogram
    

### Mental Trigger

> Need nearest greater/smaller neighbor.

---

# 8. Monotonic Queue / Deque Pattern

> Efficient max/min maintenance in a moving window.

### Used For

- Sliding window maximum/minimum
    

### Examples

- Sliding Window Maximum
    

### Mental Trigger

> Need window max/min in O(n).

---

# 9. Heap / Priority Queue Pattern

> Always access smallest/largest efficiently.

### Used For

- Top K problems
    
- Scheduling
    
- Running median
    
- Greedy extraction
    

### Examples

- Kth Largest Element
    
- Merge K Sorted Lists
    

### Mental Trigger

> Repeatedly need best element.

---

# 10. Greedy Pattern

> Make locally optimal choices.

### Used For

- Scheduling
    
- Interval optimization
    
- Resource allocation
    

### Examples

- Activity Selection
    
- Jump Game
    
- Huffman Coding
    

### Mental Trigger

> Can we decide immediately without regret?

---

# 11. Backtracking Pattern

> Try → recurse → undo.

### Used For

- Permutations
    
- Combinations
    
- Constraint problems
    
- Exhaustive search
    

### Examples

- N Queens
    
- Sudoku Solver
    
- Subsets
    

### Core Structure

```python
choose
recurse
unchoose
```

### Mental Trigger

> Explore all valid possibilities.

---

# 12. Dynamic Programming (DP)

> Store overlapping subproblem results.

### Main Concepts

- State
    
- Transition
    
- Memoization
    
- Tabulation
    

### Common Subpatterns

- 1D DP
    
- 2D DP
    
- Knapsack
    
- LIS
    
- Interval DP
    
- Bitmask DP
    

### Examples

- Fibonacci
    
- Coin Change
    
- Longest Common Subsequence
    

### Mental Trigger

> Optimal substructure + repeated work.

---

# 13. Divide and Conquer

> Split problem recursively.

### Used For

- Sorting
    
- Recursive decomposition
    
- Parallelizable problems
    

### Examples

- Merge Sort
    
- Quick Sort
    
- Segment Tree
    

### Mental Trigger

> Independent recursive halves.

---

# 14. Merge Intervals Pattern

> Sort and merge overlapping intervals.

### Used For

- Scheduling
    
- Time overlap
    
- Range consolidation
    

### Examples

- Merge Intervals
    
- Meeting Rooms
    

### Mental Trigger

> Overlapping ranges.

---

# 15. Sweep Line Pattern

> Process events in sorted order.

### Used For

- Timeline overlap
    
- Geometry
    
- Active intervals
    

### Examples

- Meeting room overlap count
    

### Mental Trigger

> Events happening over time/coordinates.

---

# 16. Tree DFS Pattern

> Explore depth-first recursively.

### Types

- Preorder
    
- Inorder
    
- Postorder
    

### Used For

- Tree properties
    
- Paths
    
- Subtree aggregation
    

### Mental Trigger

> Hierarchical recursive structure.

---

# 17. Tree BFS / Level Order Pattern

> Explore level by level.

### Used For

- Minimum depth
    
- Level traversal
    
- Shortest level path
    

### Examples

- Binary Tree Level Order Traversal
    

### Mental Trigger

> Need nearest/level-wise traversal.

---

# 18. Graph Traversal Pattern

> Explore nodes and edges.

### Algorithms

- DFS
    
- BFS
    

### Used For

- Connectivity
    
- Components
    
- Reachability
    

### Examples

- Number of Islands
    
- Clone Graph
    

### Mental Trigger

> Network-like relationships.

---

# 19. Topological Sort Pattern

> Resolve dependency ordering.

### Used For

- DAGs
    
- Task scheduling
    
- Build systems
    

### Examples

- Course Schedule
    

### Mental Trigger

> A depends on B.

---

# 20. Union Find / DSU Pattern

> Efficient grouping/connectivity.

### Operations

- Find
    
- Union
    

### Used For

- Connected components
    
- Dynamic connectivity
    
- Kruskal MST
    

### Mental Trigger

> Repeated merging of groups.

---

# 21. Shortest Path Patterns

> Find minimum-cost path.

### Algorithms

- BFS (unweighted)
    
- Dijkstra
    
- Bellman-Ford
    
- Floyd-Warshall
    

### Mental Trigger

> Minimum cost/path.

---

# 22. Trie Pattern

> Efficient prefix matching.

### Used For

- Dictionaries
    
- Autocomplete
    
- Prefix search
    

### Mental Trigger

> Prefix-based lookup.

---

# 23. Segment Tree / Fenwick Tree Pattern

> Fast range queries and updates.

### Used For

- Dynamic prefix/range calculations
    
- Competitive programming
    

### Mental Trigger

> Many updates + many range queries.

---

# 24. Bit Manipulation Pattern

> Use binary-level optimization.

### Used For

- XOR tricks
    
- State compression
    
- Subset generation
    
- Power-of-two checks
    

### Examples

- Single Number
    
- Bitmask DP
    

### Mental Trigger

> Binary representation matters.

---

# 25. Matrix Traversal Pattern

> Traverse 2D structures.

### Used For

- Grid BFS/DFS
    
- Simulations
    
- Directional movement
    

### Examples

- Number of Islands
    
- Rotting Oranges
    

### Mental Trigger

> 2D movement/adjacency.

---

# 26. Simulation Pattern

> Directly model the process.

### Used For

- Games
    
- Robot movement
    
- Stateful operations
    

### Mental Trigger

> Just follow the rules carefully.

---

# 27. Recursion Pattern

> Define problem in terms of itself.

### Used For

- Trees
    
- Divide and conquer
    
- Recursive structures
    

### Mental Trigger

> Smaller identical subproblems.

---

# 28. State Machine Pattern

> Track finite states and transitions.

### Used For

- Stock DP
    
- Parsing
    
- Automata
    

### Mental Trigger

> Current state controls future decisions.

---

# 29. Meet in the Middle Pattern

> Split exponential search into halves.

### Used For

- Subset optimization
    
- Large brute-force reduction
    

### Mental Trigger

> 2^(n/2) feasible, 2^n not.

---

# 30. Randomized Pattern

> Use randomness for optimization/simplification.

### Used For

- Random pivot selection
    
- Probabilistic balancing
    

### Examples

- Quickselect
    
- Reservoir Sampling
    

---

# High-ROI Patterns (80/20)

These solve a huge percentage of interview questions:

1. HashMap / Frequency
    
2. Sliding Window
    
3. Two Pointers
    
4. Binary Search
    
5. DFS/BFS
    
6. Backtracking
    
7. Dynamic Programming
    
8. Heap
    
9. Monotonic Stack
    
10. Greedy
    
11. Union Find
    
12. Prefix Sum
    

---

# Ultimate Mental Compression

|Problem Type|Common Pattern|
|---|---|
|Remember things|HashMap|
|Continuous range|Sliding Window / Prefix Sum|
|Sorted optimization|Two Pointers / Binary Search|
|Hierarchical structure|Trees / DFS|
|Connectivity|Graph BFS/DFS / DSU|
|Dependencies|Topological Sort|
|Repeated best choice|Heap / Greedy|
|Explore all possibilities|Backtracking|
|Repeated subproblems|Dynamic Programming|
|Range queries|Segment Tree / Fenwick Tree|
|Neighbor comparisons|Monotonic Stack|
|Prefix matching|Trie|

---

# Final Advice

Do not try to memorize solutions.

Train yourself to recognize:

1. What information needs to persist?
    
2. What operation is repeated?
    
3. What structure naturally models the problem?
    
4. Which constraint eliminates brute force?
    

That is what pattern recognition actually is in DSA.