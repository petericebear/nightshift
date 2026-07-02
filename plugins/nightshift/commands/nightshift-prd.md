---
description: Generate .context/PRD.md (milestones + ordered, testable work breakdown) from the SPEC.
argument-hint: ""
allowed-tools: Read, Write, Edit, Glob, Grep, Task
model: fable
---

# Nightshift — SPEC → PRD

Delegate to the **prd-writer** subagent to read `.context/SPEC.md` and produce
`.context/PRD.md`: milestones, an ordered work breakdown where each item has a title,
the SPEC requirement IDs it covers, scope, acceptance criteria + proving tests,
dependencies, and a size estimate; plus a test strategy and build sequencing.

If `.context/SPEC.md` is missing, stop and tell the user to run `/nightshift-interview`
first. When done, suggest `/nightshift-issues` (if using GitHub) or `/nightshift-build`.
