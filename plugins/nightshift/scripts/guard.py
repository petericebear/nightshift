#!/usr/bin/env python3
"""
Nightshift PreToolUse guard.

Deterministic safety net that runs on EVERY Bash tool call, even in full-auto /
bypassPermissions mode. It hard-blocks destructive operations (data loss, force
history rewrites, mass deletion, privilege changes) while allowing the
create/alter operations Nightshift needs to build software unattended.

Contract (Claude Code hooks):
  - stdin  : JSON hook payload
  - stdout : JSON with hookSpecificOutput.permissionDecision
  - exit 2 : block the tool call (stderr is surfaced to the agent)
  - exit 0 : allow / defer to normal permission flow
"""
import json
import re
import sys

# Regexes matched against the raw command string (case-insensitive).
# Keep these conservative: block clear data-loss / irreversible actions only.
DESTRUCTIVE = [
    # --- Filesystem: recursive / forced mass deletion ---
    (r"\brm\s+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-r\s+-f|-f\s+-r)\b", "recursive+forced rm"),
    (r"\brm\s+-[a-z]*r[a-z]*\s+/(\s|$)", "rm targeting root"),
    (r"\brm\s+-[a-z]*r[a-z]*\s+~(/\s*)?($|\s)", "rm targeting home"),
    (r"\b(sudo\s+)?rm\s+-[a-z]*r", "recursive rm (review required)"),
    (r":\(\)\s*\{.*\};:", "fork bomb"),
    (r"\b(mkfs|fdisk|parted)\b", "disk format/partition"),
    (r"\bdd\s+.*of=/dev/", "dd to raw device"),
    (r">\s*/dev/sd[a-z]", "write to raw disk device"),

    # --- Git: history rewrites / forced destructive ops ---
    (r"\bgit\s+push\s+.*(--force\b|(^|\s)-f(\s|$))", "git force push"),
    (r"\bgit\s+push\s+.*--delete\b", "git remote branch delete"),
    (r"\bgit\s+reset\s+--hard\b", "git hard reset (loses work)"),
    (r"\bgit\s+clean\s+-[a-z]*f", "git clean force (deletes untracked)"),
    (r"\bgit\s+branch\s+-D\b", "git force branch delete"),
    (r"\bgit\s+filter-branch\b", "git history rewrite"),

    # --- Databases: schema / data destruction ---
    (r"\bDROP\s+(DATABASE|SCHEMA|TABLE|INDEX|VIEW)\b", "SQL DROP"),
    (r"\bTRUNCATE\s+(TABLE\s+)?\w", "SQL TRUNCATE"),
    (r"\bDELETE\s+FROM\s+\w+\s*(;|$)", "SQL unqualified DELETE"),
    (r"\bFLUSH\s+(ALL|PRIVILEGES|DATABASES)\b", "DB FLUSH"),
    (r"\bFLUSHALL\b|\bFLUSHDB\b", "Redis FLUSH"),
    (r"\bdb\.dropDatabase\(", "Mongo dropDatabase"),

    # --- Cloud / infra teardown ---
    (r"\bterraform\s+destroy\b", "terraform destroy"),
    (r"\b(kubectl|oc)\s+delete\s+(ns|namespace|all|pvc|pv|deploy)", "k8s destructive delete"),
    (r"\baws\s+s3\s+rb\b", "aws bucket delete"),
    (r"\baws\s+s3\s+rm\s+.*--recursive", "aws recursive S3 delete"),
    (r"\b(shutdown|reboot|halt|poweroff)\b", "host power control"),

    # --- Privilege / credential tampering ---
    (r"\bchmod\s+-R\s+777\b", "world-writable recursive chmod"),
    (r"\b(userdel|groupdel|passwd\s+-d)\b", "account/credential removal"),
]

COMPILED = [(re.compile(p, re.IGNORECASE), why) for p, why in DESTRUCTIVE]


def decide(command: str):
    for rx, why in COMPILED:
        if rx.search(command):
            return why
    return None


def emit(decision: str, reason: str):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": decision,
            "permissionDecisionReason": reason,
        }
    }))


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        # Fail open on malformed input rather than wedging the session.
        sys.exit(0)

    if payload.get("tool_name") != "Bash":
        sys.exit(0)

    command = (payload.get("tool_input") or {}).get("command", "") or ""
    why = decide(command)
    if why:
        reason = (
            f"NIGHTSHIFT GUARD blocked a destructive operation ({why}). "
            "Full-auto is allowed for create/alter work, but irreversible/data-loss "
            "actions require a human. If this is truly required, ask the user to run it "
            "manually or add an explicit exception to scripts/guard.py."
        )
        emit("deny", reason)
        sys.stderr.write(reason + "\n")
        sys.exit(2)

    # Not destructive -> let normal permissions/auto-mode handle it.
    sys.exit(0)


if __name__ == "__main__":
    main()
