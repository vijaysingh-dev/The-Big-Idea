# 04 — Chunking Strategies

This is the file you asked for most directly, and it's the right instinct: chunking is where the largest quality swings live for the least engineering effort, and it's the question interviewers use to separate people who read a tutorial from people who ran an experiment.

All implementations below share one interface so they drop straight into the capstone's registry.

---

## Mental model

Chunking exists because of a **conflict between two different consumers of the same text**:

| Consumer | Wants |
|----------|-------|
| The **embedding model / retriever** | Small, focused, single-topic text. One idea per vector. A vector averaging five topics is close to nothing |
| The **generator (LLM)** | Enough surrounding context to actually answer — definitions, preceding setup, the table header, the "it" that a sentence refers to |

Small chunks retrieve precisely but answer poorly. Large chunks answer well but retrieve vaguely (and blow your context budget).

**The key insight — and the best single thing you can say about chunking in an interview:**

> The retrieval unit and the generation unit don't have to be the same thing. Embed something small
> and specific; return something larger around it.

Every advanced strategy below (sentence-window, parent-document, auto-merging, late chunking, contextual retrieval) is a different way of exploiting that decoupling. Once you see that, the strategy zoo collapses into one idea with variations.

Second insight: **chunking is a lossy compression of document structure.** A document has a tree (doc → section → subsection → paragraph) and chunking flattens it into a list. Strategies that respect the tree beat strategies that ignore it, which is why "recursive" and "markdown-aware" outperform "every 500 characters".

---

## The common interface

```python
# raglab/ingest/base.py
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

import tiktoken

TOKENIZER = tiktoken.get_encoding("cl100k_base")


def ntokens(text: str) -> int:
    return len(TOKENIZER.encode(text))


@dataclass
class Chunk:
    id: str
    embed_text: str                    # what goes into the embedding model
    context_text: str                  # what goes into the LLM prompt (may be larger)
    doc_id: str
    meta: dict = field(default_factory=dict)

    @classmethod
    def simple(cls, doc_id: str, i: int, text: str, **meta) -> "Chunk":
        return cls(id=f"{doc_id}::{i}", embed_text=text, context_text=text,
                   doc_id=doc_id, meta=meta)


class Chunker(Protocol):
    name: str
    def split(self, doc_id: str, text: str) -> list[Chunk]: ...


REGISTRY: dict[str, Chunker] = {}


def register(chunker: Chunker) -> Chunker:
    REGISTRY[chunker.name] = chunker
    return chunker
```

Two fields — `embed_text` and `context_text` — is the whole architectural trick. Most tutorial code has one field and therefore structurally cannot express half the strategies below.

---

## Strategy 1 — Fixed-size (token) chunking

Split every N tokens with O tokens of overlap. The baseline everything is measured against.

```python
class FixedTokenChunker:
    def __init__(self, size: int = 400, overlap: int = 50):
        self.size, self.overlap = size, overlap
        self.name = f"fixed_{size}_{overlap}"

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        ids = TOKENIZER.encode(text)
        step = self.size - self.overlap
        chunks = []
        for i, start in enumerate(range(0, len(ids), step)):
            window = ids[start : start + self.size]
            if not window:
                break
            chunks.append(Chunk.simple(doc_id, i, TOKENIZER.decode(window), start_token=start))
        return chunks
```

**Why overlap exists:** a fact sitting exactly on a boundary would otherwise be split in half and appear in neither chunk coherently. Overlap of 10–20% is the usual insurance premium. The cost is duplication: 20% overlap means ~20% more vectors, more storage, and near-duplicate results crowding your top-k.

- **Pros:** trivial, predictable sizes, fast, perfectly uniform for benchmarking.
- **Cons:** cuts mid-sentence, mid-table, mid-code-block. Ignores all structure.
- **Use when:** you need a control group, or the text genuinely has no structure (transcripts, OCR sludge, chat logs).

---

## Strategy 2 — Recursive character/token splitting

The pragmatic default, and what LangChain popularized. Try to split on the most semantic separator available; if the piece is still too big, recurse to a weaker separator.

