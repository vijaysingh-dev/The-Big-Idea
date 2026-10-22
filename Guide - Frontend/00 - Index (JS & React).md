# Frontend Master Course — Index

> **Purpose**: A single, permanent reference for JavaScript, the browser, HTML/CSS, React and frontend architecture. Depth-first, example-heavy, revision-optimized. Every note is self-contained: read it once to learn, skim it later to revise.
>
> **How to read**: Notes are linked in a single linear chain via **Prev** / **Next**. The order below is the reading order. Folders are for organization only — the chain crosses folder boundaries.

---

## Navigation

### 01 — JavaScript Execution Model

| File | Topic |
| ---- | ----- |
| [[01.1 - How JavaScript Runs]] | Engine vs runtime, parsing, JIT compilation, optimization |
| [[01.2 - Execution Context and Scope Chain]] | Creation vs execution phase, variable environment |
| [[01.3 - The Call Stack]] | Frames, stack overflow, reading stack traces |
| [[01.4 - The Event Loop]] | Single thread, non-blocking concurrency model |
| [[01.5 - Web APIs and the Task Queue]] | Timers, I/O, macrotasks, where async work actually runs |
| [[01.6 - Microtasks vs Macrotasks]] | Ordering rules, starvation, queueMicrotask |
| [[01.7 - The Rendering Cycle]] | Frame budget, requestAnimationFrame, requestIdleCallback |

### 02 — Functions and Scope

| File | Topic |
| ---- | ----- |
| [[02.1 - Function Declarations Expressions and IIFE]] | Forms of functions, hoisting differences, module pattern |
| [[02.2 - Lexical Scope]] | Static scoping, shadowing, block vs function scope |
| [[02.3 - Closures]] | What they are mechanically, why they exist |
| [[02.4 - Closure Patterns in Production]] | Private state, memoization, once, event handlers |
| [[02.5 - Higher Order Functions and Callbacks]] | Functions as values, composition, pipelines |
| [[02.6 - Arrow Functions]] | Lexical this, no arguments, when not to use them |
| [[02.7 - this in JavaScript]] | All binding rules, real-world breakage cases |
| [[02.8 - call apply and bind]] | Explicit binding, polyfilling bind |
| [[02.9 - Currying and Partial Application]] | Practical uses in config and API layers |

### 03 — Objects and Prototypes

| File | Topic |
| ---- | ----- |
| [[03.1 - Objects and Property Descriptors]] | Getters, setters, enumerability, freeze/seal |
| [[03.2 - The Prototype Chain]] | \_\_proto\_\_ vs prototype, lookup mechanics |
| [[03.3 - Prototypal Inheritance and Object.create]] | Delegation over copying |
| [[03.4 - Classes vs Prototypes]] | Sugar or not, private fields, static members |
| [[03.5 - Shallow vs Deep Copy]] | Spread, structuredClone, JSON pitfalls |
| [[03.6 - Symbols and Well Known Symbols]] | Unique keys, iterator protocol hooks |

### 04 — Asynchronous JavaScript

| File | Topic |
| ---- | ----- |
| [[04.1 - Callbacks and Callback Hell]] | Inversion of control, error-first convention |
| [[04.2 - Promises from First Principles]] | States, then/catch/finally, building a mini promise |
| [[04.3 - Promise Chaining and Error Handling]] | Flattening, error propagation, unhandled rejections |
| [[04.4 - async await]] | Desugaring to promises, sequential vs parallel traps |
| [[04.5 - Promise Combinators]] | all, allSettled, any, race and when each fits |
| [[04.6 - AbortController and Cancellation]] | Cancelling fetch, timeouts, cleanup |
| [[04.7 - Async Concurrency Patterns]] | Queues, concurrency limits, retries with backoff |

### 05 — Language Fundamentals

| File | Topic |
| ---- | ----- |
| [[05.1 - var let and const]] | Scope, redeclaration, reassignment, loop capture |
| [[05.2 - Hoisting and the Temporal Dead Zone]] | What is really hoisted and why TDZ exists |
| [[05.3 - Types Coercion and Equality]] | Primitives, == vs ===, coercion table, Object.is |
| [[05.4 - null vs undefined]] | Intent, defaults, API design implications |
| [[05.5 - Destructuring]] | Objects, arrays, nesting, defaults, function params |
| [[05.6 - Spread vs Rest]] | Same syntax, opposite jobs |
| [[05.7 - Optional Chaining and Nullish Coalescing]] | Safe access, falsy vs nullish |
| [[05.8 - Template Literals and Tagged Templates]] | Interpolation, multiline, tagged template use cases |
| [[05.9 - Error Handling and Custom Errors]] | try/catch/finally, Error subclassing, cause |

