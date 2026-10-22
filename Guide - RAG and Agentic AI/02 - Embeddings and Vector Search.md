# 02 — Embeddings and Vector Search

This is the layer where most RAG systems are silently broken. It's also where your database instincts transfer almost perfectly: it's an index with a recall/latency/memory tradeoff.

---

## Mental model

An **embedding** is a fixed-length vector of floats that represents the *meaning* of a piece of text, produced by a small neural network. Texts with similar meaning land close together in that space.

The useful reframing for a backend engineer: an embedding model is a **learned hash function whose collisions are semantic**. Normal hashing destroys similarity by design; embeddings preserve it, so "nearby" becomes a meaningful query.

```
"how do I reset my password"   -> [0.021, -0.113, ..., 0.077]   (384 floats)
"password recovery steps"      -> [0.019, -0.108, ..., 0.081]   ← close
"quarterly revenue in Q3"      -> [-0.204, 0.331, ..., -0.012]  ← far
```

Semantic search = embed the query, find the nearest document vectors, return those documents.

---

## 1. Why the vectors mean anything

Embedding models are trained with **contrastive learning**: given (query, relevant passage) pairs, the loss pulls those two vectors together and pushes apart random ("negative") passages. Train on hundreds of millions of pairs and you get a space where cosine distance ≈ relevance.

Two implications people miss:

- **The model learned a specific notion of "similar"** — the one in its training pairs (mostly web/QA data). It does not know that in your domain "policy" means an insurance document, not an IAM rule. This is why domain-specific retrieval often needs hybrid search or fine-tuned embeddings.
- **Similarity is not relevance.** "How do I *enable* SSO?" and "How do I *disable* SSO?" are extremely close in embedding space. Negation, numbers, dates, IDs and version numbers are all poorly captured. Keyword search handles those precisely — hence hybrid retrieval (file 05).

## 2. Distance metrics
| Metric | Formula | Use |
|---|---|---|
| **Cosine similarity** | $\frac{A \cdot B}{\lVert A\rVert \lVert B\rVert}$ | Default. Ignores magnitude, compares direction |
| **Dot product (inner product)** | $A \cdot B$ | Identical to cosine if vectors are normalized to unit length |
| **Euclidean (L2)** | $\lVert A - B\rVert$ | Also monotonically equivalent to cosine on normalized vectors |

Practical rule: **normalize your vectors, then use inner product.** It's the fastest, and it makes the three metrics agree. The classic production bug is indexing unnormalized vectors with L2 or IP: long documents get systematically higher scores because their vectors are longer, and your retrieval develops a length bias you'll spend a day debugging.

```python
import numpy as np
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")

docs = [
    "To reset your password, click 'Forgot password' on the login screen.",
    "Passwords must be at least 12 characters and rotate every 90 days.",
    "Our Q3 revenue grew 14% year over year.",
    "SSO can be disabled from the admin console under Security.",
]
D = model.encode(docs, normalize_embeddings=True)      # (4, 384), unit length

def search(query, k=3):
    q = model.encode([query], normalize_embeddings=True)[0]
    scores = D @ q                                      # cosine, because everything is normalized
    order = np.argsort(-scores)[:k]
    return [(float(scores[i]), docs[i]) for i in order]

for s, d in search("I forgot my login credentials"):
    print(f"{s:.3f}  {d[:60]}")

print(search("how do I enable SSO")[0])   # note: the 'disable SSO' doc wins. This is the negation problem.
```

Run the last line and *see* the negation failure yourself — it's a great story to tell in an interview, and it motivates every technique in file 05.

## 3. Choosing an embedding model

