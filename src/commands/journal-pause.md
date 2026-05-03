---
description: Pause auto-journaling for the current project
---

Run `scribe pause` in the project root to create the `journal/.paused` sentinel. After this command runs, do not write anything to `journal/` for the rest of this session unless `scribe resume` is run.

Confirm to the user: "Journaling paused. Run /journal-resume (or say 'resume journaling') to turn it back on."
