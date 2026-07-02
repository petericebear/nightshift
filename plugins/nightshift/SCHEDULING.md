# Scheduling daily issue triage

`/nightshift-triage` needs the tools on your Mac (`gh`, `cursor-agent`, `codex`, git),
so the daily run should invoke **Claude Code headless** from inside the repo folder.
Two options — pick one.

## Option A — macOS `launchd` (recommended, survives reboots)

Create `~/Library/LaunchAgents/com.nightshift.triage.plist` (edit the two paths):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.nightshift.triage</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>cd /ABSOLUTE/PATH/TO/your-repo && claude --permission-mode acceptEdits -p "/nightshift-triage" >> .context/nightshift-cron.log 2>&1</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>6</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>/tmp/nightshift-triage.out</string>
  <key>StandardErrorPath</key><string>/tmp/nightshift-triage.err</string>
</dict>
</plist>
```

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.nightshift.triage.plist
# run once now to test:
launchctl start com.nightshift.triage
```

## Option B — `cron`

```bash
crontab -e
# then add (runs 06:00 daily):
0 6 * * * cd /ABSOLUTE/PATH/TO/your-repo && /usr/bin/env -i PATH="$PATH:/opt/homebrew/bin:$HOME/.local/bin" claude --permission-mode acceptEdits -p "/nightshift-triage" >> .context/nightshift-cron.log 2>&1
```

(`cron` has a minimal environment — make sure `PATH` includes wherever `claude`, `gh`,
`cursor-agent`, and `codex` live.)

## Notes
- `--permission-mode acceptEdits` gives the full-auto posture; the `guard.py` hook still
  blocks destructive ops.
- Bound each run with `NIGHTSHIFT_TRIAGE_MAX` (default 3 issues) and the loop-guard
  budgets (`NIGHTSHIFT_MAX_ITERS`, `NIGHTSHIFT_MAX_MINUTES`) to cap cost/time.
- Each morning, review the opened `ai-review` PRs and read `.context/NIGHTSHIFT_REPORT.md`
  (or run `/nightshift-status`).

## Lighter alternative (Cowork scheduler)
If you'd rather have Cowork run a lightweight triage that only needs `gh` + Claude's own
file/edit tools (no Cursor/Codex CLIs), a Cowork scheduled task can do that against a
connected repo folder. Ask and I'll set it up — but for full Cursor/Codex-driven builds,
use Option A or B above.
