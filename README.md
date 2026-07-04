# Nightshift

> Hand off the *how*. Describe *what* you want; Nightshift runs the build unattended
> and only bothers you when it's done or genuinely stuck.

Nightshift is a **Claude Code plugin** that turns an idea into shipped, tested code
through a spec-driven pipeline, orchestrated by Fable 5 and executed by Cursor and Codex.

```
idea → interview.md → SPEC.md → PRD.md → GitHub issues → autonomous build → verified code
```

This repository is also a **Claude Code plugin marketplace** (see
`.claude-plugin/marketplace.json`), so co-workers can install it in one command.

## Install

```
/plugin marketplace add petericebear/nightshift
/plugin install nightshift@nightshift-marketplace
```

Full setup (permissions posture, executor CLIs, unattended runs): see
[INSTALL.md](./INSTALL.md).

## Commands

| Command | Does |
|---|---|
| `/nightshift-init [idea]` | Scaffold `interview.md` + `.context/` |
| `/nightshift-interview` | Interview → `.context/SPEC.md` |
| `/nightshift-prd` | SPEC → `.context/PRD.md` |
| `/nightshift-issues` | PRD → GitHub issues via `gh` |
| `/nightshift-build [item]` | Autonomous, self-verifying build |
| `/nightshift [idea\|build]` | Whole pipeline, resuming from current state |
| `/nightshift-triage [issue#]` | Build open `ai-ready` GitHub issues on their own branch and open reviewed PRs |
| `/nightshift-ads "<title>" "<desc>" [platforms]` | Generate on-brand ad creatives (Google/LinkedIn/Meta) |
| `/nightshift-status` | Morning briefing: report + loop state + open issues |

Saying **"nightshift"** in chat also triggers the skill.

## Daily issue triage

Label a GitHub issue **`ai-ready`** and `/nightshift-triage` will build it on a
`nightshift/issue-<n>` branch, verify (tests + review), and open a ready-for-review PR
that closes the issue — moving it `ai-ready` → `ai-building` → `ai-review`. It only
processes `ai-ready` issues and claims each by relabelling, so it's safe to run every
morning. See [plugins/nightshift/SCHEDULING.md](./plugins/nightshift/SCHEDULING.md).

## Ad creatives

`/nightshift-ads "<title>" "<description>"` turns an offer + project context into
platform-exact, on-brand ad images. Codex/gpt-image-2 generates the visual; a Pillow
compositor overlays crisp logo + headline + subhead + CTA using
`.context/brand-assets/DESIGN.md`. Sizes (in `plugins/nightshift/assets/ad_specs.json`):
Google Ads 1200×628 / 1200×1200 / 900×1200, LinkedIn single 1200×628 / 1200×1200,
LinkedIn carousel 1080×1080 × N, Meta/IG 1080×1080 / 1080×1920. Output lands in
`.context/ad-creatives/<slug>/` with a manifest. Image generation is **Codex-only**
(gpt-image-2); no external-API path.

## Everything lives in `.context/`

All Nightshift inputs, state, and outputs stay in one folder per project:

```
.context/
├── SPEC.md · PRD.md · NIGHTSHIFT_REPORT.md
├── brand-assets/        DESIGN.md · design.json · logo/
├── ad-creatives/<slug>/ base/ · <format>.png · index.md
└── .nightshift/         state.json · consensus/
```

(The only exception is the optional macOS LaunchAgent plist, which the OS requires in
`~/Library/LaunchAgents`.)

## How it works

- **Orchestrator** (`nightshift-orchestrator`, model **Fable 5**) plans, delegates,
  verifies, and decides — doing minimal coding itself.
- **Executors**: Cursor/Composer (`scripts/cursor.sh`) as primary coder; Codex
  (`scripts/codex.sh`) for debugging, review, and computer-use.
- **Quality gate**: `verifier` runs tests, `reviewer` checks correctness/security/PRD
  (with a Codex second pass). Done = tests pass **and** review clean.
- **Consensus when stuck**: `scripts/consensus.sh` asks both executors for an approach;
  the orchestrator picks the stronger one.
- **Loop/budget guard**: `scripts/loopguard.py` caps iterations, wall-clock, and
  no-progress spinning, forcing escalation over infinite loops.
- **Destructive-op guard**: `scripts/guard.py` (PreToolUse hook) hard-blocks
  irreversible/data-loss commands even in full-auto.
- **Reporting**: `.context/NIGHTSHIFT_REPORT.md` stays current for the morning read.

## Repository layout

```
.claude-plugin/marketplace.json   # marketplace manifest (repo root)
plugins/nightshift/               # the plugin
  .claude-plugin/plugin.json
  commands/  agents/  skills/  hooks/  scripts/
  nightshift.settings.json        # permissions block to merge into your settings
  README.md
INSTALL.md
```

## Requirements

Claude Code (Fable 5 available), `cursor-agent`, `codex`, optionally `gh`
(authenticated), and `python3`. Missing executor CLIs degrade gracefully.

## License

MIT — see [LICENSE](./LICENSE).
