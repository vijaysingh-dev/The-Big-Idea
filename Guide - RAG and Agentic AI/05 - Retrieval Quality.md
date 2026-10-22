# 05 — Retrieval Quality

Chunking decides *what could be found*. This file decides *what actually gets found and ranked first*. If your baseline RAG is disappointing, the fixes here typically move quality more than any prompt change, model upgrade, or framework migration.

---

## Mental model

Stop thinking "vector search" and start thinking like a **search engineer**, because that's what this is. Every serious retrieval system has the same two-stage shape:

```
query ──▶ [ CANDIDATE GENERATION ]  ──▶ [ RANKING ]  ──▶ top 3–5 into the prompt
           cheap, high recall,            expensive, high precision,
           returns 50–200 candidates      returns the best few
           (BM25 + dense vectors)         (cross-encoder reranker)
```

**Recall is the job of stage 1. Precision is the job of stage 2.** They have different failure modes and different fixes, and conflating them is the most common architectural mistake in RAG.

A useful corollary: **you cannot rerank your way out of a recall miss.** If the answer chunk isn't in the 100 candidates, no reranker in the world will surface it. So measure recall@50 and recall@5 separately — the gap between them tells you which stage to invest in.

- Low recall@50 → fix candidate generation (hybrid, query rewriting, chunking, metadata).
- High recall@50 but low recall@5 → fix ranking (reranker, MMR, fusion weights). This is the happier problem and the cheaper fix.

---

## 1. Hybrid search — dense + lexical

Dense (embedding) retrieval fails on a very predictable class of queries:

| Query type | Dense | BM25 |
|---|---|---|
| "how do I recover access to my account" | Strong — paraphrase-tolerant | Weak — no shared words |
| "error KB-4471" | **Weak** — IDs are semantic noise | Strong — exact match |
| "difference between v2.14.3 and v2.15" | **Weak** — version numbers embed similarly | Strong |
| "how to *disable* SSO" | **Weak** — negation barely registers | Strong — "disable" is a term |
| a rare proper noun / internal codename | **Weak** — likely out-of-vocabulary in training | Strong |

That table is a complete interview answer to "why hybrid search?" Memorize its shape.

**BM25** (Best Match 25) is the classic lexical ranking function: it scores a document by how many query terms it contains, weighting rare terms higher (IDF — inverse document frequency), with diminishing returns for term repetition and a penalty for document length. Forty-year-old technology that still beats embeddings on exact-match queries.

```python
# raglab/retrieve/hybrid.py
import re

import numpy as np
from rank_bm25 import BM25Okapi


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9_\-\.]+", text.lower())


class HybridRetriever:
    def __init__(self, chunks, encoder, k_dense: int = 50, k_sparse: int = 50):
        self.chunks = chunks
        self.encoder = encoder
        self.k_dense, self.k_sparse = k_dense, k_sparse
        self.matrix = encoder.encode([c.embed_text for c in chunks],
                                     normalize_embeddings=True).astype("float32")
        self.bm25 = BM25Okapi([tokenize(c.embed_text) for c in chunks])

    def _dense(self, query: str) -> list[int]:
        q = self.encoder.encode([query], normalize_embeddings=True)[0].astype("float32")
        return list(np.argsort(-(self.matrix @ q))[: self.k_dense])

    def _sparse(self, query: str) -> list[int]:
        return list(np.argsort(-self.bm25.get_scores(tokenize(query)))[: self.k_sparse])

    def search(self, query: str, k: int = 10):
        fused = reciprocal_rank_fusion([self._dense(query), self._sparse(query)])
        return [(self.chunks[i], score) for i, score in fused[:k]]
```

### Fusing the two result lists

You cannot add a cosine score (0–1) to a BM25 score (unbounded, corpus-dependent) — they aren't on the same scale, and normalizing per query is unstable because score distributions shift with the query. The standard solution ignores scores entirely and uses **ranks**.

