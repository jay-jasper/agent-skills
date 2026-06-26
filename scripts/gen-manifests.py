#!/usr/bin/env python3
"""Regenerate manifests/ from the live machine state.

Source of truth on this machine:
  ~/agent-skill-repos/<dir>   git clones of third-party skill repos
  ~/.claude/skills/<name>     symlinks into those clones (340) or own dirs (7)
  ~/.claude/plugins/*.json    installed plugins + their marketplaces

Run on the machine that currently has everything set up. Commits the JSON.
No skill .md files are copied for third-party repos — only their git remote.
"""
import json, os, subprocess, sys
from pathlib import Path

HOME = Path.home()
REPOS = HOME / "agent-skill-repos"
SKILLS = HOME / ".claude" / "skills"          # symlink -> ~/agent-skills
PLUGINS = HOME / ".claude" / "plugins"
OUT = Path(__file__).resolve().parent.parent / "manifests"


def git_remote(d: Path):
    try:
        return subprocess.check_output(
            ["git", "-C", str(d), "remote", "get-url", "origin"],
            text=True, stderr=subprocess.DEVNULL).strip() or None
    except subprocess.CalledProcessError:
        return None


def gen_skills():
    # repodir -> {"remote": url, "skills": {name: relpath-within-clone}}
    repos = {}
    local = []                     # own skills, no upstream -> committed as files
    IGNORE = {"learned"}   # ECC continuous-learning runtime dir, not a tracked skill
    for entry in sorted(SKILLS.iterdir()):
        if entry.name.startswith(".") or entry.name in IGNORE:
            continue
        if entry.is_symlink():
            tgt = os.readlink(entry)
            parts = Path(tgt).parts
            if "agent-skill-repos" in parts:
                i = parts.index("agent-skill-repos")
                repodir = parts[i + 1]
                relpath = "/".join(parts[i + 2:])   # "" when skill == clone root
                repos.setdefault(repodir, {"remote": None, "skills": {}})
                repos[repodir]["skills"][entry.name] = relpath
            else:
                local.append(entry.name)        # symlink outside the repo cache
        elif entry.is_dir():
            local.append(entry.name)            # real own-authored dir

    for repodir in repos:
        repos[repodir]["remote"] = git_remote(REPOS / repodir)
        repos[repodir]["skills"] = dict(sorted(repos[repodir]["skills"].items()))

    lock = {
        "_note": "Third-party skills. install.sh clones each remote into "
                 "~/agent-skill-repos/<dir> and symlinks listed skills into "
                 "~/.claude/skills. No skill files are vendored here.",
        "repos": dict(sorted(repos.items())),
        "local_skills": sorted(local),   # committed under local-skills/, copied in by install.sh
    }
    (OUT / "skills.lock.json").write_text(json.dumps(lock, indent=2) + "\n")
    n = sum(len(r["skills"]) for r in repos.values())  # skills is a {name: relpath} dict
    print(f"skills.lock.json: {len(repos)} repos, {n} skills, "
          f"{len(local)} local skills")
    missing = [d for d, r in repos.items() if not r["remote"]]
    if missing:
        print("  WARN no remote for:", missing, file=sys.stderr)
    return lock


def gen_plugins():
    installed = json.loads((PLUGINS / "installed_plugins.json").read_text())
    markets = json.loads((PLUGINS / "known_marketplaces.json").read_text())

    market_src = {}
    for name, m in markets.items():
        s = m["source"]
        market_src[name] = s.get("repo") or s.get("url")  # github repo slug or git url

    plugins = []
    for key in installed["plugins"]:
        plug, _, market = key.partition("@")
        plugins.append({"plugin": plug, "marketplace": market})
    plugins.sort(key=lambda p: (p["marketplace"], p["plugin"]))

    lock = {
        "_note": "Re-add each marketplace, then install each plugin. "
                 "claude plugin marketplace add <src>; claude plugin install <plugin>@<market>",
        "marketplaces": dict(sorted(market_src.items())),
        "plugins": plugins,
    }
    (OUT / "plugins.lock.json").write_text(json.dumps(lock, indent=2) + "\n")
    print(f"plugins.lock.json: {len(market_src)} marketplaces, {len(plugins)} plugins")
    return lock


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    gen_skills()
    gen_plugins()
