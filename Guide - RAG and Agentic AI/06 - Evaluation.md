# 06 — Evaluation

This is the file that decides your interview. Almost every candidate can describe RAG. Very few can answer *"how did you know it got better?"* with anything except "it seemed better in testing".

Evaluation is also what makes your capstone leaderboard meaningful — without it, the chunking sweep in file 04 is just a script that prints numbers.

---

## Mental model

You are working on a system whose output is **fluent, confident, and frequently wrong**. Fluency is precisely the property that makes human spot-checking unreliable — a wrong answer *reads* as well as a right one. Vibes-based development in this domain doesn't just fail; it fails while feeling like success.

So: **build the eval before the optimization.** Everything in files 04, 05 and 07 is a knob, and a knob without a gauge is a random number generator.

Frame it for the interview using language you already own: *"An eval set is a test suite for a non-deterministic function. It doesn't assert equality — it asserts that aggregate quality metrics stay above a threshold. Same role in CI, same regression-catching purpose, different assertion."*

### Evaluate components, not just the whole

End-to-end scores tell you *that* something is wrong. Component scores tell you *where*.

```
Retrieval eval   →  did we fetch the right chunks?        (fast, cheap, deterministic)
Generation eval  →  given those chunks, was the answer good?  (slower, needs a judge)
End-to-end eval  →  did the user get a correct answer?     (what actually matters)
```

Run retrieval eval on every commit — it's free and it catches most regressions. Run generation eval nightly or per-PR on a smaller sample.

---

## 1. The golden dataset

Everything rests on this. 30–50 examples is enough to start and enough to be useful; 200+ is production-grade.

Each example:

```python
@dataclass
class GoldenExample:
    question: str
    ground_truth: str                 # the reference answer
    relevant_chunk_ids: list[str]     # or answer substrings, if ids aren't stable yet
    source_doc: str
    category: str                     # factual | multi_hop | comparison | negation | unanswerable
    difficulty: str                   # easy | medium | hard
```

### Building it fast (the practical recipe)

**Step 1 — Synthesize.** Sample chunks from your corpus and have an LLM generate a question each chunk answers. This gives you volume in minutes.

```python
GEN = """Given this document excerpt, write one specific question that it answers, and the answer.
The question must be answerable from this excerpt alone and must not refer to "the document" or
"this excerpt". Return JSON: {{"question": ..., "answer": ...}}

Excerpt:
{chunk}"""


def synthesize(chunks, n=60):
    examples = []
    for chunk in random.sample(chunks, n):
        data = json.loads(llm(GEN.format(chunk=chunk.embed_text)))
        examples.append(GoldenExample(
            question=data["question"], ground_truth=data["answer"],
            relevant_chunk_ids=[chunk.id], source_doc=chunk.doc_id,
            category="factual", difficulty="easy",
        ))
    return examples
```

**Step 2 — Hand-verify every one.** Non-negotiable, and it's an hour of work for 60 examples. Synthetic questions have a systematic bias: they're phrased in the document's own vocabulary, so retrieval looks artificially easy. An unverified golden set will happily tell you your system is excellent while users suffer.

**Step 3 — Add the hard categories manually.** These are where systems break and where synthetic generation never goes:

- **Multi-hop** — needs two or more documents.
- **Negation / contrast** — "which regions are *not* covered".
- **Comparison** — "how does X differ from Y".
- **Aggregation** — "how many...", "list all...".
- **Temporal** — "what changed in the 2024 version".
- **Unanswerable** — the answer genuinely isn't in the corpus. **Include ~10–15% of these.** The correct behaviour is refusal, and a system that never refuses is a system that hallucinates. If your eval set has no unanswerable questions, you are not measuring your biggest risk.
- **Real user queries** — as soon as you have logs, mine them. They look nothing like synthetic ones.

**Step 4 — Freeze it and version it.** Check it into the repo as JSONL. When you change the golden set, that's a new version and old numbers aren't comparable. Keep a small **held-out** slice you don't look at during tuning, or you'll overfit the eval the same way you'd overfit a training set.

---

## 2. Retrieval metrics

These are classic IR metrics — cheap, deterministic, no LLM needed. Run them constantly.

