#!/usr/bin/env bash
# Usage: ./create_gh_issue.sh <ticket-file.md> [--blocked-by "num1,num2"]
# Creates a GitHub issue from a ticket markdown file in .scratch/missing-features/issues/
# Requires: gh CLI authenticated (gh auth login)
#
# Expected ticket file format (see .scratch/missing-features/issues/*.md):
#   # NN — Ticket title
#   **What to build:** <description>
#   **Blocked by:** <blockers>
#   **Status:** ready-for-agent
#   - [ ] Acceptance criterion
#   - [ ] Acceptance criterion
#
# Optional --blocked-by sets native GitHub blocking relationships
# (comma-separated issue numbers).

set -euo pipefail

TICKET_FILE="${1:-}"
shift 2>/dev/null || true
BLOCKED_BY_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --blocked-by)
      BLOCKED_BY_FLAG="$2"
      shift 2 || true
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$TICKET_FILE" || ! -f "$TICKET_FILE" ]]; then
  echo "Usage: $0 <ticket-file.md> [--blocked-by \"num1,num2\"]"
  echo "Example: $0 .scratch/missing-features/issues/01-use-operation-ids.md"
  exit 1
fi

# Extract ticket number and slug from filename
FILENAME=$(basename "$TICKET_FILE")
TICKET_NUM="${FILENAME%%-*}"

# Parse the markdown file
# Title is like "01 — Use Operation IDs for command naming"; strip leading "NN — "
TITLE=$(grep -m1 '^# ' "$TICKET_FILE" | sed 's/^# *//' | sed -E 's/^[0-9]+ *[—-]? *//')
BODY=$(sed -n 's/^\*\*What to build:\*\* //p' "$TICKET_FILE")
BLOCKED_BY=$(sed -n 's/^\*\*Blocked by:\*\* //p' "$TICKET_FILE")
STATUS=$(sed -n 's/^\*\*Status:\*\* //p' "$TICKET_FILE")
STATUS="${STATUS:-ready-for-agent}"

# Extract acceptance criteria (already formatted as "- [ ] xyz")
CRITERIA=$(grep '^\- \[' "$TICKET_FILE")

# Build the issue body
ISSUE_BODY=$(cat <<EOF
## What to build
$BODY

## Acceptance criteria
$CRITERIA

## Blocked by
$BLOCKED_BY

## Status
$STATUS

---
*Generated from ticket: \`$FILENAME\`*
EOF
)

# Print what we're creating
echo "Creating GitHub issue for ticket $TICKET_NUM: $TITLE"
echo "  Blocked by: $BLOCKED_BY"
echo "  Status: $STATUS"

# Ensure the label exists (create if missing, idempotent)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
if ! gh label view "$STATUS" --repo "$REPO" >/dev/null 2>&1; then
  gh label create "$STATUS" --description "Ticket status" --color "0E8A16" --repo "$REPO" >/dev/null 2>&1 || true
fi

# Create the issue
GH_ARGS=(--title "[$TICKET_NUM] $TITLE" --body "$ISSUE_BODY" --label "$STATUS,enhancement" --repo "$REPO")
if [[ -n "$BLOCKED_BY_FLAG" ]]; then
  GH_ARGS+=(--blocked-by "$BLOCKED_BY_FLAG")
  echo "  Blocking edges: $BLOCKED_BY_FLAG"
fi
gh issue create "${GH_ARGS[@]}"

echo "Done."
