# Installing Nightshift

Nightshift is distributed as a Claude Code plugin from a marketplace repo hosted at
**github.com/petericebear/nightshift**.

## 1. Add the marketplace and install the plugin

In any Claude Code session:

```
/plugin marketplace add petericebear/nightshift
/plugin install nightshift@nightshift-marketplace
```

`/plugin marketplace add` accepts the GitHub `owner/repo` shorthand and reads
`.claude-plugin/marketplace.json` from the repo root. Installed at **user scope** it
works in every project / new chat. Confirm with `/plugin list`.

> Prefer a local clone? `git clone https://github.com/petericebear/nightshift`
> then `/plugin marketplace add /absolute/path/to/nightshift`.

## 2. Turn on the full-auto permission posture

The plugin's destructive-op guard hook loads automatically. Permissions live in *your*
settings, so merge the `permissions` block from
`plugins/nightshift/nightshift.settings.json` into either:

- `~/.claude/settings.json` (all projects), or
- `<project>/.claude/settings.json` (that project only, shareable with the team).

That block auto-approves create/alter work (`defaultMode: acceptEdits` + an allow-list)
and denies destructive commands as defence-in-depth. `guard.py` is the real safety net
and always runs.

## 3. Make sure the executors are available

On your machine's PATH (checked at runtime; missing tools degrade gracefully):

- `cursor-agent` — Cursor CLI (primary coder). Model defaults to Composer.
- `codex` — Codex CLI (debug / review / computer-use).
- `gh` — GitHub CLI, authenticated (`gh auth login`), only for issue tracking.
- `python3` — for the guard and loop-guard scripts.

## 4. Run it

Interactive, from a project folder:

```
/nightshift-init  "Build a CLI that syncs Notion pages to Markdown"
# edit interview.md, then:
/nightshift
```

Or one shot: `/nightshift "Build a CLI that syncs Notion pages to Markdown"`.

### Truly unattended (overnight) run

After the SPEC/PRD exist, launch headless from the project dir:

```
claude --permission-mode acceptEdits -p "/nightshift build"
```

Read the results in the morning with `/nightshift-status` or by opening
`.context/NIGHTSHIFT_REPORT.md`.

## Updating

```
/plugin marketplace update
```

## Uninstall

```
/plugin uninstall nightshift
/plugin marketplace remove nightshift-marketplace
```
