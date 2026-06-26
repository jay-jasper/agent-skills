#!/usr/bin/env bash
# Reproduce all skills + plugins on a fresh machine from the manifests.
#   - plugin-capable repos: installed via `claude plugin` (preferred)
#   - the rest: cloned into ~/agent-skill-repos/<dir> and symlinked into ~/.claude/skills
# Idempotent: safe to re-run. Requires git, python3, and (for plugins) the claude CLI.
# Reports every failure at the end and exits non-zero if anything failed.
set -uo pipefail   # NOT -e: we collect failures instead of aborting

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS="${HOME}/agent-skill-repos"
SKILLS_LINK="${HOME}/.claude/skills"
SKILLS="$(cd "$(dirname "$SKILLS_LINK")" && readlink "$(basename "$SKILLS_LINK")" 2>/dev/null || echo "$SKILLS_LINK")"
mkdir -p "$REPOS" "$SKILLS"

# Some plugin marketplaces declare their plugin source over SSH (git@github.com);
# rewrite to HTTPS so `claude plugin install` works with an HTTPS GitHub token.
git config --global --get-regexp '^url\.https://github\.com/\.insteadof$' >/dev/null 2>&1 \
  || git config --global url."https://github.com/".insteadOf "git@github.com:"

jqpy() { python3 -c "import json,sys; $1" < "$2"; }
FAILS=()

# ---- clone + symlink repos ----
echo "==> Skill repos (clone + symlink) -> $REPOS"
linked=0; expected=0
while IFS=$'\t' read -r repodir remote name relpath; do
  expected=$((expected+1))
  dest="$REPOS/$repodir"
  if [ ! -d "$dest/.git" ]; then
    echo "  clone $repodir"
    git clone --depth 1 -q "$remote" "$dest" || { FAILS+=("clone $remote"); continue; }
  fi
  src="$dest${relpath:+/$relpath}"
  if ! ls "$src"/[Ss][Kk][Ii][Ll][Ll].md >/dev/null 2>&1; then FAILS+=("no SKILL.md: $name @ $src"); continue; fi
  ln -sfn "$src" "$SKILLS/$name" && linked=$((linked+1)) || FAILS+=("symlink $name")
done < <(jqpy "d=json.load(sys.stdin)['repos']; [print('\t'.join((k,v['remote'],n,p))) for k,v in d.items() for n,p in v['skills'].items()]" "$ROOT/manifests/skills.lock.json")
echo "  linked $linked/$expected skills"

# ---- plugins ----
echo "==> Plugins"
if ! command -v claude >/dev/null 2>&1; then
  FAILS+=("claude CLI not found — plugins skipped; install Claude Code and re-run")
  echo "  SKIP: claude CLI not found" >&2
else
  while IFS=$'\t' read -r name src; do
    claude plugin marketplace add "$src" >/dev/null 2>&1 \
      || claude plugin marketplace add "$src" 2>&1 | grep -qi 'already' \
      || FAILS+=("marketplace add $src")
  done < <(jqpy "d=json.load(sys.stdin)['marketplaces']; [print(f'{k}\t{v}') for k,v in d.items()]" "$ROOT/manifests/plugins.lock.json")

  pcount=0; pok=0
  while read -r ref; do
    pcount=$((pcount+1))
    if out=$(claude plugin install "$ref" 2>&1); then pok=$((pok+1))
    elif echo "$out" | grep -qi 'already'; then pok=$((pok+1))
    else FAILS+=("install $ref"); fi
  done < <(jqpy "d=json.load(sys.stdin)['plugins']; [print(f\"{p['plugin']}@{p['marketplace']}\") for p in d]" "$ROOT/manifests/plugins.lock.json")
  echo "  installed $pok/$pcount plugins"
fi

# ---- self-check / summary ----
broken=$(find "$SKILLS" -maxdepth 1 -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
[ "$broken" -gt 0 ] && FAILS+=("$broken broken symlink(s) in $SKILLS")

echo
if [ ${#FAILS[@]} -eq 0 ]; then
  echo "==> OK. Restart Claude Code to load."
else
  echo "==> ${#FAILS[@]} problem(s):" >&2
  printf '   - %s\n' "${FAILS[@]}" >&2
  exit 1
fi
