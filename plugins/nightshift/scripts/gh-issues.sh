#!/usr/bin/env bash
# Nightshift GitHub helper. Thin, safe wrapper around the gh CLI for issue + PR
# work. No destructive gh operations are exposed here.
#
# Issue creation / status:
#   gh-issues.sh check                                  -> verify gh + repo + auth (prints repo)
#   gh-issues.sh create "<title>" "<body>" "l1,l2"      -> create issue, prints URL
#   gh-issues.sh comment <number|url> "<markdown body>" -> append a progress comment
#   gh-issues.sh close   <number|url> "<comment>"       -> comment + close as done
#   gh-issues.sh list                                   -> list open nightshift issues
#
# Triage lifecycle (ai-ready -> ai-building -> ai-review):
#   gh-issues.sh ensure-labels                          -> create the ai-* labels if missing
#   gh-issues.sh ready                                  -> TSV "<num>\t<title>" of open ai-ready issues
#   gh-issues.sh get <number>                           -> issue title + body (as mini-spec)
#   gh-issues.sh relabel <number> <add> <remove>        -> swap labels atomically
#   gh-issues.sh pr <branch> <title> <body>             -> open a ready-for-review PR, prints URL
set -euo pipefail

need_gh() {
  command -v gh >/dev/null 2>&1 || { echo "NIGHTSHIFT: gh CLI not found. GitHub sync skipped." >&2; exit 127; }
}

ensure_label() {
  local name="$1" color="$2" desc="$3"
  gh label create "$name" --color "$color" --description "$desc" >/dev/null 2>&1 || \
  gh label edit   "$name" --color "$color" --description "$desc" >/dev/null 2>&1 || true
}

cmd="${1:-check}"; shift || true

case "$cmd" in
  check)
    need_gh
    gh auth status >/dev/null 2>&1 || { echo "NIGHTSHIFT: gh not authenticated (run: gh auth login)." >&2; exit 1; }
    gh repo view --json nameWithOwner -q .nameWithOwner
    ;;

  ensure-labels)
    need_gh
    ensure_label "ai-ready"    "1D76DB" "Ready for Nightshift to build"
    ensure_label "ai-building" "FBCA04" "Nightshift is currently building this"
    ensure_label "ai-review"   "0E8A16" "Built by Nightshift; PR awaiting human review"
    ensure_label "nightshift"  "5319E7" "Created/handled by Nightshift"
    echo "labels ensured"
    ;;

  ready)
    need_gh
    gh issue list --label ai-ready --state open --limit 100 \
      --json number,title --jq '.[] | "\(.number)\t\(.title)"'
    ;;

  get)
    need_gh
    NUM="${1:?issue number required}"
    gh issue view "$NUM" --json number,title,body,labels,url \
      --jq '"# Issue #\(.number): \(.title)\nURL: \(.url)\nLabels: \([.labels[].name]|join(", "))\n\n\(.body // "(no description)")"'
    ;;

  relabel)
    need_gh
    NUM="${1:?issue number required}"; ADD="${2:?add label required}"; REMOVE="${3:-}"
    if [ -n "$REMOVE" ]; then
      gh issue edit "$NUM" --add-label "$ADD" --remove-label "$REMOVE"
    else
      gh issue edit "$NUM" --add-label "$ADD"
    fi
    ;;

  create)
    need_gh
    TITLE="${1:?title required}"; BODY="${2:-}"; LABELS="${3:-nightshift}"
    gh issue create --title "$TITLE" --body "$BODY" --label "$LABELS" 2>/dev/null \
      || gh issue create --title "$TITLE" --body "$BODY"
    ;;

  comment)
    need_gh
    REF="${1:?issue number or url required}"; BODY="${2:?body required}"
    gh issue comment "$REF" --body "$BODY"
    ;;

  close)
    need_gh
    REF="${1:?issue number or url required}"; BODY="${2:-Completed by Nightshift.}"
    gh issue comment "$REF" --body "$BODY"
    gh issue close "$REF"
    ;;

  list)
    need_gh
    gh issue list --label nightshift --state open
    ;;

  pr)
    need_gh
    BRANCH="${1:?branch required}"; TITLE="${2:?title required}"; BODY="${3:-}"
    # Ready-for-review PR (not draft). Base is the repo default branch.
    gh pr create --head "$BRANCH" --title "$TITLE" --body "$BODY" --fill-first 2>/dev/null \
      || gh pr create --head "$BRANCH" --title "$TITLE" --body "$BODY"
    ;;

  *)
    echo "usage: gh-issues.sh [check|ensure-labels|ready|get|relabel|create|comment|close|list|pr] ..." >&2
    exit 64
    ;;
esac