| Metric | Question it answers | When to use |
|---|---|---|
| **Hit rate @k** | Did *any* relevant chunk appear in top-k? | Blunt but interpretable; good headline number |
| **Recall@k** | What fraction of all relevant chunks did we find? | The main candidate-generation metric |
| **Precision@k** | What fraction of returned chunks were relevant? | Context efficiency / noise |
| **MRR** | How high was the *first* relevant result? | Great when there's one right answer |
| **nDCG@k** | Ranking quality with graded relevance and position discounting | The most complete ranking metric |
| **MAP** | Precision averaged over recall points | Multi-relevant-document settings |

```python
# raglab/eval/retrieval.py
import numpy as np


def hit_rate(retrieved: list[str], relevant: set[str]) -> float:
    return float(bool(set(retrieved) & relevant))


def recall_at_k(retrieved: list[str], relevant: set[str], k: int) -> float:
    return len(set(retrieved[:k]) & relevant) / max(len(relevant), 1)


def precision_at_k(retrieved: list[str], relevant: set[str], k: int) -> float:
    return len(set(retrieved[:k]) & relevant) / k


def mrr(retrieved: list[str], relevant: set[str]) -> float:
    for rank, doc_id in enumerate(retrieved, start=1):
        if doc_id in relevant:
            return 1.0 / rank
    return 0.0


def ndcg_at_k(retrieved: list[str], relevance: dict[str, float], k: int) -> float:
    gains = [relevance.get(doc_id, 0.0) for doc_id in retrieved[:k]]
    # Position discount: a relevant result at rank 5 is worth less than the same result at rank 1.
    dcg = sum(g / np.log2(i + 2) for i, g in enumerate(gains))
    ideal = sorted(relevance.values(), reverse=True)[:k]
    idcg = sum(g / np.log2(i + 2) for i, g in enumerate(ideal))
    return dcg / idcg if idcg else 0.0


def evaluate_retrieval(retriever, golden, k: int = 5) -> dict:
    rows = []
    for ex in golden:
        got = [c.id for c, _ in retriever.search(ex.question, k=max(k, 50))]
        relevant = set(ex.relevant_chunk_ids)
        rows.append({
            f"hit@{k}": hit_rate(got[:k], relevant),
            f"recall@{k}": recall_at_k(got, relevant, k),
            f"precision@{k}": precision_at_k(got, relevant, k),
            "recall@50": recall_at_k(got, relevant, 50),
            "mrr": mrr(got, relevant),
        })
    return {key: round(float(np.mean([r[key] for r in rows])), 3) for key in rows[0]}
```

Report **recall@5 alongside recall@50** — as file 05 explained, the gap tells you whether to fix candidate generation or ranking. Reporting both unprompted in an interview is a strong signal.

---

## 3. Generation metrics — the RAG triad

Retrieval metrics can't tell you whether the answer was any good. For that you need judgment, which in practice means an LLM (or a human, at 1000× the cost).

| Metric | Definition | Catches |
|---|---|---|
| **Faithfulness / groundedness** | Fraction of claims in the answer that are supported by the retrieved context | Hallucination — **the most important one** |
| **Answer relevancy** | Does the answer address the question asked? | Evasive, off-topic, or padded answers |
| **Context precision** | Are the retrieved chunks that were used ranked highly? | Noisy retrieval |
| **Context recall** | Did the context contain everything needed for the ground-truth answer? | Retrieval gaps |
| **Answer correctness** | Semantic agreement with the reference answer | Overall quality |

Note the clean separation: **context precision/recall grade the retriever; faithfulness grades the generator; answer correctness grades the system.** When correctness drops, the other three tell you which half to look at.

### Faithfulness, implemented from scratch

Worth writing yourself once — it's how you'll explain it in an interview.

```python
CLAIMS = """Break the answer into atomic factual claims, one per line, no numbering.
Answer: {answer}"""

VERIFY = """Context:
{context}

Claim: {claim}

Is the claim fully supported by the context? Reply with exactly one word: SUPPORTED or UNSUPPORTED."""


def faithfulness(answer: str, context: str) -> float:
    claims = [c.strip() for c in llm(CLAIMS.format(answer=answer)).split("\n") if c.strip()]
    if not claims:
        return 1.0
    supported = sum(
        llm(VERIFY.format(context=context, claim=c)).strip().upper().startswith("SUPPORTED")
        for c in claims
    )
    return supported / len(claims)
```

Decomposing into atomic claims before judging is the important detail: asking "is this whole paragraph faithful?" gets you mush, because most answers are 80% grounded and 20% invented.

