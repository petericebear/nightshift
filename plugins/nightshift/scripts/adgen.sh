#!/usr/bin/env bash
# Nightshift ad-visual generator. Produces a BASE visual (background imagery only,
# no text) at the nearest model-supported size; the compositor (compose.py) then
# crops to exact ad dimensions and overlays crisp logo + copy.
#
#   adgen.sh <aspect> "<image prompt>" <out.png>
#     aspect: square | landscape | portrait | story
#
# Backend: Codex CLI only. Codex drives its image-generation skill using your
# OpenAI/ChatGPT auth. Model via NIGHTSHIFT_IMAGE_MODEL (default gpt-image-2).
# If Codex is unavailable, the ad-designer falls back to the compositor's on-brand
# gradient (no base image) — there is no external API path.
set -euo pipefail

ASPECT="${1:?aspect required: square|landscape|portrait|story}"
PROMPT="${2:?image prompt required}"
OUT="${3:?output path required}"
MODEL="${NIGHTSHIFT_IMAGE_MODEL:-gpt-image-2}"

case "$ASPECT" in
  square)              SIZE="1024x1024" ;;
  landscape)          SIZE="1536x1024" ;;
  portrait|story)     SIZE="1024x1536" ;;
  *) echo "adgen.sh: unknown aspect '$ASPECT'" >&2; exit 64 ;;
esac

mkdir -p "$(dirname "$OUT")"

# Reinforce: background imagery only. Text is composited later, so the model must
# NOT try to render headlines/logos (it does that badly).
FULL_PROMPT="$PROMPT

Constraints: high-quality advertising BACKGROUND imagery only. Do NOT render any
words, letters, headlines, captions, watermarks, UI, or logos — leave clean negative
space (roughly one third of the frame) for text to be added later. Professional,
on-brand, uncluttered composition."

if ! command -v codex >/dev/null 2>&1; then
  echo "NIGHTSHIFT: codex not found on PATH. Install the Codex CLI (the ad-designer will otherwise fall back to a brand gradient)." >&2
  exit 127
fi

CODEX_TASK="Generate a single image using your image-generation skill (model ${MODEL}) \
at size ${SIZE}. Save it to the exact path: ${OUT} (create parent dirs if needed). \
After saving, print only the absolute path. Prompt for the image:
${FULL_PROMPT}"

# workspace-write so Codex can save the file; never prompts (unattended-safe).
codex exec --sandbox workspace-write --ask-for-approval never "$CODEX_TASK" >&2 || true

if [ -f "$OUT" ]; then
  echo "$OUT"
else
  echo "NIGHTSHIFT: Codex did not produce $OUT. Check Codex auth / image skill." >&2
  exit 1
fi
