#!/usr/bin/env bash
# Nightshift ad-visual generator. Produces a BASE visual (background imagery only,
# no text) at the nearest model-supported size; the compositor (compose.py) then
# crops to exact ad dimensions and overlays crisp logo + copy.
#
#   adgen.sh <aspect> "<image prompt>" <out.png>
#     aspect: square | landscape | portrait | story
#
# Backends (all CLI-driven — no raw API keys). Choose with NIGHTSHIFT_IMAGE_BACKEND:
#   auto    (default) -> prefer Gemini (Nano Banana) if the `gemini` CLI is present,
#                        else Codex. Falls through on failure.
#   gemini            -> Gemini CLI + nanobanana extension. Model via
#                        NIGHTSHIFT_GEMINI_MODEL (default gemini-3-pro-image =
#                        Nano Banana Pro; use gemini-3.1-flash-image for the faster
#                        Nano Banana 2). Requires: gemini extensions install nanobanana
#   codex             -> Codex CLI image skill. Model via NIGHTSHIFT_IMAGE_MODEL
#                        (default gpt-image-2).
# If no image CLI is available, the ad-designer falls back to the compositor's
# on-brand gradient (no base image). There is no external HTTP-API path.
set -euo pipefail

ASPECT="${1:?aspect required: square|landscape|portrait|story}"
PROMPT="${2:?image prompt required}"
OUT="${3:?output path required}"
BACKEND="${NIGHTSHIFT_IMAGE_BACKEND:-auto}"

case "$ASPECT" in
  square)              SIZE="1024x1024" ;;
  landscape)          SIZE="1536x1024" ;;
  portrait|story)     SIZE="1024x1536" ;;
  *) echo "adgen.sh: unknown aspect '$ASPECT'" >&2; exit 64 ;;
esac

mkdir -p "$(dirname "$OUT")"

# Reinforce: background imagery only. Text is composited later, so the model must
# NOT try to render headlines/logos (it does that badly, and we want exact brand fonts).
FULL_PROMPT="$PROMPT

Constraints: high-quality advertising BACKGROUND imagery only, aspect ${ASPECT} (~${SIZE}).
Do NOT render any words, letters, headlines, captions, watermarks, UI, or logos — leave
clean negative space (roughly one third of the frame) for text to be added later.
Professional, on-brand, uncluttered composition."

gen_gemini() {
  command -v gemini >/dev/null 2>&1 || return 127
  export NANOBANANA_MODEL="${NIGHTSHIFT_GEMINI_MODEL:-gemini-3-pro-image}"
  local task="Generate ONE image with the nanobanana image tool and save it to the exact \
path: ${OUT} (create parent dirs if needed). Target aspect ${ASPECT} (~${SIZE}). \
After saving, print only the path. Image prompt:
${FULL_PROMPT}"
  # -y/--yolo auto-approves tool/file actions for unattended runs.
  gemini -y -p "$task" >&2 || return 1
  [ -f "$OUT" ]
}

gen_codex() {
  command -v codex >/dev/null 2>&1 || return 127
  local model="${NIGHTSHIFT_IMAGE_MODEL:-gpt-image-2}"
  local task="Generate a single image using your image-generation skill (model ${model}) \
at size ${SIZE}. Save it to the exact path: ${OUT} (create parent dirs if needed). \
After saving, print only the absolute path. Prompt for the image:
${FULL_PROMPT}"
  codex exec --sandbox workspace-write --ask-for-approval never "$task" >&2 || true
  [ -f "$OUT" ]
}

try() {  # try a backend fn; on success echo OUT and exit 0
  if "$1"; then echo "$OUT"; exit 0; fi
}

case "$BACKEND" in
  gemini) try gen_gemini ;;
  codex)  try gen_codex ;;
  auto)   try gen_gemini; try gen_codex ;;
  *) echo "adgen.sh: unknown backend '$BACKEND' (use auto|gemini|codex)" >&2; exit 64 ;;
esac

echo "NIGHTSHIFT: no image backend produced $OUT (backend=$BACKEND). Install the Gemini CLI + nanobanana extension or the Codex CLI, or let the compositor use its brand-gradient fallback." >&2
exit 1