Separator ladder: `["\n\n", "\n", ". ", " ", ""]` — paragraphs, then lines, then sentences, then words, then raw characters as a last resort.

```python
class RecursiveChunker:
    def __init__(self, size: int = 400, overlap: int = 50,
                 separators: list[str] | None = None):
        self.size, self.overlap = size, overlap
        self.separators = separators or ["\n\n", "\n", ". ", " ", ""]
        self.name = f"recursive_{size}_{overlap}"

    def _split(self, text: str, seps: list[str]) -> list[str]:
        if ntokens(text) <= self.size:
            return [text]
        if not seps:
            ids = TOKENIZER.encode(text)
            return [TOKENIZER.decode(ids[i : i + self.size])
                    for i in range(0, len(ids), self.size)]

        sep, rest = seps[0], seps[1:]
        parts = text.split(sep) if sep else list(text)

        # Greedily merge neighbouring parts up to the size limit, recursing only into oversized ones.
        out, buf = [], ""
        for part in parts:
            candidate = f"{buf}{sep}{part}" if buf else part
            if ntokens(candidate) <= self.size:
                buf = candidate
            else:
                if buf:
                    out.append(buf)
                buf = part if ntokens(part) <= self.size else ""
                if not buf:
                    out.extend(self._split(part, rest))
        if buf:
            out.append(buf)
        return out

    def _add_overlap(self, pieces: list[str]) -> list[str]:
        if self.overlap <= 0:
            return pieces
        out = []
        for i, piece in enumerate(pieces):
            if i == 0:
                out.append(piece)
                continue
            tail = TOKENIZER.decode(TOKENIZER.encode(pieces[i - 1])[-self.overlap :])
            out.append(f"{tail} {piece}")
        return out

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        pieces = self._add_overlap([p for p in self._split(text, self.separators) if p.strip()])
        return [Chunk.simple(doc_id, i, p) for i, p in enumerate(pieces)]
```

- **Pros:** respects natural boundaries most of the time; near-zero cost; good default.
- **Cons:** still structure-blind for markdown headings, tables, code; sizes vary.
- **Use when:** you need one default for mixed prose. This is the correct answer to "what would you start with?" — start here, then measure whether anything beats it.

---

## Strategy 3 — Document-structure-aware (markdown / HTML)

Split on the document's own hierarchy, and **carry the heading path into every chunk**. This is the highest value-per-line-of-code change in this entire file.

```python
import re


class MarkdownChunker:
    """Splits on headings and prefixes each chunk with its heading path."""

    name = "markdown_structural"
    HEADING = re.compile(r"^(#{1,6})\s+(.*)$", re.MULTILINE)

    def __init__(self, max_size: int = 600, overlap: int = 50):
        self.max_size = max_size
        self.fallback = RecursiveChunker(max_size, overlap)

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        matches = list(self.HEADING.finditer(text))
        sections, path = [], {}

        for i, m in enumerate(matches):
            level, title = len(m.group(1)), m.group(2).strip()
            path = {k: v for k, v in path.items() if k < level}
            path[level] = title
            end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
            body = text[m.end() : end].strip()
            if body:
                sections.append((" > ".join(path[k] for k in sorted(path)), body))

        chunks = []
        for heading_path, body in sections:
            pieces = ([body] if ntokens(body) <= self.max_size
                      else [c.embed_text for c in self.fallback.split(doc_id, body)])
            for piece in pieces:
                header = f"{doc_id} > {heading_path}"
                chunks.append(Chunk(
                    id=f"{doc_id}::{len(chunks)}",
                    embed_text=f"{header}\n\n{piece}",     # header is embedded, not just stored
                    context_text=f"[{header}]\n{piece}",
                    doc_id=doc_id,
                    meta={"heading_path": heading_path},
                ))
        return chunks
```

Why prefixing the heading path into `embed_text` matters so much: a chunk that reads *"Set this to false to skip validation."* is unretrievable on its own — no query will be near it. The same chunk embedded as *"api-reference.md > Configuration > strict_mode — Set this to false to skip validation."* is retrievable by dozens of realistic queries. This is called a **contextual chunk header**, and it typically buys more recall than switching embedding models.

