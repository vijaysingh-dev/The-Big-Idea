# 08 — Agents Fundamentals

"Agentic AI" is the part of your interview title with the most hype and the least consensus. That's an opportunity: a candidate who can define an agent precisely, build one without a framework, and explain when *not* to use one stands out immediately.

---

## Mental model

An agent is a **loop where the LLM decides what happens next**.

```python
while not done:
    decision = llm(context)          # the model chooses: answer, or call a tool
    if decision.is_tool_call:
        result = execute(decision)   # your code runs it
        context += result            # observation goes back into the prompt
    else:
        done = True
```

That's it. Everything else — ReAct, planners, multi-agent, LangGraph — is structure imposed on that loop.

The precise definition worth memorizing, because interviewers ask it and most answers are mush:

> **A workflow has the control flow written by a human in code. An agent has the control flow
> decided by the model at runtime.**

That distinction is the whole ballgame. `retrieve → generate` is a workflow. `decide whether to retrieve, then decide whether to retrieve again, then answer` is an agent. Both are legitimate; they differ in reliability, cost, and debuggability, and choosing correctly is the skill.

### The spectrum (use this framing in the interview)

| Pattern | Control flow | Reliability | Use when |
|---|---|---|---|
| **Single call** | Fixed | Highest | Classification, extraction, summarization |
| **Chain / pipeline** | Fixed, sequential | High | RAG, ETL-style transforms |
| **Routing** | Model picks one branch, then fixed | High | Multiple query types, tiered models |
| **Parallelization** | Fixed fan-out, then aggregate | High | Multi-perspective checks, voting |
| **Orchestrator–workers** | Model decides subtasks dynamically | Medium | Variable-shape research/coding tasks |
| **Evaluator–optimizer** | Generate → critique → revise loop | Medium | Writing, code with a clear quality signal |
| **Autonomous agent** | Model drives everything, open-ended | **Lowest** | Genuinely unpredictable tasks with good feedback signals |

**The senior position:** start at the top of that table and move down only when forced. Agents buy flexibility and pay in reliability, latency, cost, and debuggability. Most production "agents" that work are actually routing or orchestrator–workers with tightly constrained tools.

---

## 1. Building one without a framework (do this tomorrow)

A working ReAct-style agent in ~60 lines. **ReAct** = *Reason + Act*: the model alternates between reasoning about what to do and taking an action, observing the result each time.

```python
# raglab/agent/simple.py
import json

from openai import OpenAI

client = OpenAI()
MODEL = "gpt-4o-mini"

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_docs",
            "description": (
                "Search the internal documentation corpus and return the most relevant passages. "
                "Use for any question about product behaviour, policies, or configuration. "
                "Call once per distinct sub-question."
            ),
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string", "description": "A standalone search query"}},
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "calculator",
            "description": "Evaluate a simple arithmetic expression, e.g. '1200 * 0.18'.",
            "parameters": {
                "type": "object",
                "properties": {"expression": {"type": "string"}},
                "required": ["expression"],
            },
        },
    },
]


def search_docs(query: str) -> str:
    hits = retriever.search(query, k=3)
    return "\n\n".join(f"[{c.id}] {c.context_text}" for c, _ in hits)


def calculator(expression: str) -> str:
    allowed = set("0123456789+-*/(). ")
    if not set(expression) <= allowed:
        return "ERROR: unsupported characters"
    return str(eval(expression))          # safe only because of the character whitelist above


REGISTRY = {"search_docs": search_docs, "calculator": calculator}

SYSTEM = """You answer questions about internal documentation.
Use search_docs before answering anything factual — never answer from memory.
Break complex questions into multiple searches.
Cite chunk ids in square brackets.
If the documents don't contain the answer, say so explicitly."""


def run_agent(question: str, max_steps: int = 6) -> dict:
    messages = [{"role": "system", "content": SYSTEM},
                {"role": "user", "content": question}]
    trace = []

    for step in range(max_steps):
        response = client.chat.completions.create(
            model=MODEL, messages=messages, tools=TOOLS, temperature=0,
        )
        msg = response.choices[0].message
        messages.append(msg)

        if not msg.tool_calls:
            return {"answer": msg.content, "trace": trace, "steps": step}

        for call in msg.tool_calls:
            args = json.loads(call.function.arguments)
            try:
                result = REGISTRY[call.function.name](**args)
            except Exception as exc:
                # Errors are returned to the model rather than raised, so it can correct itself.
                result = f"ERROR: {type(exc).__name__}: {exc}"
            trace.append({"step": step, "tool": call.function.name, "args": args,
                          "result": result[:500]})
            messages.append({"role": "tool", "tool_call_id": call.id, "content": result})

    return {"answer": "Step limit reached without a final answer.", "trace": trace,
            "steps": max_steps}
```

