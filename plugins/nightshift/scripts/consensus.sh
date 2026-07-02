#!/usr/bin/env bash
# Nightshift consensus: when the orchestrator is stuck on a blocker, ask BOTH
# executors (Cursor + Codex) to independently propose a direction, in read-only
# mode (no edits). Their proposals are written to .context/.nightshift/consensus/
# and echoed. The ORCHESTRATOR then reads both and decides which approach to hand
# off for implementation. This script does NOT choose — deciding is the
# orchestrator's job (that's the "advisor" pattern: smart model picks).
#
#   consensus.sh "<problem statement / blocker description>"
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBLEM="${*:-}"
[ -z "$PROBLEM" ] && PROBLEM="$(cat)"

OUTDIR="${CLAUDE_PROJECT_DIR:-$PWD}/.context/.nightshift/consensus"
mkdir -p "$OUTDIR"
STAMP="$(date +%Y%m%d-%H%M%S)"

read -r -d '' ASK <<EOF || true
You are being consulted for a SECOND OPINION. Do NOT modify any files.
A build is blocked. Propose the single best concrete approach to unblock it.
Respond with: (1) root-cause hypothesis, (2) step-by-step fix, (3) risks,
(4) how to verify the fix. Be specific to this repository.

BLOCKER:
$PROBLEM
EOF

CURSOR_OUT="$OUTDIR/${STAMP}-cursor.md"
CODEX_OUT="$OUTDIR/${STAMP}-codex.md"

echo "== Asking Cursor (composer) for a proposal ==" >&2
if "$HERE/cursor.sh" propose "$ASK" >"$CURSOR_OUT" 2>>"$OUTDIR/${STAMP}-cursor.err"; then
  echo "cursor proposal -> $CURSOR_OUT" >&2
else
  echo "(cursor unavailable or errored; see ${STAMP}-cursor.err)" | tee "$CURSOR_OUT" >&2
fi

echo "== Asking Codex for a proposal ==" >&2
if "$HERE/codex.sh" propose "$ASK" >"$CODEX_OUT" 2>>"$OUTDIR/${STAMP}-codex.err"; then
  echo "codex proposal -> $CODEX_OUT" >&2
else
  echo "(codex unavailable or errored; see ${STAMP}-codex.err)" | tee "$CODEX_OUT" >&2
fi

echo "===== CURSOR PROPOSAL ====="
cat "$CURSOR_OUT"
echo
echo "===== CODEX PROPOSAL ====="
cat "$CODEX_OUT"
echo
echo "===== ORCHESTRATOR: compare the two proposals above, pick the stronger one"
echo "      (or synthesize), then hand off implementation to a single executor. ====="
