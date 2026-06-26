#!/usr/bin/env bash
# Reproduce all skills + plugins on a fresh machine from the manifests.
#   - clones each third-party repo into ~/agent-skill-repos/<dir>
#   - symlinks the recorded skills into ~/.claude/skills
#   - copies the own-authored local-skills/ in as real dirs
#   - re-adds plugin marketplaces and installs plugins via `claude`
# Idempotent: safe to re-run. Requires git, python3, and (for plugins) the claude CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS="${HOME}/agent-skill-repos"
# ~/.claude/skills may itself be a symlink; resolve to the real dir.
SKILLS_LINK="${HOME}/.claude/skills"
SKILLS="$(cd "$(dirname "$SKILLS_LINK")" && readlink "$(basename "$SKILLS_LINK")" 2>/dev/null || echo "$SKILLS_LINK")"
mkdir -p "$REPOS" "$SKILLS"

jqpy() { python3 -c "import json,sys; $1" < "$2"; }

echo "==> Third-party skill repos -> $REPOS"
# emit one line per skill: <repodir>\t<remote>\t<name>\t<relpath-within-clone>
jqpy "d=json.load(sys.stdin)['repos']; [print('\t'.join((k,v['remote'],n,p))) for k,v in d.items() for n,p in v['skills'].items()]" \
  "$ROOT/manifests/skills.lock.json" |
while IFS=$'\t' read -r repodir remote name relpath; do
  dest="$REPOS/$repodir"
  if [ ! -d "$dest/.git" ]; then
    echo "  clone $repodir"
    git clone --depth 1 -q "$remote" "$dest" || { echo "    FAILED $remote" >&2; continue; }
  fi
  src="$dest${relpath:+/$relpath}"
  # some repos ship lowercase skill.md
  if ! ls "$src"/[Ss][Kk][Ii][Ll][Ll].md >/dev/null 2>&1; then echo "    WARN no SKILL.md at $src" >&2; continue; fi
  ln -sfn "$src" "$SKILLS/$name"
done

echo "==> Plugins"
if ! command -v claude >/dev/null 2>&1; then
  echo "  SKIP: claude CLI not found. Install Claude Code, then re-run." >&2
else
  jqpy "d=json.load(sys.stdin)['marketplaces']; [print(f'{k}\t{v}') for k,v in d.items()]" \
    "$ROOT/manifests/plugins.lock.json" |
  while IFS=$'\t' read -r name src; do
    echo "  marketplace add $name ($src)"
    claude plugin marketplace add "$src" >/dev/null 2>&1 || echo "    (already added or failed: $src)" >&2
  done
  jqpy "d=json.load(sys.stdin)['plugins']; [print(f\"{p['plugin']}@{p['marketplace']}\") for p in d]" \
    "$ROOT/manifests/plugins.lock.json" |
  while read -r ref; do
    echo "  install $ref"
    claude plugin install "$ref" >/dev/null 2>&1 || echo "    (already installed or failed: $ref)" >&2
  done
fi

echo "==> Done. Restart Claude Code to load."
