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

## Tracking

[_Topic Log.md](_Topic%20Log.md) lists every note created, so "surprise me" requests avoid repeats and can spot gaps across topics.

## What Claude should output for every note request

1. **If Claude has file-write access to this repo (e.g. Claude Code):** write the note file into the matching topic folder (create the folder if it doesn't exist yet), following the Note format above.
2. **If Claude cannot write files (e.g. chat mode):**
   - State the folder path the note belongs in (e.g. `Topic/Title.md`), so it can be filed manually.
   - Give the note as a downloadable file if the interface supports it; otherwise output the full note as markdown in the response.
3. In both cases, also print one single-line table row for `_Topic Log.md`, in a fenced code block so it's easy to copy:

   ```
   | YYYY-MM-DD | Topic | [Title](Topic/Title.md) |
   ```

Do not edit `_Topic Log.md` directly — always hand back the line above for manual pasting.