### Using RAGAS

```python
from datasets import Dataset
from ragas import evaluate
from ragas.metrics import (answer_correctness, answer_relevancy,
                           context_precision, context_recall, faithfulness)

data = Dataset.from_dict({
    "question":     [ex.question for ex in golden],
    "answer":       [run_rag(ex.question)["answer"] for ex in golden],
    "contexts":     [[c.context_text for c in run_rag(ex.question)["chunks"]] for ex in golden],
    "ground_truth": [ex.ground_truth for ex in golden],
})

result = evaluate(data, metrics=[faithfulness, answer_relevancy,
                                 context_precision, context_recall, answer_correctness])
print(result)
```

RAGAS is the standard toolkit and is fine to use — but implement faithfulness by hand at least once so you can explain what it's doing rather than citing a library.

---

## 4. LLM-as-judge — how to do it without fooling yourself

Using an LLM to grade LLM output is standard practice and genuinely works, but it has known biases. Naming them is a strong depth signal:

| Bias | Effect | Mitigation |
|---|---|---|
| **Position bias** | Prefers whichever answer is shown first in pairwise comparison | Run both orders, average |
| **Verbosity bias** | Rates longer answers higher | Control for length; instruct explicitly |
| **Self-preference** | Prefers text from the same model family | Judge with a different model than the generator |
| **Score clustering** | Everything gets 4/5 on a 1–5 scale | Use binary or 3-point scales, with rubric definitions |
| **Sycophancy to the prompt** | Agrees with framing in the question | Neutral wording; don't hint at the expected answer |

Rules that make judges usable:

1. **Binary or 3-point, with an explicit rubric**, beats a 1–10 scale every time.
2. **Require reasoning before the verdict** — it improves accuracy and gives you something to debug.
3. **Reference-based beats reference-free.** Give the judge the ground-truth answer where you have it.
4. **Calibrate against humans.** Label 50 examples yourself, compute agreement with your judge, and report it. *"My judge agrees with my own labels 88% of the time"* is a sentence that ends the argument about whether the eval is trustworthy.
5. **Temperature 0, fixed prompt, versioned.** Judge prompt changes invalidate historical scores — treat the judge prompt as part of the eval's version.

```python
JUDGE = """You are grading an answer against a reference. Be strict.

Question: {question}
Reference answer: {reference}
Candidate answer: {candidate}

First give one sentence of reasoning. Then on a new line output exactly one of:
VERDICT: CORRECT
VERDICT: PARTIALLY_CORRECT
VERDICT: INCORRECT"""
```

---

## 5. Wiring it into CI, and into production

### Offline: the regression gate

```python
# raglab/eval/gate.py
THRESHOLDS = {"recall@5": 0.70, "mrr": 0.60, "faithfulness": 0.85}

def gate(results: dict) -> int:
    failures = [f"{m}: {results[m]:.3f} < {t}" for m, t in THRESHOLDS.items() if results[m] < t]
    for f in failures:
        print("FAIL", f)
    return 1 if failures else 0
```

Run retrieval metrics on every PR (seconds, free). Run the full generation eval nightly and before releases. Store every run's results with the config that produced it — the artifact you want is a CSV where each row is `(commit, config, metrics)`, so any regression can be bisected.

Important nuance to raise: with 40 examples, a 2-point change is noise. Either report confidence intervals (bootstrap over examples) or set thresholds loose enough that only real regressions trip them. Claiming a 1% improvement on 40 questions is exactly the kind of thing a good interviewer will push back on — get ahead of it.

### Online: what you measure once real users arrive

Offline evals go stale because they don't contain your users' actual questions.

- **Implicit signals:** thumbs up/down, copy events, follow-up rephrasing (a strong negative signal), conversation abandonment, click-through on citations.
- **Explicit feedback** with a reason code, funneled straight into the golden set. **Every reported failure becomes a permanent test case** — this is the flywheel, and it's the answer to "how does your system improve over time".
- **Guardrail metrics:** refusal rate, citation-validity rate, p95 latency, cost per query, retrieved-score distribution (a sudden shift means your index or embedding pipeline broke).
- **A/B testing** for anything user-visible; offline wins don't always survive contact with users.
- **Shadow evaluation:** run the new pipeline alongside the old on live traffic, compare outputs, ship nothing. The safest way to validate a retrieval change at scale.

