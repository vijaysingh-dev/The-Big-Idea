# 03 — The Baseline RAG Pipeline

Build it once by hand, with no framework. Everything after this file is an optimization of one of these eight stages, and being able to name the stage a problem lives in is most of what "senior" looks like in a GenAI interview.

---

## Mental model

RAG is **search + prompt templating**. That's the honest description.

```
                 INGESTION (offline, batch)
  raw docs ──▶ load ──▶ chunk ──▶ embed ──▶ index
                                             │
                 QUERY (online, per request) │
  question ──▶ transform ──▶ retrieve ◀──────┘
                              │
                              ▼
                          rerank ──▶ assemble prompt ──▶ generate ──▶ (cite / verify)
```

Eight stages. Say them in this order in an interview and you've already outperformed the "embed, search, ask" answer:

| # | Stage | Owns | Typical failure |
|---|-------|------|-----------------|
| 1 | **Load / parse** | PDF→text, HTML→text, tables, OCR | Garbage in: broken PDF extraction silently poisons everything downstream |
| 2 | **Chunk** | Splitting into retrievable units | Chunks cut mid-idea; answer split across two chunks; no metadata |
| 3 | **Embed** | Text → vectors | Wrong model, missing prefix, truncation past max seq length |
| 4 | **Index** | Storage + ANN + metadata | No filtering, no versioning, stale index |
| 5 | **Query transform** | Rewriting the user's question | Ambiguous follow-ups ("and the second one?") retrieve nothing |
| 6 | **Retrieve** | Candidate generation | Recall miss — the answer chunk is never fetched. **Most common root cause** |
| 7 | **Rerank / select** | Precision + context budget | Top-20 stuffed in; the right chunk is at rank 14 and gets ignored |
| 8 | **Generate** | Answer + citations | Hallucination, ignoring context, no escape hatch |

The single most useful diagnostic sentence: **"Is the answer present in the retrieved chunks?"** If no → stages 1–7. If yes → stage 8. Almost every RAG bug report resolves with that one check, and almost nobody does it because they don't log the retrieved chunks.

---

## The whole thing in ~120 lines

No LangChain, no LlamaIndex. This is the reference you'll refactor into the capstone.

```python
# baseline_rag.py
from __future__ import annotations

import glob
import os
import re
import textwrap
from dataclasses import dataclass, field

import numpy as np
import tiktoken
from openai import OpenAI
from sentence_transformers import SentenceTransformer

EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

encoder = SentenceTransformer(EMBED_MODEL)
tokenizer = tiktoken.get_encoding("cl100k_base")
llm = OpenAI(base_url=os.getenv("LLM_BASE_URL"), api_key=os.getenv("LLM_API_KEY"))


@dataclass
class Chunk:
    id: str
    text: str                      # what gets embedded and shown to the model
    doc_id: str
    meta: dict = field(default_factory=dict)


def load(directory: str) -> list[tuple[str, str]]:
    docs = []
    for path in glob.glob(f"{directory}/**/*.md", recursive=True):
        with open(path, encoding="utf-8") as f:
            docs.append((os.path.relpath(path, directory), f.read()))
    return docs


def chunk_fixed(doc_id: str, text: str, size: int = 400, overlap: int = 50) -> list[Chunk]:
    ids = tokenizer.encode(text)
    step = size - overlap
    out = []
    for i, start in enumerate(range(0, len(ids), step)):
        window = ids[start : start + size]
        if not window:
            break
        out.append(Chunk(id=f"{doc_id}::{i}", text=tokenizer.decode(window), doc_id=doc_id,
                         meta={"start_token": start}))
    return out


class VectorIndex:
    """Brute-force cosine index. Exact, and fast enough well past 100k chunks."""

    def __init__(self, chunks: list[Chunk]):
        self.chunks = chunks
        self.matrix = encoder.encode(
            [c.text for c in chunks], normalize_embeddings=True,
            batch_size=64, show_progress_bar=True,
        ).astype("float32")

    def search(self, query: str, k: int = 5) -> list[tuple[Chunk, float]]:
        q = encoder.encode([query], normalize_embeddings=True)[0].astype("float32")
        scores = self.matrix @ q
        top = np.argsort(-scores)[:k]
        return [(self.chunks[i], float(scores[i])) for i in top]


PROMPT = """Answer the question using ONLY the context below.
If the context does not contain the answer, reply exactly: NOT_FOUND.
Cite the chunk id in square brackets after each claim, e.g. [doc.md::3].

# Context
{context}

# Question
{question}

# Answer"""


def build_context(hits: list[tuple[Chunk, float]], budget_tokens: int = 2000) -> str:
    parts, used = [], 0
    for chunk, score in hits:
        block = f"[{chunk.id}] (score={score:.3f})\n{chunk.text}"
        cost = len(tokenizer.encode(block))
        if used + cost > budget_tokens:
            break
        parts.append(block)
        used += cost
    return "\n\n---\n\n".join(parts)


def answer(question: str, index: VectorIndex, k: int = 5) -> dict:
    hits = index.search(question, k=k)
    context = build_context(hits)
    prompt = PROMPT.format(context=context, question=question)

    response = llm.chat.completions.create(
        model=LLM_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0,
        max_tokens=500,
    )
    text = response.choices[0].message.content

    # Verifying that cited ids were actually retrieved catches the most common citation hallucination.
    retrieved_ids = {c.id for c, _ in hits}
    cited = set(re.findall(r"\[([^\]]+)\]", text))
    return {
        "answer": text,
        "retrieved": [(c.id, s) for c, s in hits],
        "invalid_citations": sorted(cited - retrieved_ids),
        "prompt_tokens": len(tokenizer.encode(prompt)),
    }


if __name__ == "__main__":
    chunks = [c for doc_id, body in load("data/raw") for c in chunk_fixed(doc_id, body)]
    print(f"{len(chunks)} chunks")
    index = VectorIndex(chunks)

    while True:
        q = input("\nquestion> ").strip()
        if not q:
            break
        result = answer(q, index)
        print(textwrap.fill(result["answer"], 100))
        print("\nretrieved:", result["retrieved"])
        if result["invalid_citations"]:
            print("!! hallucinated citations:", result["invalid_citations"])
```

