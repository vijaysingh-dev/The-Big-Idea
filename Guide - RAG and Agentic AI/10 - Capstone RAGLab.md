# 10 — Capstone RAGLab

One codebase where every component is swappable and one command produces a leaderboard. Build this tomorrow. It's the thing you'll actually talk about in the interview — not because it's impressive software, but because it produces **numbers you measured yourself**, and almost no candidate has any.

---

## The pitch (memorize a 45-second version)

> "I built a RAG experimentation harness. Chunkers, retrievers and rerankers are pluggable behind
> interfaces, experiments are declared in YAML, and one command runs a sweep and emits a leaderboard
> with recall@5, recall@50, MRR, faithfulness, ingest time, p95 latency and cost per thousand
> queries. I used it to compare six chunking strategies and three retrieval configurations on a
> corpus of my own documents. The headline result was [your number] — and the more interesting
> finding was [your surprise]."

That last clause matters most. Have a surprise ready. There will be one.

---

## Structure

```
raglab/
├── data/
│   ├── raw/                     your corpus
│   └── golden.jsonl             the evaluation set
├── raglab/
│   ├── ingest/
│   │   ├── base.py              Chunk, Chunker protocol, REGISTRY   (file 04)
│   │   ├── loaders.py           md / pdf / html → (doc_id, text)
│   │   └── chunkers.py          the six strategies                  (file 04)
│   ├── index/
│   │   ├── embedder.py          sentence-transformers wrapper + cache
│   │   └── store.py             VectorIndex (dense) + BM25Index
│   ├── retrieve/
│   │   ├── dense.py
│   │   ├── hybrid.py            BM25 + dense + RRF                  (file 05)
│   │   ├── rerank.py            cross-encoder                       (file 05)
│   │   └── mmr.py
│   ├── generate/
│   │   ├── llm.py               thin client wrapper                 (appendix)
│   │   └── answer.py            prompt assembly + citation checking (file 03)
│   ├── eval/
│   │   ├── retrieval.py         recall@k, MRR, nDCG                 (file 06)
│   │   ├── generation.py        faithfulness, judge                 (file 06)
│   │   └── golden.py            build / load / verify the golden set
│   ├── config.py                dataclass ← YAML
│   └── run.py                   the sweep runner
├── experiments/
│   ├── chunking_sweep.yaml
│   └── retrieval_sweep.yaml
└── results/
    └── results.csv              one row per (config, run)
```

---

## The config object — the spine of the whole thing

Every experiment is one of these. Everything else reads from it.

```python
# raglab/config.py
from dataclasses import dataclass, field, asdict
import hashlib, json


@dataclass
class RunConfig:
    name: str
    chunker: str = "recursive_400_50"
    embed_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    retriever: str = "dense"                 # dense | hybrid
    rerank: bool = False
    rerank_candidates: int = 50
    mmr: bool = False
    mmr_lambda: float = 0.6
    top_k: int = 5
    context_budget_tokens: int = 2000
    query_rewrite: bool = False
    llm_model: str = "gpt-4o-mini"
    generate: bool = True                    # False = retrieval-only, fast and free

    @property
    def index_version(self) -> str:
        key = json.dumps({"chunker": self.chunker, "embed": self.embed_model}, sort_keys=True)
        return hashlib.sha256(key.encode()).hexdigest()[:12]

    def as_row(self) -> dict:
        return asdict(self)
```

The `index_version` property is the piece that makes the sweep fast **and** teaches you the production lesson from file 07: two configs sharing a chunker and embedding model share an index, so you build each index once and reuse it across every retrieval variant.

---

## The runner

