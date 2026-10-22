# AI Engineer Master Guide — Index

> **Purpose**: Zero-to-hero production AI engineering. Depth-first, implementation-focused, revision-optimized. **Companion codebase**: [Onyx (onyx.app)](https://github.com/onyx-dot-app/onyx) — referenced throughout for real production patterns.

---

## Navigation

### 01 — AI Engineering Foundations

| File                                             | Topic                                          |
| ------------------------------------------------ | ---------------------------------------------- |
| [[01.1 - What is AI Engineering]]                | Definition, scope, what the job actually is    |
| [[01.2 - Roles - ML vs AI vs Applied Scientist]] | Role comparison, career clarity                |
| [[01.3 - Production AI Systems Overview]]        | What real systems look like end-to-end         |
| [[01.4 - Where Backend Meets AI]]                | Backend engineer's entry point into AI systems |

### 02 — Deep Learning Foundations

|File|Topic|
|---|---|
|[[02.1 - Neural Networks Intuition]]|Intuition, forward pass, backprop|
|[[02.2 - Attention Mechanism]]|Self-attention from first principles|
|[[02.3 - Transformer Architecture]]|Full architecture, positional encoding, layer norms|
|[[02.4 - Encoder vs Decoder vs Encoder-Decoder]]|Model families, when each is used|
|[[02.5 - Pretraining vs Finetuning vs Inference]]|Training paradigms and compute implications|

### 03 — LLM Foundations

|File|Topic|
|---|---|
|[[03.1 - Tokens and Tokenization]]|BPE, SentencePiece, tokenizer gotchas|
|[[03.2 - Embeddings and Vector Representations]]|What embeddings are, how they encode meaning|
|[[03.3 - Similarity Search]]|Cosine, dot product, euclidean — tradeoffs|
|[[03.4 - Semantic vs Dense vs Sparse Retrieval]]|Retrieval paradigms compared|
|[[03.5 - BM25 and Hybrid Search]]|BM25 internals, hybrid architecture|
|[[03.6 - Rerankers - Cross vs Bi Encoders]]|Reranking systems, latency tradeoffs|
|[[03.7 - Prompting and In-Context Learning]]|Prompt engineering, ICL, few-shot|
|[[03.8 - Sampling Strategies]]|Temperature, top-k, top-p, penalties|
|[[03.9 - Hallucinations and Grounding]]|Why LLMs hallucinate, mitigation strategies|
|[[03.10 - Chain of Thought and Reasoning]]|CoT, self-consistency, reflection|
|[[03.11 - Structured Outputs and Tool Calling]]|JSON mode, function calling, tool use|
|[[03.12 - Memory and Context Management]]|Context windows, memory systems, compression|

### 04 — Fine-Tuning and Model Adaptation

|File|Topic|
|---|---|
|[[04.1 - Fine-Tuning Fundamentals]]|Full FT, instruction tuning, SFT|
|[[04.2 - RLHF and DPO]]|Alignment techniques explained|
|[[04.3 - PEFT - LoRA QLoRA Adapters]]|Parameter-efficient methods, when to use each|
|[[04.4 - Dataset Preparation and Quality]]|Data curation, labeling, quality signals|
|[[04.5 - Evaluation - Offline vs Online]]|Metrics, regression prevention, eval design|

### 05 — RAG Systems

|File|Topic|
|---|---|
|[[05.1 - What RAG Solves and When Not to Use It]]|Core motivation, failure modes, alternatives|
|[[05.2 - Ingestion and Connector Pipelines]]|How documents enter the system|
|[[05.3 - Chunking Strategies]]|Recursive, semantic, hierarchical, metadata-aware|
|[[05.4 - Query Transformation]]|Rewriting, multi-query, HyDE|
|[[05.5 - Hybrid Retrieval and Reranking]]|Combining sparse + dense, reranking pipeline|
|[[05.6 - Citation and Access Control]]|Citation systems, permission-aware retrieval|
|[[05.7 - Indexing - Incremental Freshness Deduplication]]|Keeping index fresh at scale|
|[[05.8 - RAG Evaluation Frameworks]]|RAGAS, evaluation datasets, metrics|
|[[05.9 - Onyx RAG Architecture Deep Dive]]|End-to-end Onyx walkthrough|

### 06 — Vector Databases

|File|Topic|
|---|---|
|[[06.1 - Vector DB Internals - ANN HNSW IVF PQ]]|Core algorithms, index tradeoffs|
|[[06.2 - Metadata Filtering and Hybrid Search]]|Filtered ANN, pre vs post filtering|
|[[06.3 - Vector DB Comparison]]|Vespa, Qdrant, Pinecone, Weaviate, Chroma, ES|

### 07 — AI Frameworks and Orchestration

|File|Topic|
|---|---|
|[[07.1 - LangChain - When to Use and When Not To]]|LangChain internals, failure patterns|
|[[07.2 - LangGraph and Stateful Workflows]]|Graph-based agent orchestration|
|[[07.3 - Custom Orchestration vs Frameworks]]|Decision framework for choosing|

### 08 — Agents

|File|Topic|
|---|---|
|[[08.1 - What Agents Actually Are]]|Real definition, not the hype version|
|[[08.2 - Agent Architectures - Single vs Multi]]|Architecture patterns, failure modes|
|[[08.3 - Memory Planning and Reflection]]|How agents reason across steps|
|[[08.4 - Observability Guardrails and Cost Control]]|Production agent operations|

### 09 — Knowledge Graphs and Enterprise AI

|File|Topic|
|---|---|
|[[09.1 - Knowledge Graphs and GraphRAG]]|When graphs help, GraphRAG patterns|
|[[09.2 - Enterprise Search and Permission-Aware Retrieval]]|Multi-source, ACL-aware systems|

### 10 — Production AI Engineering

|File|Topic|
|---|---|
|[[10.1 - Latency and Cost Optimization]]|Token reduction, batching, profiling|
|[[10.2 - Caching Strategies]]|Embedding cache, prompt cache, semantic cache|
|[[10.3 - Async Architecture and Streaming]]|Async patterns, streaming responses|
|[[10.4 - Model Routing and Multi-Model Architecture]]|Routing logic, fallback strategies|
|[[10.5 - Evaluation Pipelines and Monitoring]]|LLM-as-judge, drift detection, dashboards|
|[[10.6 - Prompt and Model Versioning]]|Version control for non-deterministic systems|
|[[10.7 - Safety Systems and Abuse Prevention]]|Guardrails, input/output validation|

### 11 — Architecture Case Studies

|File|Topic|
|---|---|
|[[11.1 - Enterprise Search Assistant]]|Full system design walkthrough|
|[[11.2 - Internal Company Copilot]]|Copilot architecture, access control|
|[[11.3 - AI Support Agent]]|Support agent with tool use and escalation|
|[[11.4 - Multi-Tenant RAG Platform]]|Isolation, billing, scaling strategies|
|[[11.5 - AI Document Intelligence Platform]]|Extraction, classification, structured output|

### 12 — Retrieval and Knowledge

|File|Topic|
|---|---|
| [[12.1 - Embedding Model Selection and Engineering Tradeoffs]] | Bi-encoder internals, MRL, model comparison table, context window mismatch, asymmetric prefixes, fine-tuning with MultipleNegativesRankingLoss |
| [[12.2 - Vespa Internals and Onyx Use]] | Container vs Content nodes, schema directives, YQL hybrid query pattern, two-phase ranking, PagedAttention analogue, Onyx file map |
| [[12.3 - Multimodal Basics]] | CLIP architecture + cross-modal search, image indexing strategies (LLM description vs CLIP embed vs hybrid), vision LLM context injection, ColPali document embeddings |
| [[12.4 - GraphRAG in Practice]] | Microsoft GraphRAG pipeline + real cost (~190× standard RAG), community detection (Leiden), global vs local search, LightRAG comparison, hybrid routing pattern |

### 13 — LLM Serving and Operations
|File|Topic|
|---|---|
| [[13.1 - Token Economics KV Cache Prefix Caching]] | KV cache memory formula, GQA/MQA, prefix caching architecture (Anthropic explicit, OpenAI auto), stable-first prompt design, Batch API |
| [[13.2 - LLM Observability Stack]] | Trace→span data model, Langfuse (ClickHouse backend, decorator/manual/drop-in), Helicone (Cloudflare Workers proxy), Arize Phoenix (OTel-native, run_evals) |
| [[13.3 - Evaluation Deep Dive]] | RAGAS metric internals (faithfulness decompose→verify, answer relevance reverse-QG), LLM judge biases + calibration, golden dataset stratification, regression thresholds, A/B significance |
| [[13.4 - Inference Internals]] | Prefill vs decode, PagedAttention, GQA with repeat_kv code, Flash Attention tiling, continuous batching, vLLM config, quantization table (INT8/GPTQ/AWQ) |

### 14 — System Design and Safety
|File|Topic|
|---|---|
| [[14.1 - Voice and Speech Stack]] | ASR (Whisper internals, faster-whisper, VAD), TTS (streaming, TTFB), full real-time pipeline, Indian language models, speaker diarization |
| [[14.2 - Function Calling and Structured Outputs]] | Full call-execute-observe loop (OpenAI + Anthropic), parallel tool calls with asyncio.gather, schema design rules, constrained decoding internals, error-as-observation pattern |
| [[14.3 - Multi-Tenancy Patterns for AI SaaS]] | Silo/bridge/pool models, ContextVar propagation, collection-per-tenant isolation, PostgreSQL RLS, KMS per-tenant credentials, rate limiting, offboarding |
| [[14.4 - AI Security]] | Direct + indirect prompt injection, OWASP LLM Top 10, structural prompt defenses, SSRF tool attack, path traversal, SQL injection via tools, exfiltration patterns, red-team test suite |

---

## Key Mental Models

> Quick-access anchors for revision

- **RAG vs Fine-tuning**: RAG = inject knowledge at query time. FT = bake knowledge into weights. Use RAG for dynamic/private data, FT for consistent behavior/style.
- **Retrieval quality hierarchy**: Sparse (BM25) → Dense (embeddings) → Hybrid → Reranked
- **Agent complexity rule**: If you can solve it with a single prompt + retrieval, do that. Agents add latency, cost, and failure modes.
- **Chunking mantra**: Chunk for retrieval, not for storage. The right chunk size is the one that retrieves the right context.
- **Evaluation first**: Define what "good" looks like before building. Offline evals before online evals.
