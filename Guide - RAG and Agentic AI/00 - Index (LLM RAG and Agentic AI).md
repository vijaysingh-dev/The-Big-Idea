# LLM RAG and Agentic AI — Master Index

You have 5 years of real engineering behind you. That changes what this guide should be. You do **not** need "what is an API call". You need:

1. The **correct mental model** of each component (so you can reason, not recite).
2. The **failure modes** — because interviews for GenAI roles are mostly "what breaks and how do you know".
3. **Code you can run and break** tomorrow.
4. **Vocabulary** — the exact words senior people use, so you sound like you've shipped this.

Everything here is written assuming you know distributed systems, caching, indexing, testing and observability from normal backend work. GenAI is mostly those same ideas applied to a probabilistic, expensive, non-deterministic function call. That framing alone will put you ahead of most candidates.

---

## The one-paragraph map of the whole field

An **LLM** is a function `text -> probability distribution over the next token`, called in a loop. It knows only what was in its training data plus what you put in the prompt. **RAG** (Retrieval-Augmented Generation — fetch relevant text at query time and paste it into the prompt) exists because the prompt is the only cheap way to give the model new, private, or fresh knowledge. **Agents** exist because some tasks need more than one LLM call: the model decides which *tool* to call, sees the result, and decides again — a loop with state. That's it. Everything else (chunking, rerankers, vector databases, LangGraph, evals) is engineering around those three facts.

---

## File structure

| # | File | What it gives you | Read time |
|---|------|-------------------|-----------|
| 01 | [[01 - LLM Internals That Matter]] | Tokens, context window, KV cache, sampling, tool calling, cost/latency math, why hallucination is mechanical | 45 min |
| 02 | [[02 - Embeddings and Vector Search]] | Embeddings, cosine, ANN indexes (HNSW/IVF-PQ), quantization, metadata filtering, index pitfalls | 45 min |
| 03 | [[03 - The Baseline RAG Pipeline]] | Build naive RAG end to end in ~120 lines, then name every failure point in it | 40 min |
| 04 | [[04 - Chunking Strategies]] | Fixed / recursive / sentence-window / semantic / parent-doc / structural / late chunking — with implementations | 50 min |
| 05 | [[05 - Retrieval Quality]] | Hybrid search (BM25 + dense), RRF, cross-encoder reranking, MMR, HyDE, multi-query, query routing | 50 min |
| 06 | [[06 - Evaluation]] | Golden sets, recall@k / MRR / nDCG, faithfulness & answer-relevancy, LLM-as-judge and its traps, CI regression gates | 45 min |
| 07 | [[07 - Production RAG]] | Incremental ingestion, idempotent upserts, caching, multi-tenancy, latency budgets, guardrails, observability, cost control | 45 min |
| 08 | [[08 - Agents Fundamentals]] | The tool loop, ReAct, memory, planning, MCP, when agents are the wrong answer | 45 min |
| 09 | [[09 - Agent Patterns and LangGraph]] | Graph/state-machine agents, retries, human-in-the-loop, multi-agent, agent evaluation | 45 min |
| 10 | [[10 - Capstone RAGLab]] | The project: one codebase, pluggable chunkers + retrievers, an evaluation harness and a leaderboard | build |
| 11 | [[11 - Interview Drill]] | ~60 questions with senior-level answers, 4 system-design prompts, diagrams you can draw on a whiteboard | 60 min |
| A | [[Appendix - Environment Setup]] | Environment, package versions, local vs API models, cost-free path | 15 min |

Each topic file has the same five sections:

- **Mental model** — the thing to actually believe
- **How it really works** — mechanics, with numbers
- **In production** — how senior engineers use it at scale, tradeoffs, pitfalls
- **Code** — runnable, plus which open-source repo to read for the real implementation
- **Exercises + interview questions** — what you do tomorrow, and what you'll be asked

---

## Two-day schedule

### Today (reading day — ~6 hours, no coding)

| Block | Files | Goal at end of block |
|-------|-------|----------------------|
| 1 (90 min) | 01, 02 | You can explain tokens, context, sampling, embeddings, HNSW without notes |
| 2 (90 min) | 03, 04 | You can draw the RAG pipeline and list 6 chunking strategies with tradeoffs |
| 3 (90 min) | 05, 06 | You can explain hybrid + rerank, and how you'd *prove* a retrieval change helped |
| 4 (60 min) | 07, 08 | You can talk about production concerns and the agent loop |
| 5 (60 min) | 09, 11 skim | You've seen the question bank once |

Set up the environment tonight ([[Appendix - Environment Setup]]) so tomorrow is pure coding — package installs and model downloads always eat an hour you didn't budget.