```python
# raglab/run.py
import time, yaml, pandas as pd
from pathlib import Path


INDEX_CACHE: dict[str, tuple] = {}


def build_index(cfg: RunConfig, docs):
    if cfg.index_version in INDEX_CACHE:
        return INDEX_CACHE[cfg.index_version] + (0.0,)

    chunker = CHUNKERS[cfg.chunker]
    t0 = time.time()
    chunks = [c for doc_id, text in docs for c in chunker.split(doc_id, text)]
    embedder = get_embedder(cfg.embed_model)
    dense = VectorIndex(chunks, embedder)
    sparse = BM25Index(chunks)
    ingest_s = time.time() - t0

    INDEX_CACHE[cfg.index_version] = (chunks, dense, sparse)
    return chunks, dense, sparse, ingest_s


def build_retriever(cfg, chunks, dense, sparse):
    base = HybridRetriever(dense, sparse) if cfg.retriever == "hybrid" else DenseRetriever(dense)
    if cfg.rerank:
        base = RerankingRetriever(base, candidates=cfg.rerank_candidates)
    if cfg.mmr:
        base = MMRRetriever(base, lam=cfg.mmr_lambda)
    return base


def run_one(cfg: RunConfig, docs, golden) -> dict:
    chunks, dense, sparse, ingest_s = build_index(cfg, docs)
    retriever = build_retriever(cfg, chunks, dense, sparse)

    latencies, retrieval_rows, gen_rows, cost = [], [], [], 0.0

    for ex in golden:
        t0 = time.time()
        query = rewrite_query(ex.question) if cfg.query_rewrite else ex.question
        hits = retriever.search(query, k=max(cfg.top_k, 50))
        retrieval_rows.append(retrieval_metrics(hits, ex, k=cfg.top_k))

        if cfg.generate:
            result = answer(ex.question, hits[: cfg.top_k], budget=cfg.context_budget_tokens)
            gen_rows.append(generation_metrics(ex, result))
            cost += result["cost_usd"]
        latencies.append((time.time() - t0) * 1000)

    return {
        **cfg.as_row(),
        "chunks": len(chunks),
        "avg_chunk_tokens": round(mean(ntokens(c.embed_text) for c in chunks), 1),
        "ingest_s": round(ingest_s, 1),
        **aggregate(retrieval_rows),
        **aggregate(gen_rows),
        "p50_ms": round(percentile(latencies, 50)),
        "p95_ms": round(percentile(latencies, 95)),
        "usd_per_1k": round(cost / len(golden) * 1000, 3),
        "timestamp": time.time(),
    }


def main(config_path: str):
    spec = yaml.safe_load(Path(config_path).read_text())
    docs = load_corpus("data/raw")
    golden = load_golden("data/golden.jsonl")

    rows = [run_one(RunConfig(**variant), docs, golden) for variant in spec["runs"]]

    df = pd.DataFrame(rows)
    out = Path("results/results.csv")
    df.to_csv(out, mode="a", header=not out.exists(), index=False)
    print(df[["name", "chunks", "ingest_s", "recall@5", "recall@50", "mrr",
              "faithfulness", "p95_ms", "usd_per_1k"]].to_string(index=False))
```

Appending to a single `results.csv` (rather than overwriting) means you accumulate a real experiment log across the day. That file is a portfolio artifact — bring it up in the interview.

---

## The experiment configs

```yaml
# experiments/chunking_sweep.yaml
runs:
  - {name: fixed_400,        chunker: fixed_400_0,        generate: false}
  - {name: fixed_400_ov50,   chunker: fixed_400_50,       generate: false}
  - {name: recursive_400,    chunker: recursive_400_50,   generate: false}
  - {name: recursive_800,    chunker: recursive_800_100,  generate: false}
  - {name: markdown,         chunker: markdown_structural, generate: false}
  - {name: sentence_window,  chunker: sentence_window_3,  generate: false}
  - {name: parent_doc,       chunker: parent_1500_250,    generate: false}
  - {name: semantic,         chunker: semantic_p95,       generate: false}
```

`generate: false` makes this sweep pure retrieval — fast, free, deterministic. Run it repeatedly while iterating, then turn generation on once for the winners.

