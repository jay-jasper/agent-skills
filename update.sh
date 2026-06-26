#!/usr/bin/env bash
# Pull latest for every clone+symlink repo and update every installed plugin,
# then refresh the manifests to match. Run from a machine that's already set up.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS="${HOME}/agent-skill-repos"

echo "==> git pull skill clones"
for d in "$REPOS"/*/; do
  [ -d "$d/.git" ] || continue
  name="$(basename "$d")"
  if git -C "$d" pull -q --ff-only 2>/dev/null; then echo "  ok   $name"; else echo "  skip $name (no ff / not a branch)"; fi
done

echo "==> update plugins"
if command -v claude >/dev/null 2>&1; then
  while read -r p; do
    claude plugin update "$p" >/dev/null 2>&1 && echo "  ok   $p" || echo "  skip $p"
  done < <(python3 -c "import json;[print(p['plugin']) for p in json.load(open('$ROOT/manifests/plugins.lock.json'))['plugins']]")
else
  echo "  SKIP: claude CLI not found" >&2
fi

echo "==> regenerate manifests"
python3 "$ROOT/scripts/gen-manifests.py"
echo "==> done. Review 'git diff manifests/' and commit if changed."