### 06 — Arrays, Iteration and Data Structures

| File | Topic |
| ---- | ----- |
| [[06.1 - map filter reduce and forEach]] | Core transforms, reduce as a universal tool |
| [[06.2 - find some every and includes]] | Search and predicate methods |
| [[06.3 - flat flatMap and Reshaping Data]] | Grouping, indexing, denormalizing API payloads |
| [[06.4 - Sorting and Comparators]] | Stability, locale compare, sorting objects |
| [[06.5 - Map and Set]] | When they beat plain objects and arrays |
| [[06.6 - Iterators and Generators]] | Iteration protocol, lazy sequences, async generators |
| [[06.7 - Immutable Data Patterns]] | Non-mutating updates on nested structures |

### 07 — Memory Management

| File | Topic |
| ---- | ----- |
| [[07.1 - How Garbage Collection Works]] | Reachability, generational and mark-sweep GC |
| [[07.2 - Memory Leaks from Closures and Timers]] | Retained scopes, forgotten intervals |
| [[07.3 - Memory Leaks from Listeners and Detached DOM]] | The most common real-world leak |
| [[07.4 - WeakMap WeakSet and WeakRef]] | Weak references, caches, metadata |
| [[07.5 - Profiling Memory in DevTools]] | Heap snapshots, allocation timeline, diffing |

### 08 — Modules and Advanced Language Features

| File | Topic |
| ---- | ----- |
| [[08.1 - ES Modules vs CommonJS]] | Static vs dynamic, live bindings, interop |
| [[08.2 - Dynamic Imports]] | Runtime loading, code splitting foundation |
| [[08.3 - Proxy and Reflect]] | Interception, how reactive libraries work |
| [[08.4 - Web Workers]] | Moving work off the main thread |
| [[08.5 - Serialization and Structured Clone]] | postMessage, JSON limits, transferables |

### 09 — HTML Essentials

| File | Topic |
| ---- | ----- |
| [[09.1 - Semantic HTML and Document Structure]] | Landmarks, headings, why semantics matter |
| [[09.2 - Forms and Native Input Behavior]] | Inputs, labels, native validation, submission |
| [[09.3 - Images Media and Loading Attributes]] | srcset, sizes, lazy, decoding, aspect ratio |
| [[09.4 - Head Metadata and SEO Basics]] | Meta tags, Open Graph, canonical, crawlability |
| [[09.5 - Accessibility Fundamentals]] | Roles, ARIA, focus management, keyboard support |

### 10 — CSS Essentials

| File | Topic |
| ---- | ----- |
| [[10.1 - The Cascade Specificity and Inheritance]] | How a value actually gets chosen |
| [[10.2 - The Box Model and Sizing]] | Content box vs border box, margin collapse |
| [[10.3 - Selectors and Pseudo Classes]] | Combinators, :is, :where, :has |
| [[10.4 - Units Custom Properties and Theming]] | rem/em/vh/clamp, CSS variables, dark mode |
| [[10.5 - Positioning and Stacking Contexts]] | position values, z-index, containing blocks |

### 11 — CSS Layout and Responsive Design

| File | Topic |
| ---- | ----- |
| [[11.1 - Flexbox]] | One-dimensional layout, common recipes |
| [[11.2 - CSS Grid]] | Two-dimensional layout, template areas, auto-fit |
| [[11.3 - Responsive Design]] | Media queries, container queries, fluid type |
| [[11.4 - Transitions and Animations]] | Keyframes, easing, animating cheaply |
| [[11.5 - CSS Architecture]] | BEM, CSS Modules, Tailwind, CSS-in-JS tradeoffs |

### 12 — The DOM and Events

| File | Topic |
| ---- | ----- |
| [[12.1 - The DOM Tree and Node APIs]] | Nodes vs elements, traversal, live collections |
| [[12.2 - DOM Manipulation]] | Creating, inserting, fragments, batching writes |
| [[12.3 - The Event Model]] | Capturing, target, bubbling, event objects |
| [[12.4 - Event Delegation]] | One listener for many nodes, dynamic content |
| [[12.5 - Custom Events and Observer APIs]] | Intersection, Mutation and Resize observers |

### 13 — Browser Rendering