**Reciprocal Rank Fusion (RRF):** each list contributes `1/(k + rank)` to each document, with `k ≈ 60` damping the influence of the very top positions.

```python
def reciprocal_rank_fusion(rankings: list[list[int]], k: int = 60,
                           weights: list[float] | None = None) -> list[tuple[int, float]]:
    weights = weights or [1.0] * len(rankings)
    scores: dict[int, float] = {}
    for ranking, w in zip(rankings, weights):
        for rank, doc_id in enumerate(ranking, start=1):
            scores[doc_id] = scores.get(doc_id, 0.0) + w / (k + rank)
    return sorted(scores.items(), key=lambda kv: -kv[1])
```

Why RRF is the default: it's scale-free, needs no tuning, works with any number of retrievers, and is robust to one retriever producing garbage scores. The alternative — min-max normalizing both score sets and taking `α·dense + (1-α)·sparse` — can work slightly better *if* you tune `α` on your eval set, but it's brittle across query types. Say: *"RRF by default because it's scale-free; weighted score fusion only if I have an eval set to tune alpha on, and I'd expect the right alpha to differ between natural-language and identifier-style queries."*

**Production note:** many vector databases (Qdrant, Weaviate, Elasticsearch, pgvector + `tsvector`) support hybrid natively in one query, which saves you a round trip and keeps filtering consistent across both arms.

---

## 2. Reranking with a cross-encoder — the highest-ROI addition

This is usually the single biggest quality jump available for ~20 lines of code.

**Bi-encoder** (your embedding model): encodes query and document **separately** into vectors, then compares. Documents can be embedded offline → fast, scalable, but the model never sees query and document together.

**Cross-encoder** (the reranker): takes `(query, document)` as **one concatenated input** and outputs a single relevance score. Attention runs across both, so it can catch negation, qualifiers, and subtle mismatch that cosine similarity misses. It cannot be precomputed — you run it per candidate at query time — so it's only usable on a small candidate set.

```python
from sentence_transformers import CrossEncoder

reranker = CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")   # ~80MB, fast on CPU


def rerank(query: str, candidates, top_n: int = 5, batch_size: int = 32):
    pairs = [(query, c.embed_text) for c in candidates]
    scores = reranker.predict(pairs, batch_size=batch_size)
    ranked = sorted(zip(candidates, scores), key=lambda cs: -cs[1])
    return ranked[:top_n]
```

The full pipeline becomes:

```
query → hybrid retrieve top 50 → cross-encoder rerank → top 5 → prompt
```

**Cost/latency:** a small cross-encoder scores 50 pairs in roughly 50–150ms on CPU, a few milliseconds on GPU. Hosted rerankers (Cohere Rerank, Voyage, Jina) add a network hop, typically 100–300ms, and charge per search. Larger LLM-based rerankers are better and much slower.

**Tuning knob:** how many candidates you rerank. 50 is a good default; 100+ gives diminishing returns against linear latency growth. Measure recall@50 first — if it's 0.95, reranking 200 candidates buys you almost nothing.

Say this in an interview: *"If I could make exactly one change to a naive RAG system, it'd be adding a cross-encoder reranker on top of hybrid retrieval. It fixes the precision problem directly, needs no retraining, and I can measure the gain in an afternoon."*

---

## 3. MMR — diversity instead of five copies of the same paragraph

**Maximal Marginal Relevance** trades relevance against novelty, so results aren't near-duplicates. This matters enormously with overlapping chunks, sentence windows, or a corpus with boilerplate repeated across documents.

```
MMR = argmax over unselected d of:  λ · sim(d, query) − (1 − λ) · max sim(d, already_selected)
```

`λ = 1` is pure relevance; `λ = 0.5–0.7` is the useful range.

