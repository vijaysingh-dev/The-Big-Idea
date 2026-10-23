**Up:** [[00 - Index (Interview)]] | **Prev:** [[01 - LLM Fundamentals]]

---

# 02 — Retrieval-Augmented Generation (RAG)

> Every stage of a RAG pipeline: ingestion, chunking, embeddings, vector indexes, hybrid search, reranking, and evaluation with LLM-as-a-judge.

---

## Section A: The big picture
### Q1. What is RAG, and why use it?

**Answer**
**RAG (Retrieval-Augmented Generation)** means: before asking the LLM to answer, **retrieve** relevant information from your own data, put it in the prompt, and ask the model to answer **grounded in** that information.

Why:
- **Knowledge the model doesn't have:** private company data, recent events, anything after its training cutoff.
- **Freshness:** update the index, not the model.
- **Citations and auditability:** you know which sources the answer used.
- **Access control:** retrieve only what *this* user is allowed to see. You can't do that with knowledge baked into weights.
- **Fewer hallucinations,** when the retrieval is good.
- **Cost:** far cheaper than fine-tuning to "teach" facts, and fine-tuning doesn't reliably teach facts anyway.

**Likely follow-ups**
- *When is RAG the wrong choice?* When the problem is behaviour or format (prompting or fine-tuning fixes those), when the whole corpus fits comfortably in context and rarely changes, or when the answer needs computation over structured data (use SQL or tools instead).

**What a strong answer shows:** You frame RAG around a business need (freshness, access, citations), not just "it reduces hallucinations".

**Go deeper:** [[05.1 - What RAG Solves and When Not to Use It]]

---

### Q2. Walk me through a production RAG pipeline end to end.

**Answer**
There are two pipelines: **offline indexing** and **online querying**.

**Indexing (offline / async):**
1. **Ingest:** pull from sources (S3, Confluence, databases, email…) through connectors. Track the source ID, version and timestamps.
2. **Parse:** extract clean text and structure from PDFs, HTML, DOCX, tables and images. Often the hardest, most underrated step (Q3).
3. **Clean and enrich:** remove boilerplate (headers, footers, signatures). Add metadata: source, date, author, permissions, section titles.
4. **Chunk:** split into retrievable units (Q4).
5. **Embed:** turn each chunk into a vector with an embedding model (Q5).
6. **Index:** store the vectors in an ANN index (Q9), plus a keyword index (BM25, Q11) and metadata for filtering.

**Querying (online, latency-sensitive):**
1. **Query understanding:** guardrails, rewriting, extracting filters ("last quarter" → a date range), possibly routing (Q15).
2. **Retrieve:** vector search plus keyword search, with metadata filters (top 20–100).
3. **Fuse:** merge the result lists (RRF, Q12).
4. **Rerank:** a cross-encoder narrows to the best 3–10 (Q13).
5. **Assemble the prompt:** instructions + delimited context with IDs + question (Q18).
6. **Generate:** the LLM answers with citations, or abstains.
7. **Post-process:** validate citations, run output guardrails, stream to the user.
8. **Log and evaluate:** traces, user feedback, offline eval sets (Q19).

**Likely follow-ups**
- *Which stage do you optimise first?* Retrieval. If the right chunk isn't in the top-k, nothing downstream can fix it. Measure **recall@k** before touching prompts.

**What a strong answer shows:** You know both pipelines, you name the less glamorous stages (parsing, metadata, evaluation), and you know where quality is won or lost.

**Go deeper:** [[03 - The Baseline RAG Pipeline]] · [[07 - Production RAG]]

---

## Section B: Ingestion and chunking

### Q3. What makes document parsing hard, and how do you handle it?

**Answer**
Real documents aren't clean text:
- **PDFs** store characters positioned on a page, not paragraphs. Columns, headers, footers and footnotes get mixed together.
- **Tables** lose their structure when flattened into text, and numbers lose their row and column meaning.
- **Scanned documents** need **OCR** (optical character recognition: converting images of text to text).
- **Slides and images** carry meaning visually.

Approaches:
- Use layout-aware parsers (e.g. Unstructured, Docling, PyMuPDF, or managed services like AWS Textract) that detect titles, lists and tables.
- Convert tables to Markdown or HTML, or describe each row in a sentence, so the meaning survives chunking.
- For visually rich documents, use a vision LLM to describe pages, or **multimodal embeddings** that embed page images directly.
- **Inspect the output.** Look at 20 parsed documents by eye before building anything else. Bad parsing silently caps quality.

**What a strong answer shows:** Experience. People who've shipped RAG always mention parsing pain.

**Go deeper:** [[05.2 - Ingestion and Connector Pipelines]]

---

### Q4. How do you chunk documents? How do you choose chunk size?

**Answer**
**Why chunk at all?**
- Embedding models have input limits (often 512–8k tokens).
- One vector for a 50-page document blurs every topic into an average.
- Retrieving smaller units puts fewer, more relevant tokens in the prompt.

**Strategies:**
- **Fixed-size with overlap:** e.g. 500 tokens with 50 overlapping. Simple and a fine baseline, but it can cut sentences or ideas in half.
- **Recursive splitting:** try to split on paragraphs, then sentences, then words, until pieces fit the size. This is the common default.
- **Structure-aware:** split on the document's own structure (Markdown headings, HTML sections, code functions, one email = one chunk). Usually the best when structure exists.
- **Semantic chunking:** embed sentences and start a new chunk where the similarity between neighbours drops (a topic shift). It can help, but it costs more and the gains are inconsistent.
- **Small-to-big (parent-child):** embed small chunks for precise matching, but give the LLM the larger parent section for context.
- **Contextual chunk headers:** prepend context to each chunk before embedding (`Doc: Leave Policy > Section 3: Carry-over`). Anthropic's "Contextual Retrieval" generates a 1–2 sentence context per chunk with an LLM, and reported large reductions in retrieval failures.

