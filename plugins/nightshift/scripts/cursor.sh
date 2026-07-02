#!/usr/bin/env bash
# Nightshift wrapper for the Cursor CLI (cursor-agent), used as a coding executor.
#
#   cursor.sh code   "<prompt>"   -> applies changes (headless, auto-approve)
#   cursor.sh propose "<prompt>"  -> read-only; proposes an approach, no edits
#
# Prompt may also be piped on stdin. Model defaults to Composer; override with
# NIGHTSHIFT_CURSOR_MODEL (e.g. composer / composer-2.5).
set -euo pipefail

MODE="${1:-code}"; shift || true
PROMPT="${*:-}"
[ -z "$PROMPT" ] && PROMPT="$(cat)"
MODEL="${NIGHTSHIFT_CURSOR_MODEL:-composer}"

if ! command -v cursor-agent >/dev/null 2>&1; then
  echo "NIGHTSHIFT: cursor-agent not found on PATH. Install the Cursor CLI or set another executor." >&2
  exit 127
fi

case "$MODE" in
  code)
    # --force applies edits without interactive approval (non-destructive ops
    # are still filtered by the PreToolUse guard at the orchestrator layer).
    exec cursor-agent -p --force -m "$MODEL" "$PROMPT"
    ;;
  propose)
    # No --force => Cursor only proposes; nothing is written.
    exec cursor-agent -p -m "$MODEL" "$PROMPT"
    ;;
  *)
    echo "usage: cursor.sh [code|propose] \"<prompt>\"" >&2
    exit 64
    ;;
esac
