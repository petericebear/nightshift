#!/usr/bin/env bash
# Nightshift wrapper for the OpenAI Codex CLI (codex exec), used as a coding /
# review / computer-use executor.
#
#   codex.sh code    "<prompt>"  -> workspace-write, no approval prompts (applies)
#   codex.sh review  "<prompt>"  -> read-only sandbox (review / analysis only)
#   codex.sh propose "<prompt>"  -> read-only sandbox (propose an approach)
#
# Prompt may also be piped on stdin. Model overridable with NIGHTSHIFT_CODEX_MODEL.
set -euo pipefail

MODE="${1:-code}"; shift || true
PROMPT="${*:-}"
[ -z "$PROMPT" ] && PROMPT="$(cat)"

MODEL_ARGS=()
[ -n "${NIGHTSHIFT_CODEX_MODEL:-}" ] && MODEL_ARGS=(-m "$NIGHTSHIFT_CODEX_MODEL")

if ! command -v codex >/dev/null 2>&1; then
  echo "NIGHTSHIFT: codex not found on PATH. Install the Codex CLI or set another executor." >&2
  exit 127
fi

case "$MODE" in
  code)
    exec codex exec --sandbox workspace-write --ask-for-approval never "${MODEL_ARGS[@]}" "$PROMPT"
    ;;
  review|propose)
    exec codex exec --sandbox read-only --ask-for-approval never "${MODEL_ARGS[@]}" "$PROMPT"
    ;;
  *)
    echo "usage: codex.sh [code|review|propose] \"<prompt>\"" >&2
    exit 64
    ;;
esac
