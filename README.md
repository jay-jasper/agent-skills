# agent-skills

Reproducible record of my Claude Code skills + plugins. Switch machines, run one
script, get everything back. Third-party skills are tracked by their **git remote**
(not vendored); only my own skills live here as files.

## Layout

```
manifests/skills.lock.json    33 third-party repos -> which skills each provides + local skill list
manifests/plugins.lock.json   8 plugin marketplaces + 18 installed plugins
local-skills/                 my own skills, real files (no upstream): agent-reach, clone-website,
                              find-skills, graphify, impeccable, lean-ctx, learned
install.sh                    rebuild everything from the manifests
scripts/gen-manifests.py      regenerate the manifests from the live machine
skills-cleanup.md             my keep/archive curation notes
```

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