```python
def mmr(query_vec, cand_vecs, candidates, k: int = 5, lam: float = 0.6):
    relevance = cand_vecs @ query_vec
    selected: list[int] = []
    remaining = list(range(len(candidates)))

    while len(selected) < k and remaining:
        if not selected:
            best = max(remaining, key=lambda i: relevance[i])
        else:
            sim_to_selected = cand_vecs[remaining] @ cand_vecs[selected].T   # (r, s)
            redundancy = sim_to_selected.max(axis=1)
            best = remaining[int(
                max(range(len(remaining)),
                    key=lambda j: lam * relevance[remaining[j]] - (1 - lam) * redundancy[j])
            )]
        selected.append(best)
        remaining.remove(best)

    return [candidates[i] for i in selected]
```

Use it when: a question needs evidence from **multiple** documents (comparisons, "list all the ways to…", multi-hop). Skip it when: questions are narrow and factual — diversity then just dilutes.

---

## 4. Query transformation — fix the query, not just the index

The user's raw text is often a bad search query. Five techniques, roughly in order of practical value:

### 4a. Conversational query rewriting (do this first — it's the most common real bug)

"What about the second one?" has no standalone meaning. Embedding it retrieves noise.

```python
REWRITE = """Rewrite the user's latest message into a standalone search query that makes sense
without the conversation history. Keep entity names exactly. Output only the query.

Conversation:
{history}

Latest message: {message}
Standalone query:"""


def rewrite_query(history: str, message: str) -> str:
    return llm(REWRITE.format(history=history[-2000:], message=message)).strip()
```

Any multi-turn RAG system without this is broken from turn two onward. Mentioning it unprompted is a strong signal you've actually shipped a chatbot.

### 4b. Multi-query (query expansion)

Generate 3–4 paraphrases, retrieve for each, fuse with RRF. Covers vocabulary mismatch between how users ask and how documents are written.

```python
def multi_query(question: str, retriever, n: int = 3, k: int = 10):
    variants = llm(f"Generate {n} different search queries for: {question}\n"
                   f"One per line, no numbering.").strip().split("\n")
    rankings = [[c.id for c, _ in retriever.search(q, k=k)] for q in [question] + variants]
    return reciprocal_rank_fusion(rankings)
```

Cost: n+1 retrievals plus one LLM call, so it adds real latency. Best used as an offline/batch technique or for high-value queries.

### 4c. HyDE — Hypothetical Document Embeddings

Ask the LLM to *write a fake answer* to the question, then embed **that** and search with it. The reasoning: an answer looks more like the target document than a question does, so it's closer in embedding space (this is the symmetric/asymmetric mismatch from file 02, solved from the query side).

```python
def hyde(question: str, retriever, k: int = 10):
    fake = llm(f"Write a short factual paragraph that would answer this question:\n{question}")
    return retriever.search(fake, k=k)
```

Works well on out-of-domain or jargon-heavy queries; risks drifting when the model hallucinates the wrong domain entirely. Adds an LLM call to your critical path.

### 4d. Query decomposition (multi-hop)

"How does our refund policy differ between EU and India?" is two retrievals and a comparison, not one. Split into sub-questions, retrieve each independently, then synthesize.

```python
def decompose(question: str) -> list[str]:
    out = llm(f"If this question requires multiple separate lookups, break it into standalone "
              f"sub-questions, one per line. If not, return it unchanged.\n\n{question}")
    return [q.strip() for q in out.split("\n") if q.strip()]
```

This is also the natural bridge into agentic RAG (file 08): the "decide how many retrievals I need" step is exactly what an agent loop does dynamically.

### 4e. Step-back prompting

For narrow questions, also retrieve on a more general version ("What is the retry policy for the payments webhook in v3?" → "How do webhook retries work?"). Fuse both. Useful when the specific answer requires general background.

---

## 5. Metadata filtering and routing

**Self-querying:** extract structured filters from natural language before searching.

> "What did the 2024 security policy say about laptop encryption?"
> → filter `{year: 2024, doc_type: "security_policy"}`, semantic query `"laptop encryption"`.

