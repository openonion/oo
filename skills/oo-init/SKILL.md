---
name: oo-init
description: Use when the user wants to start, scaffold, or create their `oo` publishable identity. Triggers on phrases like "init my agent", "set up oo", "make my Claude/Codex setup publishable", "create agent.json", "start a new oo bundle".
allowed-tools: Bash, Read
---

# Initialize the user's publishable identity

There is **no bundle directory**. The user's `~/.co/` IS the bundle:

```
~/.co/keys/agent.key      identity
~/.co/keys.env            managed-key auth
~/.co/agent.json          publishable profile (alias, bio, version)
~/.co/skills/             skill library (sources from claude/codex/cursor/kiro)
~/.co/skills/index.json   discovery cache
```

All four are created and refreshed by one command: `co setup`. This skill
just gathers the right inputs and shells out.

## Prerequisites

```bash
co setup --help >/dev/null && co skills --help >/dev/null \
  || { echo "MISSING: pip install -U connectonion"; exit 1; }
```

## Phase A — Gather inputs

Ask the user for **two things** (or infer + confirm):

1. **Alias / name** — default to `git config user.name | tr '[:upper:]' '[:lower:]' | tr -d ' '` or `$USER`. Must be lowercase, alphanumeric + hyphens.
2. **One-line bio** — push back on placeholders ("my agent"). A vague bio is the most common reason a publication gets ignored.

Mention but don't block on `co auth` — publishing works without managed-key auth; only the `co/*` models require it.

## Phase B — Run `co setup`

```bash
co setup --name <alias> --bio "<one-line bio>"
```

That single command:
- Bootstraps `~/.co/keys/agent.key` (via `co init` in a tmpdir) if missing.
- Writes `~/.co/agent.json` with the signing address, alias, bio, and skill metadata. **Skips** profile creation if a profile already exists unless you pass `--force` (which backs up to `agent.json.bak`).
- Runs `co skills discover && co skills copy --all && co skills manifest` to populate the library and merge skill metadata into `agent.json`. Idempotent — existing skills are not overwritten without `--force`. New skill entries default to `publish: false`.
- Reports identity, auth status, and library counts.

If `~/.co/agent.json` already exists with a different alias/bio, surface
the conflict to the user before passing `--force` — don't clobber silently.

If they're scripting (e.g. a clean test setup), `--no-skills` skips the
library refresh.

## Phase C — Point at next steps

The CLI prints a summary. Add the publishing hint if not obvious:

```
✓ Setup complete. Your identity is at ~/.co/agent.json.

Next:
  • Browse your library:       co skills list
  • Edit bio if needed:        $EDITOR ~/.co/agent.json
  • Publish:                   run the oo-publish skill
```

## Anti-patterns

- **Don't `mkdir` a separate bundle directory.** There is no bundle dir. Everything lives in `~/.co/`. The "bundle" abstraction was deleted on purpose.
- **Don't reimplement `co setup` in bash.** If you find yourself writing `mkdir`, `cat > agent.json`, `cp ~/.claude/skills/...`, or `python -c "from connectonion import address"` blocks, stop. The logic lives in `connectonion/cli/commands/setup_commands.py` and is the single source of truth.
- **Don't curate which skills get published here.** `co setup` copies *every* discoverable skill into the user's library. Picking which ones go into the announced profile is `oo-publish`'s job.
- **Don't sign `agent.json` here.** Signature is a publish-time concern.
- **Don't pass `--force` without telling the user.** A backup is made, but a noisy confirmation prevents accidental loss.
