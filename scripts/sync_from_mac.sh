#!/bin/bash
# Keep a long-lived "windows" branch in step with your main (Mac) branch WITHOUT losing the Windows-only edits.
#
# The idea: the Windows branch is a copy of main as of some commit BASE, plus a handful of Windows edits. To catch up, for every
# file main changed since BASE:
#   - the Windows branch never touched it -> take main's version;
#   - both changed it                      -> 3-way merge (git merge-file: BASE / this branch / main);
#   - conflicts stay in the file as <<<<<<< markers and are listed at the end.
# Then build in CI, and use the new main commit as BASE next time.
#
#   scripts/sync_from_mac.sh <ref of newer main, e.g. origin/main> [BASE commit] [paths...]
# BASE defaults to the file .windows-sync-base (one line: a commit id) at the repo root. Run it on a clean tree.
set -eu
NEW="${1:?usage: sync_from_mac.sh <newer ref, e.g. origin/main> [BASE] [paths...]}"
BASE="${2:-$(cat .windows-sync-base 2>/dev/null || true)}"
[ -n "$BASE" ] || { echo "no BASE: pass a commit id or write one into .windows-sync-base"; exit 1; }
shift 2 2>/dev/null || shift $# || true
PATHS="${*:-.}"
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "commit or stash first"; exit 1; }

conflicts=()
while IFS=$'\t' read -r st f g; do
  case "$st" in
    M|A)
      if [ ! -e "$f" ] || git diff --quiet "$BASE" HEAD -- "$f" 2>/dev/null; then       # the branch never touched it (or it is new)
        git checkout "$NEW" -- "$f"; echo "took   $f"
      else
        b=$(mktemp); n=$(mktemp)
        git show "$BASE:$f" > "$b" 2>/dev/null || : > "$b"
        git show "$NEW:$f" > "$n"
        if git merge-file "$f" "$b" "$n" 2>/dev/null; then echo "merged $f"; else echo "CONFLICT $f"; conflicts+=("$f"); fi
        rm -f "$b" "$n"
      fi ;;
    D) echo "main deleted $f (check by hand)" ;;
    R*) echo "renamed on main: $f -> $g (check by hand)" ;;
  esac
done < <(git diff --name-status "$BASE" "$NEW" -- $PATHS)

echo; echo "${#conflicts[@]} conflict(s)"; printf '  %s\n' "${conflicts[@]:-none}"
echo "Next: fix conflicts, git add -A, build in CI, then write $(git rev-parse --short "$NEW") into .windows-sync-base."
