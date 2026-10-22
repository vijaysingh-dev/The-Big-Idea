# 09 — Agent Patterns and LangGraph

File 08 gave you the loop. This file gives you the structures teams actually ship, and the vocabulary to discuss them. You will not build all of this tomorrow — build the corrective-RAG graph and read the rest.

---

## Mental model

The raw agent loop has one problem: **it's an unstructured `while` loop with a model as the branch predictor.** You can't test it, resume it, or reason about its states.

The industry's answer is to make the control flow an explicit **graph**, where nodes are steps (functions) and edges are transitions (some fixed, some model-decided). You get back everything you lose in a free-form loop:

- **Inspectable state** — one typed object flows through, not an opaque message list.
- **Checkpointing** — persist state at each node, so you can resume after a crash or a human's approval three hours later.
- **Deterministic edges where you want them**, model-decided edges only where you need them.
- **Testability** — nodes are plain functions you can unit test without an LLM.

This is a state machine. You've built these before for order flows and payment reconciliation; the only difference is that some transitions are decided by a model. Saying that out loud is a good way to sound like someone who's shipped this rather than watched a demo.

---

## 1. LangGraph in one page

```python
from typing import Annotated, Literal, TypedDict

from langgraph.graph import END, START, StateGraph
from langgraph.checkpoint.memory import MemorySaver


class RAGState(TypedDict):
    question: str
    rewritten: str
    documents: list[str]
    answer: str
    attempts: int
    grade: Literal["relevant", "irrelevant", ""]


def rewrite(state: RAGState) -> dict:
    return {"rewritten": rewrite_query(state["question"]),
            "attempts": state["attempts"] + 1}


def retrieve(state: RAGState) -> dict:
    hits = retriever.search(state["rewritten"] or state["question"], k=5)
    return {"documents": [c.context_text for c in hits]}


def grade(state: RAGState) -> dict:
    verdict = llm(GRADE_PROMPT.format(question=state["question"],
                                      docs="\n---\n".join(state["documents"])))
    return {"grade": "relevant" if "RELEVANT" in verdict.upper() else "irrelevant"}


def generate(state: RAGState) -> dict:
    return {"answer": llm(ANSWER_PROMPT.format(question=state["question"],
                                               context="\n---\n".join(state["documents"])))}


def give_up(state: RAGState) -> dict:
    return {"answer": "I couldn't find this in the documentation."}


def route_after_grade(state: RAGState) -> str:
    if state["grade"] == "relevant":
        return "generate"
    return "rewrite" if state["attempts"] < 2 else "give_up"


graph = StateGraph(RAGState)
for name, fn in [("retrieve", retrieve), ("grade", grade), ("rewrite", rewrite),
                 ("generate", generate), ("give_up", give_up)]:
    graph.add_node(name, fn)

graph.add_edge(START, "retrieve")
graph.add_edge("retrieve", "grade")
graph.add_conditional_edges("grade", route_after_grade,
                            {"generate": "generate", "rewrite": "rewrite", "give_up": "give_up"})
graph.add_edge("rewrite", "retrieve")
graph.add_edge("generate", END)
graph.add_edge("give_up", END)

app = graph.compile(checkpointer=MemorySaver())

result = app.invoke({"question": "how do refunds work in the EU?", "attempts": 0,
                     "documents": [], "answer": "", "rewritten": "", "grade": ""},
                    config={"configurable": {"thread_id": "user-123"}})
```

That's **corrective RAG** (retrieve → grade → rewrite and retry → generate, with a bounded retry and an explicit give-up path), and it's a genuinely good production pattern. Note the details a reviewer would look for: the retry counter lives in state, the give-up branch exists, and the graph terminates.

Key concepts: nodes return **partial state updates** that get merged; `Annotated` reducers control how fields combine (e.g. appending to a list rather than replacing it); the checkpointer persists state per `thread_id`, which is what makes durable, resumable, multi-turn agents possible.

---

## 2. The patterns worth knowing by name

### Routing
A cheap classifier picks the path: FAQ → cached answer; factual → RAG; analytical → agentic RAG; math → calculator; chit-chat → direct answer, no retrieval. **The highest-ROI "agentic" pattern in production** because it saves cost *and* improves quality, with almost no reliability risk.

