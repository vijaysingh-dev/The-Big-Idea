# 01 — LLM Internals That Matter

You don't need to derive attention gradients. You need the ~10 mechanical facts that explain every weird behaviour, every cost surprise, and every design decision downstream.

---

## Mental model

An LLM is a **pure function** with a very long argument:

```
f(token_sequence) -> probability distribution over ~100k–200k possible next tokens
```

Text generation is calling that function in a loop, appending the sampled token each time (**autoregressive** decoding — each output token becomes part of the input for the next step).

Three consequences you should internalise now, because most interview answers reduce to them:

1. **It is stateless.** "Memory", "conversation", "the agent remembers" — all illusions built by re-sending previous text on every call. Chat history is just a growing prompt.
2. **It has no notion of truth**, only of *likely continuation*. Nothing in the architecture distinguishes "recalling a fact" from "producing a plausible-looking string".
3. **Cost and latency are functions of token counts**, not of "difficulty". A 50-page prompt with a one-word answer is expensive; a one-line prompt generating 3 pages is slow.

---

## 1. Tokens — the unit of everything

Models don't see characters or words. Text is split into **tokens** (subword units produced by a BPE-style tokenizer — Byte Pair Encoding, a compression scheme that merges frequent character pairs into single symbols).

Rules of thumb for English: **1 token ≈ 4 characters ≈ 0.75 words**; 1000 tokens ≈ 750 words ≈ 1.5 pages. Code is denser (more tokens per character). Non-Latin scripts are much worse — Hindi or Chinese text can cost 2–4× more tokens for the same meaning, which is a real cost and context-budget issue for Indian-market products.

```python
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")

for s in ["hello world",
          "unbelievable",
          "def get_user_by_id(user_id: int) -> User:",
          "नमस्ते दुनिया",
          "1234567890"]:
    ids = enc.encode(s)
    print(f"{len(ids):3d} tokens | {[enc.decode([i]) for i in ids]}")
```

Run it. You'll see `unbelievable` splits into pieces, numbers fragment unpredictably, and the Hindi string explodes. Why this matters in practice:

- **Chunk sizes must be measured in tokens, not characters.** A "1000 character" chunk is a different size for code, prose and Hindi. Every chunker in file 04 takes a token counter.
- **Arithmetic and exact-string bugs** often trace back to tokenization: `1234567890` may split as `123`, `456`, `789`, `0`, so the model isn't "seeing" digits the way you are.
- **Cost estimation** is token counting. Do it before you ship, not after the bill.
- Truncation happens at token boundaries — silently cutting your context if you overflow.

---

## 2. Context window — the hard limit, and the soft one

The **context window** is the maximum number of tokens (prompt + generated output) the model can attend to in one call. Modern models range from 8k to 1M+.

There are two limits:

- **Hard limit:** exceed it and the API errors (or silently truncates, which is worse).
- **Soft limit — this is the interview answer:** models degrade well before the hard limit. The **"lost in the middle"** effect: information placed in the middle of a long context is retrieved much less reliably than information at the beginning or end. A model with 200k context is not a model that *uses* 200k tokens equally well.

Why this exists mechanically: self-attention compares every token to every other token, so compute grows **O(n²)** with sequence length. Long-context models use tricks (sparse attention, positional interpolation) that trade fidelity for length.

### The cost/latency shape of one call

An LLM call has two phases:

| Phase | What happens | Scales with | Parallel? |
|-------|--------------|-------------|-----------|
| **Prefill** | Reads your entire prompt, builds the KV cache | prompt length | Yes — fast, GPU-saturating |
| **Decode** | Generates output tokens one at a time | output length | No — inherently sequential |

The **KV cache** is the stored key/value attention tensors for tokens already processed, so each new token doesn't recompute the whole sequence. It's why generation is ~linear rather than quadratic per token — and why long prompts consume GPU *memory*, not just compute.

Practical consequences:

- **Time to first token (TTFT)** is dominated by prompt length → streaming exists to hide it.
- **Total time** is dominated by output length → asking for a 3000-token JSON blob is slow no matter how small the prompt is. Ask for less output.
- **Prompt caching** (offered by most providers): if the *prefix* of your prompt is identical across calls, the provider reuses the KV cache and charges ~10% for those tokens. This is why you put static instructions **first** and the variable user content **last**. It is a free 3–5× cost reduction on RAG systems with big system prompts, and mentioning it signals production experience.

### "Why not just put all documents in a 1M-token context and skip RAG?"

