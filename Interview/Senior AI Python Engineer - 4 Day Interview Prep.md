**Budget:** 4 days × 5 hrs. **Approach:** read the topic → code it yourself → validate with Claude Code.

> **How to use each session**
> 1. **Read** the linked resources (time-boxed).
> 2. **Build** the listed deliverable on your own. No copy-paste.
> 3. **Validate** by pasting the "Claude Code review prompt" into Claude Code inside the repo.
> 4. **Explain** it out loud in 2 minutes. If you can't explain it, you're not done.

Suggested workspace: one repo, `ai-prep/`, with folders `day1-agents/`, `day2-rag/`, `day3-infra/`, `day4-drills/`.

---

## Reference repos (read + partially rebuild)

| Repo | Why it matters for this JD | Rebuild | Skim |
|---|---|---|---|
| [agent-service-toolkit](https://github.com/JoshuaC215/agent-service-toolkit) | LangGraph + FastAPI + streaming + tracing: almost exactly this stack | Service layer, `/invoke` + `/stream` endpoints, agent registry | Streamlit UI, Docker |
| [open_deep_research](https://github.com/langchain-ai/open_deep_research) | Production multi-agent LangGraph (supervisor + sub-agents) | Graph wiring, state schema, supervisor routing | Prompts, search-tool configs |
| [pr-agent](https://github.com/qodo-ai/pr-agent) | AI code review inside CI (supports Jenkins), your "AI-driven SDLC" example | Nothing; study diff fetching, token-budget compression, comment posting | Everything else |
| [full-stack-fastapi-template](https://github.com/fastapi/full-stack-fastapi-template) | Production FastAPI structure | — | Settings, dependency injection, tests, Alembic |
| [Langfuse](https://github.com/langfuse/langfuse) / [Ragas](https://github.com/explodinggradients/ragas) | Fill your observability + eval gap | Integrate into your own projects | Source code |

---

## Day 1: Agents & multi-agent orchestration

### Session 1.1: Advanced LangGraph (1.5h)
**Concepts**
- **Checkpointer:** saves graph state after each step, so a run can pause, resume, or be replayed.
- **Human-in-the-loop (HITL):** `interrupt()` pauses the graph until a human approves or edits.
- **Subgraphs:** a graph used as a node inside another graph, for modular agents.
- **`Send` API:** dynamic fan-out that spawns N parallel sub-tasks at runtime (map-reduce).
- **Supervisor vs. swarm:** a central router agent, vs. agents handing off to each other directly.

**Read**
- [ ] [LangGraph docs (concepts: persistence, HITL, multi-agent)](https://langchain-ai.github.io/langgraph/concepts/)
- [ ] [LangGraph multi-agent concepts](https://langchain-ai.github.io/langgraph/concepts/multi_agent/)
- [ ] [Anthropic: Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) (workflows vs. agents; when *not* to use agents)

### Session 1.2: CrewAI comparison (0.5h)
- [ ] [CrewAI docs: Agents, Tasks, Crews, Flows](https://docs.crewai.com/)
- [ ] Write 5 bullets: LangGraph (explicit state machine, fine control) vs. CrewAI (role-based, faster to start, less control). Know when you'd pick each.

### Session 1.3: Build a mini agent service (3h)
**Read first:** the `src/service/` and `src/agents/` folders of [agent-service-toolkit](https://github.com/JoshuaC215/agent-service-toolkit), then the graph in [open_deep_research](https://github.com/langchain-ai/open_deep_research).

**Build**
- [ ] FastAPI app with `POST /invoke` and `POST /stream`. The stream uses **SSE** (Server-Sent Events, a one-way HTTP stream for pushing tokens to the client).
- [ ] Supervisor graph with 2 workers (e.g., `researcher` with a search tool, `writer`).
- [ ] Postgres (or SQLite) checkpointer and a `thread_id` per conversation.
- [ ] A `max_steps` / recursion limit, so the agent can't loop forever.
- [ ] Langfuse tracing on every LLM and tool call.

**Resources**
- [FastAPI custom responses / StreamingResponse](https://fastapi.tiangolo.com/advanced/custom-response/)
- [Langfuse docs (LangChain/LangGraph integration)](https://langfuse.com/docs)

**Claude Code review prompt**
> Review this FastAPI + LangGraph service like a senior engineer. Check: streaming correctness and client-disconnect handling, checkpointer usage, recursion/step limits, error handling inside tool nodes, async correctness (no blocking calls in async routes), and whether tracing captures every node. List issues by severity; don't rewrite the code.

---

## Day 2: Knowledge Base, RAG evals & guardrails

### Session 2.1: Centralized KB architecture (1.5h)
**Concepts**
- **Ingestion pipeline:** connectors → parsing → chunking → embedding → index, plus incremental re-sync.
- **Hybrid search:** combines keyword search (BM25, term-frequency ranking) with vector similarity, merged with RRF (Reciprocal Rank Fusion, which combines the two ranked lists).
- **Reranker:** a cross-encoder model that re-scores the top-k results more accurately than embeddings do.
- **Metadata filtering / ACLs:** restrict retrieval to documents the user is allowed to see (an ACL is an access control list).
- **Bedrock Knowledge Bases:** the managed AWS version of this whole pipeline.

**Read**
- [ ] [Bedrock Knowledge Bases](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- [ ] [OpenSearch docs: vector search & hybrid search](https://docs.opensearch.org/)
- [ ] [Anthropic: Contextual Retrieval](https://www.anthropic.com/news/contextual-retrieval) (chunking + BM25 + rerank, with numbers)
- [ ] [Eugene Yan: Patterns for building LLM-based systems](https://eugeneyan.com/writing/llm-patterns/)

**Deliverable:** a one-page architecture diagram (draw.io or paper) of an org-wide KB. Be ready to whiteboard it.

### Session 2.2: RAG evaluation (1.5h)
**Concepts**
- **Faithfulness:** is the answer supported by the retrieved context (i.e., not hallucinated)?
- **Context precision / recall:** did retrieval return relevant chunks, and all the needed ones?
- **Answer relevancy:** does the answer actually address the question?
- **Golden dataset:** a curated set of question → expected answer/context pairs used for regression testing.
- **LLM-as-judge:** using an LLM to grade outputs. It's cheap but biased, so calibrate it against human labels.

**Read**
- [ ] [Ragas docs](https://docs.ragas.io/)
- [ ] [Hamel Husain: Your AI product needs evals](https://hamel.dev/blog/posts/evals/)

**Build (in sentinel-rag)**
- [ ] A golden dataset of 15–20 questions.
- [ ] `evals/run_ragas.py` that outputs a scores table and exits non-zero below a threshold, so it can gate CI.
- [ ] Langfuse traces on retrieval + generation, with chunk IDs logged.

### Session 2.3: Guardrails (1.5h)
**Concepts**
- **Input guardrails:** prompt-injection detection (malicious instructions hidden in user input or retrieved docs), PII redaction, topic restriction.
- **Output guardrails:** schema validation, grounding checks, toxicity filtering, refusal handling.
- **Structured output with retry:** validate the LLM's JSON with Pydantic; on failure, re-prompt with the validation error.

**Read**
- [ ] [OWASP Top 10 for LLM Applications](https://genai.owasp.org/llm-top-10/)
- [ ] [Amazon Bedrock Guardrails](https://docs.aws.amazon.com/bedrock/latest/userguide/guardrails.html)
- [ ] [NeMo Guardrails](https://github.com/NVIDIA/NeMo-Guardrails) and [Guardrails AI](https://github.com/guardrails-ai/guardrails) (skim the README for concepts)
- [ ] [Instructor (structured outputs)](https://python.useinstructor.com/)

**Build**
- [ ] A `guardrails/` module: a reusable `GuardedLLM` wrapper with pluggable input/output validators. This is your "reusable AI component" story.

### Session 2.4: Agent observability (0.5h)
- [ ] List the metrics you'd put on a dashboard: p50/p95 latency per node, tokens and cost per request, tool error rate, retry count, eval scores over time, user feedback.
- [ ] Know trace vs. span: a trace is one whole request; a span is one step inside it.

**Claude Code review prompt**
> Review my RAG eval script and guardrail module. Is the golden dataset representative? Are the metrics computed correctly? Is the guardrail wrapper actually reusable (dependency injection, no hard-coded model)? What production failure modes am I missing?

---

## Day 3: AWS, IaC & CI/CD

### Session 3.1: AWS CDK + Sceptre (1.5h)
**Concepts**
- **IaC (Infrastructure as Code):** cloud resources defined in versioned code instead of console clicks.
- **CDK:** you write Python and it generates CloudFormation. Constructs come in L1 (raw), L2 (sensible defaults), and L3 (patterns).
- **Sceptre:** a CLI that orchestrates raw CloudFormation templates across environments/stacks with config files. No code generation.

**Read**
- [ ] [CDK Workshop (Python track)](https://cdkworkshop.com/)
- [ ] [AWS CDK v2 Developer Guide](https://docs.aws.amazon.com/cdk/v2/guide/home.html)
- [ ] [Sceptre GitHub / docs](https://github.com/Sceptre/sceptre)

**Build**
- [ ] A CDK stack with S3 bucket + Lambda + API Gateway + least-privilege IAM. Run `cdk synth` and `cdk diff`.
- [ ] Write 5 bullets: CDK vs. Sceptre vs. Terraform.

### Session 3.2: boto3 production patterns (0.5h)
**Read**
- [ ] [boto3 retries config](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/retries.html)
- [ ] [boto3 paginators](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/paginators.html)
- [ ] [Bedrock Converse API](https://docs.aws.amazon.com/bedrock/latest/userguide/conversation-inference.html)

**Build:** a script that lists all S3 objects with a paginator, uses `adaptive` retry mode, and calls Bedrock `converse`.

### Session 3.3: Jenkins (2h)
**Concepts**
- **Declarative pipeline:** structured `pipeline { agent; stages; post }` syntax.
- **Agent:** where a stage runs (a node label, or a Docker container).
- **`credentials()`:** injects secrets from the Jenkins credential store without hard-coding them.
- **Shared libraries:** reusable Groovy pipeline code in a separate repo, called from many Jenkinsfiles. This is a common senior-level question.
- **Multibranch pipeline:** a separate pipeline per Git branch/PR, discovered automatically.

**Read**
- [ ] [Jenkins Pipeline syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [ ] [Jenkins Shared Libraries](https://www.jenkins.io/doc/book/pipeline/shared-libraries/)

**Build:** a `Jenkinsfile` for the Day 1 project with:
- [ ] Stages: lint → unit tests → Ragas eval gate → Docker build → push to ECR → `cdk deploy`
- [ ] `parallel` for lint + tests
- [ ] A `when { branch 'main' }` condition on deploy
- [ ] `post { always / failure }` for reports and notifications

### Session 3.4: AI-driven SDLC design (1h)
**Read**
- [ ] [pr-agent repo](https://github.com/qodo-ai/pr-agent): README + Jenkins usage section

**Deliverable:** a one-page rollout plan covering:
- AI PR review in Jenkins.
- AI-generated unit tests.
- A repo-aware assistant on top of the KB.
- A shared prompt/template library.
- Metrics: PR cycle time, review turnaround, escaped defects.
- Risks: hallucinated code, secrets leaking into prompts, over-trusting AI review, cost.

**Claude Code review prompt**
> Review my CDK stack and Jenkinsfile. Check IAM least privilege, secret handling, idempotent deploys, stage ordering, failure handling, and what's missing for a production pipeline.

---

## Day 4: Coding drills, system design, stories

### Session 4.1: Backend coding drills (2.5h, 15–20 min each, timed)

**General backend**
- [ ] **Retry with exponential backoff + jitter** (decorator, sync + async). Jitter is randomness added to the wait so clients don't all retry at once (a "thundering herd"). [AWS Builders' Library](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
- [ ] **Rate limiter:** token bucket + sliding window log. [Stripe: Scaling rate limiters](https://stripe.com/blog/rate-limiters)
- [ ] **LRU cache with TTL** (entries expire after a time limit), using `OrderedDict`.
- [ ] **Circuit breaker:** closed/open/half-open states that stop calling a failing dependency during a cooldown. [Martin Fowler](https://martinfowler.com/bliki/CircuitBreaker.html)
- [ ] **Bounded concurrency:** `asyncio.Semaphore` + `gather`, plus a fixed worker pool.
- [ ] **Producer-consumer** with `asyncio.Queue` + graceful shutdown. [asyncio queues](https://docs.python.org/3/library/asyncio-queue.html)
- [ ] **Timeout wrapper** with proper cancellation (`asyncio.timeout` / `wait_for`).
- [ ] **Idempotency-key middleware** in FastAPI. Idempotency means retrying the same request has the same effect as sending it once. [Stripe: Idempotency](https://stripe.com/blog/idempotency)
- [ ] **Distributed lock** with Redis `SET NX PX` + safe release via a Lua script. [Redis distributed locks](https://redis.io/docs/latest/develop/use/patterns/distributed-locks/)
- [ ] **Cursor-based pagination** endpoint (vs. offset: why cursors are stable under inserts).
- [ ] **Chunked/streamed processing:** a generator to batch an iterable; reading a huge file line by line.
- [ ] **Context manager + timing/logging decorator** (`contextlib`, `functools.wraps`).
- [ ] **In-memory pub/sub / event bus.**
- [ ] **Consistent hashing:** maps keys to nodes so adding a node only remaps a fraction of keys. [Toptal guide](https://www.toptal.com/big-data/consistent-hashing)

**AI-specific**
- [ ] **Tool-calling agent loop from scratch** (no framework): LLM → parse tool call → execute → append result → loop until done or `max_steps`.
- [ ] **Structured output + Pydantic validation + re-prompt on error.** [Pydantic docs](https://docs.pydantic.dev/latest/)
- [ ] **Chunking with overlap + top-k cosine similarity** in NumPy.
- [ ] **Streaming LLM tokens** via FastAPI SSE.
- [ ] **Semantic cache:** reuse an earlier answer if a new query's embedding is within a similarity threshold.
- [ ] **Token-budget truncation** of chat history (keep the system prompt + the most recent turns).

**Claude Code review prompt (per drill)**
> Review this implementation as an interviewer would. Check correctness, edge cases, thread/async safety, and complexity. Ask me 2 follow-up questions an interviewer would ask. Don't give me the fixed code unless I ask.

### Session 4.2: Mock system design (1.5h, talk out loud, 40 min each)
- [ ] **"Design a centralized org Knowledge Base accessible via AI."** Cover ingestion, ACLs, hybrid search, freshness, evals, guardrails, cost.
- [ ] **"Refactor a legacy media-processing pipeline."** S3 events → SQS → workers or Step Functions; idempotent processing; **DLQ** (dead-letter queue that holds messages that kept failing); partner configs moved into a config store; observability.
  - [AWS Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/welcome.html) · [SQS dead-letter queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)

### Session 4.3: Map your experience to the JD (1h)
Write a STAR story for each row (Situation, Task, Action, Result). Two minutes each, with numbers.

| JD area | Your story |
|---|---|
| GenAI apps | SageMaker transformer classification pipeline + rule-based refinement |
| Governance / guardrails | Centralized audit logging framework across Lambda services |
| Refactor legacy pipelines | Glue ETL 3× faster, 65% cost cut; Lambda → Glue migration |
| Core backend / performance | Report generation from ~3 hrs/index to seconds (85+ indices) |
| RAG / agents | Cloud Companion (LLM + RAG + graph DB); sentinel-rag; RCA agent |
| Reliability | Elasticsearch snapshot backup/restore automation |
| Mentoring / leadership | *(pick one real example: onboarding, code reviews, a platform upgrade you led)* |

### Rapid-fire questions: have a 2-minute answer ready
- [ ] Why LangGraph instead of a plain while-loop?
- [ ] How do you stop an agent from looping forever or burning tokens?
- [ ] How do you evaluate an agent, not just RAG? (trajectory evals: did it call the right tools in a sensible order)
- [ ] How do you version and test prompts?
- [ ] How do you control LLM cost in production? (caching, model routing, prompt compression, batching)
- [ ] How do you defend against prompt injection from retrieved documents?
- [ ] CDK vs. Terraform vs. Sceptre: when would you pick each?
- [ ] How would you roll out AI-assisted SDLC to a skeptical team?

---

## Top resources if you only read two
- [Anthropic: Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)
- [AWS Builders' Library: Timeouts, retries, and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