That's a functioning RAG system. Roughly 90% of "RAG tutorials" stop here; the remaining 90% of the work is everything in files 04–07.

---

## Reading the code as a senior engineer would

Things this baseline gets *right*, which many production systems get wrong:

- **`temperature=0`** — extraction task, not a creative one.
- **An explicit escape hatch** (`NOT_FOUND`). Without it you're commanding the model to invent.
- **A token budget on context assembly**, not "top 5 and hope". Context assembly is a knapsack problem against a hard limit.
- **Citation verification** — the model can cite an id it never saw; checking is three lines.
- **Chunk ids are stable and human-readable** (`file::index`) so a bug report is debuggable.
- **Returning the retrieved set with the answer** — this is your entire observability story.

Things it gets wrong (deliberately — you'll fix them):

- Fixed-token chunking that cuts through sentences and tables (file 04).
- Dense-only retrieval, so exact identifiers and negations fail (file 05).
- No reranking, so precision at the top is mediocre (file 05).
- No query transformation, so conversational follow-ups break (file 05).
- No evaluation at all — you cannot tell if any change helped (file 06).
- Re-embeds the world on every run; no incremental ingestion, caching, or access control (file 07).

---

## Prompt design for RAG specifically

The generation prompt is small but every clause is load-bearing.

```
Answer the question using ONLY the context below.          ← scopes to context, reduces parametric recall
If the context does not contain the answer, reply          ← escape hatch: the single biggest
exactly: NOT_FOUND.                                          hallucination reducer in RAG
Cite the chunk id in square brackets.                      ← makes claims verifiable + auditable
Quote the relevant sentence before answering.              ← optional: forces grounding, costs tokens
If sources conflict, say so and cite both.                 ← conflict handling; otherwise it silently picks one
```

Ordering matters for two reasons: **prompt caching** wants the static text first (file 01), and **lost-in-the-middle** wants the question restated *after* the context, close to the generation point. A common trick is stating the question both before and after the context.

Chunk ordering inside the context is a real lever too: put the highest-scoring chunk **first or last**, not in the middle. Some teams interleave — best, third, fifth ... fourth, second — so the strongest evidence occupies both edges.

---

## Debugging methodology (this is an interview scenario, expect it)

> "Users say the chatbot gives wrong answers. Go."

Answer as a systematic bisection, not a list of guesses:

**Step 1 — Reproduce and capture.** Get 10 concrete failing questions with expected answers. If you can't get them, you're optimizing folklore.

**Step 2 — Split retrieval from generation.** For each failure, dump the retrieved chunks and ask: *is the answer text present?*

- **Not present → retrieval problem.** Continue to step 3.
- **Present but the answer is wrong → generation problem.** Go to step 5.

**Step 3 — Is the answer even in the index?** Grep the raw corpus for the expected answer string.

- **Not in the corpus** → an ingestion problem: the PDF parser dropped a table, the loader skipped the file, the doc was never crawled. Very common and completely invisible unless you check.
- **In the corpus but not in any chunk** → chunking destroyed it (split mid-table, or truncated past the embedding model's max sequence length).
- **In a chunk but not retrieved** → a ranking problem. Check: does BM25 find it? If keyword search finds it and dense doesn't, you need hybrid. Is it at rank 8 when you take top-5? Raise k and add a reranker.

**Step 4 — Is it retrieved but ranked badly?** Measure recall@20 vs recall@5. If recall@20 is high and recall@5 is low, that's precisely the reranker's job.

**Step 5 — Generation problems.** Check in this order: context window overflow (was the chunk truncated out of the prompt?), position (was it in the middle?), conflicting chunks, missing escape hatch, temperature > 0, an over-constrained output format squeezing out the answer.

**Step 6 — Only now change something, and measure it on the golden set** (file 06).

The "RAG triad" is a compact way to name where a failure sits:

- **Context relevance** — did retrieval fetch the right thing? (stages 1–7)
- **Groundedness / faithfulness** — is the answer supported by what was fetched? (stage 8)
- **Answer relevance** — does it actually address the question? (stage 8)

---

## What frameworks add (and when to use one)

| Framework | Real value | Cost |
|-----------|-----------|------|
| **LangChain** | Huge integration surface: loaders, splitters, stores, model adapters | Abstraction sprawl; debugging through layers |
| **LlamaIndex** | Best-in-class ingestion/indexing abstractions: node parsers, parent-child, query engines | Opinionated; heavy for simple needs |
| **Haystack** | Explicit pipeline DAG, production-oriented | Smaller ecosystem |
| **LangGraph** | Stateful graphs — the right tool for *agents*, not for plain RAG (file 09) | Learning curve |

The mature position, and a good thing to say: *"I use framework components where they save real work — document loaders and text splitters especially, since parsing 40 file formats is not a differentiator — but I keep the retrieval and prompting logic in my own code, because that's where quality lives and I need to see and instrument every step."*

---

## Open source to read

- **LangChain `RecursiveCharacterTextSplitter`** — `libs/text-splitters/langchain_text_splitters/character.py`. ~100 lines and you'll fully understand it after file 04. Read the actual separator recursion.
- **LlamaIndex `SentenceWindowNodeParser`** and `AutoMergingRetriever` — the cleanest reference implementations of decoupling "what you retrieve" from "what you send to the model".
- **Verba** (github.com/weaviate/Verba) — a complete, readable open-source RAG app. Skim `goldenverba/components/` to see how a real system organizes readers → chunkers → embedders → retrievers → generators. This structure is essentially what your capstone will be.

---

## Exercises (tomorrow, ~90 minutes — this is the core build)

1. **Type it in and run it.** Point it at 30–60 of your own documents. Ask 5 questions you know the answers to. Do not skip this: everything downstream is a refactor of this file.
2. **Break each stage on purpose and observe the symptom.** Set chunk size to 50 tokens; then 4000. Query with a synonym never used in the corpus. Ask a question whose answer spans two documents. Ask something not in the corpus at all — does it say `NOT_FOUND`, or invent?
3. **Remove the escape hatch** from the prompt and re-ask the unanswerable question. Record what it does. That contrast is a genuinely persuasive interview anecdote.
4. **Instrument it.** Log per query: retrieved ids + scores, prompt token count, latency split into embed / search / LLM, and answer length. You now have the observability most systems lack.
5. **Context position experiment.** Force the correct chunk to position 1, position 5, and the middle of 10. Does answer quality change? You've just reproduced lost-in-the-middle yourself.
6. **Refactor into modules** — `load / chunk / index / retrieve / generate` with clean interfaces. This becomes the capstone skeleton, so do it now rather than later.

---

## Interview questions

1. Walk me through a RAG system end to end. *(the eight stages, ingestion vs query path)*
2. Which stage do you suspect first when answers are wrong? *(retrieval; and the check is "is the answer in the retrieved chunks")*
3. How do you tell a retrieval failure from a generation failure? *(the bisection in step 2 above)*
4. What goes in the prompt besides the chunks? *(scope instruction, escape hatch, citation contract, conflict rule, question restated after context)*
5. How many chunks do you retrieve, and why? *(budget-driven; retrieve wide k=20–50, rerank down to 3–5; more context is not monotonically better)*
6. Why do users' follow-up questions fail? *("what about the second one?" has no standalone meaning — needs query rewriting against history; file 05)*
7. What's the RAG triad? *(context relevance, groundedness, answer relevance)*
8. When would you not build RAG? *(small corpus fits in context; the task is behavioural not knowledge-based; a SQL query or plain keyword search answers it — this is a maturity signal)*
9. What do you log per request in production? *(query, rewritten query, retrieved ids + scores, reranker scores, final prompt hash, token counts, latency per stage, model version, index version, user feedback)*
10. Your PDF-based bot can't answer questions about tables. Why? *(text extraction flattens tables into unusable token soup; the fix is a layout-aware parser and table-specific handling — file 04)*

---

## Resources

- **LlamaIndex "Building RAG from Scratch"** — https://docs.llamaindex.ai/en/stable/optimizing/building_rag_from_scratch/ — the framework docs that best explain the primitives independently of the framework.
- **Anthropic, "Introducing Contextual Retrieval"** — https://www.anthropic.com/news/contextual-retrieval — a genuinely well-measured engineering writeup of a baseline RAG pipeline and the specific changes that improved it, with numbers. Read it before your interview; it's exactly the kind of reasoning they want to hear.
