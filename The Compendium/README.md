# The Compendium

A running collection of deep-dive and curiosity notes — the antidote to doomscrolling. Ask Claude for a note on any topic, or say "surprise me."

## How it works

- **Specific request** ("give me a note on the 2008 financial crisis") → filed under the matching topic folder.
- **"Surprise me"** → Claude picks an interesting topic/subtopic not yet covered (see [_Topic Log.md](_Topic%20Log.md)), across any of the folders below.
- **Deep dive** → an existing note gets expanded, or split into a subfolder with multiple linked notes if it grows large.

## Topics

- Finance
- Economics
- Health & Fitness
- Sociology
- History
- Politics
- Geology
- Artificial Intelligence *(general-interest — separate from the root-level AI folder, which is technical/study notes)*
- Philosophy
- Psychology

New topics get their own folder as they come up — this list isn't fixed.

## Note format

Each note starts with:

```
# Title

*Topic · YYYY-MM-DD*

One-line hook — why this is interesting.

---

[content]

## See also
- [[related note]]
```

## Naming convention

All notes live in the GitHub repo [vijaysingh-dev/The-Big-Idea](https://github.com/vijaysingh-dev/The-Big-Idea), under the **The Compendium** folder:

```
The Compendium/<Topic Space Separated>/<NN - Space Separated Note>.md
```

- `<Topic Space Separated>` is the topic folder name, spaced out normally (e.g. `Health & Fitness`, `Artificial Intelligence`).
- `<NN - Space Separated Note>` is a two-digit, zero-padded sequence number within that topic folder, a space, a hyphen, a space, then the note title (e.g. `01 - Human Body & Nutrition Basics.md`, `02 - Micronutrients & RDAs.md`). The number reflects build order within the topic, since notes are meant to be read sequentially and layer on each other.
- A companion note that extends an existing one takes that note's number plus a letter (e.g. `11a - The Monthly Indian Meal Plan.md` after `11 - The Indian Plate - Rebuilding the Thali.md`), so it sorts next to its parent without renumbering later notes.
- Links between notes are Obsidian wikilinks by bare note name, e.g. `[[11a - The Monthly Indian Meal Plan]]`.
- `_Topic Log.md` and this `README.md` sit at the root of **The Compendium** folder, not inside any topic folder (the leading underscore keeps the log sorted to the top alongside topic folders).

## Tracking

[_Topic Log.md](_Topic%20Log.md) lists every note created, so "surprise me" requests avoid repeats and can spot gaps across topics.

## What Claude should output for every note request

Claude works directly in the GitHub repo. For every note request:

1. Pull the latest `main` first, so local edits made in Obsidian aren't overwritten.
2. Create (or update) the note at `The Compendium/<Topic>/<NN - Title>.md`, following the naming convention and note format above. When a note is renamed or renumbered, update every wikilink that points to it.
3. Add a row for the note at the top of `_Topic Log.md`.
4. If the note is the first in a new topic, create the topic folder first.
5. Update this `README.md` whenever the topic list, conventions, or workflow change.
6. Commit the note, the log and any README change together, and push to `main`.