---

## Strategy 4 — Sentence-window retrieval

**Embed one sentence. Return that sentence plus its k neighbours.** The purest expression of decoupling retrieval from generation.

```python
class SentenceWindowChunker:
    def __init__(self, window: int = 3):
        self.window = window
        self.name = f"sentence_window_{window}"

    @staticmethod
    def _sentences(text: str) -> list[str]:
        # Good enough for English prose; use spaCy or pysbd if abbreviations bite.
        return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        sents = self._sentences(text)
        chunks = []
        for i, sent in enumerate(sents):
            lo, hi = max(0, i - self.window), min(len(sents), i + self.window + 1)
            chunks.append(Chunk(
                id=f"{doc_id}::s{i}",
                embed_text=sent,
                context_text=" ".join(sents[lo:hi]),
                doc_id=doc_id,
                meta={"sentence_index": i},
            ))
        return chunks
```

- **Pros:** excellent precision — the vector represents exactly one claim; the generator still gets surrounding context.
- **Cons:** many more vectors (one per sentence: 3–10× storage and embedding cost); adjacent sentences retrieve near-duplicate windows, so you need **deduplication/merging** of overlapping windows before building the prompt.
- **Use when:** dense factual documents — policies, specs, legal, medical, API docs.

---

## Strategy 5 — Parent-document / small-to-big / auto-merging

Same idea, one level up: chunk twice. Embed the **child** (small); return the **parent** (the section or page it belongs to).

```python
class ParentDocumentChunker:
    def __init__(self, parent_size: int = 1500, child_size: int = 250):
        self.parent = RecursiveChunker(parent_size, overlap=0)
        self.child = RecursiveChunker(child_size, overlap=0)
        self.name = f"parent_{parent_size}_{child_size}"

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        chunks = []
        for p_i, parent in enumerate(self.parent.split(doc_id, text)):
            for c_i, child in enumerate(self.child.split(doc_id, parent.embed_text)):
                chunks.append(Chunk(
                    id=f"{doc_id}::p{p_i}c{c_i}",
                    embed_text=child.embed_text,
                    context_text=parent.embed_text,
                    doc_id=doc_id,
                    meta={"parent_id": f"{doc_id}::p{p_i}"},
                ))
        return chunks
```

At query time you must **deduplicate by `parent_id`** — five children of the same parent will each pull in the identical 1500-token parent and destroy your context budget. That deduplication step is the detail interviewers listen for.

**Auto-merging** (LlamaIndex) is the adaptive version: build a real hierarchy (2048 → 512 → 128), and if enough sibling leaf chunks are retrieved, replace them with their parent. You get small chunks for narrow questions and large ones for broad questions, automatically.

- **Use when:** documents have coherent sections and answers need surrounding setup.
- **Cost:** highest context consumption per answer — watch the token bill (file 07).

---

## Strategy 6 — Semantic chunking

Split where the *meaning* changes, not where the character count runs out. Embed each sentence, measure cosine distance between consecutive sentences, and cut at the peaks.

```python
import numpy as np
from sentence_transformers import SentenceTransformer

_encoder = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")


class SemanticChunker:
    def __init__(self, percentile: int = 95, buffer: int = 1, max_size: int = 800):
        self.percentile, self.buffer, self.max_size = percentile, buffer, max_size
        self.name = f"semantic_p{percentile}"

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        sents = SentenceWindowChunker._sentences(text)
        if len(sents) < 4:
            return [Chunk.simple(doc_id, 0, text)]

        # Each sentence is embedded together with its neighbours so a single short sentence
        # doesn't register as a topic shift on its own.
        combined = [" ".join(sents[max(0, i - self.buffer) : i + self.buffer + 1])
                    for i in range(len(sents))]
        vecs = _encoder.encode(combined, normalize_embeddings=True)
        distances = 1 - np.sum(vecs[:-1] * vecs[1:], axis=1)

        threshold = np.percentile(distances, self.percentile)
        breakpoints = [i + 1 for i, d in enumerate(distances) if d > threshold]

        chunks, start = [], 0
        for end in breakpoints + [len(sents)]:
            body = " ".join(sents[start:end])
            if ntokens(body) > self.max_size:
                for piece in RecursiveChunker(self.max_size, 0).split(doc_id, body):
                    chunks.append(Chunk.simple(doc_id, len(chunks), piece.embed_text))
            elif body.strip():
                chunks.append(Chunk.simple(doc_id, len(chunks), body))
            start = end
        return chunks
```

