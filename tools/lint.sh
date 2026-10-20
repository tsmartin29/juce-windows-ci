#!/bin/bash
# Cheap checks you can run on a Mac before pushing (no Windows needed):
#   - actionlint on the workflow, if it is installed (brew install actionlint)
#   - otherwise a plain YAML parse (ruby ships with macOS) plus a check that every script the workflow calls exists
#   - shellcheck on the shell scripts, if installed
set -eu
cd "$(dirname "$0")/.."
wf=.github/workflows/windows.yml
if command -v actionlint >/dev/null; then
  actionlint "$wf" && echo "actionlint: ok"
else
  echo "actionlint not installed: falling back to a YAML parse"
  ruby -ryaml -e 'y = YAML.load_file(ARGV[0]); abort("no jobs") unless y["jobs"]; puts "yaml: ok (#{y["jobs"].keys.join(", ")})"' "$wf"
fi
missing=0
for f in $(grep -o '\./scripts/[A-Za-z_]*\.ps1' "$wf" | sort -u) installer/GainExample.iss; do
  [ -e "$f" ] || { echo "MISSING $f (used by the workflow)"; missing=1; }
done
[ "$missing" = 0 ] && echo "referenced files: ok"
if command -v shellcheck >/dev/null; then shellcheck scripts/*.sh tools/*.sh && echo "shellcheck: ok"; fi
exit "$missing"