### Tomorrow (coding day — ~8 hours)

| Block | Work |
|-------|------|
| 1 (60 min) | Exercises in 01 and 02 — tokenizer, embeddings, brute force vs HNSW recall |
| 2 (90 min) | Build the baseline RAG from 03 from scratch. No framework. |
| 3 (150 min) | Capstone part 1: pluggable chunkers + eval harness (file 10). Run the chunking leaderboard. |
| 4 (90 min) | Capstone part 2: hybrid + reranker, re-run leaderboard, record the deltas |
| 5 (60 min) | Build the smallest possible agent (file 08 exercise): a 40-line ReAct loop with 2 tools, no framework |
| 6 (60 min) | Re-read 11, say answers out loud, write your 3 "war stories" from what you built |

### Interview day
Re-read only: file 11, the failure-mode lists in 04/05/06, and your own leaderboard numbers. **Your leaderboard numbers are your differentiator** — "I measured semantic chunking against recursive on 40 questions and recall@5 went from 0.62 to 0.71 but ingestion cost 8× more" beats any amount of theory.

---

## The capstone (why the whole guide points at it)

You asked for a project where you can swap chunking strategies and evaluate them. That's exactly the right instinct — it's also the single most convincing thing you can describe in an interview. Full spec is in [[10 - Capstone RAGLab]]; the shape is:

```
raglab/
  ingest/        loaders + chunkers          <- pluggable via a registry
  index/         embedders + vector stores + BM25
  retrieve/      dense | hybrid | rerank | mmr   <- pluggable
  generate/      prompt templates + LLM client
  eval/          golden set, retrieval metrics, generation metrics
  experiments/   YAML configs -> results.csv -> leaderboard
```

One command runs a full sweep:

```bash
python -m raglab.run --config experiments/chunking_sweep.yaml
```

and prints:

```
strategy            chunks  ingest_s  recall@5  mrr    faithfulness  p95_ms  $/1k_q
fixed_512                412     11.2     0.58  0.44          0.71     840   0.42
recursive_512_50         447     12.0     0.66  0.51          0.78     845   0.44
sentence_window_3        1180     19.4     0.74  0.63          0.83     910   0.61
semantic_p95             389     96.7     0.71  0.58          0.81     835   0.43
parent_doc               1180     20.1     0.72  0.60          0.88    1020   0.95
```

Numbers above are illustrative — yours will differ, and *that's the point*: you'll have your own.

---

## What interviewers actually probe (so you know why each file exists)

| They ask | They're testing | File |
|----------|-----------------|------|
| "Walk me through RAG" | Can you name all 8 stages, not 3 | 03 |
| "Your RAG returns wrong answers. Debug it." | Do you isolate retrieval vs generation | 03, 06 |
| "How do you chunk?" | Do you have a *reason*, or a default | 04 |
| "Why not just use a 1M-token context window?" | Cost, latency, lost-in-the-middle, recall | 01, 07 |
| "How do you know your change made it better?" | Evaluation maturity — the biggest filter | 06 |
| "Vector DB choice?" | Tradeoffs, not brand loyalty | 02, 07 |
| "When would you use an agent?" | Do you know they're unreliable and expensive | 08 |
| "Fine-tune or RAG?" | Decision framework | 01 |
| "Scale it to 50M documents / 10k QPS" | Normal distributed systems thinking | 07 |

Note the pattern: half the questions are ordinary senior-engineer questions wearing a GenAI hat. Your 5 years count for more than you think — lean on them explicitly in answers.

---

## Ground rules while you learn

1. **Never trust a demo that has one document.** Everything works at n=3.
2. **Build the evaluation before the optimization.** Without it you are guessing in a domain designed to make guesses feel correct.
3. **Retrieval quality dominates.** In most broken RAG systems the generator is fine and the retriever never returned the answer. Log the retrieved chunks. Always.
4. **Frameworks are optional; the concepts are not.** Write the naive version once by hand. Then read LangChain/LlamaIndex source to see what they added and why.
5. **Every LLM call is a network call to a slow, expensive, non-deterministic service.** Timeouts, retries, idempotency, circuit breakers, caching, budgets — all your existing instincts apply.

---

## Progress checklist

- [ ] 01 LLM internals
- [ ] 02 Embeddings & vector search
- [ ] 03 Baseline RAG
- [ ] 04 Chunking
- [ ] 05 Retrieval quality
- [ ] 06 Evaluation
- [ ] 07 Production
- [ ] 08 Agents
- [ ] 09 Agent patterns
- [ ] 10 Capstone built and leaderboard produced
- [ ] 11 Question bank answered out loud