This is a top-5 interview question. The answer has four legs:

1. **Cost** — you pay per token, per call. 500k tokens per query at $0.15/1M input = $0.075 *per question*. At 10k queries/day that's $750/day for something RAG does for a few dollars.
2. **Latency** — prefill of 500k tokens is seconds, before a single output token appears.
3. **Accuracy** — lost-in-the-middle; retrieval acts as a precision filter that raises signal.
4. **Freshness and scale** — your corpus is 50GB, not 1MB. Context windows don't index; they don't do incremental updates or access control either.

Correct nuance to add: *for small corpora (< ~100k tokens) that fit comfortably, long context often beats RAG and is much simpler. Don't build a vector database for a 30-page handbook.* Saying that shows judgment rather than dogma.

---

## 3. Sampling — where non-determinism comes from

The model outputs **logits** (raw scores per token), turned into probabilities via softmax. How you pick from that distribution is decoding:

| Parameter | What it does | When to use |
|-----------|--------------|-------------|
| `temperature` | Scales logits before softmax. 0 → always take the top token; higher → flatter distribution, more variety | **0 for extraction, classification, RAG answers, tool calls.** 0.7–1.0 for brainstorming/creative |
| `top_p` (nucleus) | Sample only from the smallest set of tokens whose probabilities sum to `p` | 0.9–1.0; leave alone if you're setting temperature |
| `top_k` | Sample only from the k most likely tokens | Rarely needed alongside top_p |
| `frequency/presence_penalty` | Discourage repeats | Long-form generation loops |
| `max_tokens` | Hard stop on output | Always set it — it's your latency and cost circuit breaker |
| `stop` | Sequences that end generation | Structured/agent formats |
| `seed` | Requests reproducibility | Best-effort only |

**Temperature 0 is not deterministic in practice.** Batching on the provider side, floating-point non-associativity across GPU kernels, and model version updates all introduce variation. Never write a test that asserts exact string equality on LLM output — assert on structure, on a checked property, or on a judge score with a threshold. This single point is a very strong signal in interviews because it's the first thing that breaks people's CI.

### Logprobs — the underused debugging tool

Most APIs can return the log-probability of chosen tokens. Uses:

- **Confidence estimation**: low mean logprob on an answer correlates with hallucination.
- **Classification**: instead of parsing "yes"/"no" text, compare the probability of the `yes` vs `no` token — a calibrated score you can threshold.
- **Debugging**: see whether the model was torn between two answers.

```python
resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "Is the sky blue? Answer yes or no."}],
    logprobs=True, top_logprobs=5, max_tokens=1, temperature=0,
)
for lp in resp.choices[0].logprobs.content[0].top_logprobs:
    print(f"{lp.token!r:10} logprob={lp.logprob:.3f}")
```

---

## 4. The message format, and what actually influences the model

```python
messages = [
    {"role": "system",    "content": "Rules, persona, output contract. Static."},
    {"role": "user",      "content": "Turn 1"},
    {"role": "assistant", "content": "Reply 1"},
    {"role": "user",      "content": "Turn 2 (+ retrieved context in RAG)"},
]
```

Under the hood these are concatenated with special tokens into one string. Roles are a *convention the model was fine-tuned on*, not an enforcement mechanism — which is exactly why prompt injection works: retrieved text sitting in the user turn can say "ignore previous instructions" and there is no memory-protection boundary to stop it. (More in file 07.)

What actually moves the needle, in rough order of effect:

1. **Giving it the right information** (retrieval quality) — dwarfs everything else.
2. **A precise output contract** — "Return JSON matching this schema. If the answer isn't in the context, return `{"answer": null}`."
3. **Few-shot examples** — 2–5 examples of input→output beat three paragraphs of description, especially for formatting and edge-case behaviour.
4. **Explicit reasoning space** — "think step by step before answering" helps on multi-step tasks; on modern reasoning models it's often built in and adding it can hurt.
5. **Persona fluff** ("You are a world-class expert...") — mostly noise. Spend the tokens on rules.

### Structured output

Three levels, use the strongest available:

```python
# Level 3 — constrained decoding: provider guarantees schema-valid JSON
from pydantic import BaseModel

class Answer(BaseModel):
    answer: str | None
    citations: list[int]
    confidence: float

resp = client.chat.completions.parse(   # or response_format={"type":"json_schema", ...}
    model="gpt-4o-mini",
    messages=[...],
    response_format=Answer,
)
```

