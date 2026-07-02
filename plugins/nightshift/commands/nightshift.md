---
description: Run the full Nightshift pipeline (interview -> SPEC -> PRD -> issues -> autonomous build). Resumes from wherever the project currently is.
argument-hint: "[optional one-line idea, or 'build' to jump straight to building]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, WebSearch, WebFetch
model: fable
---

# Nightshift — autonomous build pipeline

You are kicking off (or resuming) a **Nightshift** run. Goal: take an idea all the
way to verified, tested code with minimal human involvement, running unattended for
as long as it takes, self-verifying before ever bothering the human.

User input (optional idea / directive): **$ARGUMENTS**

## Step 0 — Orient
Check the current project state and resume from the right phase:
- `interview.md` exists? `.context/SPEC.md`? `.context/PRD.md`? A git repo? `gh` available/authed?
- Create `.context/` if missing. Create `.context/NIGHTSHIFT_REPORT.md` if missing.
- If `$ARGUMENTS` contains an idea and there is no `interview.md`, write the idea into
  `interview.md` first. If `$ARGUMENTS` is `build`, skip to the build phase.

## Step 1 — SPEC
If `.context/SPEC.md` is missing, delegate to the **spec-interviewer** subagent to run
the interview from `interview.md` and produce `.context/SPEC.md`. (Equivalent to
`/nightshift-interview`.)

## Step 2 — PRD
If `.context/PRD.md` is missing, delegate to the **prd-writer** subagent to derive
`.context/PRD.md` from the SPEC. (Equivalent to `/nightshift-prd`.)

## Step 3 — GitHub issues (optional)
If this is a git repo and `gh` is available and authenticated
(`${CLAUDE_PLUGIN_ROOT}/scripts/gh-issues.sh check`), create one issue per PRD work
item, labelled `nightshift`. If `gh` is missing/unauthed, skip and note it in the
report — do not block. (Equivalent to `/nightshift-issues`.)

## Step 4 — Autonomous build
Hand off to the **nightshift-orchestrator** subagent to build every PRD item to the
definition of done (tests pass + clean review), using Cursor and Codex as executors,
consensus-when-stuck, and the loop/budget guard. (Equivalent to `/nightshift-build`.)

## Throughout
- Keep `.context/NIGHTSHIFT_REPORT.md` current.
- Never perform destructive/irreversible actions (the guard hook enforces this).
- Only stop and surface to the human when everything is done, or a decision is
  genuinely required. Otherwise keep going.

Begin now. Announce which phase you're starting, then proceed autonomously.