```python
FILTER_SCHEMA = """Extract search filters as JSON with keys: year (int|null),
doc_type (one of: policy, runbook, api_reference, null), and query (the semantic part).
Question: {q}"""
```

Filtering before ranking is a **massive** precision win and costs nothing at query time — the metadata was free, you just have to have attached it during chunking (file 04, pitfall 2).

**Routing:** not every question should hit the same index. A classifier (LLM or a small trained model) sends the query to the right place: the docs index, the tickets index, a SQL query, or straight to the model with no retrieval at all ("hi", "summarize what you just said"). Routing decisions are also where you save money — many queries need no retrieval.

**Recency and authority boosting:** in corpora with versioned or superseded documents, blend a decay factor into the final score (`final = rerank_score * exp(-age_days / τ)`) or filter deprecated documents outright. Otherwise your bot cheerfully quotes the 2019 policy.

---

## 6. Assembling the final context

After ranking, three decisions remain — all of them measurable:

1. **How many chunks?** Not "as many as fit". More context lowers precision and raises cost. Start at 3–5 reranked chunks; test 3 vs 5 vs 10 on your eval set. Many systems get *worse* past 5.
2. **What order?** Highest-scored at the edges (first and last), weakest in the middle — lost-in-the-middle, from file 01.
3. **Deduplication and merging.** Overlapping sentence-windows and sibling parent-doc chunks must be merged, or you'll spend 60% of your context budget on repeated text.

```python
def assemble(ranked, budget_tokens: int = 2000):
    seen_parents, kept = set(), []
    for chunk, score in ranked:
        parent = chunk.meta.get("parent_id", chunk.id)
        if parent in seen_parents:
            continue
        seen_parents.add(parent)
        kept.append((chunk, score))

    selected, used = [], 0
    for chunk, score in kept:
        cost = ntokens(chunk.context_text)
        if used + cost > budget_tokens:
            continue
        selected.append((chunk, score))
        used += cost

    # Strongest evidence at the edges, since models attend least to the middle of long contexts.
    ordered = selected[::2] + selected[1::2][::-1]
    return ordered
```

---

## 7. The full pipeline and its latency budget

```
user query
  → rewrite (LLM, ~300ms)            [only if conversational]
  → filter extraction (LLM, ~300ms)  [only if metadata-rich corpus]
  → hybrid retrieve top 50 (~30ms)
  → cross-encoder rerank to 5 (~100ms)
  → dedupe + assemble (~1ms)
  → generate (LLM, 1–5s)             [dominates]
```

Note what dominates: generation. So optimize retrieval for **quality first**, and only then trim its latency. The exception is the LLM calls in stages 1–2 — those are serial LLM hops before you've even started retrieving, which is why query rewriting is often done with a small fast model, or skipped when the query is already standalone (a cheap heuristic: does it contain a pronoun or demonstrative with no antecedent?).

---

## 8. Pitfalls

1. **Reranking a too-small candidate set.** Reranking top-5 is nearly pointless; the reranker needs room to reorder. Retrieve 50, rerank to 5.
2. **Believing the reranker fixes recall.** It cannot. Measure both stages.
3. **Tuning `α` in weighted fusion on a handful of queries** — you're fitting noise. RRF or an eval set.
4. **Query expansion on the critical path** without measuring — you may add 800ms for +1% recall.
5. **Forgetting filters must apply to *both* arms** of hybrid search, and to the reranker's input. A leaked tenant document is a leak whether it arrived via BM25 or via vectors.
6. **No handling of "no good results".** If the top reranker score is below a calibrated threshold, the correct behaviour is to say so — not to answer from five irrelevant chunks. Add a relevance floor and an explicit "I don't have information on that" path.
7. **Ignoring the query distribution.** Look at 100 real user queries before tuning anything. If 40% are navigational ("where is the leave policy?") and 30% are conversational follow-ups, that dictates your priorities more than any benchmark.

