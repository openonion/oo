---
name: oo-init
description: Use when the user wants to start, scaffold, or create a new `oo` agent bundle to publish later. Triggers on phrases like "init my bundle", "scaffold an agent bundle", "start a new oo bundle", "make my Claude/Codex setup publishable", "create agent.json".
allowed-tools: Bash, Read, Write
---

# Scaffold a new `oo` bundle

Create the directory layout and `agent.json` template the user needs before
they can curate skills and run `oo-publish`. **No content curation here** —
that's `oo-publish`'s job. This skill just gives them an empty house.

## Prerequisites

```bash
python -c "import connectonion; print(connectonion.__version__)"
ls ~/.co/keys/agent.key
```

If `connectonion` is missing: `pip install connectonion`.
If `~/.co/keys/agent.key` is missing: `co init`. Stop until both pass.

## Phase A — Pick a name

Default to the user's git/system username (`git config user.name` lowercased,
or `$USER`). Confirm with the user before creating the directory. Bundle
names must be lowercase, alphanumeric + hyphens (no spaces, no `:`).

## Phase B — Scaffold the layout

```bash
NAME=<bundle-name>
mkdir -p "$NAME"/{skills,commands,agents,.claude-plugin}
cd "$NAME"
```

## Phase C — Write `agent.json` template

This is the **single source of truth** for the bundle. Identity fields come
from the user's connectonion keypair. `skills` is empty until `oo-publish`
walks `skills/` and fills it. No signature yet — `oo-publish` adds it.

```python
python -c "
from connectonion import address
from pathlib import Path
import json
keys = address.load(Path.home() / '.co')
profile = {
    'address': keys['address'],
    'alias': '<bundle-name>',
    'name': '<bundle-name>',
    'bio': 'One-line description of your agent. Edit me.',
    'skills': [],
    'version': 'v0.1.0',
}
Path('agent.json').write_text(json.dumps(profile, indent=2))
print('wrote agent.json for', keys['address'])
"
```

After running, ask the user to edit `bio` (and optionally `name`) before
publishing. A vague bio is the most common reason a bundle gets ignored.

## Phase D — Write supporting files

**`.claude-plugin/plugin.json`** — Claude Code namespace manifest:
```json
{
  "name": "<bundle-name>",
  "version": "0.1.0",
  "description": "Agent bundle published via agent.openonion.ai"
}
```

**`.gitignore`**:
```
.DS_Store
node_modules/
__pycache__/
```

**`README.md`** — short skeleton (the user expands later):
```
# <bundle-name>

<one-line bio matching agent.json>

## Skills

(populated by oo-publish from skills/ directory)
```

## Phase E — Tell the user what's next

Print:

```
✓ Bundle scaffolded at ./<name>/

Next steps:
  1. Edit agent.json — fix the bio.
  2. Drop your skills into skills/<skill-name>/SKILL.md
     (and optionally commands/<name>.md, agents/<name>.md).
  3. Run the oo-publish skill — it signs agent.json and announces
     your bundle over the relay so others can subscribe.
```

## Anti-patterns

- **Don't curate `~/.claude/` here.** Curation belongs in `oo-publish`'s
  Phase C — keeping the two skills sharply separated lets the user iterate
  on bundle contents without re-scaffolding.
- **Don't sign `agent.json` here.** Signature is a publish-time concern.
  Signing an empty `skills` array would just mean re-signing later.
- **Don't run `git init`.** The bundle ships over the relay, not via git.
  The user can add a repo if they want, but it's not a publish dependency.