Everything important about agents is visible in those 60 lines:

- **`max_steps` is not optional.** Without it, a confused agent loops until your budget is gone. Every real agent has a step cap, a wall-clock timeout, and a token/cost budget.
- **Errors go back to the model as observations**, not as exceptions. Self-correction is most of where agent value comes from — but cap the retries, because models can loop on the same failure.
- **The trace is the product.** An agent without a full trace of every decision, tool call, argument and observation is undebuggable. This is the thing to insist on in an interview.
- **Tool descriptions are the contract**, and `temperature=0` for tool selection.

---

## 2. Agentic RAG — the natural bridge from files 03–06

Classic RAG always retrieves once. Agentic RAG lets the model decide:

- **Whether** to retrieve at all ("hi", "summarize your last answer" → no retrieval).
- **How many times** — multi-hop questions need sequential retrievals where the second query depends on the first result.
- **Which source** — docs vs tickets vs SQL vs web.
- **Whether the results were good enough**, and to re-query with different terms if not (this is **self-RAG** / corrective RAG).

```
question → [decide: retrieve?] → search → [grade relevance] ──low──▶ rewrite query, search again
                                                │
                                              high
                                                ▼
                                          generate + cite → [check grounded?] ──no──▶ retry
```

This is genuinely useful and is the most defensible use of agency in a RAG system. It's also where the cost shows up: 3–6 LLM calls instead of 1, and 5–15s instead of 2s. The right answer to "should we make our RAG agentic?" is: *"For the 20% of queries that are multi-hop or comparative, yes — routed there by a cheap classifier. Making every query agentic quadruples cost and latency for queries a single retrieval already answers."*

---

## 3. Memory

"Memory" is not a model feature. It's storage you manage. Four kinds:

| Type | What | Implementation |
|---|---|---|
| **Working / short-term** | The current conversation | The message list itself |
| **Episodic** | What happened in past sessions | Summaries or events in a DB, retrieved by relevance |
| **Semantic** | Durable facts about the user/domain | Key-value or a vector store — retrieved, not always injected |
| **Procedural** | How to do a task | Prompts, few-shot examples, tools |

Context management strategies once the conversation outgrows the window:

- **Sliding window** — keep the last N turns. Simple; loses early constraints.
- **Summarization** — compress older turns into a running summary. Standard; lossy, and errors compound as summaries summarize summaries.
- **Retrieval over history** — embed past turns, retrieve relevant ones. Scales best.
- **Structured state** — extract the durable facts into an explicit object (`{"order_id": ..., "issue_type": ...}`) and carry that instead of raw text. **This is the one senior engineers reach for**, because it's inspectable, testable, and doesn't drift.

Also: memory is user data. It needs retention policies, deletion on request, and tenant scoping — same as any other PII store.

---

## 4. Tools: designing them for a non-deterministic caller

Tool design is API design where the client is unreliable and reads only your docstring.

- **Descriptions are prompts.** Say what it does, when to use it, when *not* to, and what it returns. Ambiguity between two tools is the top cause of wrong calls.
- **Few tools.** Accuracy degrades noticeably beyond ~10–15. Fixes: hierarchical routing (a router picks a toolset), or retrieving the relevant tools per query — yes, RAG over your tool catalog.
- **Coarse-grained beats fine-grained.** One `create_ticket(title, body, priority)` beats five tools that each set one field. Fewer decisions, fewer failure points.
- **Validate arguments with a schema before execution.** The model *will* invent an `order_id`.
- **Return compact, structured results.** A tool returning 40k tokens of JSON destroys the context budget; truncate, summarize, or return a handle the model can page through.
- **Make errors instructive**: `"ERROR: order_id must match ORD-\d+; got 'last one'"` lets the model fix itself. `"400 Bad Request"` does not.
- **Least privilege and confirmation gates.** Read-only tools are cheap to get wrong. Anything that writes, spends, sends, or deletes needs idempotency keys and — for consequential actions — a human in the loop.

### MCP (Model Context Protocol)

An open standard for exposing tools/data to LLM applications over a uniform protocol, so an integration written once works across clients instead of being re-implemented per framework. The mental model: **MCP is to tools what LSP is to editors** — an N×M integration problem collapsed into N+M. Know that definition; it's a current-events question in 2026 interviews.

Security note worth raising unprompted: connecting an agent to arbitrary MCP servers means giving a model tools whose descriptions you didn't write — which is a prompt-injection and supply-chain surface. Pin and review your servers.

---

## 5. Why agents fail (know these cold)