| Factor | What to know |
|--------|--------------|
| **Dimensions** | 384 / 768 / 1024 / 1536 / 3072. More dims ≈ slightly better quality, linearly more memory and slower search. 768 is a sane default |
| **Max sequence length** | Usually 512 tokens (~2 pages). **Text beyond this is silently truncated.** This is a hard constraint on chunk size — a 2000-token chunk fed to a 512-token model loses 75% of its content and nobody errors |
| **Symmetric vs asymmetric** | Symmetric = comparing two similar-length texts. Asymmetric = short query vs long passage (what RAG does). Models like `bge`, `e5`, `nomic` expect **instruction prefixes** (`"query: ..."` vs `"passage: ..."`). Forgetting the prefix costs several points of recall |
| **Domain & language** | Check MTEB, but weight the retrieval tasks and your language, not the overall average |
| **Local vs API** | Local (sentence-transformers) = free, private, no rate limits, CPU-slow at ingest. API = better quality, per-token cost, network dependency |

**MTEB** (Massive Text Embedding Benchmark, on Hugging Face) is the standard leaderboard — treat it as a shortlist generator, not a decision. Leaderboards are partly overfit; test 2–3 candidates on *your* golden set (file 06).

```python
# Asymmetric models need their prefixes — this is the #1 silent quality bug
model = SentenceTransformer("BAAI/bge-base-en-v1.5")
doc_vecs   = model.encode(docs, normalize_embeddings=True)
query_vec  = model.encode(["Represent this sentence for searching relevant passages: " + q],
                          normalize_embeddings=True)
```

### Cost/scale intuition

1M chunks × 768 dims × 4 bytes (float32) = **~3 GB** of raw vectors, plus index overhead (HNSW roughly doubles it). That fits in RAM on a normal box — which is why "just use pgvector" is a legitimate answer far longer than people assume.

---

## 4. Approximate nearest neighbour (ANN) indexes

Brute force ("flat") search compares the query to every vector: exact, O(n·d), fine up to ~100k–1M vectors. Beyond that you trade exactness for speed.

**Recall@k** here means: of the true top-k nearest neighbours, what fraction did the index return. ANN indexes are tunable — you choose your recall.

| Index | How it works | Build | Query | Memory | Use when |
|-------|--------------|-------|-------|--------|----------|
| **Flat** | Compare to everything | instant | O(n) | 1× | < ~500k vectors, or you need exact ground truth |
| **HNSW** | Hierarchical Navigable Small World: a multi-layer proximity graph; search greedily descends layers | slow-ish | very fast, ~O(log n) | 1.5–2× (graph edges) | Default for most production systems |
| **IVF** | Inverted File: k-means cluster the space, search only the `nprobe` nearest clusters | medium | fast | ~1× | Large sets, memory-sensitive |
| **IVF-PQ** | IVF + Product Quantization: compress each vector into a few bytes of codebook ids | medium | fastest | 10–50× smaller | 100M+ vectors, memory-bound |
| **ScaNN / DiskANN** | Google's / Microsoft's variants; DiskANN keeps the graph on SSD | — | — | tiny RAM | Billion-scale on one machine |

Key knobs (worth memorizing — they come up):

- **HNSW `M`**: edges per node. Higher = better recall, more memory. Typical 16–64.
- **HNSW `ef_construction`**: candidate list size during build. Higher = better graph, slower build. 100–400.
- **HNSW `ef_search`**: candidate list at query time. **This is your runtime recall/latency dial** — raise it when quality is poor, lower it when p99 hurts. Typical 50–200.
- **IVF `nlist`**: number of clusters, ~`sqrt(n)`. **`nprobe`**: clusters searched per query, the recall dial.

```python
import numpy as np, faiss, time

d, n = 384, 50_000
rng = np.random.default_rng(0)
X = rng.normal(size=(n, d)).astype("float32")
faiss.normalize_L2(X)
Q = X[:200].copy()                      # query with known vectors

flat = faiss.IndexFlatIP(d); flat.add(X)
_, truth = flat.search(Q, 10)

hnsw = faiss.IndexHNSWFlat(d, 32, faiss.METRIC_INNER_PRODUCT)
hnsw.hnsw.efConstruction = 200
t0 = time.time(); hnsw.add(X); build = time.time() - t0

for ef in (10, 40, 100, 200):
    hnsw.hnsw.efSearch = ef
    t0 = time.time(); _, got = hnsw.search(Q, 10); dt = (time.time() - t0) * 1000
    recall = np.mean([len(set(g) & set(t)) / 10 for g, t in zip(got, truth)])
    print(f"efSearch={ef:4d}  recall@10={recall:.3f}  {dt:6.1f} ms / 200 queries  (build {build:.1f}s)")
```

