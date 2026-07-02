---
description: Create GitHub issues (one per PRD work item, labelled 'nightshift') via the gh CLI.
argument-hint: ""
allowed-tools: Read, Grep, Glob, Bash
model: sonnet
---

# Nightshift — PRD → GitHub issues

Turn `.context/PRD.md` work items into tracked GitHub issues.

1. Verify prerequisites: `${CLAUDE_PLUGIN_ROOT}/scripts/gh-issues.sh check`.
   - If it fails (no `gh`, not authed, or not a GitHub repo), STOP gracefully and tell
     the user how to fix it (`gh auth login`), then note it in
     `.context/NIGHTSHIFT_REPORT.md`. Do not fabricate issues.
2. Read `.context/PRD.md`. For each work item, create an issue:
   `${CLAUDE_PLUGIN_ROOT}/scripts/gh-issues.sh create "<title>" "<body with acceptance criteria, SPEC IDs, deps>" "nightshift"`
3. Record the created issue numbers/URLs back into `.context/PRD.md` (next to each item)
   and into the report, so the orchestrator can comment/close them during the build.

Print a summary table of created issues when finished.
