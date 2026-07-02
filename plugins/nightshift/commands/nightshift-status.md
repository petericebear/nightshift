---
description: Show the current Nightshift status — reads the report, loop-guard state, and open nightshift GitHub issues.
argument-hint: ""
allowed-tools: Read, Grep, Glob, Bash
model: haiku
---

# Nightshift — status

Give a concise morning-briefing style status:
1. Print `.context/NIGHTSHIFT_REPORT.md` (or say it doesn't exist yet).
2. Show loop-guard state: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/loopguard.py" --report`.
3. If `gh` is available, list open items:
   `${CLAUDE_PLUGIN_ROOT}/scripts/gh-issues.sh list` (skip quietly if unavailable).
4. Summarize: what's done, what's in progress, what's blocked and needs a decision.
Keep it skimmable.