### Orchestrator–workers
The orchestrator decomposes a task into subtasks *at runtime* (not a fixed fan-out), workers execute in parallel, a synthesizer merges. This is what "deep research" products are. Good when the number and shape of subtasks genuinely vary per request.

### Evaluator–optimizer (generate → critique → revise)
One model generates, another critiques against explicit criteria, the first revises. Works when critique is genuinely easier than generation (writing, code with tests, translations). Fails when the critic has the same blind spots as the generator — which is why a *deterministic* critic (a test suite, a linter, a schema validator, a SQL execution check) beats an LLM critic whenever one exists. Always bound the loop; two or three rounds is usually the point of diminishing returns.

### Reflection / self-correction
The single-model version of the above. Useful, but be honest in the interview: models are unreliable at spotting their own errors without external signal. Real self-correction needs a **verifier that isn't the model** — tests, a type checker, a database, a schema.

### Multi-agent
Separate agents with distinct prompts, tools, and roles, coordinated by a supervisor or by handoffs.

The nuance that separates experienced people from hype: **multi-agent is mostly a context-management technique, not a magic capability upgrade.** Each agent gets a smaller, cleaner context and fewer tools, which raises per-step reliability. The costs are real: token usage multiplies (each agent re-reads shared context), coordination failures appear, and debugging gets much harder. Use it when subtasks are genuinely parallel and read-only; avoid it when agents must write to shared state, because you've now invented distributed consensus with a probabilistic participant.

### Human-in-the-loop
Not a fallback — a design primitive. Interrupt before consequential actions, surface the proposed action for approval, and resume from the checkpoint on response.

```python
app = graph.compile(checkpointer=MemorySaver(), interrupt_before=["execute_write"])

state = app.invoke(inputs, config)            # pauses at the gate
# ... show state["proposed_action"] to a human, get approval ...
app.invoke(None, config)                      # resumes from the checkpoint
```

Say this: *"For anything that spends money, sends a message, or mutates production data, I'd interrupt before the tool call and require approval. The agent proposes; a human disposes."*

---

## 3. Making agents reliable — the engineering checklist

| Concern | Mechanism |
|---|---|
| **Runaway loops** | `max_steps`, wall-clock timeout, token/cost budget, loop detection on repeated (tool, args) |
| **Bad tool args** | Schema validation before execution; return the validation error as an observation |
| **Side effects on retry** | Idempotency keys on every mutating tool — the same instinct as retrying a payment |
| **Partial failure** | Checkpoint per node; resume rather than restart |
| **Context rot** | Summarize or evict old observations; restate the goal near the end of the prompt |
| **Blast radius** | Least-privilege tools, read-only default, HITL gates, sandboxed execution |
| **Unpredictability** | Constrain the graph: fewer model-decided edges, more fixed ones |
| **Debuggability** | Persist the full trace: state at each node, every tool call and observation, tokens, latency |

The reliability instinct to state explicitly: **push work from model-decided edges into code-decided edges wherever the logic is actually known.** Every fixed edge is a decision the model can't get wrong.

---

## 4. Evaluating agents

Harder than RAG eval, because there are many valid paths to a correct answer.

**Three levels:**

1. **Outcome / task success** — did it achieve the goal? Binary or rubric-scored against a golden set of tasks. This is what actually matters.
2. **Trajectory** — did it take a sensible path? Metrics: tool-selection accuracy (compare against an expected tool set), number of steps vs optimal, redundant call rate, recovery rate after an error, loop rate.
3. **Per-step** — was each individual tool call correct given the state? Useful for pinpointing which node in the graph is degrading.

**Do not score exact-match trajectories.** Multiple paths are valid; grading on path equality punishes better solutions. Grade the outcome, and use trajectory metrics diagnostically.

Also track, always, next to quality: **steps per task, tokens per task, cost per task, p95 latency, and the rate of hitting the step cap.** An agent that's 3% more accurate for 4× the cost is usually a bad trade, and being the person who says that in a design review is the point.

```python
def evaluate_agent(tasks, agent):
    rows = []
    for task in tasks:
        result = agent(task.question)
        tools_used = {t["tool"] for t in result["trace"]}
        rows.append({
            "success": judge(task.question, task.expected, result["answer"]),
            "steps": result["steps"],
            "hit_cap": result["steps"] >= MAX_STEPS,
            "tool_precision": len(tools_used & set(task.expected_tools)) / max(len(tools_used), 1),
            "tokens": result["tokens"],
            "latency_ms": result["latency_ms"],
        })
    return rows
```

