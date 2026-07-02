#!/usr/bin/env bash
# Nightshift GitHub helper. Thin, safe wrapper around the gh CLI for creating and
# updating issues from the PRD. No destructive gh operations are exposed here.
#
#   gh-issues.sh check                                  -> verify gh + repo + auth
#   gh-issues.sh create "<title>" "<body>" "l1,l2"      -> create issue, prints URL
#   gh-issues.sh comment <number|url> "<markdown body>" -> append a progress comment
#   gh-issues.sh close   <number|url> "<comment>"       -> comment + close as done
#   gh-issues.sh list                                   -> list open nightshift issues
set -euo pipefail

need_gh() {
  command -v gh >/dev/null 2>&1 || { echo "NIGHTSHIFT: gh CLI not found. GitHub sync skipped." >&2; exit 127; }
}

cmd="${1:-check}"; shift || true

case "$cmd" in
  check)
    need_gh
    gh auth status >/dev/null 2>&1 || { echo "NIGHTSHIFT: gh not authenticated (run: gh auth login)." >&2; exit 1; }
    gh repo view --json nameWithOwner -q .nameWithOwner
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
  *)
    echo "usage: gh-issues.sh [check|create|comment|close|list] ..." >&2
    exit 64
    ;;
esac