---

## Open source to read

- **`rank_bm25`** (github.com/dorianbrown/rank_bm25) — 200 lines; read `BM25Okapi.get_scores` and you'll understand IDF and length normalization concretely.
- **`sentence-transformers` cross-encoder examples** — `examples/applications/retrieve_rerank/`. The retrieve-and-rerank example is essentially the reference implementation of this whole file.
- **RAGatouille / ColBERT** (github.com/AnswerDotAI/RAGatouille) — late-interaction retrieval, a middle ground between bi-encoders and cross-encoders (per-token vectors with MaxSim scoring). Worth knowing the name and the one-line explanation.

---

## Exercises (tomorrow, ~90 minutes — capstone part 2)

1. **Add BM25 + RRF** to your capstone. Re-run the leaderboard. Record recall@5 before and after.
2. **Find the queries where hybrid wins.** Diff the result sets between dense-only and hybrid; look at which questions changed. They'll be the identifier/negation/rare-noun ones — confirm the theory with your own data.
3. **Add the cross-encoder reranker.** Retrieve 50, rerank to 5. Measure recall@5 and MRR delta, and the added p95 latency. This should be your biggest single jump.
4. **Measure the recall ceiling.** Compute recall@50 for your retriever. That's the maximum any reranker could achieve. If it's 0.7, stop tuning ranking and go fix chunking or add query expansion.
5. **Implement MMR** and test on a question that needs two documents. Compare with and without.
6. **Break negation on purpose.** Write 5 question pairs differing only by enable/disable, include/exclude, before/after. Measure dense-only vs hybrid vs hybrid+rerank on those 10. This makes an excellent 30-second interview story.
7. **Add a relevance floor.** Determine the reranker score below which answers are usually wrong, and return an explicit refusal under it. Measure how many false answers this prevents.

---

## Interview questions

1. Why hybrid search? Give concrete failing queries for dense-only. *(IDs, versions, negation, rare proper nouns)*
2. How do you combine two rankers with incompatible scores? *(RRF — rank-based, scale-free; or normalized weighted fusion if you can tune α on eval data)*
3. Bi-encoder vs cross-encoder? *(separate vs joint encoding; precomputable vs per-query; scale vs accuracy — hence two-stage)*
4. Where does a reranker sit and how many candidates does it see? *(after candidate generation; ~50; it cannot recover a recall miss)*
5. Your recall@50 is 0.95 but recall@5 is 0.55. What now? *(ranking problem — reranker, fusion weights, MMR; not a chunking problem)*
6. Recall@50 is 0.6. What now? *(candidate generation — hybrid, query rewriting/expansion, chunking, metadata filters, check parsing)*
7. What is HyDE and when does it help/hurt? *(hypothetical answer embedding; helps on jargon/out-of-domain; hurts when the model hallucinates the wrong domain; adds latency)*
8. Multi-turn chat retrieves garbage on turn 3. Why? *(no query rewriting — the follow-up isn't standalone)*
9. What is MMR for? *(redundancy reduction; multi-document questions; λ tradeoff)*
10. How do you handle "the corpus doesn't contain the answer"? *(calibrated relevance floor + explicit refusal path + measure the abstention rate — most systems have no answer to this and it's a great differentiator)*

---

## Resources

- **Pinecone, "Rerankers and Two-Stage Retrieval"** — https://www.pinecone.io/learn/series/rag/rerankers/ — the clearest explanation of the bi-encoder/cross-encoder split and why two-stage retrieval exists.
- **Sentence-Transformers retrieve & re-rank guide** — https://sbert.net/examples/applications/retrieve_rerank/README.html — runnable reference for the exact pipeline in this file.
- Optional depth: **"Precision Neighbours: RRF" (Cormack et al., 2009)** — the original reciprocal rank fusion paper; two pages, and it explains why such a simple formula is so hard to beat.