Running this once gives you a real, felt understanding of the recall/latency curve — and a concrete answer to "how would you tune a vector index?"

---

## 5. Vector stores — how to choose without brand loyalty

| Option | Shape | Pick it when |
|--------|-------|--------------|
| **FAISS** | Library, in-process, no persistence layer of its own | You want control, batch jobs, benchmarks, embedded use |
| **pgvector** (Postgres) | Extension: vectors as a column type | **You already run Postgres.** Transactions, joins, real filters, one system to operate. Comfortable into the tens of millions of rows |
| **Chroma** | Embedded/lightweight server | Prototypes, local dev, the capstone |
| **Qdrant / Weaviate / Milvus** | Dedicated vector DBs | Large scale, need sharding, replication, quantization, first-class hybrid search |
| **Pinecone / managed** | SaaS | Don't want to operate it; cost scales with vectors |
| **Elasticsearch / OpenSearch** | Search engine + vectors | You already run it and want BM25 + dense in one query |

Interview-grade answer: *"I'd start with pgvector if Postgres is already in the stack — one fewer system to run, and I get ACID, joins to my metadata, and row-level security for multi-tenancy for free. I'd move to a dedicated vector DB when I need >50M vectors, quantization, or sharded horizontal scale."* That reasoning matters far more than the name.

### Metadata filtering — the subtlety worth knowing

Real queries are "search these vectors **where** `tenant_id = X and doc_type = 'policy' and updated_at > ...`". Three implementations:

- **Post-filter**: ANN search top-k, then filter. Fast, but if the filter is selective you may get zero results back ("I searched 100 and none matched my tenant").
- **Pre-filter**: build the allowed id set, then search only those. Correct, but can degrade to a scan and breaks the ANN graph's assumptions.
- **Filtered ANN** (Qdrant, Weaviate, recent pgvector): filtering integrated into graph traversal. This is the reason to pick a dedicated vector DB.

**Multi-tenancy**: never rely on post-filtering for tenant isolation — a bug becomes a data leak. Use separate collections/namespaces per tenant, or a database that enforces the filter in the index (and in Postgres, row-level security).

---

## 6. Quantization and compression

- **float32 → float16**: half the memory, negligible quality loss. Free win.
- **int8 scalar quantization**: 4× smaller, ~1–2% recall loss. Standard in production.
- **binary quantization**: 32× smaller, big recall loss alone — but the pattern is *binary search for top-1000, then rescore those with full-precision vectors*. That two-stage approach gets near-full recall at a fraction of memory, and is a great thing to mention.
- **Matryoshka embeddings** (e.g. OpenAI `text-embedding-3-*`, `nomic-embed`): trained so that the first N dimensions are usable on their own. You can truncate 3072 → 512 dims and keep most of the quality. Same two-stage trick: search truncated, rescore full.

---

## 7. Pitfalls that break real systems

1. **Changing the embedding model without re-indexing.** Vectors from two models are not comparable — the space is different. Store `model_name` and `model_version` in your index metadata and assert it at query time. This is *the* most common production incident in RAG.
2. **Query/document asymmetry ignored** — missing instruction prefixes on `e5`/`bge` models.
3. **Chunk longer than the model's max sequence length** → silent truncation.
4. **Unnormalized vectors** with IP/L2 → length bias.
5. **Embedding the wrong text.** If you embed a chunk that begins mid-sentence with no title or section header, its vector encodes nothing useful. Prepending document title + section heading to the embedded text ("contextual chunk headers") is a cheap, large win.
6. **No BM25 fallback**, so exact identifiers ("error KB-4471", "v2.14.3") are unfindable.
7. **Embedding cost forgotten at re-index time.** Re-embedding 5M chunks isn't free in money or hours; design ingestion so you can re-embed incrementally and run two indexes during a migration.
8. **Similarity score thresholds copied from a blog.** Cosine 0.8 means nothing across models — calibrate thresholds on your own data, or use rank-based cutoffs instead.