| File | Topic |
| ---- | ----- |
| [[13.1 - The Critical Rendering Path]] | HTML to pixels, render-blocking resources |
| [[13.2 - Reflow Repaint and Composite]] | The three costs and how to avoid the expensive ones |
| [[13.3 - Layout Thrashing]] | Forced synchronous layout, read/write batching |
| [[13.4 - Compositor Layers and GPU Acceleration]] | will-change, transform/opacity, layer explosion |
| [[13.5 - Core Web Vitals]] | LCP, INP, CLS — what they measure and how to fix them |

### 14 — Browser Storage

| File | Topic |
| ---- | ----- |
| [[14.1 - Cookies]] | Attributes, SameSite, HttpOnly, size limits |
| [[14.2 - LocalStorage and SessionStorage]] | Sync API cost, quotas, cross-tab sync |
| [[14.3 - IndexedDB]] | Structured async storage, when it is worth it |
| [[14.4 - Cache API and Service Workers]] | Offline, precaching, runtime caching strategies |

### 15 — Networking, Auth and Security

| File | Topic |
| ---- | ----- |
| [[15.1 - HTTP Fundamentals]] | Methods, status codes, headers, idempotency |
| [[15.2 - The Fetch API]] | Requests, responses, streaming, error semantics |
| [[15.3 - Same Origin Policy and CORS]] | Preflight, credentials, debugging CORS failures |
| [[15.4 - Authentication vs Authorization]] | Identity vs permissions, flows overview |
| [[15.5 - JWT Sessions and Token Storage]] | Access/refresh tokens, where to store them |
| [[15.6 - Frontend Security]] | XSS, CSRF, clickjacking, CSP |
| [[15.7 - HTTP Caching and CDNs]] | Cache-Control, ETag, revalidation, edge caching |
| [[15.8 - WebSockets and Server Sent Events]] | Real-time transport choices |

### 16 — React Fundamentals

| File | Topic |
| ---- | ----- |
| [[16.1 - Why React]] | The problem with imperative DOM code |
| [[16.2 - JSX]] | Compilation, expressions, gotchas |
| [[16.3 - Components and Props]] | Composition, children, prop design |
| [[16.4 - State and useState Mental Model]] | Snapshots, batching, updater functions |
| [[16.5 - Rendering and Purity]] | Render as a pure function, side effect boundaries |
| [[16.6 - Lists and Keys]] | Why keys exist, why index keys break things |
| [[16.7 - Conditional Rendering and Composition]] | Patterns that avoid prop explosions |
| [[16.8 - Controlled vs Uncontrolled Components]] | Source of truth tradeoffs |
| [[16.9 - Lifecycle in the Hooks Era]] | Class lifecycle mapped to hooks |

### 17 — React Hooks

| File | Topic |
| ---- | ----- |
| [[17.1 - Rules of Hooks and How They Work]] | The hook linked list, why order matters |
| [[17.2 - useState in Depth]] | Lazy init, functional updates, derived state |
| [[17.3 - useEffect and the Dependency Array]] | Timing, cleanup, dependency correctness |
| [[17.4 - useEffect Pitfalls]] | Effects you should delete, infinite loops, races |
| [[17.5 - useLayoutEffect vs useEffect]] | Paint blocking, measuring the DOM |
| [[17.6 - useMemo]] | When memoizing helps and when it costs |
| [[17.7 - useCallback]] | Referential stability, dependency chains |
| [[17.8 - useRef]] | Mutable boxes, DOM refs, instance variables |
| [[17.9 - useContext]] | Reading context, re-render behavior |
| [[17.10 - useReducer]] | Complex state transitions, state machines |
| [[17.11 - Custom Hooks]] | Extracting logic, naming, testing |
| [[17.12 - Lesser Known Hooks]] | useId, useSyncExternalStore, useDebugValue |

### 18 — React Internals

| File | Topic |
| ---- | ----- |
| [[18.1 - Virtual DOM and React Elements]] | What an element really is |
| [[18.2 - Reconciliation and the Diffing Algorithm]] | Heuristics, element type identity |
| [[18.3 - Fiber Architecture]] | Units of work, the fiber tree, double buffering |
| [[18.4 - Render Phase vs Commit Phase]] | Interruptible vs synchronous work |
| [[18.5 - Concurrent Rendering and the Scheduler]] | Priorities, time slicing, yielding |
| [[18.6 - Batching and the Update Queue]] | Automatic batching, flushSync |
| [[18.7 - Strict Mode and Double Invocation]] | What it catches and why |

### 19 — React Performance

