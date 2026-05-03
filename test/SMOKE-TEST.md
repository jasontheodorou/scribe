# scribe Manual Smoke Test

Run on a Mac (and once on Linux if available). This is the test plan from the design spec, executed by hand.

## Prerequisites
- A clean home directory (or a test machine).
- Claude Code installed and on PATH.
- A test project: `mkdir -p /tmp/scribe-smoke && cd /tmp/scribe-smoke`.

## Steps

1. **Install.** Run `bash ~/projects/scribe/dist/scribe-installer.sh`. Confirm friendly output and no prompts.
2. **doctor.** Run `~/.scribe/bin/scribe doctor`. Should report all green.
3. **Bootstrap prompt.** `cd /tmp/scribe-smoke; claude`. Within Claude's first response, it should ask about enabling journaling.
4. **Yes path.** Answer "yes". Confirm `journal/`, `.gitignore` line, and `CLAUDE.md` block all appear. Claude acknowledges.
5. **Live writing.** Have a real session — discuss a small architectural choice. Close the session. Open `journal/logbook/<today>.md`. Confirm it has prose. Open `journal/decisions/001-*.md` if a decision was made.
6. **Re-open.** `claude` again in the same project. Confirm the SessionStart context contains the latest log entry and lessons.
7. **Pause.** Tell Claude "pause journaling". Confirm `journal/.paused` exists. Do work; close. Confirm no new entries appeared.
8. **Resume.** Tell Claude "resume journaling". Confirm sentinel removed.
9. **Read on behalf.** Ask Claude "what did we decide?" Confirm Claude reads `decisions/` and replies in chat.
10. **Archive.** Tell Claude "archive this project". Confirm a `<project>_archive.md` appears on the desktop. Open it; confirm sections look right.
11. **Library.** Confirm an identical copy lands in `~/.scribe/library/`.
12. **Cross-project recall.** Make a second project, `scribe init`, ask Claude "have we made decisions about X before?" where X is in the archived project. Confirm Claude finds the excerpt.
13. **Link.** In the second project, tell Claude "use <first-project> as background context". Confirm `journal/.imports.txt` updated. Re-open the session and confirm imported summary + lessons appear in SessionStart context.
14. **Off.** Tell Claude "turn off journaling here" in one project. Answer the confirmation. Confirm the journal directory and CLAUDE.md block are gone.
15. **Decline path.** Make a fresh project. Answer "no" to the consent prompt. Confirm `.scribe-declined` is created. Re-open Claude; confirm no consent prompt re-fires.
16. **Not-now path.** Make a fresh project. Answer "not now". Confirm no marker; the prompt re-fires next session.
17. **Uninstall.** `bash ~/.scribe/uninstall.sh`. Confirm settings cleaned, slash commands removed, PATH line removed, library prompt defaulted to No.
18. **Re-install after uninstall.** Run installer again. Confirm clean re-install.
19. **Restricted-environment dry-run.** Disconnect network *after* downloading installer. Run install. Confirm success.

Record results in this file as you go.

## Status

Not yet run by a human. The automated test suite (77 bats tests) covers the underlying mechanics; this list verifies the end-to-end user experience.
