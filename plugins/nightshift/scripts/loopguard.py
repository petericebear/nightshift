#!/usr/bin/env python3
"""
Nightshift loop / budget guard.

The orchestrator calls this at the top of every build iteration. It tracks, per
task key, how many iterations have run and the wall-clock since the task started,
plus a rolling "signature" of progress to detect no-progress spinning. It exits
non-zero (and prints STOP) when a limit is hit, which is the orchestrator's cue
to stop looping and escalate (consensus / report / human).

Usage:
  loopguard.py <task_key> [--max-iters N] [--max-minutes M] [--signature STR]
  loopguard.py <task_key> --reset
  loopguard.py --report        # dump full state as JSON

State: $NIGHTSHIFT_STATE_DIR or <project>/.context/.nightshift/state.json
Env overrides: NIGHTSHIFT_MAX_ITERS, NIGHTSHIFT_MAX_MINUTES, NIGHTSHIFT_MAX_NOPROGRESS
"""
import json
import os
import sys
import time

DEF_MAX_ITERS = int(os.environ.get("NIGHTSHIFT_MAX_ITERS", "25"))
DEF_MAX_MIN = float(os.environ.get("NIGHTSHIFT_MAX_MINUTES", "180"))
MAX_NOPROGRESS = int(os.environ.get("NIGHTSHIFT_MAX_NOPROGRESS", "5"))


def state_path():
    d = os.environ.get("NIGHTSHIFT_STATE_DIR")
    if not d:
        base = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
        d = os.path.join(base, ".context", ".nightshift")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "state.json")


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except Exception:
        return {"tasks": {}}


def save(p, data):
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, p)


def arg(flag, default=None):
    if flag in sys.argv:
        i = sys.argv.index(flag)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


def main():
    p = state_path()
    data = load(p)

    if "--report" in sys.argv:
        print(json.dumps(data, indent=2))
        return

    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        sys.stderr.write("usage: loopguard.py <task_key> [--max-iters N] [--max-minutes M] [--signature STR] [--reset]\n")
        sys.exit(64)

    key = sys.argv[1]
    tasks = data.setdefault("tasks", {})

    if "--reset" in sys.argv:
        tasks.pop(key, None)
        save(p, data)
        print(f"reset {key}")
        return

    max_iters = int(arg("--max-iters", DEF_MAX_ITERS))
    max_min = float(arg("--max-minutes", DEF_MAX_MIN))
    signature = arg("--signature")

    now = time.time()
    t = tasks.setdefault(key, {"iters": 0, "started": now, "last_sig": None, "noprogress": 0})
    t["iters"] += 1
    t["updated"] = now

    # No-progress detection: same signature (e.g. identical failing test set) repeating.
    if signature is not None:
        if signature == t.get("last_sig"):
            t["noprogress"] += 1
        else:
            t["noprogress"] = 0
            t["last_sig"] = signature

    elapsed_min = (now - t["started"]) / 60.0
    save(p, data)

    reasons = []
    if t["iters"] > max_iters:
        reasons.append(f"iteration cap reached ({t['iters']}/{max_iters})")
    if elapsed_min > max_min:
        reasons.append(f"time budget reached ({elapsed_min:.0f}m/{max_min:.0f}m)")
    if t["noprogress"] >= MAX_NOPROGRESS:
        reasons.append(f"no progress for {t['noprogress']} iterations (same signature)")

    status = {
        "task": key,
        "iters": t["iters"],
        "elapsed_min": round(elapsed_min, 1),
        "noprogress": t["noprogress"],
    }

    if reasons:
        status["decision"] = "STOP"
        status["reasons"] = reasons
        print(json.dumps(status))
        sys.exit(1)

    status["decision"] = "CONTINUE"
    print(json.dumps(status))


if __name__ == "__main__":
    main()
