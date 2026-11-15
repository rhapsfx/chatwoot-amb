#!/usr/bin/env bash
# Verify that relative links inside docs/ still resolve.
#
# Background: docs/README.md was a hand-maintained file inventory and drifted
# badly — 54% of relative links were dead before the 2026-11 restructure. This
# script gates new breakage against a baseline of known-dead links so it can be
# used in CI today, while the remaining ones are cleaned up area by area.
#
# Usage:
#   script/check-docs-links.sh                    # fail on links not in the baseline
#   script/check-docs-links.sh --list             # print every broken link
#   script/check-docs-links.sh --update-baseline  # accept current state (review the diff!)
set -euo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0"/..)"

BASELINE="script/docs-links-baseline.txt"
mode="check"
for arg in "$@"; do
  case "$arg" in
    --list) mode="list" ;;
    --update-baseline) mode="update" ;;
    *)
      echo "Usage: $0 [--list|--update-baseline]" >&2
      exit 2
      ;;
  esac
done

python3 - "$mode" "$BASELINE" <<'PY'
import os
import re
import sys
import urllib.parse

mode, baseline_path = sys.argv[1], sys.argv[2]
ROOT = "docs"
LINK = re.compile(r"\]\(([^)\s]+)\)")

broken = set()
total = 0
outside = set()

for dirpath, _, files in os.walk(ROOT):
    for name in sorted(files):
        if not name.endswith(".md"):
            continue
        path = os.path.join(dirpath, name)
        rel_file = os.path.relpath(path, ROOT)
        text = open(path, encoding="utf-8", errors="ignore").read()
        for match in LINK.finditer(text):
            target = match.group(1)
            if target.startswith(("http://", "https://", "mailto:", "#", "/")):
                continue
            path_part = urllib.parse.unquote(target.split("#")[0])
            if not path_part:
                continue
            total += 1
            resolved = os.path.normpath(os.path.join(dirpath, path_part))
            if os.path.exists(resolved):
                continue
            broken.add(f"{rel_file} -> {target}")
            if not resolved.startswith(ROOT + os.sep):
                outside.add(resolved)

if mode == "list":
    print(f"docs/ relative links: {total}, broken: {len(broken)}")
    for entry in sorted(broken):
        print(f"  {entry}")
    sys.exit(0)

if mode == "update":
    with open(baseline_path, "w", encoding="utf-8") as fh:
        fh.write("# Known-broken relative links in docs/ (regenerate: script/check-docs-links.sh --update-baseline)\n")
        fh.write("# Fix these area by area; the checker fails only on links missing from this list.\n")
        for entry in sorted(broken):
            fh.write(entry + "\n")
    print(f"baseline updated: {len(broken)} known-broken links -> {baseline_path}")
    sys.exit(0)

known = set()
if os.path.exists(baseline_path):
    for line in open(baseline_path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#"):
            known.add(line)

new = sorted(broken - known)
fixed = sorted(known - broken)

print(f"docs/ relative links: {total}, broken: {len(broken)} "
      f"(baseline {len(known)})")

if outside:
    print(f"WARNING: {len(outside)} link(s) point outside docs/, which is excluded "
          f"from the Docker image — prefer a GitHub URL.")

if new:
    print(f"\nFAIL: {len(new)} new broken link(s) not in {baseline_path}:")
    for entry in new:
        print(f"  {entry}")
if fixed:
    print(f"\nNOTE: {len(fixed)} baseline link(s) now resolve — "
          f"run --update-baseline to shrink the baseline.")

sys.exit(1 if new else 0)
PY
