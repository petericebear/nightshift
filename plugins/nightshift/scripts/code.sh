#!/usr/bin/env bash
# Nightshift coding dispatcher — one entry point that picks an available coding CLI
# and degrades gracefully. Primary coder is Cursor (Composer); if Cursor isn't on
# PATH it falls back to Codex automatically. Reviews always prefer Codex.
#
#   code.sh code    "<prompt>"   -> apply a change (cursor, else codex)
#   code.sh propose "<prompt>"   -> propose only, no edits (cursor, else codex)
#   code.sh review  "<prompt>"   -> review only (codex, else cursor propose)
#
# Prompt may be piped on stdin. Preference override with NIGHTSHIFT_CODER:
#   auto (default, cursor->codex) | cursor | codex
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-code}"; shift || true
PROMPT="${*:-}"
[ -z "$PROMPT" ] && PROMPT="$(cat)"
PREF="${NIGHTSHIFT_CODER:-auto}"

has_cursor() { command -v cursor-agent >/dev/null 2>&1; }
has_codex()  { command -v codex >/dev/null 2>&1; }

run_cursor() { echo "NIGHTSHIFT: coder=cursor mode=$1" >&2; "$HERE/cursor.sh" "$1" "$PROMPT"; }
run_codex()  { echo "NIGHTSHIFT: coder=codex  mode=$1" >&2; "$HERE/codex.sh"  "$1" "$PROMPT"; }

case "$MODE" in
  code|propose)
    if [ "${PREF}" = "codex" ] && has_codex; then run_codex "$MODE"; exit $?; fi
    if [ "${PREF}" = "cursor" ] && has_cursor; then run_cursor "$MODE"; exit $?; fi
    # auto: cursor first, then codex
    if has_cursor; then run_cursor "$MODE"; exit $?; fi
    if has_codex;  then
      echo "NIGHTSHIFT: cursor-agent not found — falling back to Codex." >&2
      # cursor 'propose' maps to codex 'propose'; 'code' to 'code'
      run_codex "$MODE"; exit $?
    fi
    echo "NIGHTSHIFT: no coding CLI available (need cursor-agent or codex)." >&2; exit 127
    ;;
  review)
    if has_codex; then run_codex review; exit $?; fi
    echo "NIGHTSHIFT: codex not found — using Cursor for a proposal-style review instead." >&2
    if has_cursor; then run_cursor propose; exit $?; fi
    echo "NIGHTSHIFT: no coding CLI available for review." >&2; exit 127
    ;;
  *)
    echo "usage: code.sh [code|propose|review] \"<prompt>\"" >&2
    exit 64
    ;;
esac
