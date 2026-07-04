---
description: Scaffold a new Nightshift project — creates interview.md, the .context/ folder, and a report stub, then invites you to fill in the idea.
argument-hint: "[project name or one-line idea]"
allowed-tools: Read, Write, Edit, Bash, Glob
model: sonnet
---

# Nightshift — init project

Set up a fresh Nightshift project in the current directory.

Input: **$ARGUMENTS**

Do the following:
1. If `$ARGUMENTS` looks like a folder name and the user wants a new subfolder, create
   it and work inside it; otherwise scaffold in the current directory.
2. Create `.context/` and `.context/.nightshift/` (state dir). Also scaffold
   `.context/brand-assets/` by copying `${CLAUDE_PLUGIN_ROOT}/assets/brand-assets-template/`
   into it (for later ad-creative generation) — tell the user they can add their logo and
   edit `DESIGN.md` whenever they want ads.
3. Create `interview.md` from the template below. If `$ARGUMENTS` contains an idea,
   seed the "Initial idea" section with it.
4. Create an empty `.context/NIGHTSHIFT_REPORT.md` with a title and timestamp.
5. If not already a git repo, offer to `git init` (non-destructive).
6. Tell the user to flesh out `interview.md`, then run `/nightshift-interview`
   (or just `/nightshift` to run the whole pipeline).

### interview.md template
```markdown
# <Project> — Idea & Interview Seed

## Initial idea
<one or two paragraphs: what you want to build and why>

## Who is it for
<primary users>

## Success looks like
<what "done and good" means>

## Must-have
- 

## Nice-to-have
- 

## Non-goals
- 

## Constraints
<stack, existing code, deadlines, budget, integrations>

## Known risks / open questions
- 
```