---

## 5. Framework landscape (know the shape, don't be dogmatic)

| Framework | Model | Best for |
|---|---|---|
| **LangGraph** | Explicit graph + persistent state + checkpointing | Production agents needing durability, HITL, controllability |
| **OpenAI Agents SDK / Swarm-style** | Lightweight agents + handoffs | Simple multi-agent routing |
| **CrewAI** | Role-playing crews with tasks | Fast prototyping; less control |
| **AutoGen** | Conversational multi-agent | Research, agent-to-agent experiments |
| **smolagents** | Minimal, code-writing agents | Learning; small tasks |
| **No framework** | Your own loop | Single agent, few tools — often the right call |

Interview-safe position: *"For one agent with a handful of tools I'd write the loop myself — it's 60 lines and fully transparent. I'd reach for LangGraph when I need persistence, human-in-the-loop interrupts, resumability, or a control flow complex enough that an explicit state machine is clearer than nested conditionals."*

---

## Open source to read

- **LangGraph examples** (github.com/langchain-ai/langgraph) — the `rag/` notebooks implement corrective RAG, self-RAG and adaptive RAG. Reading these three is the fastest way to see the patterns as code.
- **`openai-agents-python`** or **`smolagents`** — compare a minimal framework's loop against your hand-rolled one from file 08; the diff *is* the framework's value proposition.

---

## Exercises (tomorrow, ~45 minutes — do #1 and #2 at minimum)

1. **Build the corrective-RAG graph** above against your capstone retriever. Ask a question the corpus can't answer and confirm it reaches `give_up` rather than hallucinating.
2. **Instrument it**: log state at every node. Then answer, from logs alone, why one query took three retrievals.
3. **Add a human-in-the-loop gate** on a fake `send_email` tool with `interrupt_before`. Approve one call, reject another.
4. **Evaluate**: run 20 golden questions through (a) plain RAG, (b) the corrective graph. Compare success rate, mean steps, latency, cost. Split by question category.
5. **Induce failure**: give the grader an impossible standard so it always says "irrelevant". Confirm the retry cap holds and the graph terminates. Bounded failure is a feature.

---

## Interview questions

1. Why a graph instead of a loop? *(inspectable state, checkpointing/resumability, deterministic edges where possible, testable nodes, HITL interrupts)*
2. Describe corrective / self-RAG. *(retrieve → grade relevance → rewrite and retry on failure → generate; bounded retries and an explicit give-up path)*
3. When is multi-agent worth it? *(parallel, read-only subtasks; it's context management, not a capability upgrade; costs are token multiplication and coordination failures)*
4. How do you do human-in-the-loop properly? *(interrupt before consequential tools, persist state, surface the proposed action, resume from checkpoint — agent proposes, human disposes)*
5. How do you evaluate an agent? *(outcome-level success on a golden task set; trajectory metrics diagnostically; never exact-match paths; always report steps/cost/latency)*
6. How do you stop an agent from looping or burning budget? *(step cap, timeout, cost budget, loop detection, forced escalation)*
7. Agent works in dev, unreliable in prod. Debug approach? *(traces first; check tool-selection accuracy, context length growth, error-recovery rate, step-cap hit rate; then constrain the graph — move model-decided edges into code)*
8. LangGraph vs writing it yourself? *(the position above — persistence, HITL, resumability, complexity are the triggers)*
9. How do you make tool calls safe to retry? *(idempotency keys, read-only defaults, schema validation, confirmation gates)*
10. Your agent is 3% more accurate than a workflow but costs 4× and is 5× slower. Ship it? *(usually no — and the fact that you framed it as a trade rather than a win is the answer they want)*

---

## Resources

- **LangGraph documentation, "Why LangGraph" + persistence and human-in-the-loop concepts** — https://langchain-ai.github.io/langgraph/ — the concepts pages are worth more than the tutorials; read persistence and interrupts specifically.
- **Anthropic, "Building Effective Agents"** — https://www.anthropic.com/engineering/building-effective-agents — re-read the workflow patterns section alongside this file; it's the taxonomy these implementations instantiate.