Level 2 is `response_format={"type": "json_object"}` (valid JSON, unchecked shape); level 1 is "please return JSON" + parse + retry. Constrained decoding works by masking the logits of tokens that would make the output invalid at each step — the model *cannot* emit a bad token. Knowing that mechanism is a nice depth signal.

---

## 5. Tool calling — the entire basis of agents

The model doesn't execute anything. It emits a **structured request** to call a function, you execute it, and you feed the result back. That's the whole mechanism.

```python
tools = [{
    "type": "function",
    "function": {
        "name": "get_order_status",
        "description": "Look up the current status of a customer order by ID.",
        "parameters": {
            "type": "object",
            "properties": {"order_id": {"type": "string", "description": "e.g. ORD-1234"}},
            "required": ["order_id"],
        },
    },
}]

msgs = [{"role": "user", "content": "Where is order ORD-1234?"}]
r1 = client.chat.completions.create(model=MODEL, messages=msgs, tools=tools)

call = r1.choices[0].message.tool_calls[0]      # name + JSON arguments
result = get_order_status(**json.loads(call.function.arguments))

msgs += [r1.choices[0].message,
         {"role": "tool", "tool_call_id": call.id, "content": json.dumps(result)}]
r2 = client.chat.completions.create(model=MODEL, messages=msgs, tools=tools)
print(r2.choices[0].message.content)
```

Points senior engineers make about this:

- The **description strings are the API contract for a non-deterministic caller**. Bad descriptions are the #1 cause of wrong tool selection. Write them like docs for a junior with no context.
- **Fewer tools = better accuracy.** Beyond ~10–15 tools, selection accuracy degrades sharply; the fix is hierarchical routing or retrieving the relevant tool subset per query.
- **The model will hallucinate arguments.** Validate with a schema before execution, and never let a tool call reach a destructive operation without an idempotency key or confirmation step.
- Tool results re-enter the context — a tool returning 50k tokens of JSON will blow your budget. Truncate and summarize tool outputs.

---

## 6. Why hallucination happens (mechanical answer)

Say: *"The model is trained to produce the most likely continuation, and it's never trained to output 'I don't know' as often as the truth requires. Fluent text with the right shape is high probability whether or not it's factually grounded — there's no internal fact-check step."*

Contributing factors:
- **Knowledge gaps** — the fact was never in training data, or is post-cutoff.
- **Retrieval failure** — the fact wasn't in the context you provided (the dominant cause in RAG).
- **Conflicting context** — two retrieved chunks disagree; the model picks one, confidently.
- **Instruction pressure** — "Answer the question" without an escape hatch forces invention.
- **Sampling** — high temperature broadens the distribution to less-likely (less-true) tokens.

Mitigation ladder, cheapest first:
1. Retrieve better (file 05) — most of the win.
2. Temperature 0 and an explicit escape hatch: *"If the context does not contain the answer, say 'Not found in the provided documents.'"*
3. **Force citations** — require the model to attach the chunk id supporting each claim, then verify programmatically that the ids exist and the claim's key terms appear there.
4. **Groundedness check** — a second call (or an NLI model — Natural Language Inference, a classifier that judges whether text B is entailed by text A) that verifies each sentence against the context.
5. Fine-tuning for domain style/format — helps tone, not facts.

Correct framing to state explicitly: **hallucination cannot be eliminated, only reduced and detected.** Systems that need guarantees put a human or a deterministic verifier in the loop.

---

## 7. RAG vs fine-tuning vs prompting — the decision table

| Need | Use | Why |
|------|-----|-----|
| New/private/changing **facts** | RAG | Update by re-indexing; attributable; access-controllable |
| Consistent **format, tone, or style** | Fine-tuning (LoRA) | Behaviour, not knowledge |
| Better performance on a **narrow repeated task** | Fine-tune a small model | Cheaper + faster than a big model at scale |
| Fix a one-off behaviour | Prompt / few-shot | Minutes, not days |
| Reduce cost at high volume | Distill: big model generates data → fine-tune small model | 10–50× cost drop |

**LoRA** = Low-Rank Adaptation: you freeze the base model and train small adapter matrices, so fine-tuning costs a fraction of full training and adapters can be swapped per tenant.

The senior answer to "RAG or fine-tune?" is: *"They solve different problems and they compose. Fine-tuning teaches behaviour, RAG supplies knowledge. If the complaint is 'it doesn't know our data', that's RAG. If it's 'it knows but answers in the wrong shape', that's prompting first, then fine-tuning. And I'd never fine-tune before I had an eval set, because I couldn't tell if it helped."*