---

## Open source to read

- **FAISS wiki** (github.com/facebookresearch/faiss/wiki) — "Guidelines to choose an index" is the single best page on the recall/memory/latency tradeoff. Read it.
- **pgvector README** (github.com/pgvector/pgvector) — short; the sections on index types (`ivfflat` vs `hnsw`), `maintenance_work_mem`, and filtering are directly interview-usable.
- **`sentence-transformers`** — read `SentenceTransformer.encode()`; note the pooling step that turns per-token vectors into one sentence vector (mean pooling vs CLS pooling).

---

## Exercises (tomorrow, ~45 minutes)

1. **Feel the space.** Embed 20 sentences from your corpus + 5 paraphrases + 5 negations ("enable X" / "disable X"). Print the similarity matrix. Confirm paraphrases score high — and that negations *also* score high. Write one sentence about what that means for retrieval.
2. **Model bake-off.** Same 20 queries against `all-MiniLM-L6-v2` and `bge-base-en-v1.5` (with the proper query prefix). Record which returns the right doc at rank 1. Then run `bge` *without* the prefix and measure how much you lose.
3. **Recall curve.** Run the FAISS script above on your real embedded corpus. Plot recall@10 vs `efSearch` vs latency. Keep the plot — it's a portfolio artifact.
4. **Truncation trap.** Embed a 3000-token chunk and its first 400 tokens. Compare the two vectors' similarity to a query answerable only from the *end* of the chunk. Explain the result.
5. **Filtered search.** In Chroma, add `{"source": ..., "section": ...}` metadata and run a query restricted to one source. Then make the filter so selective that post-filtering would return nothing, and observe the behaviour.

---

## Interview questions

1. What is an embedding, and how is the model trained? *(contrastive learning on (query, passage) pairs)*
2. Cosine vs dot product vs L2 — when does it matter? *(equivalent on normalized vectors; length bias otherwise)*
3. Explain HNSW to someone who knows skip lists. *(multi-layer proximity graph; upper layers are long-range hops; greedy descent; `ef_search` is the recall dial)*
4. 500M vectors, 32GB RAM. Options? *(IVF-PQ or binary quantization + rescoring; DiskANN; sharding; or reduce dims via Matryoshka)*
5. Semantic search misses exact error codes. Why, and what do you do? *(embeddings encode meaning not surface form; add BM25 + fuse with RRF)*
6. You want to upgrade the embedding model on a live system. Plan? *(dual-write/dual-index, backfill in background, version tag on every vector, shadow-evaluate on golden set, cut over, keep rollback)*
7. How do you enforce tenant isolation in a vector DB? *(namespace per tenant or index-level filtering + RLS; never post-filter for security)*
8. What's the max chunk size you'd embed, and why? *(model max sequence length — and below it, because quality degrades before the hard limit)*
9. Why might cosine 0.85 be a bad relevance threshold? *(uncalibrated across models/domains; score distributions differ; prefer relative ranking or a trained reranker)*

---

## Resources

- **FAISS "Guidelines to choose an index"** — https://github.com/facebookresearch/faiss/wiki/Guidelines-to-choose-an-index — the practical decision tree for ANN indexes.
- **MTEB paper / leaderboard** — https://huggingface.co/spaces/mteb/leaderboard — for model selection; read the paper's task taxonomy so you know what the numbers mean.
- Optional depth: **HNSW paper** (Malkov & Yashunin) — https://arxiv.org/abs/1603.09320 — skim figures 1–3 for the layer structure.
