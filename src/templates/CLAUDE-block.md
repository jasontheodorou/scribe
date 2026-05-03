<!-- scribe-block-begin -->
## Auto-journal (managed by scribe)

This project has a `journal/` directory. **Before any journal write, check whether `journal/.paused` exists. If it does, skip all journal writes for this session.**

Otherwise, as we work, extend these files in plain-English prose:

- `journal/logbook/YYYY-MM-DD.md` — chronological blow-by-blow.
- `journal/decisions/NNN-slug.md` — real architectural decisions (Context / Decision / Why / Consequences). Number sequentially.
- `journal/lessons.md` — durable lessons. Bar: "would someone joining the project in six months thank me for this?"
- `journal/experiments/YYYY-MM-DD-slug.md` — hypothesis + outcome (failures included).
- `journal/glossary.md` — project vocabulary as it emerges.
- Project-specific themed files (`bugs.md`, `ui.md`, etc.) — when a recurring topic warrants its own file.

Every file starts with YAML frontmatter: `id`, `type`, `date`, `topic`, `tags`, `status`, `related`.

Live writes are preferred. The Stop hook only catches misses.

**Reading on the user's behalf.** When the user asks "what did we decide?" / "what have we learned?" / "summarize the journal" / "what did I do yesterday?" — read the relevant journal files and report in chat. The user should never need to open files. When asked recall-style questions ("have we faced this before?"), grep `~/.scribe/library/` (the past-projects archive) too.

**Lifecycle commands the user invokes via plain English.** Run these via Bash:

- "Pause journaling" → `scribe pause`. "Resume journaling" → `scribe resume`.
- "Archive this project" / "give me a summary" / "wrap this up" → `scribe archive`. After it runs, tell the user where the file is on their desktop.
- "Bring in context from project X" → `scribe link X`.
- "Turn off journaling here" → `scribe off` (with explicit confirmation).
<!-- scribe-block-end -->
