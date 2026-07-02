---
description: Find open GitHub issues labelled 'ai-ready', build each on its own branch, and open a ready-for-review PR. Designed to run daily/unattended in a repo folder.
argument-hint: "[optional: a specific issue number to triage]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Task, TodoWrite, WebSearch, WebFetch
model: fable
---

# Nightshift — issue triage

Autonomously pick up ready GitHub issues and turn each into a reviewed PR. Safe to run
on a schedule: it only ever processes issues currently labelled **`ai-ready`**, and it
claims each one by relabelling, so re-runs never rebuild the same issue.

Label lifecycle: **`ai-ready` → `ai-building` (claimed) → `ai-review` (PR open)**.

Scripts live at `${CLAUDE_PLUGIN_ROOT}/scripts`. Optional focus: **$ARGUMENTS**
(a single issue number). Cap per run via `NIGHTSHIFT_TRIAGE_MAX` (default 3).

## Preconditions
1. `scripts/gh-issues.sh check` — must succeed (gh installed, authed, GitHub repo).
   If it fails, STOP gracefully, note it in `.context/NIGHTSHIFT_REPORT.md`, and exit.
2. `scripts/gh-issues.sh ensure-labels` — create the `ai-*` labels if missing.
3. Confirm a clean git working tree. If dirty, STOP and report (don't build on top of
   uncommitted changes).

## Select work
- If `$ARGUMENTS` names an issue number, process just that one (only if it is `ai-ready`).
- Otherwise: `scripts/gh-issues.sh ready` → take up to `NIGHTSHIFT_TRIAGE_MAX` issues.
- If none, write "no ai-ready issues" to the report and stop.

## Per issue (do these in order)
1. **Claim** to prevent double-processing:
   `scripts/gh-issues.sh relabel <n> ai-building ai-ready`.
2. **Fetch the mini-spec**: `scripts/gh-issues.sh get <n>` — treat the issue body as the
   requirement. If it's too thin to build safely, comment asking for detail, relabel
   back to `ai-ready` (unclaim), and skip.
3. **Branch** off the up-to-date default branch:
   `git checkout <default> && git pull --ff-only && git checkout -b nightshift/issue-<n>`.
4. **Build** by delegating to the **nightshift-orchestrator** subagent, using the issue
   body as the spec and the same definition of done as a normal build: **tests pass AND
   review clean**. Use the loop guard with key `issue-<n>`
   (`scripts/loopguard.py issue-<n> --signature "<failing-test digest>"`), and
   consensus-when-stuck (`scripts/consensus.sh`). Never run destructive commands.
5. **On success**:
   - `git add -A && git commit -m "feat: <summary> (closes #<n>)"` then
     `git push -u origin nightshift/issue-<n>`.
   - Open a ready-for-review PR:
     `scripts/gh-issues.sh pr nightshift/issue-<n> "<title>" "Closes #<n>\n\n<what changed, how verified, test results>"`.
   - `scripts/gh-issues.sh relabel <n> ai-review ai-building`.
   - `scripts/gh-issues.sh comment <n> "Nightshift opened PR <url>. Tests + review passed."`.
6. **On failure / blocked** (loop guard STOP, or consensus didn't unblock):
   - Do NOT open a PR. Push the WIP branch if useful.
   - `scripts/gh-issues.sh comment <n> "Nightshift is blocked: <precise reason + what was tried + decision needed>."`
   - Leave the issue as `ai-building` (so it isn't auto-picked again) and record it under
     "Needs human" in the report.

## Finish
Update `.context/NIGHTSHIFT_REPORT.md` with a per-issue summary: built + PR link, or
blocked + reason. Keep it skimmable — this is the morning read. Do not stop the whole
run because one issue is hard; move on to the next.
