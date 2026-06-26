# agent-skills

Reproducible record of my Claude Code skills + plugins. Switch machines, run one
script, get everything back. Nothing is vendored — every skill is tracked by its
GitHub source. **Plugin-first**: repos that ship a plugin marketplace are installed
via `claude plugin`; the rest are cloned and symlinked.

## Layout

```
manifests/plugins.lock.json   21 plugin marketplaces + 36 plugins (preferred install method)
manifests/skills.lock.json    26 non-plugin repos -> which skills each provides (clone + symlink)
install.sh                    rebuild everything from the manifests; reports every failure, exits non-zero if any
update.sh                     git-pull all clones + `claude plugin update` all plugins, then refresh manifests
scripts/gen-manifests.py      regenerate the manifests from the live machine
skills-cleanup.md             my keep/archive curation notes
```

Every source repo was checked for plugin packaging (`.claude-plugin/marketplace.json`).
Repos that have it are installed as plugins (cleaner, native); repos without it stay
clone+symlink. `install.sh` sets `git insteadOf` to rewrite SSH plugin sources to HTTPS
(needed for `addyosmani`). One plugin-capable repo still falls back to clone+symlink:
`BigPapiCB` (its marketplace.json is at the repo root, which the CLI doesn't accept).

## On a new machine

```bash
git clone <this-repo> ~/agent-skills-repo && cd ~/agent-skills-repo
./install.sh
```

This clones each third-party repo into `~/agent-skill-repos/<dir>`, symlinks the
recorded skills into `~/.claude/skills`, copies `local-skills/` in, then re-adds the
plugin marketplaces and installs the plugins (needs the `claude` CLI). Idempotent.

## After installing/removing skills, refresh the record

```bash
python3 scripts/gen-manifests.py && git commit -am "update manifests"
```

It reads the live state — `~/agent-skill-repos/` git remotes, `~/.claude/skills`
symlinks, and `~/.claude/plugins/*.json` — so the lock files always match reality.

## How it maps on this machine

`~/.claude/skills` is a symlink to `~/agent-skills`, whose entries are mostly
symlinks into the per-repo clones under `~/agent-skill-repos/`. The 7 real dirs are
my own skills, captured under `local-skills/`.
