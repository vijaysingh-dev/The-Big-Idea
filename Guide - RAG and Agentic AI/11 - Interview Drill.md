# 11 — Interview Drill

Read this last today, and again on the morning of the interview. Say the answers **out loud** — the gap between "I know this" and "I can say this fluently under mild pressure" is the entire difference, and it only closes by speaking.

---

## The five things you must be able to do without hesitation

1. **Draw the RAG pipeline** and name all eight stages (file 03).
2. **Debug a broken RAG system** systematically — retrieval vs generation bisection (file 03 §Debugging).
3. **Explain how you'd prove a change helped** — golden set, recall@5 vs recall@50, cost alongside quality (file 06).
4. **Define an agent precisely** and say when not to build one (file 08).
5. **Talk about your own numbers** from the capstone, including the limitation (file 10).

If you can only prepare five things, prepare those five.

---

## Whiteboard diagrams (practise drawing these from memory)

### 1. RAG, end to end

```
   INGESTION                                    QUERY
  ┌──────────┐                            ┌──────────────┐
  │ sources  │                            │ user query   │
  └────┬─────┘                            └──────┬───────┘
       │ load / parse                            │ rewrite (multi-turn)
       ▼                                         │ extract filters
  ┌──────────┐                                   ▼
  │  chunk   │                            ┌──────────────┐
  └────┬─────┘                            │  RETRIEVE    │
       │ + metadata (doc, heading,        │ dense + BM25 │
       │   tenant, version)               │   → RRF      │  top 50
       ▼                                  └──────┬───────┘
  ┌──────────┐      ┌───────────────┐            ▼
  │  embed   │─────▶│  VECTOR INDEX │◀────  ┌──────────┐
  └──────────┘      │  + BM25 index │       │ RERANK   │  cross-encoder → top 5
                    └───────────────┘       └────┬─────┘
                     (index_version)              │ dedupe, order, budget
                                                  ▼
                                          ┌───────────────┐
                                          │   GENERATE    │ → answer + citations
                                          └───────┬───────┘
                                                  ▼
                                          verify citations / groundedness
```

### 2. Two-stage retrieval (the one-liner picture)

```
query ─▶ candidate generation (cheap, RECALL) ─50─▶ ranking (expensive, PRECISION) ─5─▶ prompt
```

### 3. The agent loop

```
        ┌──────────────────────────────┐
        ▼                              │
   [ LLM decides ] ──tool call──▶ [ execute ] ──observation──┘
        │
     final answer          guards: max_steps, timeout, cost budget, loop detection
```

### 4. Corrective RAG

```
retrieve ─▶ grade ──relevant──▶ generate ─▶ END
              │
          irrelevant
              │  attempts < 2 ? rewrite → retrieve : give_up
```

---

## Question bank

### A. LLM fundamentals

**1. What is a token and why do you care?** Subword unit from BPE. ~4 chars/token in English, far worse in Hindi or code. Matters because chunk sizes must be measured in tokens, cost and context limits are token-denominated, and truncation happens at token boundaries.

**2. Why is generation slower than prompt processing?** Prefill processes the whole prompt in parallel; decode produces one token at a time, each depending on the last. The KV cache avoids recomputing prior tokens but can't parallelize the sequence. So output length usually owns p95, not prompt length.

**3. Is temperature 0 deterministic?** Effectively greedy but not guaranteed reproducible — provider-side batching, floating-point non-associativity on GPUs, and silent model updates all introduce variation. So never assert exact string equality in tests; assert structure, properties, or judge scores against a threshold.

**4. Why not use a 1M-token context instead of RAG?** Cost per query, prefill latency, lost-in-the-middle degradation, and it doesn't scale to a corpus larger than the window or support incremental updates and access control. *Nuance:* for a corpus under ~100k tokens, long context often beats RAG and is simpler — don't build a vector DB for a 30-page handbook.

