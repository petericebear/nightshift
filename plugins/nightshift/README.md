# Nightshift

> Hand off the *how*. Describe *what* you want; Nightshift runs the build unattended
> and only bothers you when it's done or genuinely stuck.

Nightshift is a Claude Code plugin that turns an idea into shipped, tested code through
a spec-driven pipeline with a Fable-5 orchestrator delegating to Cursor and Codex.

```
idea → interview.md → SPEC.md → PRD.md → GitHub issues → autonomous build → verified code
```

## Pipeline & commands

| Command | Does |
|---|---|
| `/nightshift-init [idea]` | Scaffold `interview.md` + `.context/` |
| `/nightshift-interview` | Interview → `.context/SPEC.md` (agent: `spec-interviewer`) |
| `/nightshift-prd` | SPEC → `.context/PRD.md` (agent: `prd-writer`) |
| `/nightshift-issues` | PRD → GitHub issues via `gh` |
| `/nightshift-build [item]` | Autonomous, self-verifying build (agent: `nightshift-orchestrator`) |
| `/nightshift [idea\|build]` | Run the whole pipeline, resuming from current state |
| `/nightshift-status` | Morning briefing: report + loop state + open issues |

Saying **"nightshift"** in chat also triggers the skill.

## Architecture

- **Orchestrator** (`nightshift-orchestrator`, model **Fable 5**) — plans, delegates,
  verifies, decides. Does minimal coding itself.
- **Executors** — Cursor/Composer (`scripts/cursor.sh`) as primary coder; Codex
  (`scripts/codex.sh`) for debugging, review, and computer-use.
- **Quality gate** — `verifier` (runs tests) + `reviewer` (correctness/security/PRD,
  with a Codex second pass). An item is *done* only when tests pass **and** review is clean.
- **Consensus when stuck** — `scripts/consensus.sh` asks *both* executors for a fix
  approach; the orchestrator picks the stronger one and hands it off.
- **Loop/budget guard** — `scripts/loopguard.py` caps iterations, wall-clock, and
  no-progress spinning per item, forcing escalation over infinite loops.
- **Destructive-op guard** — `scripts/guard.py` (PreToolUse hook) hard-blocks
  irreversible/data-loss commands even in full-auto (`rm -rf`, force-push,
  `DROP`/`TRUNCATE`/`FLUSH`, `terraform destroy`, disk formats, etc.).
- **Reporting** — `.context/NIGHTSHIFT_REPORT.md` is kept current for the morning read.

## Autonomy posture

Full-auto for create/alter work; hard stop on destructive/irreversible actions. See
`nightshift.settings.json` for the permissions block to merge into your Claude Code
settings, and `INSTALL.md` for setup.

## Requirements

- Claude Code (with Fable 5 available for the orchestrator).
- `cursor-agent` (Cursor CLI) and `codex` (Codex CLI) on PATH for the executors.
  Missing CLIs degrade gracefully — the orchestrator falls back or notes it in the report.
- `gh` (GitHub CLI), authenticated, only if you want issue tracking.
- `python3` for the guard/loop scripts.

## Tuning

Environment variables: `NIGHTSHIFT_MAX_ITERS` (25), `NIGHTSHIFT_MAX_MINUTES` (180),
`NIGHTSHIFT_MAX_NOPROGRESS` (5), `NIGHTSHIFT_CURSOR_MODEL` (`composer`),
`NIGHTSHIFT_CODEX_MODEL`.

To swap the orchestrator to Opus 4.8 instead of Fable 5, change `model: fable` to
`model: opus` in `agents/nightshift-orchestrator.md` (and the phase commands).
