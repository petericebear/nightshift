---
name: nightshift
description: Autonomous, self-verifying build orchestration. Use when the user says "nightshift", or wants to hand off a build to run unattended for hours/days — turning an idea into a SPEC, then a PRD, then GitHub issues, then tested working code. Coordinates a Fable-5 orchestrator with Cursor (Composer) and Codex as coding executors, verifies with tests + review, seeks a second opinion when stuck, and guards against loops and destructive operations.
---

# Nightshift

Nightshift lets Peter offload the *how* of building software so he can focus on the
*what*. Say "nightshift" (or run `/nightshift`) and the system runs a full pipeline
mostly unattended, only surfacing when work is done or a real decision is needed.

## The pipeline
1. **Init** (`/nightshift-init`) — scaffold `interview.md` + `.context/`.
2. **Interview → SPEC** (`/nightshift-interview`) — the `spec-interviewer` agent turns
   the idea into a testable `.context/SPEC.md`.
3. **SPEC → PRD** (`/nightshift-prd`) — the `prd-writer` agent produces
   `.context/PRD.md` with an ordered, testable work breakdown.
4. **PRD → Issues** (`/nightshift-issues`) — optional GitHub issues via `gh`.
5. **Autonomous build** (`/nightshift-build`) — the `nightshift-orchestrator`
   (Fable 5) builds each item to done: tests pass **and** review clean.

Or run **`/nightshift`** to do all phases, resuming from wherever the project is.

## Daily issue triage (`/nightshift-triage`)
For an existing repo with a backlog: label an issue **`ai-ready`** and Nightshift will
build it on its own branch (`nightshift/issue-<n>`) and open a ready-for-review PR that
closes the issue. It only touches `ai-ready` issues and claims each by relabelling
(`ai-ready` → `ai-building` → `ai-review`), so it's safe to run every day without
rebuilding the same work. Cap per run with `NIGHTSHIFT_TRIAGE_MAX` (default 3). See
`SCHEDULING.md` to run it automatically each morning.

## How the orchestrator works
- **Delegates coding**: Cursor/Composer (`scripts/cursor.sh`) for features/refactors,
  Codex (`scripts/codex.sh`) for debugging, review, and computer-use.
- **Verifies before trusting**: the `verifier` runs tests; the `reviewer` (with a Codex
  second pass) checks correctness/security/PRD conformance. Both must be green.
- **Consensus when stuck**: after repeated failure it runs `scripts/consensus.sh`, which
  asks *both* executors for an approach; the orchestrator then picks the stronger one
  and hands it off (the "advisor" pattern — smart model decides).
- **Never loops forever**: `scripts/loopguard.py` enforces per-item iteration, wall-clock,
  and no-progress caps, forcing escalation instead of spinning.
- **Never does destructive things**: a PreToolUse guard hook (`scripts/guard.py`) hard-
  blocks data-loss/irreversible commands (DB FLUSH/DROP/TRUNCATE, `rm -rf`, force-push,
  `terraform destroy`, etc.) even in full-auto mode.
- **Reports**: keeps `.context/NIGHTSHIFT_REPORT.md` current; check `/nightshift-status`.

## When to trigger this skill
Trigger on "nightshift", or when the user wants to start a spec-driven build, hand off
a long unattended coding run, or resume one. If the project lacks `interview.md` /
`.context/SPEC.md` / `.context/PRD.md`, start at the appropriate earlier phase.

## Tuning (environment variables)
- `NIGHTSHIFT_MAX_ITERS` (default 25), `NIGHTSHIFT_MAX_MINUTES` (180),
  `NIGHTSHIFT_MAX_NOPROGRESS` (5) — loop-guard budgets.
- `NIGHTSHIFT_CURSOR_MODEL` (default `composer`), `NIGHTSHIFT_CODEX_MODEL` — executor models.