- **Pros:** boundaries land where topics actually change; chunks are internally coherent.
- **Cons:** **expensive** — you embed every sentence at ingest time just to decide where to cut, then embed the chunks again. Non-deterministic sizes. The `percentile` threshold is a hyperparameter you must tune per corpus. And in published comparisons it frequently **fails to beat recursive chunking** by enough to justify the cost.
- **Interview value:** high. Saying *"I benchmarked semantic chunking; it cost 8× more at ingest and gained 2 points of recall on our corpus, so we kept recursive with structural headers"* is a far stronger answer than praising it.

---

## Strategy 7 — Contextual retrieval (LLM-generated chunk context)

Anthropic's 2024 technique, and currently the strongest simple win available. For each chunk, make a cheap LLM call that writes 1–2 sentences situating that chunk inside its document, and prepend that to the text before embedding.

```python
CONTEXT_PROMPT = """<document>
{document}
</document>

Here is a chunk from that document:
<chunk>
{chunk}
</chunk>

Give a short (1-2 sentence) context that situates this chunk within the overall document, so it can
be retrieved on its own. Answer with the context only."""


class ContextualChunker:
    """Wraps any chunker and enriches each chunk with LLM-written situating context."""

    def __init__(self, base: Chunker, llm_fn, doc_char_limit: int = 40_000):
        self.base, self.llm_fn, self.limit = base, llm_fn, doc_char_limit
        self.name = f"contextual_{base.name}"

    def split(self, doc_id: str, text: str) -> list[Chunk]:
        chunks = self.base.split(doc_id, text)
        doc = text[: self.limit]
        for c in chunks:
            situating = self.llm_fn(CONTEXT_PROMPT.format(document=doc, chunk=c.embed_text))
            c.embed_text = f"{situating.strip()}\n\n{c.embed_text}"
            c.meta["situating_context"] = situating.strip()
        return chunks
```

The reason this is affordable: the document goes in the **static prefix** of the prompt, so with prompt caching you pay ~10% for those tokens on every chunk after the first. Anthropic reported it cut retrieval failures substantially, and combining it with BM25 and reranking cut them further.

Cheap approximation with no LLM at all: the heading-path prefix in Strategy 3. Do that first, then measure whether the LLM version adds enough to justify the ingest cost.

---

## Strategy 8 — Late chunking (advanced, worth knowing by name)

Normal pipeline: chunk the text → embed each chunk independently. Each chunk's vector knows nothing about the rest of the document, so pronouns and implicit references are lost.