| File | Topic |
| ---- | ----- |
| [[19.1 - What Causes Re-renders]] | Parent renders, context, state locality |
| [[19.2 - React.memo and Memoization Strategy]] | Where memo actually pays off |
| [[19.3 - Code Splitting and React.lazy]] | Route and component level splitting |
| [[19.4 - Suspense]] | Declarative loading, fallback boundaries |
| [[19.5 - Virtualization and Windowing]] | Rendering 100k rows |
| [[19.6 - Image and Asset Optimization]] | Formats, sizing, priority hints |
| [[19.7 - Bundle Analysis and Optimization]] | Finding and removing weight |
| [[19.8 - Profiling with React DevTools]] | Flamegraphs, why-did-render investigation |
| [[19.9 - The React Compiler]] | Automatic memoization and what it changes |

### 20 — State Management

| File | Topic |
| ---- | ----- |
| [[20.1 - Where State Should Live]] | Server, URL, global, local — a decision framework |
| [[20.2 - Context API and Its Limits]] | Provider re-renders, splitting contexts |
| [[20.3 - Redux Core Concepts]] | Store, actions, reducers, dispatch, purity |
| [[20.4 - Redux Toolkit]] | Slices, createAsyncThunk, RTK Query |
| [[20.5 - Middleware and Thunks]] | The dispatch pipeline, side effects |
| [[20.6 - Immer and Immutable Updates]] | Drafts, structural sharing |
| [[20.7 - State Normalization]] | Entity maps, avoiding duplicated server data |
| [[20.8 - Zustand Jotai and Modern Alternatives]] | Store shapes, selectors, tradeoffs |

### 21 — Forms

| File | Topic |
| ---- | ----- |
| [[21.1 - Controlled Forms in Practice]] | Wiring, performance of large forms |
| [[21.2 - Validation Strategies]] | Client vs server, schema validation, UX timing |
| [[21.3 - React Hook Form]] | Uncontrolled-first design, resolvers |
| [[21.4 - Complex Forms]] | Field arrays, wizards, autosave, dirty state |

### 22 — Advanced React Patterns

| File | Topic |
| ---- | ----- |
| [[22.1 - Error Boundaries]] | Catching render errors, fallback UX |
| [[22.2 - Portals]] | Modals, tooltips, event bubbling through portals |
| [[22.3 - forwardRef and useImperativeHandle]] | Exposing imperative APIs deliberately |
| [[22.4 - useTransition and startTransition]] | Marking updates non-urgent |
| [[22.5 - useDeferredValue]] | Keeping input responsive under heavy renders |
| [[22.6 - Compound Components]] | Flexible component APIs with context |
| [[22.7 - Render Props and HOCs]] | Legacy patterns you will still meet |
| [[22.8 - Server Components]] | The RSC model, boundaries, data flow |

### 23 — Routing

| File | Topic |
| ---- | ----- |
| [[23.1 - Client Side Routing Fundamentals]] | History API, why SPAs need routers |
| [[23.2 - React Router Setup and Nested Routes]] | Layout routes, outlets |
| [[23.3 - Dynamic Routes and Params]] | Params, search params, state in the URL |
| [[23.4 - Protected Routes and Auth Flows]] | Guards, redirects, restoring intent |
| [[23.5 - Lazy Routes]] | Route level code splitting and prefetching |
| [[23.6 - Data Loading with Loaders and Actions]] | Router-driven data fetching |

### 24 — API Handling and Server State

| File | Topic |
| ---- | ----- |
| [[24.1 - Building an API Layer]] | fetch vs axios, interceptors, typed clients |
| [[24.2 - Loading Error and Empty States]] | State machines for requests |
| [[24.3 - Retries Timeouts and Cancellation]] | Backoff, idempotency, aborting stale requests |
| [[24.4 - Pagination and Infinite Scroll]] | Offset vs cursor, intersection-driven loading |
| [[24.5 - Optimistic UI]] | Predicting success, rollback on failure |
| [[24.6 - TanStack Query Fundamentals]] | Query keys, the cache, lifecycle |
| [[24.7 - Caching Stale Time and Invalidation]] | staleTime vs gcTime, refetch triggers |
| [[24.8 - Optimistic Updates with TanStack Query]] | Mutations, cache surgery, rollback |

### 25 — TypeScript for Frontend

| File | Topic |
| ---- | ----- |
| [[25.1 - Types vs Interfaces]] | Declaration merging, unions, when to pick which |
| [[25.2 - Generics]] | Constraints, inference, generic components |
| [[25.3 - Utility Types]] | Pick, Omit, Partial, Record, ReturnType |
| [[25.4 - Typing Props and Children]] | Component typing patterns beyond React.FC |
| [[25.5 - Typing Events Refs and Hooks]] | Event types, ref types, typed custom hooks |
| [[25.6 - Discriminated Unions and Narrowing]] | Modelling impossible states away |
| [[25.7 - Typing API Responses and Zod]] | Runtime validation meeting compile-time types |

