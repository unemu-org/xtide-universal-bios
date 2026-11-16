# AGENTS.md — xtide-universal-bios (unemu fork)

Repo-specific notes for coding agents. Generic software-engineering advice is out of scope.

## What this is

A git fork of the **XTIDE Universal BIOS** (GPL-2.0, upstream in Subversion at
https://www.xtideuniversalbios.org/svn/xtideuniversalbios), converted with git-svn
with its full trunk history and tags. The unemu family of emulators uses its r638
XT+ build, configured for 16-bit ATA at 1F0h, as the fixed-disk option ROM of the
open AT machines of **unemupc98**. This repository builds exactly that ROM with
Nix, byte-identical to the ROM unemupc98 pins, and attaches it with its source
archive to GitHub releases. See `README.unemu.md` for the conversion, the build,
the configuration and the release.

## Language

- Talk to the maintainer in Polish.
- Everything committed is English: code, comments, docs, commit messages, bead text.

## Work tracking

Open work lives in **beads** (`bd`, prefix `xub`): `bd ready`, `bd show <id>`.
The shared working rules are beads memories; read them at session start with
`bd memories` (`bd recall <key>` for one): roles, fork-rules, build-and-release,
publication-rule, bead-workflow. Cross-repository ids carry a tag, e.g.
`upc-dfs.7 (unemupc)`, `um-7jx.12 (unemu-media)`; an untagged id is ours.

## Hard rules

- **Never commit without the maintainer's request** (may be granted for a session).
  `bd init` and some bd commands commit on their own: check `git log -1` after them.
- **Upstream stays upstream**: the git-svn history (every commit with a
  `git-svn-id:` line) is never rewritten. unemu files are added beside upstream's
  top-level entries; upstream files are not changed (`release/assets.sh` refuses
  a tag that changes them). The ROM configuration is applied to the assembled
  image, as the XTIDE configurator does, not by editing sources.
- **Byte identity**: every image's SHA-256 is pinned in `flake.nix`; the raw
  `ide-xtp` and `ide-at` builds must equal the r638 downloads, and `xtp-ata1f0`
  must equal unemupc98's catalogue entry `xub-r638-xtp-ata1f0`. A pin changes only
  deliberately, after telling the unemupc98 session (a new ROM means a new
  catalogue entry and re-running its IDE goldens).
- **Publication rule**: write as if public; no private hosts, paths or personal
  setup; never create or publish a repository, which is the maintainer's step. No
  proprietary ROM bytes in this repository, ever.

## Quick loop

```sh
nix build                     # result/ide_xtp-r638-ata1f0-8k.bin and its .sha256
nix build .#ide-xtp           # upstream XT+ image, listing and SHA-256
nix flake check               # every image rebuilt and checked against its pin
nix develop                   # nasm, make, GNU tar
nix develop --command release/assets.sh TAG OUTDIR   # a release's ROM, source archive, SHA256SUMS
```

CI (`.github/workflows/ci.yml`) runs `nix flake check` on x86_64-linux for
pushes to main, release tags and pull requests, prints the SHA-256s and keeps
the images as an artifact; `release-assets.yml` attaches the release assets.

The emulator-side qualification (the open AT profile's IDE goldens) runs in
unemupc98; its supervisor runs it when the ROM bytes change.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