**Late chunking** inverts the order: run the *whole document* through a long-context embedding model once to get **token-level** embeddings (each token's vector is now contextualized by the entire document via attention), *then* mean-pool those token vectors into chunk vectors.

```python
# Sketch — requires a long-context embedding model, e.g. jinaai/jina-embeddings-v2-base-en (8192 tokens)
import torch
from transformers import AutoModel, AutoTokenizer

tok = AutoTokenizer.from_pretrained("jinaai/jina-embeddings-v2-base-en", trust_remote_code=True)
mdl = AutoModel.from_pretrained("jinaai/jina-embeddings-v2-base-en", trust_remote_code=True)

def late_chunk_embeddings(document: str, spans: list[tuple[int, int]]):
    """spans: (start_token, end_token) pairs describing chunk boundaries."""
    enc = tok(document, return_tensors="pt", truncation=True, max_length=8192)
    with torch.no_grad():
        token_vecs = mdl(**enc).last_hidden_state[0]        # (n_tokens, dim), document-contextualized

    out = []
    for start, end in spans:
        pooled = token_vecs[start:end].mean(dim=0)
        out.append(torch.nn.functional.normalize(pooled, dim=0).numpy())
    return out
```

- **Pros:** chunk vectors carry document context "for free"; strong gains on documents full of coreference ("the company", "this parameter", "as described above").
- **Cons:** requires a long-context embedding model; documents longer than the model's window need overlapping passes; more compute at ingest.
- **Use when:** you've exhausted the cheaper wins and your corpus is reference-heavy prose.

---

## Sizing guidance

| Content type | Strategy | Size | Why |
|---|---|---|---|
| Technical docs / markdown | Structural + recursive | 300–600 tok | Headings are real semantic boundaries |
| Policy / legal / medical | Sentence-window or parent-doc | 100–200 embed, 800+ context | Precision matters; single clauses are the atoms |
| Code | Syntax-aware (function/class level) | one unit per chunk | Never split a function; embed the signature + docstring |
| Chat / support transcripts | Turn-based or topic-segmented | 5–15 turns | Speaker turns are the natural unit |
| Tables / spreadsheets | Row-group with header repeated | keep header in every chunk | A headerless row fragment is meaningless |
| PDFs with layout | Layout-aware parse first, then structural | — | Fix stage 1 before tuning stage 2 |
| Transcripts / OCR | Fixed or semantic | 400–800 tok | No usable structure to exploit |

Overall default to state in an interview: **recursive, 400–600 tokens, 10–15% overlap, with the document title and heading path prefixed to every chunk** — then measure alternatives against it.

---

## Pitfalls

1. **Chunk exceeds the embedding model's max sequence length** → silent truncation. Assert on it.
2. **No metadata on chunks.** You need `doc_id`, `source_uri`, `heading_path`, `page`, `created_at`, `tenant_id`, `chunker_name`, `embed_model_version` — for filtering, for citations that link back to the exact page, for access control, and for debugging.
3. **Tables destroyed by naive splitting.** Row 47 without the header column names is noise. Extract tables separately, keep the header with every row group, and consider storing a text summary of the table for retrieval while returning the actual table for generation.
4. **Code split mid-function.** Use a syntax-aware splitter (tree-sitter, or LangChain's language-specific splitter) — you already know why a half-function is useless.
5. **Overlap too large** → near-duplicate chunks crowd the top-k, so 5 results contain 2 distinct facts. Deduplicate results by content hash or use MMR (file 05).
6. **Changing chunking without re-indexing.** Chunker identity is part of your index version, same as the embedding model.
7. **Chunk ids not stable across re-ingestion.** If ids change on every run, incremental updates, caches, and citation links all break. Derive ids from `(doc_id, content_hash)` rather than position where you can.
8. **Optimizing chunking before fixing parsing.** If your PDF extractor is producing column-jumbled text, no chunking strategy will save you. Print raw extracted text for 5 documents and read it with your own eyes before touching anything else.

---

## The chunking experiment harness (build this tomorrow)

This is the heart of your capstone, and it's less code than it sounds.

```python
# raglab/experiments/chunk_sweep.py
import time

CHUNKERS = [
    FixedTokenChunker(400, 0),
    FixedTokenChunker(400, 50),
    RecursiveChunker(400, 50),
    RecursiveChunker(800, 100),
    MarkdownChunker(600, 50),
    SentenceWindowChunker(3),
    ParentDocumentChunker(1500, 250),
    SemanticChunker(95),
]

def sweep(docs, golden, k=5):
    rows = []
    for chunker in CHUNKERS:
        t0 = time.time()
        chunks = [c for doc_id, text in docs for c in chunker.split(doc_id, text)]
        index = VectorIndex(chunks)
        ingest_s = time.time() - t0

        hits = 0
        for question, answer_substring in golden:
            retrieved = index.search(question, k=k)
            # A hit means the ground-truth answer text appears in what we returned to the model.
            if any(answer_substring.lower() in c.context_text.lower() for c, _ in retrieved):
                hits += 1

        rows.append({
            "strategy": chunker.name,
            "chunks": len(chunks),
            "avg_tokens": sum(ntokens(c.embed_text) for c in chunks) / len(chunks),
            "ingest_s": round(ingest_s, 1),
            f"recall@{k}": round(hits / len(golden), 3),
        })
    return rows
```

Your golden set can start as 30–40 `(question, answer_substring)` pairs. Generate a first draft by asking an LLM to produce questions from random chunks, then **hand-check every one** — an unverified golden set is worse than none. File 06 turns this into proper metrics (MRR, nDCG, faithfulness).

---

## Open source to read

- **`chunking_evaluation`** (github.com/brandonstarxel/chunking_evaluation) — Chroma's research framework for exactly this experiment, with token-level precision/recall metrics. Read their metric definitions; they're more rigorous than substring matching.
- **LlamaIndex node parsers** — `llama_index/core/node_parser/` — `SentenceWindowNodeParser`, `HierarchicalNodeParser`, `SemanticSplitterNodeParser`. Compare their implementations to yours above; the differences are instructive.
- **LangChain text splitters** — `libs/text-splitters/` — especially the language-specific separators for code splitting.

---

## Exercises (tomorrow, ~150 minutes — this *is* the capstone's first half)

1. **Implement all six core chunkers** against the `Chunker` interface above. Copy the code, then modify: change the separator ladder, change the window size, break something and see what happens.
2. **Print the chunks.** For one document, dump the first 10 chunks from each strategy side by side and read them. Half your intuition will come from this alone.
3. **Build the golden set** — 30–40 question/answer-substring pairs from your corpus. Hand-verify.
4. **Run the sweep.** Produce the table. Write down the winner and the *cost* of winning (ingest time, chunk count, average context tokens per query).
5. **Add the heading-path prefix** to your best strategy and re-run. Measure the delta. This is usually the biggest single-line improvement you'll find all day.
6. **Break the tie fairly:** hold chunk count roughly constant across strategies, so you're not just measuring "more chunks = more recall". This is the experimental-design trap, and noticing it is exactly the kind of rigour that gets remembered in an interview.
7. **Optional, high value:** implement `ContextualChunker` over 5 documents only (to control cost) and measure the delta on questions touching those documents.

---

## Interview questions

1. How do you choose a chunk size? *(driven by content type + embedding model max length + eval; default recursive 400–600 with 10–15% overlap, then measure)*
2. Why overlap, and what does it cost? *(boundary insurance; duplication, near-duplicate top-k)*
3. What's sentence-window retrieval? *(embed a sentence, return neighbours — decoupling retrieval unit from generation unit)*
4. Parent-document retrieval — what's the gotcha? *(deduplicate by parent id or you blow the context budget)*
5. Is semantic chunking worth it? *(sometimes; expensive at ingest, often doesn't beat recursive — answer with your measured numbers)*
6. How do you chunk code? Tables? PDFs? *(syntax-aware; header-preserving row groups; fix layout parsing first)*
7. What metadata do you attach and why? *(filtering, citations, access control, versioning, debugging)*
8. You changed the chunker on a live system. What's the deployment plan? *(new index version, dual-index, shadow-eval on golden set, cut over, keep rollback — same as any schema migration)*
9. What is contextual retrieval? *(LLM-written situating context prepended before embedding; made affordable by prompt caching)*
10. How would you prove one chunking strategy beats another? *(golden set, recall@k and MRR, hold chunk count constant, report ingest cost and context cost alongside quality, check statistical stability across question subsets)*

---

## Resources

- **Chroma, "Evaluating Chunking Strategies for Retrieval"** — https://research.trychroma.com/evaluating-chunking — the most rigorous public study of this exact question, with the token-level metrics your sweep should eventually adopt.
- **Anthropic, "Introducing Contextual Retrieval"** — https://www.anthropic.com/news/contextual-retrieval — the contextual-chunk technique with measured results and cost analysis.
- Optional depth: **Jina AI, "Late Chunking"** — https://arxiv.org/abs/2409.04701 — for the strategy 8 mechanism.
