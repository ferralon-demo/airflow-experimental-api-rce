#!/usr/bin/env bash
# prep-demo.sh — reset `main` to the exact tree of this repository's GOLDEN branch.
#
# Generalised from ferralon-demo/demo-go-svc/.demo/prep-demo.sh (TEG-049) by the fixture layout
# standard (pipeline-test 1.3, 2026-09-22). The only change: the golden branch name is read
# from .demo/golden-branch (one line), because the case-study repos use `baseline` where
# demo-go-svc uses `vulnerable`. DEMO_GOLDEN_BRANCH still overrides it.
#
# THE BRANCH MODEL
#   <golden>  = the reference tree (`vulnerable` or `baseline`). Honestly vulnerable. NEVER fired
#               against, NEVER the default branch, NEVER takes a merge. Designated protected per
#               repo in the backend (cmd/protect-ref).
#   main      = the DISPOSABLE fire target and the default branch. The only scanned branch. Reset
#               FROM the golden branch, fired against, then patched by the auto-prove fix-PR.
#
# A hard reset / force-push is used, NOT a merge: a merge accumulates history and cannot cleanly
# re-introduce the vulnerability over a previously-patched main.
#
# SAFETY: this FORCE-PUSHES main. DRY-RUN BY DEFAULT — it fetches, prints the plan and the
# main→golden diff, and changes NOTHING. Pass --execute to reset + force-push (it still asks you
# to type the branch name, unless --yes).
#
# Usage:
#   .demo/prep-demo.sh                 # dry-run (default)
#   .demo/prep-demo.sh --execute       # live, with typed confirmation
#   .demo/prep-demo.sh --execute --yes # live, no prompt
#
# Env overrides: DEMO_REMOTE (origin), DEMO_GOLDEN_BRANCH (from .demo/golden-branch, else
# vulnerable), DEMO_TARGET_BRANCH (main).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

REMOTE="${DEMO_REMOTE:-origin}"
if [ -n "${DEMO_GOLDEN_BRANCH:-}" ]; then
  GOLDEN="$DEMO_GOLDEN_BRANCH"
elif [ -f .demo/golden-branch ]; then
  GOLDEN="$(tr -d '[:space:]' < .demo/golden-branch)"
else
  GOLDEN=vulnerable
fi
TARGET="${DEMO_TARGET_BRANCH:-main}"
EXECUTE=0
ASSUME_YES=0

for arg in "$@"; do
  case "$arg" in
    --execute)  EXECUTE=1 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    -h|--help)  sed -n '2,31p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "prep-demo: unknown argument: $arg (try --help)" >&2; exit 2 ;;
  esac
done

if [ "$GOLDEN" = "$TARGET" ]; then
  echo "prep-demo: golden branch and target are both '$TARGET' — refusing." >&2
  exit 2
fi

banner() {
  echo "==============================================================================="
  echo "  $*"
  echo "==============================================================================="
}

echo "prep-demo: fetching $REMOTE …"
git fetch --prune "$REMOTE" >/dev/null 2>&1 || { echo "prep-demo: git fetch $REMOTE failed" >&2; exit 1; }

if ! git rev-parse --verify --quiet "$REMOTE/$GOLDEN" >/dev/null; then
  echo "prep-demo: golden branch '$REMOTE/$GOLDEN' not found — cannot reset from a missing baseline." >&2
  exit 1
fi
GOLDEN_SHA="$(git rev-parse "$REMOTE/$GOLDEN")"

if git rev-parse --verify --quiet "$REMOTE/$TARGET" >/dev/null; then
  TARGET_SHA="$(git rev-parse "$REMOTE/$TARGET")"
  TARGET_EXISTS=1
else
  TARGET_SHA="(does not exist yet — would be created)"
  TARGET_EXISTS=0
fi

banner "prep-demo — reset  $TARGET  ->  $GOLDEN's exact tree   [remote: $REMOTE]"
echo "  golden  $GOLDEN : $GOLDEN_SHA"
echo "  target  $TARGET : $TARGET_SHA"
echo ""

ALREADY_CLEAN=0
if [ "$TARGET_EXISTS" -eq 1 ] && git diff --quiet "$REMOTE/$TARGET" "$REMOTE/$GOLDEN"; then
  ALREADY_CLEAN=1
  echo "  $TARGET is ALREADY identical to $GOLDEN's tree — reset is a no-op."
elif [ "$TARGET_EXISTS" -eq 1 ]; then
  echo "  $TARGET differs from $GOLDEN — a reset would change:"
  git diff --stat "$REMOTE/$TARGET" "$REMOTE/$GOLDEN" | sed 's/^/      /'
else
  echo "  $TARGET does not exist on $REMOTE — a reset would CREATE it from $GOLDEN."
fi
echo ""

if [ "$EXECUTE" -ne 1 ]; then
  banner "DRY-RUN — nothing changed. Re-run with --execute to reset + force-push $TARGET."
  exit 0
fi
if [ "$ALREADY_CLEAN" -eq 1 ]; then
  banner "DONE (no-op) — $TARGET was already at $GOLDEN's tree."
  exit 0
fi

banner "!!  LIVE  —  about to FORCE-PUSH '$TARGET' to '$GOLDEN's tree' on '$REMOTE'  !!"
echo "  This DISCARDS whatever is on $REMOTE/$TARGET. It NEVER touches $GOLDEN."
if [ "$ASSUME_YES" -ne 1 ]; then
  printf "  Type the target branch name (%s) to confirm: " "$TARGET"
  read -r reply
  [ "$reply" = "$TARGET" ] || { echo "  confirmation mismatch — aborted, nothing pushed." >&2; exit 1; }
fi

if [ "$TARGET_EXISTS" -eq 1 ]; then
  git push --force-with-lease="$TARGET:$TARGET_SHA" "$REMOTE" "$REMOTE/$GOLDEN:refs/heads/$TARGET"
else
  git push "$REMOTE" "$REMOTE/$GOLDEN:refs/heads/$TARGET"
fi

banner "DONE — $TARGET now points at $GOLDEN ($GOLDEN_SHA)."
echo "  Fire against $TARGET. NEVER fire against, or merge into, $GOLDEN."
