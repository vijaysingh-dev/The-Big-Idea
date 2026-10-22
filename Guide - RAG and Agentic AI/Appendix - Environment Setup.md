# Appendix — Environment Setup

Goal: tomorrow you write code, not `pip install` incantations.

## 1. Python environment

```bash
# uv is a fast Python package manager (drop-in replacement for pip/venv, ~10x faster installs)
curl -LsSf https://astral.sh/uv/install.sh | sh

mkdir raglab && cd raglab
uv venv --python 3.11
source .venv/bin/activate
```

Python 3.11 specifically: some ML wheels still lag on 3.13.

## 2. Packages

```bash
uv pip install \
  sentence-transformers \
  faiss-cpu \
  chromadb \
  rank-bm25 \
  tiktoken \
  langchain-text-splitters \
  pypdf \
  numpy pandas scikit-learn \
  pydantic \
  openai \
  ragas datasets \
  rich pyyaml tqdm
```

What each one is for:

| Package | Role |
|---------|------|
| `sentence-transformers` | Loads embedding models locally (no API cost) |
| `faiss-cpu` | Meta's vector similarity library — brute force and ANN indexes |
| `chromadb` | Small embedded vector DB with metadata filtering — good for the capstone |
| `rank-bm25` | Classic keyword/lexical search, needed for hybrid retrieval |
| `tiktoken` | OpenAI's tokenizer — for counting tokens exactly |
| `langchain-text-splitters` | Reference implementations of chunkers you'll read and reimplement |
| `ragas` | RAG evaluation metrics (faithfulness, answer relevancy, context precision/recall) |
| `openai` | Client library; also speaks to any OpenAI-compatible endpoint, including local ones |

## 3. Models

### Embeddings (local, free, required)

```python
from sentence_transformers import SentenceTransformer

# ~130MB, 384 dims, fast on CPU. Good default for learning.
m = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
print(m.encode(["warm up the cache"]).shape)   # (1, 384)
```

Also pull a stronger one to compare later (~440MB, 768 dims):

```python
SentenceTransformer("BAAI/bge-base-en-v1.5")
```

And a **cross-encoder** for reranking (file 05):

```python
from sentence_transformers import CrossEncoder
CrossEncoder("cross-encoder/ms-marco-MiniLM-L-6-v2")
```

Run those three lines tonight so the downloads are cached.

### Generation (pick one)

**Option A — API key (simplest).** Any provider with an OpenAI-compatible endpoint. Budget: the whole capstone is a few hundred short calls; well under $2 on a cheap model.

**Option B — fully local, zero cost.** [Ollama](https://ollama.com):

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull qwen2.5:7b-instruct     # ~4.7GB, needs ~8GB RAM
ollama pull llama3.2:3b             # ~2GB fallback for weaker machines
```

Ollama exposes an OpenAI-compatible API at `http://localhost:11434/v1`, so the same client code works:

```python
from openai import OpenAI
client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")
```

Write your code against **one thin LLM wrapper** so the backend is swappable:

```python
# raglab/generate/llm.py
import os
from openai import OpenAI

_client = OpenAI(
    base_url=os.getenv("LLM_BASE_URL", "https://api.openai.com/v1"),
    api_key=os.getenv("LLM_API_KEY", "not-needed-for-local"),
)

def complete(prompt: str, system: str = "", model: str | None = None, temperature: float = 0.0) -> str:
    messages = ([{"role": "system", "content": system}] if system else []) + \
               [{"role": "user", "content": prompt}]
    resp = _client.chat.completions.create(
        model=model or os.getenv("LLM_MODEL", "gpt-4o-mini"),
        messages=messages,
        temperature=temperature,
    )
    return resp.choices[0].message.content
```

This wrapper is also the natural place to later add retries, timeouts, token accounting and caching — mention that in an interview and you sound like you've operated one of these.

## 4. Corpus for the capstone

You need a document set with real structure. Best options, in order:

1. **Your own domain** — download 30–60 PDFs/markdown files from a public technical docs site you know (e.g. Postgres docs, Kubernetes docs, a company's public handbook). Familiarity means you can judge whether an answer is actually right.
2. **A single long book/manual** in PDF — tests chunking harder because sections are nested.
3. **A mixed bag**: markdown + PDF + HTML, which forces you to deal with loaders and metadata.

Put them in `data/raw/`. Aim for 200–2000 pages total. Not 5 files (everything works) and not 50k (ingestion becomes the bottleneck of your learning).

## 5. Sanity check script

```python
# scripts/smoke.py
from sentence_transformers import SentenceTransformer
import faiss, numpy as np, tiktoken

print("tokens:", len(tiktoken.get_encoding("cl100k_base").encode("hello world")))

m = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
v = m.encode(["the cat sat", "a feline was seated", "kubernetes autoscaling"],
             normalize_embeddings=True)

index = faiss.IndexFlatIP(v.shape[1])
index.add(v.astype("float32"))
print(index.search(v[:1].astype("float32"), 3))
```

If that prints scores where sentence 2 beats sentence 3, your stack works and you understand semantic search already.