1. **Compounding error.** At 95% per-step reliability, a 10-step task succeeds ~60% of the time. This single arithmetic fact is the strongest argument for short, constrained loops — and it's a great thing to compute out loud.
2. **Looping** — the same failing tool call repeatedly. Fix: step caps, loop detection on repeated (tool, args) pairs, and forced escalation.
3. **Wrong tool selection** — too many tools, vague descriptions.
4. **Context rot** — long traces fill the window with stale observations; the model loses the goal. Fix: summarize or drop old observations, keep the goal restated near the end.
5. **Cost explosions** — every step re-sends the whole growing context, so cost grows quadratically in steps. Budget caps are mandatory.
6. **Non-reproducibility** — two runs take different paths, so bug reports aren't reproducible without the full trace.
7. **Unbounded blast radius** — an agent with write access and no confirmation gate is an outage waiting to happen.

---

## 6. When *not* to use an agent

Say this plainly; it's a maturity signal:

- The steps are known in advance → write a workflow. Deterministic, testable, 5× cheaper.
- The task needs guaranteed correctness → agents are probabilistic.
- Latency budget is under a couple of seconds → each step is an LLM round trip.
- There's no feedback signal for the agent to act on → it can't self-correct, so agency adds nothing.
- A SQL query, a search index, or an if-statement answers it.

The reframe that lands: *"I'd use the least agency that solves the problem. Agency is a cost I pay for flexibility I actually need, not a default architecture."*

---

## Open source to read

- **Anthropic's `anthropic-cookbook`** (github.com/anthropics/anthropic-cookbook) — the tool-use and agent patterns notebooks are short, framework-free, and directly runnable.
- **`smolagents`** (github.com/huggingface/smolagents) — a deliberately tiny agent library; you can read the entire core loop in an hour and it demystifies every larger framework.
- **`mcp` spec + reference servers** (github.com/modelcontextprotocol) — skim the protocol overview and one server implementation.

---

## Exercises (tomorrow, ~60 minutes)

1. **Type in the 60-line agent** and run it against your capstone retriever. Ask a multi-hop question ("how does X differ from Y?") and read the trace — watch it issue two searches.
2. **Break tool selection**: give both tools vague, overlapping descriptions and observe wrong calls. Then fix the descriptions and measure the difference. This is a fast, vivid lesson.
3. **Force a loop**: make `search_docs` always return "no results" and watch the agent's behaviour until `max_steps` trips. Then add loop detection on repeated arguments.
4. **Add a budget**: track cumulative tokens and abort with a partial answer when exceeded.
5. **Compare agentic vs plain RAG** on your golden set: accuracy, mean steps, latency, cost per query. Split results by question category — the multi-hop rows are where agency earns its cost. **This comparison is a genuinely strong interview exhibit.**
6. **Add a relevance grader**: after retrieval, have the model rate the chunks, and re-query with a rewritten term if the rating is low. You've now built corrective RAG.

---

## Interview questions

1. What is an agent? *(the loop; and the workflow-vs-agent distinction — who owns control flow)*
2. How does tool calling work mechanically? *(model emits a structured call, your code executes, result returns as an observation; the model never executes anything)*
3. When would you *not* build an agent? *(known steps, correctness requirements, tight latency, no feedback signal — start with a workflow)*
4. Why do multi-step agents fail? *(compounding error — 0.95^10 ≈ 0.60; plus looping, context rot, tool confusion)*
5. How do you make an agent debuggable? *(full structured trace of every decision, tool call, arguments, observation, tokens and latency per step)*
6. How do you limit blast radius? *(least-privilege tools, read-only by default, schema validation, idempotency keys, confirmation gates, step/time/cost caps)*
7. What's agentic RAG and when is it worth it? *(model decides whether/how often/where to retrieve; worth it for multi-hop and comparative queries; route to it selectively)*
8. How do you handle memory? *(four types; structured state beats raw-text summarization; it's user data with retention and scoping requirements)*
9. Your agent has 40 tools and picks the wrong one. Fix? *(reduce and consolidate tools, sharpen descriptions, hierarchical routing or retrieval over the tool catalog, evaluate tool selection as its own metric)*
10. What is MCP and why does it exist? *(open protocol for exposing tools/data to LLM apps; N×M → N+M, like LSP for editors; and it's a new trust boundary)*

---

## Resources

- **Anthropic, "Building Effective Agents"** — https://www.anthropic.com/engineering/building-effective-agents — the best single article on this topic; the workflow-vs-agent taxonomy in this file comes from it, and interviewers frequently have read it too.
- **ReAct paper (Yao et al., 2022)** — https://arxiv.org/abs/2210.03629 — short and readable; gives you the vocabulary and the original motivation for interleaving reasoning with actions.
