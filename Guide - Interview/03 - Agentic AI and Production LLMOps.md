**Up:** [[00 - Index (Interview)]] | **Prev:** [[02 - Retrieval-Augmented Generation (RAG)]]

---

# 03 — Agentic AI and Production LLMOps

> Agents, tools, LangGraph, memory, multi-agent systems, MCP, security, evals, observability and cost.

---

## Section A: Agent foundations

### Q1. What is an AI agent? How is it different from a chain or a workflow?

**Answer**
A useful distinction (from Anthropic's "Building effective agents"):
- **Workflow:** LLM calls and tools arranged in a **fixed path that you define in code**. Example: classify → retrieve → answer. Predictable, testable and cheap.
- **Agent:** the **LLM decides the control flow**. It chooses which tool to call, with what arguments, and when it's done, in a loop, based on what it observes.

A minimal agent is: **LLM + tools + a loop + a stopping condition.**

```
while not done and steps < max_steps:
    response = llm(messages, tools)
    if response.has_tool_calls:
        results = execute(response.tool_calls)
        messages += [response, results]
    else:
        done = True
```

**When to use which:**
- **Workflows** when the steps are known in advance. That's most business processes, and they're easier to evaluate and debug.
- **Agents** when the path depends on what's discovered along the way (open-ended research, debugging, multi-step tasks over varied tools), and you can tolerate more latency, cost and variance.
- Many good systems are **mostly workflow with small agentic pieces.**

**Likely follow-ups**
- *What's the biggest mistake teams make?* Building a multi-agent system when one well-prompted LLM call, or a simple workflow, would do. Start simple, and add autonomy only when evals show it's needed.

**What a strong answer shows:** A crisp definition, plus the judgement to prefer simpler designs.

**Go deeper:** [[08.1 - What Agents Actually Are]] · [[08 - Agents Fundamentals]]

---

### Q2. Explain the ReAct pattern.

**Answer**
**ReAct (Reason + Act)** interleaves reasoning with tool use:
1. **Thought:** the model reasons about what to do next.
2. **Action:** it calls a tool with arguments.
3. **Observation:** the tool result is added to the context.
4. Repeat until it can give a **final answer**.

Why it works: reasoning helps the model pick good actions, and observations ground its reasoning in real data instead of guesses.

Today it's mostly implemented with **native tool calling** (structured tool calls) rather than parsing "Thought:/Action:" text, which was fragile. LangGraph's prebuilt `create_react_agent` is essentially this loop.

**Likely follow-ups**
- *ReAct's weaknesses?*
  - It can loop, repeating the same failing action.
  - It's greedy: it decides one step at a time without a plan.
  - Long tool outputs fill the context.
  - Errors compound over many steps.
- *How do you mitigate those?* Step limits, deduplicating repeated calls, truncating or summarising tool output, a plan-then-execute structure for long tasks, and reflection or validation steps.

**What a strong answer shows:** You know the pattern *and* its failure modes in practice.

**Go deeper:** [[08 - Agents Fundamentals]]

---

### Q3. Which other agent design patterns do you know?

**Answer**
- **Prompt chaining:** a fixed sequence of calls, with checks between steps.
- **Routing:** classify the input, then send it to a specialised prompt, model or sub-graph. Also cheap model routing: simple requests go to a small model.
- **Parallelisation:**
  - *Sectioning*: independent subtasks run at once, e.g. checking several documents.
  - *Voting*: run the same task several times and take the majority, for higher confidence.
- **Orchestrator-workers:** a central LLM breaks the task into subtasks dynamically, hands them to workers, and combines the results.
- **Evaluator-optimizer (reflection):** one call generates, another critiques against criteria, and the loop repeats until the result passes or a limit is hit. Good when quality criteria are clear (code that must pass tests, writing that follows a style guide).
- **Plan-and-execute:** write an explicit plan first, run its steps (possibly with a cheaper model), and re-plan when an observation changes things. Better for long tasks than pure ReAct.
- **Human-in-the-loop:** pause for approval at risky points (Q9).

**What a strong answer shows:** A vocabulary of patterns, and when each one fits.

**Go deeper:** [[09 - Agent Patterns and LangGraph]] · [[08.3 - Memory Planning and Reflection]]

---

## Section B: Tools

### Q4. Walk me through exactly how tool calling works end to end.

**Answer**
1. **Define tools:** name, description and parameter JSON Schema. In Python this usually comes from type hints or a Pydantic model.
2. **First call:** send the messages plus the tool definitions to the model.
3. **Model output:** either text, or one or more tool calls `{id, name, arguments_json}`. Modern APIs support **parallel tool calls** in one turn.
4. **Your code:** validate the arguments, check permissions, execute the tool (with a timeout), and capture the result **or the error**.
5. **Send results back** as tool-result messages linked by the call `id`.
6. **Repeat** until the model returns a final answer or you hit a limit.

Important points:
- **The model never executes anything.** Your code is the trust boundary. Every check, permission and side effect lives there.
- **Tool errors are information, not crashes.** Return a clear error string ("Invalid date format, expected YYYY-MM-DD") so the model can fix its call.
- **Tool output size:** truncate, paginate or summarise large results so they don't flood the context.

**Likely follow-ups**
- *How do you run tools concurrently?* When the model asks for several independent calls in one turn, run them with `asyncio.gather` (or a TaskGroup), each with its own timeout, then return all the results together.

**What a strong answer shows:** You understand where control and trust sit in the loop.

**Go deeper:** [[03.11 - Structured Outputs and Tool Calling]] · [[14.2 - Function Calling and Structured Outputs]]

---

### Q5. What makes a tool well-designed for an agent?

**Answer**
Treat the tool interface as a UX for the model. Anthropic calls this the "agent-computer interface".
- **Clear names and descriptions:** say what it does, *when* to use it, and when *not* to. Include examples and formats. Descriptions are prompts.
- **Simple, strongly typed parameters:** enums instead of free text, explicit units and formats, sensible defaults, as few required fields as possible.
- **Few, distinct tools:** overlapping tools confuse selection. Merge or namespace them.
- **Useful outputs:** concise and relevant, with IDs the model can pass to the next tool. Don't dump raw 10k-line JSON.
- **Helpful errors:** explain what went wrong and how to fix it.
- **Idempotent where possible:** calling it twice with the same arguments gives the same effect, so retries are safe. For side-effecting tools, use **idempotency keys**: a unique request ID the server uses to ignore duplicates.
- **Least privilege:** read-only by default; scoped credentials; a separate "propose" step vs. an "execute" step for dangerous actions.
- **Dry-run modes** for destructive operations.

**What a strong answer shows:** You think about tools as APIs designed for a fallible caller.

**Go deeper:** [[14.2 - Function Calling and Structured Outputs]]

---

### Q6. What is MCP (Model Context Protocol), and why does it matter?

**Answer**
**MCP** is an open protocol, introduced by Anthropic in late 2024 and now widely adopted, that standardises how AI applications connect to tools and data.
- **Before MCP:** every app (IDE, chat client, agent framework) needed custom integrations for every tool. M apps × N tools.
- **With MCP:** a tool provider writes one **MCP server**, and any **MCP client** inside a host app (Claude Desktop, IDEs, agent frameworks) can use it. M + N.

Core concepts:
- **Host** (the app), **client** (the connection inside the host), **server** (exposes capabilities).
- What a server can expose:
  - **Tools:** functions the model can call.
  - **Resources:** data the app can read.
  - **Prompts:** reusable templates.
- **Transports:** `stdio` for local processes, and HTTP-based transports (streamable HTTP) for remote servers.

Why it matters to a company: build internal capabilities (a KB search, a ticketing system, a deployment status check) **once** as MCP servers, and every AI tool in the organisation can use them, with consistent auth and auditing.

**Likely follow-ups**
- *Security concerns?* MCP servers are code and data you're trusting.
  - A malicious or compromised server can return injected instructions, or overreach with its tools.
  - Tool descriptions themselves can be "poisoned".
  - Mitigations: vet servers, scope permissions, use auth (OAuth for remote servers), and require human approval for sensitive actions.

**What a strong answer shows:** You understand the integration problem MCP solves, and its trust model.

---

## Section C: LangGraph and orchestration

### Q7. Why use a framework like LangGraph? Explain its core concepts.

**Answer**
**Why a graph framework:** real agents need explicit control flow (branches, loops, retries), **persisted state** (resume after a crash, multi-turn conversations), human approval steps, streaming and observability. Hand-rolling all of that is error-prone. LangGraph models an agent as a **state machine**.

Core concepts:
- **State:** a typed object (TypedDict or Pydantic) shared by every node. Each node reads the state and returns a **partial update**.
- **Reducers:** define how updates merge into existing state. For example, `messages` uses `add_messages` (append, and replace by ID), while other fields default to overwrite. This matters for parallel branches writing to the same key.
- **Nodes:** Python functions (sync or async), e.g. call the LLM, run tools, retrieve, validate.
- **Edges:**
  - *Normal* edges: always A → B.
  - *Conditional* edges: a function looks at the state and picks the next node. This is where loops and routing live.
  - `START` / `END` mark the entry and exit.
- **Checkpointer:** saves the state after every step (in memory, SQLite, Postgres, Redis), keyed by `thread_id`. It enables multi-turn memory, crash recovery, **time travel** (replaying or forking from an earlier step) and human-in-the-loop.
- **`interrupt()` / `Command(resume=...)`:** pause inside a node for human input, then continue from exactly that point.
- **`Send`:** dynamic fan-out. Spawn N parallel tasks at runtime (map-reduce), e.g. one research task per subtopic.
- **Subgraphs:** a compiled graph used as a node, for modular multi-agent systems.
- **Streaming:** stream state updates, LLM tokens or custom events to the client.
- **`recursion_limit`:** a hard cap on steps per run (Q10).

**Likely follow-ups**
- *LangGraph vs. CrewAI vs. the OpenAI Agents SDK vs. plain Python?*
  - **LangGraph:** low-level, explicit and very controllable; best for production flows that need persistence and human approval.
  - **CrewAI:** higher-level, role-based "crews" of agents; quick to prototype, less fine control.
  - **Vendor SDKs** (OpenAI Agents SDK, Claude Agent SDK): simple handoff/agent primitives, closely tied to that provider.
  - **Plain Python:** perfectly fine for simple loops, with no dependency risk.
  - Choose based on how much control, persistence and portability you need.
- *What happens when two parallel nodes write the same state key?* Without a reducer it's a conflict error, or the last write wins. With a reducer (e.g. append to a list), the writes merge deterministically.

**What a strong answer shows:** You understand state, reducers, checkpointing and interrupts: the concepts that make agents production-ready, beyond "nodes and edges".

**Go deeper:** [[07.2 - LangGraph and Stateful Workflows]] · [[09 - Agent Patterns and LangGraph]] · [[07.3 - Custom Orchestration vs Frameworks]]

---

### Q8. When should you use multi-agent systems? Supervisor vs. swarm?

**Answer**
**Use multiple agents when:**
- The task naturally splits into **specialties** with different tools or prompts (researcher, coder, reviewer), and one prompt with every tool gets confused.
- Subtasks can run in **parallel** (research many sources at once).
- You want **context isolation:** each sub-agent sees only what it needs, which keeps each context small and focused.

**Avoid them when** a single agent with good tools works. Multi-agent systems multiply cost and latency, add coordination failures (agents misunderstanding each other, duplicated work), and are harder to evaluate and debug.

**Topologies:**
- **Supervisor (hierarchical):** a central agent routes work to specialist workers and combines their results. Easier to control, and a clear place to set limits. The supervisor can become a bottleneck.
- **Swarm / handoffs (peer-to-peer):** agents pass control directly to each other ("transfer to billing agent"). Flexible and lower latency, but harder to reason about globally.
- **Hierarchical teams:** supervisors of supervisors, for large problems.
- **Shared state vs. message passing:** whether agents write to one shared state or exchange only messages or summaries. Summaries keep contexts small; shared state is simpler but noisier.

**Likely follow-ups**
- *How do you evaluate a multi-agent system?* Evaluate each agent's sub-task alone, plus end-to-end outcomes. Trace every handoff. Track cost and latency per agent.

**What a strong answer shows:** Clear criteria for when multi-agent is worth it, plus knowledge of the topologies.

**Go deeper:** [[08.2 - Agent Architectures - Single vs Multi]]

---

## Section D: Control, memory and safety

### Q9. How do you design human-in-the-loop (HITL) into an agent?

**Answer**
Put HITL wherever an action is **irreversible, expensive, external-facing or low-confidence**: sending emails, executing payments, deleting data, deploying, posting publicly.

Patterns:
- **Approve or reject:** pause before a tool call, show the proposed action and arguments, then run or cancel.
- **Edit:** the human modifies the arguments or the draft, then resumes.
- **Review the output:** the agent drafts; a human publishes.
- **Escalation:** low confidence or a failed validation routes to a human queue.

Implementation (LangGraph):
1. Call `interrupt(payload)` inside the node.
2. The graph state is checkpointed and the run returns the interrupt payload to your API.
3. The UI shows it to the user.
4. Resume with `Command(resume=decision)` on the same `thread_id`.

Because state is persisted, the approval can come minutes or days later, from another server.

Design considerations:
- **Timeouts:** what happens if nobody responds?
- **Audit log:** who approved what, and when.
- **Approval fatigue:** don't ask for everything, or people click approve blindly. Use risk tiers.
- **Show the evidence:** let the reviewer see *why* the agent proposes this.

**What a strong answer shows:** Risk-based placement of approval points, plus knowing that durable state is what makes this possible.

**Go deeper:** [[07.2 - LangGraph and Stateful Workflows]]

---

### Q10. How do you stop an agent from looping forever or burning money?

**Answer**
Use layered limits:
1. **Step limit:** `recursion_limit` (LangGraph) or `max_iterations`. Catch the error and return a graceful partial answer.
2. **Per-loop counters in state:** e.g. `retries < 2` for a query-rewrite loop, checked in the conditional edge.
3. **Token and cost budget per request:** track usage in state and stop or downgrade the model when exceeded.
4. **Wall-clock timeout** for the whole run, plus timeouts per tool and per LLM call.
5. **Repeat detection:** the same tool with the same arguments twice in a row means stop or redirect.
6. **Progress checks:** a cheap judge or heuristic asks "is the agent getting closer?" over the last N steps.
7. **Termination criteria in the prompt:** define what "done" looks like.
8. **Monitoring:** alert on the distribution of steps per run, on cost per run, and on outliers.

**What a strong answer shows:** Defence in depth, with both code-level guarantees and observability.

**Go deeper:** [[08.4 - Observability Guardrails and Cost Control]]

---

### Q11. How does memory work in agents? Short-term vs. long-term.

**Answer**
- **Short-term (working) memory:** the conversation and state within one thread.
  - It lives in the message list, persisted by the checkpointer.
  - Problem: it grows without bound. Strategies:
    - **Trimming:** keep the last N turns or tokens. Always keep the system prompt, and keep tool-call/result pairs together.
    - **Summarisation:** compress older turns into a running summary.
    - **Selective retention:** drop bulky tool outputs and keep only conclusions.
- **Long-term memory:** persists *across* threads and sessions.
  - **Semantic memory:** facts about the user or world ("prefers Python", "Aman's birthday is 12 Nov"). Stored as records or embeddings and retrieved by relevance.
  - **Episodic memory:** past interactions or experiences ("last time this error happened, restarting the worker fixed it"). Useful as few-shot examples.
  - **Procedural memory:** how to behave, e.g. learned instructions or updated system prompts.
  - LangGraph provides a **Store** (key-value plus optional vector search, namespaced e.g. `("user", user_id)`) that is separate from the checkpointer.
- **When to write memories:**
  - *Hot path*: the agent decides during the conversation. Immediate, but adds latency.
  - *Background*: a separate process extracts memories after the conversation. Cheaper, with better judgement.

Pitfalls:
- **Storing wrong or outdated facts:** you need update and delete logic and conflict resolution.
- **Privacy:** what may be stored, user control, deletion requests, sensitive categories.
- **Retrieving irrelevant memories,** which pollutes the context.
- **Memory poisoning:** a malicious input writes false memories that persist.

**Likely follow-ups**
- *Checkpointer vs. Store?* The checkpointer holds per-thread execution state (resume, time travel). The Store holds cross-thread application data (user facts). Different lifecycles and different access patterns.

**What a strong answer shows:** A clear taxonomy, practical context management, and attention to the correctness and privacy of stored memories.

**Go deeper:** [[08.3 - Memory Planning and Reflection]] · [[03.12 - Memory and Context Management]]

---

### Q12. What is context engineering?

**Answer**
"Context engineering" is the practice of deciding **exactly what goes into the model's context at each step**: instructions, tools, retrieved knowledge, memory, history, and the results of previous steps. It's a broader idea than prompt engineering, and very relevant for agents, whose context grows with every step.

Techniques:
- Give **only the relevant tools** for each step or route.
- **Summarise or compress** long histories and tool outputs.
- **Isolate context** in sub-agents, which return only a summary.
- Use **structured scratchpads** in state instead of keeping everything in messages.
- Put **stable content first** for prompt caching.
- Fetch information **just in time** with tools, instead of front-loading everything.

**What a strong answer shows:** Awareness that agent quality is largely about managing what the model sees.

**Go deeper:** [[03.12 - Memory and Context Management]]

---

### Q13. What are the main security risks with LLM agents, and how do you mitigate them?

**Answer**
- **Direct prompt injection:** the user tells the model to ignore its instructions.
- **Indirect prompt injection:** malicious instructions hidden in *content the agent reads*: web pages, emails, documents, tool results, MCP responses. This is the more dangerous one for agents.
- **The "lethal trifecta"** (Simon Willison's term): an agent that has **(1)** access to private data, **(2)** exposure to untrusted content, and **(3)** a way to send data out (send email, make HTTP requests, even render image URLs) can be tricked into leaking data. Remove at least one of the three for risky flows.
- **Excessive agency:** tools with broader permissions than needed.
- **Insecure output handling:** passing LLM output straight into SQL, shell commands, `eval`, or HTML (XSS).
- **Data leakage:** sensitive data in prompts, logs or responses; cross-tenant leakage through retrieval.
- **Denial of wallet:** inputs that trigger very expensive loops.

**Mitigations** (no single fix; use layers):
- Treat all LLM output as **untrusted user input**: validate, parameterise SQL, sandbox code execution, escape HTML.
- **Least privilege** for tools and credentials; per-user auth enforced *in the tool*, never by the model.
- **Separate trusted instructions from untrusted data** (delimiters, explicit statements) and remember this is only partial protection.
- **Human approval** for high-impact actions.
- **Input/output classifiers** for injection and data-leak patterns.
- **Allow-lists** for outbound domains; no auto-rendering of external URLs.
- **Rate and cost limits.**
- **Red-team testing,** with injection cases in the eval suite.

**What a strong answer shows:** You understand that prompt injection isn't "solved", and you design capabilities and permissions assuming the model can be manipulated.

**Go deeper:** [[14.4 - AI Security]]

---

## Section E: Production LLMOps

### Q14. What guardrails would you put on a production LLM application?

**Answer**
Guardrails sit at several layers:

**Input:**
- Auth and rate limiting (normal API hygiene).
- Size and format limits.
- Prompt-injection and jailbreak detection (classifiers or heuristics).
- **PII** detection and redaction (PII = personally identifiable information: emails, phone numbers, ID numbers).
- Topic or scope restrictions (refuse off-topic requests).

**Retrieval and tools:**
- ACL filters.
- Untrusted-content marking.
- Tool permission checks.
- Argument validation.

**Output:**
- Schema validation (Pydantic).
- Grounding and citation checks.
- Toxicity and safety classifiers.
- PII leakage checks.
- Business-rule checks ("never promise refunds above X").
- Format and length limits.

**Action:** approval gates; dry-runs; idempotency keys.

**Tools:** Bedrock Guardrails, NeMo Guardrails, Guardrails AI, LLM-Guard, provider moderation APIs, or custom validators.

**Tradeoffs:**
- Every guardrail adds latency and false positives (blocking good requests).
- Run cheap checks first, and run independent ones in parallel.
- Decide **fail-open vs. fail-closed** per risk: if the guardrail itself errors, do you allow the request or block it?
- Measure the block rate and review samples of blocked requests.

**What a strong answer shows:** Layered thinking, and awareness of the costs and failure modes of guardrails themselves.

**Go deeper:** [[10.7 - Safety Systems and Abuse Prevention]] · [[14.4 - AI Security]]

---

### Q15. How do you evaluate an agent, not just a single LLM call?

**Answer**
Agents can succeed or fail along the *path*, not just in the final answer:
- **Final outcome:** was the task completed correctly? Use deterministic checks where possible (tests pass, the right database row exists, the answer matches) or an LLM judge with a rubric.
- **Trajectory evaluation:** did it call the right tools, in a sensible order, with correct arguments, without wasted steps? Compare against reference trajectories, or score with rules ("must call `check_permissions` before `delete`").
- **Single-step evals:** test the router, the tool selection or the grader node in isolation, with fixed inputs. These are cheap, fast and stable.
- **Efficiency:** steps, tokens, cost and latency per task.
- **Safety:** injection resistance, refusal correctness, approval-gate compliance.
- **Simulated users:** an LLM plays the user in multi-turn scenarios, for conversational agents.

**Practicalities:**
- Agents are non-deterministic, so run each case several times and report **pass rates**, not single pass/fail results.
- Pin model versions and seeds where possible; use a temperature of 0 for evaluation runs.
- Keep a regression suite drawn from production failures.

**What a strong answer shows:** You evaluate the process as well as the outcome, and handle non-determinism statistically.

**Go deeper:** [[13.3 - Evaluation Deep Dive]] · [[06 - Evaluation]]

---

### Q16. What does eval-driven development look like in practice?

**Answer**
Treat evals like unit tests for AI behaviour:
1. **Define success** for the feature, with rubrics and examples, together with product and domain experts.
2. **Build a dataset** of real or realistic cases, including hard and adversarial ones, and version it.
3. **Write scorers:** deterministic first (exact match, schema validity, citation checks, SQL results), then LLM-as-judge for subjective qualities, calibrated against human labels.
4. **Run on every change** (prompt, model, retrieval settings, tools), locally and in **CI**. Fail the build on regressions beyond a threshold.
5. **Online evaluation:** sample production traffic, score it asynchronously, and track user feedback and business metrics (resolution rate, escalations).
6. **Close the loop:** turn production failures into new eval cases.

Tools: LangSmith, Langfuse, Braintrust, Arize Phoenix, promptfoo, DeepEval and Ragas, or plain pytest.

**Likely follow-ups**
- *How big should the eval set be?* Start with 30–50 well-chosen cases. That's enough to catch major regressions. Grow to hundreds as the product matures. Coverage of distinct failure types matters more than raw count.
- *How do you trust an LLM judge?* Calibrate it: label ~50–100 examples by hand and measure agreement with the judge. Use clear rubrics with binary or few-level scores (more reliable than 1–10). Ask for reasoning before the verdict. Watch for position and length bias. Re-calibrate when you change the judge model.

**What a strong answer shows:** A disciplined, CI-integrated quality process, which is exactly what "AI-driven SDLC" roles look for.

**Go deeper:** [[10.5 - Evaluation Pipelines and Monitoring]] · [[06 - Evaluation]]

---

### Q17. How do you make an LLM application observable?

**Answer**
- **Tracing:** each request is a **trace** made of nested **spans**: retrieval, each LLM call, each tool call, each guardrail. Each span records inputs, outputs, latency, tokens, cost, model and version, prompt version and errors.
  - Tools: LangSmith, Langfuse, Arize Phoenix.
  - Or OpenTelemetry, the vendor-neutral standard for traces, metrics and logs, which now has semantic conventions for GenAI spans.
- **Metrics/dashboards:**
  - p50/p95 latency and TTFT (time to first token);
  - tokens and cost per request, per feature, per tenant;
  - error, timeout and retry rates;
  - tool error rates; steps per agent run;
  - guardrail block rates; eval scores over time; user feedback rate.
- **Logging hygiene:**
  - Prompts and outputs may contain PII or secrets. Redact them, set retention limits, and restrict access.
  - Use sampling for large volumes.
- **Correlation:** connect LLM traces to your normal request IDs and application logs.
- **Alerts:** cost spikes, latency regressions, error-rate jumps, provider outages, eval score drops.

**What a strong answer shows:** You'd be able to answer "why was this answer wrong / slow / expensive?" for any single request.

**Go deeper:** [[13.2 - LLM Observability Stack]]

---

### Q18. How do you control LLM costs at scale?

**Answer**
- **Measure first:** cost per request, per feature and per customer, broken down by model and by step.
- **Model routing:** small, cheap models for classification, extraction and routing; large models only where evals show they're needed.
- **Prompt hygiene:** shorter system prompts, fewer and better retrieved chunks, trimmed history.
- **Prompt caching:** stable prefixes (system prompt, tools, documents) first, to get large discounts on repeated input tokens.
- **Response caching:**
  - Exact-match caching for identical requests.
  - **Semantic caching** for near-duplicate questions (embedding similarity above a threshold). Be careful with personalised or time-sensitive answers.
- **Control output length:** max tokens, concise formats; output tokens are the expensive ones.
- **Batch APIs** for offline jobs (often ~50% cheaper, with results within hours).
- **Fewer agent steps:** better tools and prompts reduce loops; set budgets per request.
- **Self-hosting** open models when volume is high and steady enough to keep GPUs busy.
- **Quotas and rate limits** per user or tenant to prevent abuse.

**What a strong answer shows:** You measure first, and use a toolbox of techniques while checking quality with evals.

**Go deeper:** [[10.1 - Latency and Cost Optimization]] · [[10.2 - Caching Strategies]] · [[13.1 - Token Economics KV Cache Prefix Caching]]

---

### Q19. How do you reduce latency in an LLM application?

**Answer**
- **Stream** tokens to the UI. Perceived latency is mostly about time to first token.
- **Run independent steps in parallel:** retrieval + guardrail checks + memory lookup, and parallel tool calls.
- **Smaller or faster models** for intermediate steps (routing, grading, rewriting).
- **Shorter prompts** mean a faster prefill. Prompt caching reduces it further.
- **Cut sequential LLM calls:** each one adds a full round trip. Merge steps when quality allows.
- **Cache** embeddings, retrieval results and responses.
- **Put latency-critical models in nearby regions,** and reuse HTTP connections (keep-alive, connection pooling).
- **Do work asynchronously** where the user doesn't need to wait (memory extraction, evals, logging).
- **Speculative UX:** show progress steps ("Searching your documents…") during agent runs.

**What a strong answer shows:** A focus on the critical path, and on both actual and perceived latency.

**Go deeper:** [[10.1 - Latency and Cost Optimization]] · [[10.3 - Async Architecture and Streaming]]

---

### Q20. How do you make an LLM integration reliable when providers fail or rate-limit you?

**Answer**
Treat the provider like any flaky dependency:
- **Timeouts** on every call (connect and read), longer for long generations or streams.
- **Retries with exponential backoff + jitter** for retryable errors (429 rate limit, 5xx, timeouts). Respect `Retry-After` headers. Don't retry 400-class validation errors.
- **Circuit breaker:** after repeated failures, stop calling the provider for a cooldown and fail fast or fall back.
- **Fallback chain:** primary model → secondary model or provider → cached or degraded response → a clear error.
  - Prompts may need adapting per model, so evaluate your fallbacks too.
- **Client-side rate limiting and queuing** to stay under quotas; use priority queues for interactive vs. batch traffic.
- **Idempotency** for any side effects triggered by LLM output.
- **An LLM gateway** (LiteLLM, Portkey, or in-house) centralises keys, routing, retries, fallbacks, caching, budgets and logging for the whole organisation.

**What a strong answer shows:** Standard resilience engineering applied cleanly to LLMs.

**Go deeper:** [[10.4 - Model Routing and Multi-Model Architecture]] · [[11.2 - Timeouts Retries and Jitter]] · [[11.3 - Circuit Breakers and Bulkheads]]

---

### Q21. How do you version and manage prompts?

**Answer**
- **Prompts are code:** keep them in version control (templates in the repo) or in a prompt registry (LangSmith, Langfuse, or in-house) with versions and labels like `production` and `staging`.
- **Log the prompt version** with every trace, so you can link quality changes to prompt changes.
- **Change process:** edit, run the eval suite, compare with the baseline, get a review, deploy (optionally behind a feature flag or A/B test), then monitor online metrics.
- **Templates with typed variables;** keep logic in code, not in prompt text.
- **Pin model versions** alongside prompts. A prompt is only "tested" with a specific model.

**What a strong answer shows:** Prompt management treated with the same rigour as code releases.

**Go deeper:** [[10.6 - Prompt and Model Versioning]]

---

### Q22. How do you test code that calls an LLM?

**Answer**
- **Unit tests:** mock the LLM client behind your interface. Test prompt construction, parsing, validation, retry logic, routing decisions and tool execution **deterministically**.
- **Recorded responses:** record real responses once (VCR-style "cassettes") and replay them, for realistic but repeatable tests.
- **Contract tests:** check that structured outputs still validate against your schemas when models change.
- **Eval tests:** real model calls against the golden set, with scoring and thresholds. Run them in CI on relevant changes, or nightly, since they're slow and cost money.
- **Property-style assertions** for non-deterministic outputs: "valid JSON", "contains a citation", "mentions the order ID", "does not contain PII". Avoid exact string matches.
- **Load and latency tests,** including streaming and concurrent agent runs.

**What a strong answer shows:** You separate deterministic code testing from probabilistic behaviour evaluation.

**Go deeper:** [[10.5 - Evaluation Pipelines and Monitoring]]

---

### Q23. How would you roll out AI-assisted development (AI in the SDLC) to an engineering team?

**Answer**
- **Start with clear goals and baselines:** PR cycle time, review turnaround, escaped defects, test coverage, developer satisfaction.
- **Pick high-value, low-risk uses first:**
  - AI coding assistants in the IDE;
  - AI PR review comments in CI, which suggest rather than block;
  - test generation;
  - documentation and changelogs;
  - incident and log summarisation.
- **Shared assets:** an organisation-wide prompt and template library; repo instructions (e.g. `CLAUDE.md` / `AGENTS.md` files that describe project conventions); MCP servers for internal tools; a knowledge base the assistants can search.
- **Guardrails:**
  - Approved tools only (data retention terms checked).
  - No secrets in prompts.
  - Human review is still required.
  - Licensing and security scanning of generated code.
- **Enablement:** pairing sessions, internal demos, champions in each team, written best practices.
- **Measure and iterate:** compare metrics against the baseline, collect qualitative feedback, and drop what doesn't help.
- **Risks to name:** over-trusting AI review, larger and less-understood PRs, skill erosion in juniors, and security regressions.

**What a strong answer shows:** Change management, measurement and risk awareness, not just tool enthusiasm.

---

### Q24. Scenario: your RAG agent's answer quality dropped last week, and nobody changed the code. What do you check?

**Answer**
- **Model drift:** did the provider update the model behind an unpinned alias?
- **Data drift:** new document types or sources, a broken connector, parsing failures, stale index, permission-sync bugs that hide documents.
- **Query drift:** users asking new kinds of questions (check query clusters).
- **Infrastructure:** reranker or embedding service timeouts that silently fall back to a degraded path; cache serving stale results.
- **Config changes:** feature flags, prompt-registry labels, top-k settings changed outside the code.
- **Evidence:** compare traces and eval scores before and after; re-run the golden set against both versions; check ingestion and error dashboards.

**What a strong answer shows:** You know that LLM systems can regress without code changes, and you investigate with data.

**Go deeper:** [[10.5 - Evaluation Pipelines and Monitoring]] · [[13.2 - LLM Observability Stack]]

---

## Further reading
- [Anthropic: Building effective agents](https://www.anthropic.com/engineering/building-effective-agents): workflows vs. agents and the core patterns.
- [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/): prompt injection, excessive agency and the other main risks.

---

**Next:** [[04 - Python, Backend Engineering and AI System Design]]
