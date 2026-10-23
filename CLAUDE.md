# CLAUDE.md

An Obsidian vault of personal study notes, mostly software engineering. It is plain Markdown: there is no app to run and nothing to test. The only build step makes EPUBs.

## Layout

| Path | What it is |
|---|---|
| `Guide - AI/` | AI engineering: LLMs, fine-tuning, RAG, agents, serving |
| `Guide - Backend/` | Python runtime, networking, HTTP, DBs, queues, microservices, reliability. Loose topic notes (`Redis.md`, `Kafka.md`, `gRPC.md`, …) sit at the root. |
| `Guide - Frontend/` | JavaScript, browser, React |
| `Guide - RAG and Agentic AI/` | Hands-on RAG/agents course (flat numbered files, capstone "RAGLab") |
| `Guide - Salesforce/` | Salesforce platform |
| `Guide - System Design/High Level Design/` | HLD fundamentals, building blocks, case studies |
| `Guide - System Design/Low Level Design/` | SOLID, design patterns, LLD case studies |
| `Guide - Interview/` | Interview Q&A, flat numbered files (`01 - …md` … `06 - …md`) plus `00 - Index (Interview).md`, which maps recently asked questions to answers. Answers stay compact and link into the other guides for depth |
| `Development/` | Short references: DSA, SQL, Java, shell |
| `Investing/` | Investing notes |
| `The Compendium/` | Curiosity notes; has its own rules in `The Compendium/README.md` and `_Topic Log.md` |
| `.tools/` | EPUB build scripts |

**Personal content. Do not read, edit or commit it unless asked:** `_Quick Notes/`, `Keep Notes/`, `The Gap/`, `/Trading/`, `Ideas.md`, `Tasks.md`, `The Guide.md`. These are gitignored. `Investing/Trading/` is *not* personal and is tracked.

## Guide conventions

Every `Guide - <Topic>` folder follows the same shape:

- **One index file at the root:** `00 - Index (<Topic>).md` (HLD uses `00-Index (HLD).md`). It holds the reading order as tables of `| [[note]] | What it covers |`, one table per section. When you add a note, add a row to the index.
- **Numbered sections and notes:** `NN - Section Name/NN.M - Note Title.md`, e.g. `06 - Databases/06.3 - Indexes Deep Dive.md`. Section folders can nest one level deeper; LLD design patterns do this. A trailing unnumbered `Assets/` folder holds cheatsheets (`Assets.N - Title.md`) and images.
- **Note skeleton** (Backend/HLD/LLD style):
  ```
  **Up:** [[<Index>]] | **Prev:** [[<prev note>]]

  ---

  # Title

  #tags
  > **In one line:** ...

  ---
  ...body...
  ## Codebase / ## Exercise (Backend)
  ## High-Quality Resources   (table: | [link](url) | Why it's worth your time |)

  ---

  **Next:** [[<next note>]]
  ```
  Match the nav style of the guide you are editing. `.tools/vault-fix-nav.pl` detects and rewrites it.
- **Links:** Obsidian wikilinks by bare note name (`[[06.3 - Indexes Deep Dive]]`). Note names are unique across the vault, so don't add paths. Use `[[Note#Heading]]` to point at a section.
- **Code:** fenced blocks with a language tag. Python is the default backend language (FastAPI, asyncio, asyncpg, redis-py, aiokafka/confluent-kafka).
- **Prefer linking to adding.** Coverage is already wide. Before writing a new note, grep for the topic and link to the existing note or extend it. Write a new note only for a real gap.

## Interview notes

Files in `Guide - Interview/` use this per-question format:

```
### Qn. Question?

**Answer**
...
**Likely follow-ups**
- *Follow-up?* short answer
**What a strong answer shows:** ...
```

Every question also has a short **Code** block where it helps, a **Go deeper:** line linking vault notes, and one **Resource:** link. Questions are numbered per file. After inserting one, renumber the file and update the index table. Heading anchors in links must not contain `:` or backticks (use an em dash in the heading instead).

## Building EPUBs

```
bash .tools/build-guides.sh
```

This needs `pandoc`, `perl` and `python3`. It builds one EPUB per guide listed in the `GUIDES` array (output goes into each guide's root) and deletes the intermediate `.md`. To include a new guide, add a row to that array. The builder discovers notes from the index file plus the numbered folders, so a guide that breaks the conventions above won't build.
