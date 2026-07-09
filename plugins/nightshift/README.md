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
| `/nightshift-triage [issue#]` | Build open `ai-ready` GitHub issues on their own branch and open reviewed PRs |
| `/nightshift-ads "<title>" "<desc>" [platforms]` | Generate on-brand ad creatives (Google/LinkedIn/Meta) |
| `/nightshift-status` | Morning briefing: report + loop state + open issues |

Saying **"nightshift"** in chat also triggers the skill.

## Architecture

- **Orchestrator** (`nightshift-orchestrator`, model **Fable 5**) — plans, delegates,
  verifies, decides. Does minimal coding itself.
- **Executors** — a dispatcher (`scripts/code.sh`) prefers Cursor/Composer and
  **auto-falls back to Codex** if `cursor-agent` isn't installed; reviews prefer Codex.
  Force one with `NIGHTSHIFT_CODER=cursor|codex`; `cursor.sh`/`codex.sh` remain for
  explicit engine choice.
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

## Daily issue triage

Point Nightshift at an existing GitHub repo, label issues **`ai-ready`**, and run
`/nightshift-triage` (manually or on a schedule). For each ready issue it claims the
issue (`ai-ready` → `ai-building`), branches `nightshift/issue-<n>`, builds it to the
usual definition of done (tests pass + review clean), pushes, opens a **ready-for-review
PR** that closes the issue, and moves it to `ai-review`. It only ever processes
`ai-ready` issues, so scheduled re-runs never rebuild the same work. Blocked issues get a
comment explaining what's needed and are left in `ai-building` for a human. See
[SCHEDULING.md](./SCHEDULING.md) for the ~6am daily setup.

## Ad creatives

`/nightshift-ads "<title>" "<description>" [google,linkedin,carousel,meta]` produces
platform-exact, on-brand advertisement images. Codex/gpt-image-2 generates the visual
(background only); a Pillow compositor (`scripts/compose.py`) overlays a crisp logo +
headline + subhead + CTA at exact ad sizes, driven by `.context/brand-assets/DESIGN.md`
(colors, fonts, logo, tone, guardrails). Sizes live in `assets/ad_specs.json`:

- **Google Ads**: 1200×628, 1200×1200, 900×1200
- **LinkedIn single**: 1200×628, 1200×1200
- **LinkedIn carousel**: 1080×1080 × N cards
- **Meta / Instagram**: 1080×1080, 1080×1920

Set up `.context/brand-assets/` (scaffolded by `/nightshift-init`) with your logo and
colors first. Needs `pillow` (`pip install pillow`). Image generation is CLI-driven and
auto-selected: **Gemini Nano Banana** (default `gemini-3-pro-image`, via the Gemini CLI +
`nanobanana` extension) when available, otherwise **Codex/gpt-image-2** — no raw-API path.
Override with `NIGHTSHIFT_IMAGE_BACKEND=gemini|codex|auto` and `NIGHTSHIFT_GEMINI_MODEL`
(e.g. `gemini-3.1-flash-image` for the faster Nano Banana 2). Without any image CLI it
still renders usable drafts on a brand gradient.

## Everything lives in `.context/`

All of Nightshift's inputs, state, and outputs stay inside one folder per project, so
it's easy to see and maintain (and easy to `.gitignore` or commit as you choose):

```
.context/
├── SPEC.md                     # from the interview
├── PRD.md                      # work breakdown
├── NIGHTSHIFT_REPORT.md        # the morning read
├── brand-assets/               # your brand inputs for ads
│   ├── DESIGN.md               # colors, fonts, tone, guardrails
│   ├── design.json             # machine-readable tokens
│   └── logo/                   # your logo files (logo.png, logo-white.png)
├── ad-creatives/<slug>/        # generated ads
│   ├── base/                   # AI background visuals (Codex/gpt-image-2)
│   ├── <format>.png            # final platform-exact creatives
│   └── index.md                # manifest: platform, size, copy used
└── .nightshift/                # runtime state
    ├── state.json              # loop-guard counters
    └── consensus/              # second-opinion proposals when stuck
```

The only file Nightshift places outside `.context/` is the optional macOS LaunchAgent
plist for scheduling (the OS requires it in `~/Library/LaunchAgents`).

## Autonomy posture

Full-auto for create/alter work; hard stop on destructive/irreversible actions. See
`nightshift.settings.json` for the permissions block to merge into your Claude Code
settings, and `INSTALL.md` for setup.

## Requirements

- Claude Code (with Fable 5 available for the orchestrator).
- `cursor-agent` (Cursor CLI) and/or `codex` (Codex CLI) on PATH for the executors —
  either alone works; the dispatcher prefers Cursor and falls back to Codex.
- `gemini` (Gemini CLI) + the `nanobanana` extension for ad image generation
  (`gemini extensions install nanobanana`); Codex/gpt-image-2 is the fallback.
- `gh` (GitHub CLI), authenticated, only if you want issue tracking.
- `python3` for the guard/loop scripts.

## Tuning

Environment variables: `NIGHTSHIFT_MAX_ITERS` (25), `NIGHTSHIFT_MAX_MINUTES` (180),
`NIGHTSHIFT_MAX_NOPROGRESS` (5), `NIGHTSHIFT_CURSOR_MODEL` (`composer`),
`NIGHTSHIFT_CODEX_MODEL`.

To swap the orchestrator to Opus 4.8 instead of Fable 5, change `model: fable` to
`model: opus` in `agents/nightshift-orchestrator.md` (and the phase commands).
