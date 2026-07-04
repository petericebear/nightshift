#!/usr/bin/env bash
# Nightshift ad-visual generator. Produces a BASE visual (background imagery only,
# no text) at the nearest model-supported size; the compositor (compose.py) then
# crops to exact ad dimensions and overlays crisp logo + copy.
#
#   adgen.sh <aspect> "<image prompt>" <out.png>
#     aspect: square | landscape | portrait | story
#
# Backend (env NIGHTSHIFT_IMAGE_BACKEND):
#   codex  (default) -> drive the Codex CLI's image-generation skill (uses your
#                       OpenAI/ChatGPT auth). Model via NIGHTSHIFT_IMAGE_MODEL
#                       (default gpt-image-2).
#   api             -> call the OpenAI Images API directly with curl (needs
#                       OPENAI_API_KEY). Deterministic fallback for CI/unattended.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASPECT="${1:?aspect required: square|landscape|portrait|story}"
PROMPT="${2:?image prompt required}"
OUT="${3:?output path required}"
BACKEND="${NIGHTSHIFT_IMAGE_BACKEND:-codex}"
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

if [ "$BACKEND" = "api" ]; then
  : "${OPENAI_API_KEY:?OPENAI_API_KEY required for api backend}"
  command -v curl >/dev/null || { echo "adgen.sh: curl required" >&2; exit 127; }
  command -v python3 >/dev/null || { echo "adgen.sh: python3 required to decode" >&2; exit 127; }
  resp="$(curl -sS https://api.openai.com/v1/images/generations \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$(python3 -c 'import json,sys,os; print(json.dumps({"model":os.environ["M"],"prompt":sys.argv[1],"size":os.environ["S"],"n":1}))' "$FULL_PROMPT" M="$MODEL" S="$SIZE")")"
  M="$MODEL" S="$SIZE" python3 - "$OUT" <<'PY'
import json,sys,base64
out=sys.argv[1]
data=json.load(sys.stdin)
try:
    b64=data["data"][0]["b64_json"]
except Exception:
    sys.stderr.write("adgen.sh: unexpected API response: %s\n"%str(data)[:400]); sys.exit(1)
open(out,"wb").write(base64.b64decode(b64))
print(out)
PY
  exit 0
fi

# Default: Codex backend.
if ! command -v codex >/dev/null 2>&1; then
  echo "NIGHTSHIFT: codex not found. Install the Codex CLI, or set NIGHTSHIFT_IMAGE_BACKEND=api with OPENAI_API_KEY." >&2
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
  echo "NIGHTSHIFT: Codex did not produce $OUT. Check Codex auth/image skill, or use the api backend." >&2
  exit 1
fi
