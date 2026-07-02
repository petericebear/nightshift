---
description: Start (or resume) the autonomous, self-verifying build of all PRD items. Runs unattended with loop guards, consensus-when-stuck, and destructive-op protection.
argument-hint: "[optional: specific issue/item to focus on]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, WebSearch, WebFetch
model: fable
---

# Nightshift — autonomous build

Hand off to the **nightshift-orchestrator** subagent to build the project to the
definition of done. This is the long-running, unattended phase.

Preconditions: `.context/SPEC.md` and `.context/PRD.md` must exist (run `/nightshift`
or the earlier phase commands first if not).

Focus (optional): **$ARGUMENTS** — if a specific issue/item is named, prioritize it;
otherwise build all items in PRD sequence.

Instruct the orchestrator to:
- Work item by item, delegating coding to Cursor (`scripts/cursor.sh`) and Codex
  (`scripts/codex.sh`), and verifying each with tests + a clean review before "done".
- Call `scripts/loopguard.py <item> --signature "<failing-test digest>"` each iteration
  and honor a STOP decision.
- On repeated failure, run `scripts/consensus.sh "<blocker>"`, decide between the two
  proposals, then hand off the chosen approach.
- Comment/close the matching GitHub issue as items complete (if issues exist).
- Keep `.context/NIGHTSHIFT_REPORT.md` current, and only surface to the human when
  everything is done or a real decision is needed.
- Never run destructive/irreversible commands (the guard hook enforces this).

Begin the build now and keep going autonomously.