---

## 6. Pitfalls

1. **No unanswerable questions in the eval set** → you never measure hallucination on out-of-scope queries, which is the failure users complain about loudest.
2. **Synthetic questions only** → vocabulary leakage makes retrieval look better than it is.
3. **Optimizing a single number.** Recall@5 goes up, latency triples and cost doubles. Always report quality *with* cost and latency in the same table — your capstone leaderboard already does.
4. **Overfitting the eval set** by tuning against it 40 times. Keep a held-out slice.
5. **Changing the golden set and comparing across versions.** Version it like a schema.
6. **Judging without a rubric**, then wondering why scores are all 4/5.
7. **Evaluating end-to-end only**, so you never learn whether retrieval or generation broke.
8. **Ignoring variance.** Re-run the same config twice; if the metric moves by 3 points on its own, your reported 2-point improvement means nothing.

---

## Open source to read

- **RAGAS** (github.com/explodinggradients/ragas) — read `ragas/metrics/_faithfulness.py`. The claim-decomposition-then-verify structure is exactly what you implemented above.
- **Ragas / LlamaIndex test-set generators** — see how they sample chunks and build multi-hop questions from document graphs; useful ideas for hardening your own golden set.
- **`trulens`** (github.com/truera/trulens) — the source of the "RAG triad" framing, with instrumentation hooks for per-stage feedback functions.

---

## Exercises (tomorrow, ~60 minutes, then it runs forever)

1. **Build 40 golden examples**: 25 synthetic + verified, 10 hand-written hard ones (multi-hop, negation, comparison), 5 unanswerable. Save as JSONL, check it in.
2. **Implement the retrieval metrics** above and wire them into your chunking sweep from file 04. Your leaderboard now has recall@5, recall@50 and MRR per strategy.
3. **Implement faithfulness by hand** (claim decomposition + verification). Run it on 10 answers.
4. **Test the unanswerable path.** What's your refusal rate on the 5 unanswerable questions? If it's below 100%, that's your hallucination rate on out-of-scope queries — a number you can quote.
5. **Calibrate your judge.** Hand-label 20 answers as correct/incorrect, run the judge, compute agreement. Report the number.
6. **Measure variance.** Run the identical config three times. Record the spread. Now you know what size of improvement is real.
7. **Build the results table**: every experiment appends a row with config + all metrics + ingest time + p95 latency + estimated cost per 1k queries. This table is your interview exhibit.

---

## Interview questions

1. How do you evaluate a RAG system? *(component-level: retrieval metrics + generation metrics + end-to-end; golden set; offline gates + online signals)*
2. What's in your golden dataset and how did you build it? *(synthetic + human-verified + hard categories + unanswerable; versioned; mined from real logs over time)*
3. Which retrieval metrics and why? *(recall@k for candidate generation, MRR/nDCG for ranking; recall@5 vs recall@50 to localize the problem)*
4. How do you measure hallucination? *(faithfulness: decompose the answer into atomic claims, verify each against context; plus citation validity checks; plus refusal rate on unanswerable questions)*
5. Is LLM-as-judge trustworthy? *(usable with rubrics, binary scales, reasoning-before-verdict, a different model than the generator; named biases; calibrate against human labels and report agreement)*
6. Your recall@5 improved 2 points. Ship it? *(not without knowing variance and sample size; check the cost/latency columns; check it didn't come from overfitting the eval set)*
7. How does evaluation run in CI? *(retrieval metrics per PR — deterministic and cheap; generation eval nightly; thresholds as gates; results stored with config for bisection)*
8. How do you catch regressions in production? *(guardrail metrics, feedback loop into the golden set, shadow evaluation, A/B)*
9. Offline metrics improved but users complain. What happened? *(eval set doesn't match real query distribution — mine logs, rebuild the set)*
10. How big should the eval set be? *(30–50 to start, 200+ for confidence; large enough that your smallest meaningful improvement exceeds the noise floor)*

---

## Resources

- **RAGAS documentation** — https://docs.ragas.io/ — the metric definitions page is the best concise reference for faithfulness, answer relevancy, and context precision/recall.
- **Hamel Husain, "Your AI Product Needs Evals"** — https://hamel.dev/blog/posts/evals/ — the single most useful practitioner essay on this topic; the error-analysis and eval-flywheel sections are directly quotable in an interview.