```yaml
# experiments/retrieval_sweep.yaml — fix the chunker, vary retrieval
runs:
  - {name: dense,               chunker: recursive_400_50, retriever: dense}
  - {name: hybrid,              chunker: recursive_400_50, retriever: hybrid}
  - {name: hybrid_rerank,       chunker: recursive_400_50, retriever: hybrid, rerank: true}
  - {name: hybrid_rerank_mmr,   chunker: recursive_400_50, retriever: hybrid, rerank: true, mmr: true}
  - {name: hybrid_rerank_k3,    chunker: recursive_400_50, retriever: hybrid, rerank: true, top_k: 3}
  - {name: hybrid_rerank_k10,   chunker: recursive_400_50, retriever: hybrid, rerank: true, top_k: 10}
```

**Change one variable at a time.** The `top_k` rows in particular usually produce a counterintuitive result worth talking about.

---

## Build order (tomorrow, realistically 5–6 hours)

| Step | Time | Deliverable |
|---|---|---|
| 1. Refactor the baseline from file 03 into the package layout | 45 min | `load / chunk / index / retrieve / generate` as modules |
| 2. Golden set — 40 examples, hand-verified, incl. 5 unanswerable | 60 min | `data/golden.jsonl` |
| 3. Retrieval metrics + the runner + `results.csv` | 45 min | `python -m raglab.run --config ...` works |
| 4. All six chunkers | 60 min | chunking leaderboard printed |
| 5. BM25 + RRF + cross-encoder reranker | 60 min | retrieval leaderboard printed |
| 6. Faithfulness + judge, generation on for the top 3 configs | 45 min | full table with quality *and* cost |
| 7. The 60-line agent from file 08 pointed at the best retriever | 45 min | agentic vs plain comparison |

If you run out of time, steps 1–5 are the ones that matter. Generation metrics are the first thing to cut; the retrieval story is the stronger interview material anyway.

---

## Analysis to do once it runs (this is the actual value)

Don't just print the table — interrogate it. Write your answers down in a `FINDINGS.md`.

1. **Which strategy won on recall@5, and what did winning cost?** (ingest time, chunk count, context tokens per query)
2. **Is the winner actually different from second place?** Re-run twice; if the gap is inside the run-to-run variance, say "they're equivalent on my data" — that's the honest and more impressive answer.
3. **Did more chunks cause the win?** Sentence-window produces 3× more units. Re-check with chunk count roughly controlled.
4. **Where's your recall ceiling?** recall@50 caps what any reranker can do. If it's 0.75, 25% of your questions are unanswerable by your current ingestion, full stop.
5. **Which questions does every config fail?** Read them. Those failures cluster, and the cluster tells you what to fix — usually parsing, or a question type your chunker destroys (tables).
6. **Did the reranker help, and by how much per millisecond?** Quality per unit latency is the real currency.
7. **Does top_k=10 beat top_k=3?** Often it doesn't — more context, worse answers. If you reproduce that, you have a memorable finding.
8. **Refusal rate on the 5 unanswerable questions.** That's your hallucination rate.

---

## Stretch goals (only if you're ahead)

- **Contextual chunking** (file 04, strategy 7) on a 5-document subset — measure the delta.
- **A second embedding model** — same chunker, different embedder, straight comparison.
- **Streamlit UI**: query box, answer, retrieved chunks with scores, config switcher. Twenty minutes with `st.dataframe` and it makes the project demo-able in a screen share.
- **Corrective RAG graph** (file 09) as another "retriever" in the sweep.
- **A `pytest` regression gate** with thresholds from file 06 — shows you think in CI terms.

---

## What to say about it in the interview

Three things, in this order:

1. **The result**, with numbers and units. "Hybrid + cross-encoder reranking took recall@5 from 0.61 to 0.79 on 40 questions, for +110ms p95."
2. **The surprise.** "Semantic chunking cost 8× more at ingest and didn't beat recursive with heading prefixes." Or "top_k=10 was worse than top_k=3." Surprises prove you measured rather than repeated.
3. **The limitation, volunteered.** "40 questions is a small sample; I re-ran configs to estimate variance and treated anything under ~3 points as noise. With more time I'd mine real user queries, because synthetic questions use the document's own vocabulary and make retrieval look easier than it is."

Point 3 is the one that gets you hired. Stating the limits of your own evidence, unprompted, is the clearest available signal of engineering maturity — and it preempts the exact follow-up a good interviewer was about to ask.