**5. How do you get reliable structured output?** Constrained decoding / JSON-schema mode where the provider supports it (invalid tokens are masked at each step, so the output can't be malformed), validate with Pydantic, and keep a repair-retry as a backstop. Include the schema and one example in the prompt.

**6. RAG or fine-tuning?** Different problems. RAG supplies knowledge; fine-tuning shapes behaviour, format, and tone. If the complaint is "it doesn't know our data" → RAG. If it's "it knows but answers in the wrong shape" → prompting first, fine-tuning second. And I wouldn't fine-tune before having an eval set, because I couldn't tell whether it helped.

**7. Why do models hallucinate?** They're trained to produce likely continuations, not verified facts; nothing in the architecture distinguishes recall from plausible generation. In RAG specifically, the dominant cause is that the answer was never retrieved. Mitigate with better retrieval, an explicit escape hatch, forced citations with programmatic verification, and a groundedness check — you reduce and detect it, you don't eliminate it.

### B. Embeddings and vector search

**8. What is an embedding and how is the model trained?** A dense vector representation of meaning, trained contrastively on (query, relevant passage) pairs to pull matches together and push non-matches apart. It's effectively a hash function whose collisions are semantic.

**9. Cosine vs dot product vs L2?** Equivalent on normalized vectors. Unnormalized vectors with dot product or L2 introduce a length bias where longer documents score higher — normalize and use inner product.

**10. Explain HNSW.** A multi-layer proximity graph. Upper layers are sparse with long-range links for coarse navigation; lower layers are dense for fine search. Query descends greedily. `M` and `ef_construction` are build quality/memory knobs; `ef_search` is the runtime recall-vs-latency dial.

**11. 500M vectors, limited RAM?** Quantize (int8, or binary with full-precision rescoring of the top candidates), reduce dimensions via Matryoshka truncation, use IVF-PQ or DiskANN, and shard. Do the memory arithmetic out loud: 500M × 768 × 4 bytes ≈ 1.5TB float32 → ~380GB at int8.

**12. Which vector database?** pgvector if Postgres is already there — one fewer system, plus joins, transactions and row-level security for tenant isolation. A dedicated store (Qdrant/Weaviate/Milvus) when you need filtered ANN at scale, quantization, or sharded horizontal scale. It's a tradeoff question, not a brand one.

**13. Semantic search misses exact error codes. Why?** Embeddings capture meaning, not surface form; identifiers and version numbers carry little semantic signal. Add BM25 and fuse with RRF.

### C. Chunking

**14. How do you choose chunk size?** Content type, the embedding model's max sequence length, and measurement. Default: recursive splitting at 400–600 tokens with 10–15% overlap, plus document title and heading path prefixed to every chunk. Then benchmark alternatives on a golden set.

**15. What's the key insight about chunking?** The retrieval unit and the generation unit don't have to be the same. Embed something small and specific; return something larger around it. Sentence-window, parent-document, auto-merging and contextual retrieval are all variations on that.

**16. Is semantic chunking worth it?** Sometimes — but it embeds every sentence at ingest just to find boundaries, and in my own benchmark it [your number]. Answer with measured evidence, not enthusiasm.

**17. How do you chunk tables? Code? PDFs?** Tables: repeat the header with each row group; consider indexing a summary and returning the table. Code: syntax-aware splitting at function/class boundaries, embed the signature and docstring. PDFs: fix layout-aware parsing first — no chunking strategy survives column-jumbled extraction.

**18. What metadata goes on a chunk?** doc_id, source URI, heading path, page, timestamps, tenant_id and ACL groups, chunker name, embed model version, content hash. Needed for filtering, citations, access control, versioning and debugging.

### D. Retrieval

**19. Why hybrid search?** *(be concrete)* Dense fails on exact identifiers, version numbers, negation, and rare proper nouns; BM25 handles all four. Fuse with RRF because cosine and BM25 scores aren't on a comparable scale — RRF uses ranks, so it's scale-free and needs no tuning.

**20. Bi-encoder vs cross-encoder?** Bi-encoder embeds query and document separately, so documents precompute and search scales — but the model never sees them together. Cross-encoder encodes the pair jointly and scores relevance directly: much more accurate, can't be precomputed, so it only runs on ~50 candidates. Hence two-stage retrieval.

**21. Recall@50 is 0.95, recall@5 is 0.55. What's wrong?** Ranking, not retrieval. Add or tune the reranker, adjust fusion, consider MMR if results are redundant. Reranking can't fix the opposite case — a recall miss is unrecoverable downstream.

**22. Multi-turn chat retrieves nothing useful on turn 3.** No query rewriting. "What about the second one?" isn't a standalone query. Rewrite against the history into a self-contained query before embedding.

**23. What is HyDE?** Generate a hypothetical answer, embed that instead of the question — an answer is closer to target documents in embedding space than a question is. Helps on jargon-heavy or out-of-domain queries; hurts when the model hallucinates the wrong domain; adds an LLM call to the critical path.

**24. The corpus doesn't contain the answer. What should happen?** A calibrated relevance floor on the reranker score, an explicit refusal path, and a tracked abstention rate. Most systems have no answer here, which is why they hallucinate confidently on out-of-scope questions.

### E. Evaluation

**25. How do you evaluate a RAG system?** Component-level plus end-to-end. Retrieval: recall@k, MRR, nDCG — deterministic, cheap, run on every PR. Generation: faithfulness, answer relevancy, context precision/recall via an LLM judge — run nightly. Backed by a versioned golden set, and online signals once there's traffic.

**26. How did you build your golden set?** LLM-generated questions from sampled chunks, then hand-verified every one — synthetic questions inherit the document's vocabulary and flatter retrieval. Added hard categories manually: multi-hop, negation, comparison, temporal, and ~12% unanswerable. Versioned in the repo, with a held-out slice.

**27. How do you measure hallucination?** Decompose the answer into atomic claims and verify each against the retrieved context — that's faithfulness. Plus programmatic citation validity, plus refusal rate on the unanswerable subset.

**28. Is LLM-as-judge trustworthy?** Usable with discipline: binary or 3-point rubrics rather than 1–10, reasoning before verdict, a different model from the generator, both orders in pairwise comparisons. Known biases: position, verbosity, self-preference, score clustering. Calibrate against your own human labels and report the agreement rate.

**29. Recall@5 improved 2 points. Ship it?** Not on its own. What's the run-to-run variance, and what's the sample size? Did latency or cost move? Was the change tuned against the same set I'm measuring on? With 40 questions, 2 points is usually noise.

**30. Offline metrics improved but users complain.** The eval set doesn't match the real query distribution. Mine production logs, rebuild the golden set from real queries, and add online guardrail metrics — thumbs-down rate, rephrase rate, abandonment.

### F. Production

**31. How do you keep the index fresh?** Content-hash documents to skip unchanged ones, content-derived chunk ids for idempotent upserts, tombstone chunks that disappeared, and monitor ingestion lag against a stated freshness SLA. Missed deletes mean citing revoked documents — a compliance problem.

**32. Changing the embedding model on a live system?** Blue/green: build a new index version in the background, shadow-evaluate against the golden set, flip an alias, keep the old one for the rollback window. Stamp `index_version` on every vector and assert it at query time — mismatched query and index embedders is the classic silent incident.

**33. Tenant isolation?** Namespace per tenant, or index-level filtering enforced inside the ANN traversal, plus row-level security if it's Postgres. Never post-filtering — that's a leak waiting for a bug. And the same scoping applies to caches, logs and eval datasets.

**34. Prompt injection in RAG?** Retrieved third-party text lands in the model's instruction channel, and roles are a fine-tuning convention rather than a sandbox. Layer defenses: delimit and label untrusted content, least-privilege tools so injection can't do much, output scanning for exfiltration patterns (including markdown image URLs), human confirmation for consequential actions, and sanitizing hidden text at ingest.

**35. What do you log?** Query, rewritten query, filters, retrieved chunk ids with dense/sparse/rerank scores, token counts, per-stage latency, model and index versions, cost, refusal flag, citation validity, feedback. The retrieved ids and scores are the single most valuable line — without them, no bug report is falsifiable.

**36. How do you control cost?** Cap output tokens, exploit prompt caching by putting static text first, cache answers (keyed including tenant and index version), route easy queries to a cheaper model, and retrieve fewer chunks. Track cost per query as a first-class metric with alerts.

**37. Scale to 50M documents / 10k QPS?** Size it out loud: ~500M vectors, quantize and shard, read replicas for query traffic, IVF-PQ or DiskANN. The reranker becomes a GPU-serving problem; generation becomes the real constraint and probably the thing to design around with caching and routing. At that scale the cost sheet picks the architecture.

### G. Agents

**38. What is an agent?** A loop where the model decides what happens next. The distinction that matters: in a workflow, a human wrote the control flow; in an agent, the model decides it at runtime.

**39. When would you not use one?** When the steps are known — write a workflow: deterministic, testable, much cheaper. Also when correctness must be guaranteed, when latency budgets are tight, or when there's no feedback signal for self-correction. Use the least agency that solves the problem.

**40. Why do agents fail?** Compounding error above all: 95% per-step reliability over 10 steps is ~60% task success. Plus looping, context rot, wrong tool selection when there are too many tools, and cost growing quadratically because each step re-sends a growing context.

**41. How do you make one safe?** Step caps, wall-clock timeouts, cost budgets, loop detection, schema validation before execution, idempotency keys on mutating tools, read-only by default, and human-in-the-loop interrupts before consequential actions.

**42. How do you evaluate an agent?** Outcome-level task success on a golden task set, with trajectory metrics — tool-selection accuracy, step count, redundant calls, error-recovery rate, step-cap hit rate — used diagnostically. Never score exact trajectory matches; multiple paths are valid. Always report steps, tokens, cost and latency next to accuracy.

**43. What's agentic RAG and is it worth it?** The model decides whether to retrieve, how many times, and from where, and can grade results and retry. Worth it for multi-hop and comparative queries — route those in with a cheap classifier. Making every query agentic multiplies cost and latency for queries one retrieval already answers.

**44. Multi-agent — when?** Mainly a context-management technique: smaller context and fewer tools per agent raises per-step reliability. Good for parallel, read-only subtasks. Bad when agents write to shared state — that's distributed consensus with a probabilistic participant.

**45. What is MCP?** An open protocol for exposing tools and data to LLM applications, turning an N×M integration problem into N+M — LSP for editors, but for model tooling. It's also a new trust boundary: you're importing tool descriptions you didn't write, so pin and review servers.

---

## System design prompts (practise these out loud, 10 minutes each)

### 1. "Design a customer-support assistant over 50,000 help-center articles and 2 years of tickets."

Structure your answer: **requirements → data → pipeline → quality → scale → risks.**

- **Requirements first (always ask):** latency target, accuracy bar, must it cite, can it act (refunds, ticket creation) or only answer, languages, who can see what.
- **Data:** two very different corpora — curated articles (clean, structured, authoritative) vs tickets (messy, contradictory, contain PII, contain *wrong* answers from agents). Treat them as separate indexes with different trust weights; redact PII from tickets at ingest.
- **Pipeline:** structural chunking with heading prefixes for articles; thread-level chunking for tickets. Hybrid retrieval, cross-encoder rerank, top 5, citations required, refusal path.
- **Quality:** golden set mined from real ticket history where the resolution is known; measure deflection rate and escalation-after-bot-answer as business metrics.
- **Scale:** trivial vector-wise (~500k chunks); the constraint is generation cost and p95.
- **Risks:** stale articles (freshness SLA + recency boosting), tickets contradicting official policy (source authority weighting), prompt injection via user-submitted ticket content, and hallucinated refund promises → no write tools without confirmation.

### 2. "Our RAG chatbot's accuracy dropped from 80% to 55% overnight. Debug it."

Say "overnight implies a change, not a drift" and work backwards: what deployed? Index version mismatch (embedder changed without reindex)? Ingestion job failing silently (freshness metric)? A provider model update? Then bisect: run the golden set → is retrieval or generation degraded? Check the score distribution of top-1 results — a collapse there points squarely at the index or embedder.

### 3. "Design an agent that files expense reports from receipt photos."

Extraction (vision model, structured output) → validation against policy (deterministic rules, not an LLM) → duplicate detection → submission. Note explicitly: most of this is a **workflow**, not an agent; the only genuinely model-decided branch is handling ambiguous or unreadable receipts. Human approval gate before submission, idempotency key per receipt hash, full audit trail.

### 4. "Should we build RAG or fine-tune for our internal knowledge assistant?"

RAG, and say why in one breath: the knowledge changes, must be attributable, must respect per-document permissions, and re-indexing is cheaper than retraining. Fine-tuning enters later, for format and tone consistency, or to distill a cheaper model once you have traffic data — and only with an eval set in place.

---

## Questions to ask them (have three ready)

1. "How do you evaluate quality today — do you have a golden set, and is it in CI?" *(Tells you their maturity immediately, and signals yours.)*
2. "What's your biggest failure mode right now — retrieval misses, hallucination, latency, or cost?"
3. "Where's the line between what's a workflow and what's agentic in your system?"

---

## The morning-of checklist

- Re-read the eight-stage diagram and the two-stage retrieval picture. Draw both once on paper.
- Say your capstone pitch out loud twice: **result → surprise → limitation.**
- Have your leaderboard open in a tab. If it's a video call, offer to share it.
- Know your three numbers cold: best recall@5, the reranker's delta and its latency cost, and your refusal rate on unanswerable questions.
- If you don't know something: *"I haven't worked with that directly. My understanding is X — is that how you're using it?"* Honest and curious beats bluffing, every time. Interviewers are looking for someone they can trust to report bad news accurately, and this is you demonstrating it.
