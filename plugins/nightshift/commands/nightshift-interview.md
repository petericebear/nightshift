---
description: Run the requirements interview from interview.md and generate .context/SPEC.md.
argument-hint: "[optional extra context]"
allowed-tools: Read, Write, Edit, Glob, Grep, Task, WebSearch, WebFetch
model: fable
---

# Nightshift — interview → SPEC

Delegate to the **spec-interviewer** subagent to read `interview.md` (plus any extra
context in "$ARGUMENTS"), conduct a structured interview, and write a rigorous,
testable `.context/SPEC.md` with numbered requirements and acceptance criteria.

If `interview.md` is missing, create it from the idea in "$ARGUMENTS" or ask the user
for the idea first. When running unattended, record assumptions rather than stalling.

When done, summarize the SPEC's key requirements and suggest running `/nightshift-prd`.