**Choosing size:** there's no universal number.
- **Small chunks (100–300 tokens):** precise matches, but they may miss context. Good for FAQs and fact lookup.
- **Large chunks (800–1500 tokens):** more context, but noisier embeddings, and fewer of them fit in the prompt. Good for explanations and narrative text.
- **Overlap (10–20%)** reduces information lost at boundaries, at the cost of duplication.
- **Decide with evals:** try 2–3 configurations and compare recall@k and answer quality on a golden set.

**What goes in a chunk record:** clean text, the text actually embedded (with its header), a stable ID, the document ID, its position, a content hash, the embedding model name, and filterable metadata (date, source, author, permissions).

**Likely follow-ups**
- *How do you chunk code?* By syntax units (functions, classes) using a parser like tree-sitter, with the file path and class name as context.
- *What happens when you change the chunking strategy?* You must re-chunk and re-embed everything. Version your indexes (Q20).

**What a strong answer shows:** You choose by the content type and by measurement, and you know the contextual tricks.

**Go deeper:** [[04 - Chunking Strategies]] · [[05.3 - Chunking Strategies]]

---

## Section C: Embeddings and similarity

### Q5. How do embedding models work, and how do you choose one?

**Answer**
**How they work:**
- An embedding model is usually a Transformer **encoder** (bidirectional attention).
- Text goes in, every token gets a contextual vector, and **pooling** (e.g. averaging them) produces one fixed-size vector.
- It's a **bi-encoder**: queries and documents are encoded *separately*, so all document vectors can be computed ahead of time.
- They're trained with **contrastive learning**: (query, relevant passage) pairs are pulled together and unrelated pairs are pushed apart. A common loss uses "in-batch negatives": every other passage in the training batch serves as a negative example.

**Choosing one:**
- **Retrieval quality on your domain.** Use the MTEB leaderboard (Massive Text Embedding Benchmark) *Retrieval* tab as a first filter, then test on your own data.
- **Dimensions:** 384 / 768 / 1024 / 1536 / 3072. Bigger can be better, but costs more storage and slower search.
- **Max input length:** must fit your chunk size.
- **Languages and domain:** multilingual needs, code, legal, medical.
- **Hosting:** API (OpenAI, Cohere, Bedrock Titan) vs. local (BGE, E5, GTE, Nomic). Local is free per call and private, but you run it yourself.
- **Instruction prefixes:** some models expect a prefix like `"query: "` or "Represent this sentence for searching…" on queries. Skipping it silently lowers quality.