---

## 8. Cost and latency math you should be able to do live

Given: prompt 4,000 tokens, output 300 tokens, price $0.15/1M input and $0.60/1M output.

```
input  : 4000  / 1e6 * 0.15 = $0.00060
output :  300  / 1e6 * 0.60 = $0.00018
per call ≈ $0.00078  →  ~$0.78 per 1,000 queries  →  at 100k queries/day ≈ $78/day
```

Latency estimate: TTFT ≈ 0.3–1.0s for a few thousand prompt tokens; generation ≈ 30–100 tokens/sec → 300 tokens ≈ 3–10s. **So output length, not prompt length, usually owns your p95.**

Levers, in the order you'd actually pull them:
1. Shorter outputs (structured JSON instead of prose).
2. Prompt caching for the static prefix.
3. Smaller/cheaper model for easy queries (routing).
4. Semantic caching of whole answers for repeat questions.
5. Fewer retrieved chunks (rerank to top-3 instead of stuffing top-20).
6. Streaming — doesn't reduce cost but transforms perceived latency.

---

## Open source to read (30 minutes well spent)

- **`tiktoken`** (github.com/openai/tiktoken) — `tiktoken/core.py` is small; see how BPE merges work.
- **`vllm`** (github.com/vllm-project/vllm) — read the PagedAttention section of the README. It explains KV cache memory management the way an OS explains virtual memory, and gives you excellent vocabulary for infra questions.
- **`outlines`** (github.com/dottxt-ai/outlines) — constrained/structured generation. Skim `outlines/fsm/` to see logit masking made concrete.

---

## Exercises (tomorrow, ~45 minutes)

1. **Tokenizer forensics.** Tokenize: an English paragraph, the same paragraph in Hindi, a Python file, a UUID, and a table of numbers. Record tokens-per-character for each. Write down what that implies for chunk size and cost in a multilingual product.
2. **Context budget calculator.** Write `budget(system, history, chunks, max_output, limit)` that returns whether the call fits and how many chunks you must drop. Every real RAG system has this function; most tutorials don't.
3. **Temperature sweep.** Same prompt at temperature 0, 0.7, 1.5, 10 runs each. Measure output distinct-ratio. Then run temperature 0 ten times and check whether outputs are byte-identical.
4. **Logprob confidence.** Ask 10 questions — 5 answerable, 5 nonsense ("What is the capital of Gondwanaland Prime?"). Compare mean logprob of the answers. Does confidence separate them?
5. **Tool loop by hand.** Implement the two-turn tool-calling flow above with a fake `get_order_status`. Then deliberately give the tool a vague description and observe the model picking it wrongly.

---

## Interview questions (answer out loud)

1. What is a token, and why does it matter to a RAG system? *(chunk sizing, cost, truncation)*
2. Why is generation slower than prompt processing? *(sequential decode vs parallel prefill; KV cache)*
3. Temperature 0 — is the model deterministic? *(no; batching, fp non-associativity, model updates)*
4. Why not skip RAG and use a 1M context window? *(cost, latency, lost-in-the-middle, scale, freshness — plus the nuance that for small corpora you should)*
5. How do you get reliable JSON out of an LLM? *(constrained decoding > json mode > parse+retry; validate with pydantic; repair loop)*
6. How does tool calling actually work? *(model emits structured request; your code executes; result fed back; roles are convention not sandbox)*
7. Why do models hallucinate, and how do you reduce it? *(the mechanical answer + the mitigation ladder + "you can only reduce and detect")*
8. RAG or fine-tuning? *(knowledge vs behaviour; they compose; eval first)*
9. Estimate the monthly cost of a RAG chatbot with 5k queries/day. *(do the arithmetic out loud — most candidates can't)*
10. What's prompt caching and how does it change how you write prompts? *(static prefix first, variable content last)*

---

## Resources

- **Anthropic's prompt engineering docs** — https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview — the most practically useful prompting reference; the structured-output and tool-use pages double as design guidance.
- **"The Illustrated Transformer"** by Jay Alammar — https://jalammar.github.io/illustrated-transformer/ — the canonical visual explanation of attention. One read is enough for the depth you need.
- Optional depth: **vLLM / PagedAttention paper** — https://arxiv.org/abs/2309.06180 — for serving, batching and KV-cache memory questions.