### 26 — Testing

| File | Topic |
| ---- | ----- |
| [[26.1 - Testing Philosophy]] | What to test, the testing trophy |
| [[26.2 - Unit Testing with Vitest and Jest]] | Setup, mocking, async tests |
| [[26.3 - React Testing Library]] | Queries, user-event, testing behavior not internals |
| [[26.4 - Mocking the Network with MSW]] | Realistic request interception |
| [[26.5 - End to End Testing with Playwright]] | Critical path coverage, flakiness |

### 27 — Build Tooling and Deployment

| File | Topic |
| ---- | ----- |
| [[27.1 - npm and package.json]] | Scripts, semver, lockfiles, dependency hygiene |
| [[27.2 - Module Bundling Concepts]] | Entry, graph, chunks, why bundlers exist |
| [[27.3 - Vite]] | Dev server, esbuild, Rollup builds, config |
| [[27.4 - Webpack Basics]] | Loaders, plugins, splitChunks |
| [[27.5 - Babel and Transpilation]] | Targets, polyfills, browserslist |
| [[27.6 - Tree Shaking]] | Side effects, ESM requirements, why it fails |
| [[27.7 - Source Maps]] | Types, production strategy, error tracking |
| [[27.8 - Environment Variables and Config]] | Build-time vs runtime, secrets that are not secret |
| [[27.9 - CI CD and Frontend Deployment]] | Pipelines, previews, cache headers, rollbacks |

### 28 — Frontend System Design

| File | Topic |
| ---- | ----- |
| [[28.1 - How to Approach a Frontend System Design Interview]] | Framework, timeboxing, what interviewers score |
| [[28.2 - Project Structure and Architecture]] | Feature-sliced layout, boundaries, scaling a codebase |
| [[28.3 - Component Design and API Design]] | Props as an API, composition over configuration |
| [[28.4 - The Data Layer]] | Client abstraction, DTOs, adapters |
| [[28.5 - Global Error Handling]] | Boundaries, reporting, user-facing recovery |
| [[28.6 - Caching Strategy Across Layers]] | Memory, query cache, HTTP, CDN, service worker |
| [[28.7 - Authentication Flow Design]] | Login, refresh, silent renewal, logout everywhere |
| [[28.8 - Feature Flags and Progressive Rollout]] | Targeting, kill switches, experiment safety |
| [[28.9 - Micro Frontends]] | Module federation, isolation, real costs |
| [[28.10 - Design Systems and Component Libraries]] | Tokens, primitives, versioning, adoption |
| [[28.11 - Rendering Strategies]] | CSR, SSR, SSG, ISR, streaming — how to choose |
| [[28.12 - Real Time and Offline First]] | Sync, conflict resolution, queued mutations |
| [[28.13 - Frontend Observability]] | RUM, error tracking, logging, tracing to the backend |
| [[28.14 - Case Study - News Feed]] | Infinite feed, media, virtualization, freshness |
| [[28.15 - Case Study - Autocomplete]] | Debounce, cancellation, caching, keyboard a11y |
| [[28.16 - Case Study - Chat Application]] | Transport, ordering, presence, optimistic sends |

### 29 — Cross-Cutting Performance Techniques

| File | Topic |
| ---- | ----- |
| [[29.1 - Debounce and Throttle]] | Implementations, tradeoffs, where each belongs |
| [[29.2 - Prefetching and Preloading]] | Resource hints, predictive loading |
| [[29.3 - Lazy Loading Assets and Components]] | Deferring work without hurting UX |
| [[29.4 - Measuring Performance]] | Lighthouse, Web Vitals in the field, budgets |

### 30 — Rapid Fire Question Bank

| File | Topic |
| ---- | ----- |
| [[30.1 - Rapid Fire - JavaScript]] | Short answers with links back to the deep notes |
| [[30.2 - Rapid Fire - Async and Event Loop]] | Output-prediction questions |
| [[30.3 - Rapid Fire - Browser and DOM]] | Storage, CORS, rendering |
| [[30.4 - Rapid Fire - React]] | Hooks, internals, performance |
| [[30.5 - Rapid Fire - Redux and State]] | State management questions |
| [[30.6 - Rapid Fire - HTML CSS and Accessibility]] | Layout, cascade, semantics |
| [[30.7 - Machine Coding Drills]] | Polyfills, debounce, deep clone, promise combinators |

---

**Start here:** [[01.1 - How JavaScript Runs]]