**Matryoshka embeddings:** some models (e.g. OpenAI's text-embedding-3 family) are trained so the *first* N dimensions are already a useful embedding. You can truncate 3072 → 256 to save space, with modest loss.

**Likely follow-ups**
- *Can you mix vectors from two embedding models in one index?* No. Each model has its own vector space, so the numbers aren't comparable. Changing models means re-embedding everything.
- *Should you fine-tune an embedding model?* Only if evals show a domain gap after trying better chunking, hybrid search and reranking. Fine-tuning on (query, relevant passage) pairs from your domain can help a lot in specialised fields.

**What a strong answer shows:** You understand the bi-encoder design and choose a model by testing, dimensions and operational cost.

**Go deeper:** [[12.1 - Embedding Model Selection and Engineering Tradeoffs]] · [[03.2 - Embeddings and Vector Representations]]

---

### Q6. What is semantic search, and how is it different from keyword search?

**Answer**
- **Keyword (lexical) search** matches the actual words. It's great for exact terms (error codes, product IDs, names, acronyms), fast, and explainable. It fails on synonyms and paraphrases: "car" doesn't match "automobile".
- **Semantic (dense / vector) search** embeds the query and documents and finds documents whose vectors are close to the query's, so it matches *meaning*. "How do I reset my password" finds "Recovering account access". It can fail on exact identifiers, rare jargon, and negation ("not" is easy to ignore), and its results are harder to explain.

They fail in different ways, which is why **hybrid search** (Q12) is the production default.

**What a strong answer shows:** You know the failure modes of each, not just the benefits of the newer one.

**Go deeper:** [[03.4 - Semantic vs Dense vs Sparse Retrieval]]

---

### Q7. Explain cosine similarity, dot product and Euclidean distance. Which do you use?

**Answer**
For vectors **a** and **b**:
- **Dot product:** `a·b = Σ aᵢbᵢ`. Larger means more similar. It's affected by both direction and length (magnitude).
- **Cosine similarity:** `cos θ = (a·b) / (‖a‖·‖b‖)`. The angle between the vectors, ignoring length. The range is −1 to 1; 1 means the same direction.
- **Euclidean (L2) distance:** `‖a − b‖ = √Σ(aᵢ − bᵢ)²`. The straight-line distance; smaller means more similar.

**The key fact:** if vectors are **normalised to unit length** (‖a‖ = 1), then:
- cosine similarity = dot product;
- squared L2 distance = 2 − 2·cos θ.

All three give the **same ranking**. So most systems normalise once at indexing time and use the dot product, which is the cheapest to compute.

**Which to use:** whatever the embedding model was trained with (check its model card). Most text embedding models assume cosine or normalised dot product. If a model was trained with unnormalised dot product, the vector length can carry meaning, and normalising would throw that away.

**Likely follow-ups**
- *Why ignore magnitude?* For text, length often relates to things like passage length or word frequency, not relevance. Direction captures the topic.
- *Is a cosine of 0.8 "good"?* Absolute scores aren't comparable across models, and are often bunched in a narrow range. Use scores for *ranking*. For thresholds (e.g. "no relevant result"), calibrate on your own data.

**What a strong answer shows:** You can write the formulas, you know the normalisation equivalence, and you're careful about treating scores as absolute.

**Go deeper:** [[03.3 - Similarity Search]]

---

## Section D: Vector indexes

### Q8. Why do vector databases use approximate nearest neighbour (ANN) search instead of exact search?

**Answer**
**Exact kNN** (k-nearest-neighbours) compares the query with **every** vector: O(N·d) per query, where N is the number of vectors and d the dimensions.
- At 10k vectors that's trivial; a NumPy matrix multiply works well.
- At 100M vectors × 1536 dimensions it's far too slow and memory-heavy for interactive latency.

**ANN** algorithms build an index that finds *nearly* the nearest neighbours by examining only a small fraction of vectors. You trade a little **recall** (the fraction of true nearest neighbours you find) for orders of magnitude more speed.
- Recall@10 of 0.95–0.99 is typical and usually invisible to users, because the reranker and LLM tolerate small misses.

**Practical guidance:**
- Under roughly 100k–1M vectors, exact search (brute force, or `pgvector` without an index) may be perfectly fine and simpler.
- Beyond that, use HNSW (Q9) or IVF-based indexes (Q10).

**What a strong answer shows:** You understand the recall/latency trade, and that exact search is a legitimate choice at small scale.

**Go deeper:** [[06.1 - Vector DB Internals - ANN HNSW IVF PQ]]

---

### Q9. How does HNSW work?

**Answer**
**HNSW (Hierarchical Navigable Small World)** is the most widely used ANN index (pgvector, OpenSearch, Qdrant, Weaviate, Milvus, FAISS, Elasticsearch).

**The intuition is a skip list for vectors, layered like a road network.**
- A **navigable small-world graph** connects each vector to some of its nearest neighbours, plus a few longer-range links. From any node you can reach any other in a few hops, like "six degrees of separation".
- **Hierarchical:** build several layers.
  - The **top layer** has very few nodes with long-range links: the motorways.
  - Each lower layer has more nodes.
  - The **bottom layer (layer 0)** has every vector, connected to its close neighbours: the local streets.
  - Each new vector is assigned a random top layer, with probability falling off exponentially. Most vectors exist only at layer 0, and a few reach high layers.

**Search:**
1. Start at an entry point in the top layer.
2. **Greedily** move to whichever neighbour is closer to the query, until no neighbour is closer: a local minimum.
3. Drop to the next layer and repeat from there.
4. At layer 0, do a wider search that keeps a candidate list of size **efSearch**, then return the best k.

**Insertion:** search for the new vector's position the same way, then connect it to its nearest neighbours at each of its layers, up to **M** links per node.

**Key parameters:**
| Parameter | Meaning | Tradeoff |
|---|---|---|
| `M` | Max links per node | Higher → better recall, more memory, slower builds |
| `efConstruction` | Candidate list size while building | Higher → better graph, slower indexing |
| `efSearch` (`ef`) | Candidate list size while querying | Higher → better recall, slower queries. **Tunable per query**, so this is your main runtime knob |

**Tradeoffs:**
- ✅ Excellent recall and latency; supports incremental inserts.
- ❌ **Memory-heavy:** vectors plus graph links are usually kept in RAM.
- ❌ **Deletes are awkward:** usually marked as tombstones and cleaned up later, and heavy churn degrades the graph.
- ❌ **Filtering interacts badly** with graph traversal (Q16).
- ❌ Builds can be slow at very large scale.

**Likely follow-ups**
- *Why the hierarchy, and not just one graph?* The upper layers get you to the right region in roughly logarithmic steps. One flat graph would need many short hops.
- *How would you tune it?* Fix M and efConstruction at build time. Then sweep efSearch and plot recall@k (against exact search on a sample) vs. p95 latency. Pick the knee of the curve.

**What a strong answer shows:** You can explain the layered greedy search, name the three parameters and their tradeoffs, and know how to tune them empirically.

**Go deeper:** [[06.1 - Vector DB Internals - ANN HNSW IVF PQ]] · [[02 - Embeddings and Vector Search]]

---

### Q10. What are IVF and Product Quantization? How do they compare with HNSW?

**Answer**
- **IVF (Inverted File index):**
  - Cluster all vectors with k-means into `nlist` clusters. Each vector belongs to its nearest centroid (cluster centre).
  - At query time, find the `nprobe` closest centroids and search only those clusters.
  - Higher `nprobe` means better recall but slower queries.
  - Uses less memory than HNSW and builds faster, but recall drops at cluster boundaries. It needs a training step and re-clustering when the data distribution shifts.
- **PQ (Product Quantization):** compresses vectors.
  - Split each vector into m sub-vectors, and replace each with the ID of its nearest entry in a small learned codebook (often 256 entries, so 1 byte).
  - A 1536-dim float32 vector (6 KB) can shrink to a few dozen bytes. Distances are approximated from lookup tables.
  - It's lossy, so it's usually followed by **re-scoring** the top candidates with the full vectors.
- **IVF-PQ** combines them for billion-scale search on limited memory.
- **Scalar / binary quantization:** store float32 as int8 or as 1 bit per dimension, for 4–32× memory savings. Often paired with re-scoring.

**Rule of thumb:**
- **HNSW** for low latency and high recall when the vectors fit in memory.
- **IVF/PQ or quantization** when memory or cost dominates at very large scale.
- **DiskANN-style indexes** when you want graph-like quality from SSD.

**What a strong answer shows:** You know there are options beyond HNSW and can pick based on scale, memory and recall needs.

**Go deeper:** [[06.1 - Vector DB Internals - ANN HNSW IVF PQ]]

---

## Section E: Keyword search, hybrid search and reranking

### Q11. How does BM25 work?

**Answer**
BM25 ("Best Matching 25") is the standard keyword ranking function in Elasticsearch, OpenSearch, Lucene and Postgres extensions. It scores a document D for a query Q by summing over the query terms:

```
score(D, Q) = Σ  IDF(t) · [ f(t,D) · (k1 + 1) ] / [ f(t,D) + k1 · (1 − b + b · |D| / avgdl) ]
             t∈Q
```

Its three ideas:
1. **IDF (Inverse Document Frequency):** rare terms matter more.
   - `IDF(t) = ln( (N − n(t) + 0.5) / (n(t) + 0.5) + 1 )`, where N is the number of documents and n(t) the number containing term t.
   - "the" contributes almost nothing; "CVE-2024-3094" contributes a lot.
2. **Term-frequency saturation (k1, typically 1.2–2.0):** more occurrences help, with diminishing returns. The 10th mention of "Python" adds much less than the 2nd.
3. **Length normalisation (b, typically 0.75):** long documents naturally contain more term matches, so they're penalised relative to the average length (avgdl).
   - b = 0 turns normalisation off; b = 1 normalises fully.

It needs no training, it's fast (an **inverted index** maps each term to the documents containing it), it's explainable, and it's very strong on exact terms.

**Likely follow-ups**
- *What are BM25's weaknesses?* No understanding of meaning: synonyms, paraphrases and other languages fail. Also, results depend on tokenization and stemming choices (reducing words to their root, e.g. "running" → "run").
- *What is SPLADE / learned sparse retrieval?* A model that produces *sparse* term weights, including related terms that aren't in the text. You get keyword-index efficiency with some semantic matching.

**What a strong answer shows:** You can explain IDF, saturation and length normalisation intuitively, and roughly write the formula.

**Go deeper:** [[03.5 - BM25 and Hybrid Search]]

---

### Q12. What is hybrid search? How do you combine keyword and vector results?

**Answer**
**Hybrid search** runs keyword (BM25) and vector retrieval in parallel and merges the results. It captures both exact-term matches and meaning matches, and in most benchmarks and production systems it beats either one alone.

**The fusion problem:** BM25 scores (unbounded, e.g. 0–30) and cosine scores (e.g. 0.6–0.9) are on different scales, so you can't just add them.

Options:
- **RRF (Reciprocal Rank Fusion):** ignore the scores and use ranks.
  - `RRF(d) = Σ 1 / (k + rank_i(d))`, summed over each result list, with k usually 60.
  - A document ranked high in both lists wins.
  - Robust, needs no tuning, and is the common default.
- **Weighted score fusion:** normalise each list's scores (min-max or z-score), then combine with `α·vector + (1−α)·bm25`.
  - Can beat RRF when tuned on your data, but it's sensitive to the score distributions.

**Practical tips:**
- Retrieve more than you need from each side (e.g. top 50 each), fuse, then rerank to the final few.
- Weight lexical search more for identifier-heavy domains (logs, code, part numbers), and semantic search more for natural-language questions.

**What a strong answer shows:** You know *why* scores can't be added directly, and you can explain RRF.

**Go deeper:** [[05.5 - Hybrid Retrieval and Reranking]] · [[05 - Retrieval Quality]]

---

### Q13. What is reranking? Explain bi-encoders vs. cross-encoders.

**Answer**
- **Bi-encoder** (embedding model): encodes the query and the document **separately**, then compares the vectors.
  - Document vectors are precomputed, so it's fast enough to search millions of documents.
  - Less accurate, because the query and document never "see" each other.
- **Cross-encoder** (reranker): takes `[query] [SEP] [document]` **together** and outputs a relevance score.
  - Full attention between query and document tokens, so it's much more accurate.
  - Nothing can be precomputed: one forward pass per (query, doc) pair at query time. Too slow for millions, fine for 20–100.

So the standard pattern is **retrieve wide with a bi-encoder (plus BM25), rerank narrow with a cross-encoder.** For example: retrieve 50 → rerank → keep the top 5 for the prompt.

Options:
- Open models: `cross-encoder/ms-marco-MiniLM-L-6-v2`, BGE rerankers.
- Hosted APIs: Cohere Rerank, Bedrock rerank models.
- **LLM-as-reranker:** prompt an LLM to score or order candidates. Flexible but slower and more expensive.
- **ColBERT (late interaction):** keeps one vector *per token* and scores with "MaxSim": each query token's best match among the document tokens, summed. A middle ground: more accurate than bi-encoders, cheaper than cross-encoders, but much more storage.

**Likely follow-ups**
- *How much latency does reranking add?* Typically tens to a few hundred ms for 20–50 candidates on a GPU or a fast API. Measure it, and trade candidate count against latency.
- *How do you know reranking helps?* Compare MRR and nDCG (Q19) with and without it on your golden set.

**What a strong answer shows:** A clear explanation of the precision/compute trade and of why two stages exist.

**Go deeper:** [[03.6 - Rerankers - Cross vs Bi Encoders]]

---

## Section F: Query side

### Q14. What query-transformation techniques do you know, and when do they help?

**Answer**
Users write short, vague or multi-part questions. Transforming them can improve retrieval:
- **Query rewriting:** an LLM turns a conversational follow-up into a standalone query. "What about for contractors?" → "What is the leave policy for contractors?" **Essential in chat**, because the follow-up alone lacks the context.
- **Multi-query:** generate 3–5 phrasings, retrieve for each, and fuse the results. Improves recall on ambiguous questions.
- **Decomposition:** split a multi-part question ("Compare the 2023 and 2024 travel policies") into sub-questions, retrieve for each, then combine.
- **HyDE (Hypothetical Document Embeddings):** have the LLM write a *hypothetical answer*, embed that, and search with it. Answers look more like documents than questions do. Helps when questions and documents are phrased very differently, but adds a model call and can drift.
- **Step-back prompting:** retrieve for a more general version of the question as well, for background.
- **Filter extraction:** pull structured filters out of the query ("emails from Priya last week" → `author = priya, date in [...]`) with structured output. Often the biggest win in metadata-rich data.

Each of these adds latency and cost, so turn them on based on evals, often only for certain query types.

**What a strong answer shows:** You know the toolbox, and you apply it selectively.

**Go deeper:** [[05.4 - Query Transformation]]

---

### Q15. How do you handle metadata filtering and access control in vector search?

**Answer**
Metadata filters (tenant, user permissions, date, document type) are essential in real systems. With ANN indexes there are three approaches:
- **Post-filtering:** search the top-k, then drop results that fail the filter. Simple, but if the filter is selective you may end up with very few results, or none.
- **Pre-filtering:** filter first, then search only the matching vectors. Accurate, but with HNSW a restrictive filter can make the graph walk inefficient or disconnected.
- **Filtered search inside the index:** modern engines (Qdrant, Weaviate, OpenSearch, pgvector 0.8+ with iterative index scans) apply filters during graph traversal, adjust automatically, and fall back to exact search for very selective filters.

**Access control specifically:**
- **Never rely on the LLM to hide data.** If a chunk reaches the prompt, assume it can leak into the answer.
- Store permission metadata (ACL groups, tenant ID) on every chunk and **enforce it as a mandatory filter in the retrieval layer**, derived from the authenticated user, never from the prompt.
- For strong isolation between customers, use a **separate index or namespace per tenant**.
- Keep permissions in sync when they change upstream (permission sync is a classic production bug).

**What a strong answer shows:** You treat authorisation as a retrieval-layer filter, and you know how filters interact with ANN.

**Go deeper:** [[06.2 - Metadata Filtering and Hybrid Search]] · [[05.6 - Citation and Access Control]] · [[09.2 - Enterprise Search and Permission-Aware Retrieval]]

---

### Q16. How would you choose a vector store?

**Answer**
- **pgvector (Postgres):**
  - Great default if you already run Postgres. Transactions, joins with relational data, one less system.
  - HNSW and IVFFlat indexes; good to roughly tens of millions of vectors with tuning.
  - Hybrid search needs extra work (full-text search plus vectors combined in SQL).
- **OpenSearch / Elasticsearch:**
  - Strong BM25 plus vector (k-NN) plus filters and aggregations in one engine. Mature operations.
  - A natural fit when you already have search infrastructure, or need hybrid search heavily.
- **Dedicated vector DBs (Qdrant, Weaviate, Milvus, Pinecone):**
  - Built for vectors: filtered HNSW, quantization, multi-tenancy, managed scaling.
  - Another system to run or pay for.
- **Managed RAG (Bedrock Knowledge Bases, Vertex AI Search):** ingestion, chunking, embeddings and retrieval as a service. Fastest to ship, with less control over each stage.
- **In-process (FAISS, Chroma, LanceDB, NumPy):** prototypes, local tools, small corpora.

Decision factors: scale, the team's existing stack, hybrid search needs, filtering complexity, multi-tenancy, latency SLOs (service level objectives, e.g. "p95 under 300 ms"), and operational capacity.

**What a strong answer shows:** A pragmatic choice ("use what you have until it hurts") with clear reasons to upgrade.

**Go deeper:** [[06.3 - Vector DB Comparison]]

---

## Section G: Generation side

### Q17. How do you build the prompt from retrieved chunks? How do you get good citations?

**Answer**
- **Structure the prompt:**
  1. System instructions: role, answer *only* from the context, cite sources, say "I don't know" when the context doesn't cover it.
  2. Context: each chunk wrapped in delimiters with an ID and key metadata, e.g. `<doc id="3" title="Leave Policy" date="2026-01-10">…</doc>`.
  3. The user's question, last.
- **Order and amount:** put the most relevant chunks first (and possibly last, because of "lost in the middle"). Fewer, better chunks usually beat many mediocre ones.
- **Deduplicate** near-identical chunks so they don't waste tokens.
- **Citations:** ask for inline markers like `[3]`, or structured output `{answer, citations: [ids]}`. Then **verify in code** that each cited ID was actually in the context. Optionally check that each sentence is supported by its cited chunk.
- **Abstention:** test that the model really does say "I don't know" for questions your corpus can't answer. Put such questions in your eval set.
- **Retrieved text is untrusted.** It may contain injected instructions, so tell the model that context is data, not instructions (Part 3).

**What a strong answer shows:** Careful prompt construction, plus verification in code rather than trusting the model.

**Go deeper:** [[05.6 - Citation and Access Control]]

---

### Q18. Long context vs. RAG: will long-context models make RAG obsolete?

**Answer**
Not for most production cases.
- **Cost and latency:** sending 500k tokens per question is slow and expensive, even with caching.
- **Quality:** models get distracted by irrelevant context, and "lost in the middle" still applies.
- **Scale:** most corpora (millions of documents) don't fit in any context window.
- **Access control and freshness** are cleanly handled at retrieval time.
- **Citations** are easier with discrete chunks.

Long context does change RAG:
- You can retrieve **bigger** units (whole sections or documents) and worry less about chunk boundaries.
- For small, stable corpora (one contract, a codebase subset), putting it all in context with **prompt caching** can be simpler and better.

The modern pattern: retrieve generously, then let long context handle the retrieved material.

**What a strong answer shows:** A balanced view grounded in cost, quality and scale, not hype in either direction.

**Go deeper:** [[05.1 - What RAG Solves and When Not to Use It]] · [[03.12 - Memory and Context Management]]

---

## Section H: Evaluation and debugging

### Q19. How do you evaluate a RAG system?

**Answer**
Evaluate **retrieval** and **generation** separately, so you know where a failure comes from.

**Retrieval metrics** (need a labelled set of question → relevant chunk(s)):
- **Recall@k:** fraction of the relevant chunks that appear in the top k. **The most important metric**: if the answer isn't retrieved, it can't be generated.
- **Precision@k:** fraction of the top k that are relevant. Affects noise and token cost.
- **MRR (Mean Reciprocal Rank):** the average of 1/rank of the *first* relevant result. Rewards putting the best hit at the top.
- **nDCG (normalised Discounted Cumulative Gain):** handles graded relevance (very relevant vs. somewhat relevant). Hits further down count less (`DCG = Σ rel_i / log₂(i+1)`), and the total is normalised by the ideal ordering.
- **Hit rate:** did *any* relevant chunk appear in the top k?

**Generation metrics:**
- **Faithfulness / groundedness:** is every claim supported by the retrieved context? (Hallucination check.)
- **Answer relevance:** does it actually answer the question?
- **Correctness:** does it match a reference answer, when you have one?
- **Citation accuracy:** do the citations point to chunks that really support the claim?
- **Abstention correctness:** does it say "I don't know" when it should, and only then?

**How to build the eval set:**
1. **Golden dataset:** 50–200 real or realistic questions with expected sources and answers. Include edge cases: multi-hop, unanswerable, ambiguous, adversarial.
2. Bootstrap with LLM-generated questions from your chunks, then **have humans review them**. Synthetic-only sets are often too easy.
3. Keep growing it with real production failures.

**Scoring:**
- Deterministic metrics where possible (retrieval metrics, citation-ID checks).
- **LLM-as-judge** for faithfulness and relevance (frameworks: Ragas, DeepEval, TruLens). Judges have biases: favouring longer answers, favouring their own outputs, position bias. **Calibrate** the judge against a sample of human labels.

**Process:** run evals on every change to chunking, embeddings, prompts or models, and gate releases in CI on regressions. In production, add online signals: thumbs up/down, citation clicks, escalations.

**What a strong answer shows:** You separate retrieval from generation, know the metrics, and run evals as a regression process.

**Go deeper:** [[06 - Evaluation]] · [[05.8 - RAG Evaluation Frameworks]] · [[13.3 - Evaluation Deep Dive]]

---

### Q20. What is LLM-as-a-judge? Implement one from scratch, then show the same evaluation with RAGAS.

**Answer**

**What it is:** using a (usually strong) LLM to grade another model's output against a rubric, because the quality you care about (correct? grounded? relevant?) can't be checked with string matching, and human grading doesn't scale.

**Three kinds of judge:**

| Type | Inputs | Use for |
|---|---|---|
| **Reference-based pointwise** | question + reference answer + candidate | Offline regression gates against a golden set. The most reliable |
| **Reference-free pointwise** | question + retrieved context + candidate | Online monitoring of live traffic, where there's no reference: faithfulness, relevance |
| **Pairwise** | question + answer A + answer B | "Is v2 better than v1?" More sensitive than comparing two averages |

**Rules that make a judge trustworthy:**
1. **Binary or 3-point scale with written definitions** for each label. 1–10 scales cluster at 7–8 and mean nothing.
2. **Reasoning before the verdict**, in the output schema. It's more accurate and gives you something to debug.
3. **Temperature 0**, a fixed and **versioned** prompt. Changing the judge prompt invalidates historical scores.
4. **A different model family from the generator**, to avoid self-preference.
5. **Swap positions in pairwise** and only count agreements, to cancel position bias.
6. **Calibrate against humans:** label 50+ examples yourself and report agreement and **Cohen's kappa**. "Our judge agrees with human labels 88% of the time (κ = 0.74)" is what makes the numbers believable.
7. **Decompose before judging** for faithfulness: split the answer into atomic claims and verify each one. "Is this paragraph faithful?" gets mush.

**Code: a raw judge (any chat model behind `allm`)**

```python
import asyncio
import json
from typing import Literal

from pydantic import BaseModel, ValidationError

JUDGE_VERSION = "correctness-v3"     # store with every score; bump on any prompt change

RUBRIC = """You are grading a candidate answer against a reference answer. Be strict.

- CORRECT: every factual claim agrees with the reference; nothing important is missing.
- PARTIALLY_CORRECT: the main point is right, but a detail is wrong or something important is missing.
- INCORRECT: the main point is wrong or contradicts the reference, or the question isn't answered.
Ignore style and length. Longer is NOT better unless it is more correct.

Question: {question}
Reference answer: {reference}
Candidate answer: {candidate}

Respond with JSON only: {{"reasoning": "<1-2 sentences>", "verdict": "CORRECT" | "PARTIALLY_CORRECT" | "INCORRECT"}}"""


class Verdict(BaseModel):
    reasoning: str                                   # comes first: reason, then decide
    verdict: Literal["CORRECT", "PARTIALLY_CORRECT", "INCORRECT"]

SCORE = {"CORRECT": 1.0, "PARTIALLY_CORRECT": 0.5, "INCORRECT": 0.0}


def parse_json(text: str) -> dict:
    start, end = text.find("{"), text.rfind("}")     # tolerate ```json fences or a preamble
    return json.loads(text[start : end + 1])


async def judge(question: str, reference: str, candidate: str, retries: int = 2) -> Verdict:
    prompt = RUBRIC.format(question=question, reference=reference, candidate=candidate)
    for attempt in range(retries + 1):
        try:
            return Verdict.model_validate(parse_json(await allm(prompt, temperature=0)))
        except (ValueError, ValidationError):
            if attempt == retries:
                raise


async def evaluate(golden, answers, concurrency=8) -> float:
    sem = asyncio.Semaphore(concurrency)             # respect the judge's rate limit
    async def one(ex, ans):
        async with sem:
            return SCORE[(await judge(ex.question, ex.ground_truth, ans)).verdict]
    scores = await asyncio.gather(*(one(e, a) for e, a in zip(golden, answers)))
    return sum(scores) / len(scores)
```

**Faithfulness from scratch (reference-free, claim-level):**

```python
CLAIMS = "Break the answer into atomic factual claims, one per line, no numbering.\nAnswer: {answer}"
VERIFY = ("Context:\n{context}\n\nClaim: {claim}\n\n"
          "Is the claim fully supported by the context? Reply with one word: SUPPORTED or UNSUPPORTED.")

async def faithfulness(answer: str, context: str) -> float:
    claims = [c.strip() for c in (await allm(CLAIMS.format(answer=answer))).splitlines() if c.strip()]
    if not claims:
        return 1.0
    verdicts = await asyncio.gather(*(allm(VERIFY.format(context=context, claim=c), temperature=0)
                                      for c in claims))
    return sum(v.strip().upper().startswith("SUPPORTED") for v in verdicts) / len(claims)
```

**Calibration:**

```python
from sklearn.metrics import cohen_kappa_score
human = [...]                                       # your labels for 50+ examples
model = [(await judge(e.question, e.ground_truth, a)).verdict for e, a in zip(sample, answers)]
print(f"agreement={sum(h == m for h, m in zip(human, model)) / len(human):.0%}",
      f"kappa={cohen_kappa_score(human, model):.2f}")   # > 0.6 = substantial agreement
```

**Code: the same evaluation with RAGAS (0.2+ API)**

```python
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from ragas import EvaluationDataset, evaluate
from ragas.embeddings import LangchainEmbeddingsWrapper
from ragas.llms import LangchainLLMWrapper
from ragas.metrics import (Faithfulness, FactualCorrectness, LLMContextPrecisionWithReference,
                           LLMContextRecall, ResponseRelevancy)

rows = []
for ex in golden:
    out = run_rag(ex.question)                       # run the pipeline ONCE per question
    rows.append({"user_input": ex.question,
                 "response": out["answer"],
                 "retrieved_contexts": [c.text for c in out["chunks"]],
                 "reference": ex.ground_truth})

result = evaluate(
    dataset=EvaluationDataset.from_list(rows),
    metrics=[Faithfulness(), ResponseRelevancy(), LLMContextPrecisionWithReference(),
             LLMContextRecall(), FactualCorrectness()],
    llm=LangchainLLMWrapper(ChatOpenAI(model="gpt-4o-mini", temperature=0)),
    embeddings=LangchainEmbeddingsWrapper(OpenAIEmbeddings(model="text-embedding-3-small")),
)
df = result.to_pandas()          # per-question scores: read the 10 worst before trusting the averages
```

**What each RAGAS metric grades:** `LLMContextPrecisionWithReference` and `LLMContextRecall` grade the **retriever**. `Faithfulness` grades the **generator** (grounded in context?). `ResponseRelevancy` checks the answer addresses the question. `FactualCorrectness` grades the **system** against the reference. When end-to-end correctness drops, the first four tell you which half broke.

**Raw vs RAGAS:** RAGAS gives standard, comparable metrics fast. A custom judge gives **your** rubric (domain rules, refusal policy, tone), and you understand every line. In production you usually have both: RAGAS for the RAG triad, and a custom judge for product-specific quality.

**Likely follow-ups**
- *Known biases of LLM judges?* Position bias (fix: swap and average), verbosity bias (instruct against it, control for length), self-preference (use a different model family), score clustering (binary or 3-point scale), and sycophancy toward the question's framing (neutral wording).
- *Isn't it circular to use an LLM to grade an LLM?* Only if it's uncalibrated. The judge's task (verify one claim against given text) is much easier than the generator's, and the calibration against human labels is what grounds it.
- *How do you use it in CI?* Retrieval metrics on every PR (cheap, deterministic). The judge suite nightly or per release on a fixed golden set, gated by thresholds, with confidence intervals, because 2 points on 40 examples is noise.
- *Cost?* Judges multiply token spend (faithfulness = 1 + N claim calls). Use a smaller model for claim verification, sample in production (e.g. 5% of traffic), and cache by (prompt version, input hash).

**What a strong answer shows:** You can build a judge (rubric, structured output, reasoning first, versioning), you know its biases and how to calibrate it, and you know what RAGAS's metrics measure rather than just how to call them.

**Go deeper:** [[06 - Evaluation#4. LLM-as-judge — how to do it without fooling yourself]] (the full judge with pairwise mode and the confusion matrix) · [[06 - Evaluation#Using RAGAS]] · [[05.8 - RAG Evaluation Frameworks]] · [[13.3 - Evaluation Deep Dive]] · [[10.5 - Evaluation Pipelines and Monitoring]]

**Resource:** [Hamel Husain — "Using LLM-as-a-Judge for evaluation"](https://hamel.dev/blog/posts/llm-judge/), a practitioner's guide to building judges that domain experts trust. Also [RAGAS docs — Metrics](https://docs.ragas.io/en/stable/concepts/metrics/) and the [Zheng et al. "Judging LLM-as-a-Judge" paper (MT-Bench)](https://arxiv.org/abs/2306.05685), the paper that measured position, verbosity and self-enhancement bias.

---

### Q21. A user says, "the bot gave a wrong answer." How do you debug it?

**Answer**
Trace it stage by stage, using the request's trace:
1. **Was the answer in the corpus at all?** If not, it's a content gap. Fix ingestion, or make the bot say "I don't know".
2. **Was it parsed and chunked correctly?** Look at the actual chunk. Garbled tables or split sentences are common.
3. **Was it retrieved?** Check the top-k candidates from both vector and keyword search.
   - Not retrieved: try query rewriting, hybrid search, better chunk headers, a different embedding model, or metadata filters that were too strict (or too loose).
4. **Was it reranked out?** Compare ranks before and after reranking.
5. **Was it in the prompt but ignored or misread?** Check the context order, prompt size and instructions; try a stronger model.
6. **Was it correct but contradicted by another chunk?** Handle stale or conflicting documents: prefer recent dates, deduplicate versions.
7. **Was it a guardrail or post-processing bug?**

Then **add the case to the eval set**, so the fix is protected from future regressions.

**What a strong answer shows:** A systematic, evidence-based debugging method, which only works if you built tracing in from the start.

**Go deeper:** [[06 - Evaluation]] · [[07 - Production RAG]]

---

### Q22. How do you keep the index fresh and consistent?

**Answer**
- **Incremental ingestion:** detect changes using source timestamps, change events (e.g. S3 events, webhooks), or comparing **content hashes**. Re-embed only what changed.
- **Idempotent upserts:** deterministic chunk IDs (e.g. a hash of document ID + position), so re-running ingestion overwrites instead of duplicating.
- **Deletions:** when a source document is deleted or its permissions change, delete or update **all** of its chunks. Keep a mapping from document ID to chunk IDs.
- **Model or chunking changes:** build a **new versioned index** in the background, evaluate it, then switch traffic with an alias (blue/green). Never mix embedding versions in one index.
- **Monitoring:** document counts per source, ingestion lag, failed parses, embedding errors, and drift in query patterns.

**What a strong answer shows:** You treat the index as a data pipeline with correctness guarantees, not a one-time script.

**Go deeper:** [[05.7 - Indexing - Incremental Freshness Deduplication]]

---

## Section I: Advanced patterns

### Q23. What are Agentic RAG, Corrective RAG, Self-RAG and GraphRAG?

**Answer**
- **Agentic RAG:** retrieval becomes a *tool* the agent chooses to call, possibly several times, with different queries or sources (vector store, SQL, web). Good for complex, multi-hop questions. Costs more latency and more variance.
- **Corrective RAG (CRAG):** after retrieving, **grade** the results for relevance. If they're poor, rewrite the query, try another source (e.g. web search), or abstain. Loops are capped.
- **Self-RAG:** the model decides *when* to retrieve and critiques its own output (relevance and support) with special reflection steps. In practice, teams often implement the idea with explicit grader nodes rather than a specially trained model.
- **GraphRAG (e.g. Microsoft's approach):**
  - Use an LLM to extract **entities and relationships** into a knowledge graph.
  - Cluster the graph into communities and summarise each one.
  - Answer "global" questions ("What are the main themes across all these reports?") from those summaries, and local questions by walking the graph.
  - Strong for connected, entity-heavy data and broad summary questions; expensive to build and maintain.
- **Multi-hop retrieval:** questions needing facts from several documents chained together ("Who manages the team that owns service X?"). Decompose the question, or let an agent iterate.

**Likely follow-ups**
- *When would you not use agentic RAG?* When most questions are simple lookups. A fixed pipeline is faster, cheaper, easier to evaluate, and more predictable. Add agency only for the query types that need it, often behind a router.

**What a strong answer shows:** Awareness of the patterns *and* the judgement to use the simplest one that meets the need.

**Go deeper:** [[09.1 - Knowledge Graphs and GraphRAG]] · [[12.4 - GraphRAG in Practice]] · [[09 - Agent Patterns and LangGraph]]

---

### Q24. Design question: build a RAG system for 10M internal documents across 5,000 employees with varied permissions.

**Answer outline** (state assumptions, then go layer by layer)
- **Requirements:** p95 latency under ~3 s to first token, permission-correct results, freshness within 1 hour, citations, and evaluation.
- **Ingestion:**
  - Connectors per source feed a queue (SQS/Kafka) and a parsing worker pool. Use idempotent, hash-based change detection.
  - Dead-letter queue (DLQ) for failed parses: a separate queue holding messages that kept failing, for inspection and replay.
- **Processing:** structure-aware chunking with contextual headers; embedding workers with batching, rate limiting and retries; ACL metadata copied onto every chunk.
- **Storage:** OpenSearch (or Postgres + pgvector) for BM25 + HNSW + filters, with indexes partitioned by source or tenant. An object store holds the originals.
- **Query:**
  1. The auth service resolves the user's groups.
  2. Rewrite the query and extract filters.
  3. Hybrid retrieval *with a mandatory ACL filter*, then RRF, then a cross-encoder reranker.
  4. Generate with citations, then output guards, then stream.
- **Scale:** cache embeddings for popular queries; semantic cache for repeated questions; autoscale embedding and reranker services; tune HNSW efSearch.
- **Quality:** golden set per department; CI eval gates; feedback loop; dashboards for retrieval and faithfulness metrics.
- **Operations:** tracing per request, cost per query, permission-sync monitoring, versioned indexes with blue/green cutover.

**What a strong answer shows:** You structure the problem (requirements → data flow → scale → quality → operations), and you put security and evaluation in from the start, not as afterthoughts.

**Go deeper:** [[11.4 - Multi-Tenant RAG Platform]] · [[09.2 - Enterprise Search and Permission-Aware Retrieval]]

---

## Further reading
- [Anthropic: Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval): chunking, BM25, hybrid search and reranking, with measured gains.
- [Pinecone: HNSW explained](https://www.pinecone.io/learn/series/faiss/hnsw/): a visual walk-through of the algorithm and its parameters.

---

**Next:** [[03 - Agentic AI and Production LLMOps]]
