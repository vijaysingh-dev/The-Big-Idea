# Interview Guide — Master Index

> **Purpose:** Answers to say out loud in senior backend and AI-engineering interviews. Each question has the answer, code to put on the whiteboard, likely follow-ups, the signal the interviewer wants, links to the vault notes that go deeper, and one external resource.
>
> **How this relates to the rest of the vault:** the guides ([[00 - Index (Backend)]], [[00-Index (HLD)]], [[00 - Index (LLD)]], [[00 - Index (AI)]], [[00 - Index (LLM RAG and Agentic AI)]]) are where you *learn* a topic. This guide is where you *rehearse* it. Answers here are deliberately compact, and the **Go deeper** links point at the full treatment.

---

## Files

| File                                                      | Covers                                                                                                                                                                         | Questions |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- |
| [[01 - LLM Fundamentals]]                                 | How LLMs work, tokens, attention, inference, training, prompting, model choice                                                                                                 | 20        |
| [[02 - Retrieval-Augmented Generation (RAG)]]             | Every RAG stage, embeddings, HNSW, BM25, hybrid, reranking, evals, **LLM-as-a-judge with code**                                                                                | 24        |
| [[03 - Agentic AI and Production LLMOps]]                 | Agents, tools, LangGraph, memory, multi-agent, MCP, security, evals, observability, cost                                                                                       | 24        |
| [[04 - Python, Backend Engineering and AI System Design]] | Python internals, **coroutines and the event loop**, **FastAPI request lifecycle**, API/DB design, **pagination**, resilience, testing, AI system design                       | 31        |
| [[05 - System Design and Distributed Systems]]            | **CAP**, **consistency / availability / partitioning**, sagas, **Kafka in microservices**, queues compared, **Redis with code**, **DB optimization at scale**, database choice | 8 + a map |
| [[06 - Design Principles and Patterns]]                   | **SOLID with code**, other principles, principles vs patterns, **telling look-alike patterns apart**, Repository + UoW + DI                                                    | 10        |

---

## Recently Asked (Offer Round)

The questions from the most recent interview, and where each one is answered.

| # | Question | Answer | Full depth |
|---|---|---|---|
| 01 | Message queues in microservices (Kafka) | [[05 - System Design and Distributed Systems]] Q4, plus Q5 for Kafka vs RabbitMQ vs SQS | [[Kafka]] · [[09.3 - The Outbox Pattern]] · [[09.1 - Queue vs Log]] |
| 02 | Design patterns | [[06 - Design Principles and Patterns]] Q4 | [[02.0 - Patterns Overview]] |
| 03 | CAP theorem | [[05 - System Design and Distributed Systems]] Q1 | [[01.5 - CAP and PACELC]] |
| 04 | Redis, with code | [[05 - System Design and Distributed Systems]] Q6 | [[Redis]] · [[03.5 - Redis Patterns]] |
| 05 | LLM-as-a-judge: raw, then RAGAS, with code | [[02 - Retrieval-Augmented Generation (RAG)]] Q20 | [[06 - Evaluation]] (sections 3–4) |
| 06 | Optimize a DB doing 10M req/s that responds in 5 s | [[05 - System Design and Distributed Systems]] Q7 | [[06.18 - Fixing a Slow Database at Scale]] |
| 07 | What happens to a request in the backend (ASGI + FastAPI) | [[04 - Python, Backend Engineering and AI System Design]] Q9, plus Q8 for `def` vs `async def` | [[01.13 - FastAPI Request Lifecycle End to End]] · [[01.9 - ASGI and How Uvicorn Serves a Request]] |
| 08 | SOLID principles | [[06 - Design Principles and Patterns]] Q1 | [[01.1 - SOLID Principles]] |
| 09 | Coroutines, the event loop | [[04 - Python, Backend Engineering and AI System Design]] Q3, plus Q2 for asyncio pitfalls | [[01.4 - Building an Event Loop From Scratch]] · [[01.5 - Coroutines Tasks and Futures]] |
| 10 | Pagination, app side and DB side | [[04 - Python, Backend Engineering and AI System Design]] Q15 | [[05.2 - Versioning Pagination and Filtering]] |
| 11 | Confusing look-alike patterns (Adapter / Strategy / Factory …) | [[06 - Design Principles and Patterns]] Q5–Q7, plus Q3 for principles vs patterns | [[02.25 - Telling Similar Patterns Apart]] |
| 12 | Consistency, availability and partitioning | [[05 - System Design and Distributed Systems]] Q2 | [[01.6 - Consistency Models]] · [[01.11 - Distributed Concepts]] · [[06.13 - Partitioning and Sharding]] |

---

## Format of Every Question

- **Answer:** what a strong candidate would say, in roughly the order they'd say it.
- **Code** (where it helps): short enough to write on a whiteboard, but real enough to run.
- **Likely follow-ups:** where the interviewer goes next, with short answers.
- **What a strong answer shows:** the signal the interviewer is looking for.
- **Go deeper:** the vault notes with the full treatment.
- **Resource:** one external reference worth your time.

---

## On the Interview Itself

Good interviewers aren't trying to catch you out. They're trying to find the edge of what you know and see how you think when you get there. Habits that help:

1. **Start simple, then go deeper.** Give a one-sentence answer, then add layers. Let them choose how far to go.
2. **Name the tradeoff.** Seniors almost never say "X is best". They say "X when…, Y when…".
3. **Challenge the premise with numbers.** "10M requests per second" or "exactly-once" deserve a sanity check before an answer ([[Assets.3 - Numbers To Know]]).
4. **Measure before fixing.** For any "it's slow" question, say how you'd find where the time goes before proposing a fix.
5. **Say "I don't know, but here's how I'd reason about it."** Honest reasoning beats a confident wrong answer, every time.

---

## Other Interview Material in the Vault

| Topic | Where |
|---|---|
| HLD interview method, mistakes, communicating tradeoffs | [[07.1 - How HLD Interviews Work]] · [[07.2 - Common Mistakes]] · [[07.3 - Communicating Tradeoffs]] |
| LLD interview cram sheet | [[interview-quick-ref]] · [[pattern-cheatsheet]] |
| Backend rapid-fire questions | [[Assets.6 - Rapid Fire Question Bank]] |
| RAG interview drill | [[11 - Interview Drill]] |
| Frontend system design | [[28.1 - How to Approach a Frontend System Design Interview]] |
| System design resources | [[System Design Resources - InterviewReady]] |
