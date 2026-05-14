---
name: oo-publish
description: Use when the user wants to publish, share, ship, or release their agent so others can subscribe. Triggers on phrases like "publish my agent", "share my skills", "ship my agent", "announce my agent", "make my setup subscribable".
allowed-tools: Bash, Read, Edit
---

# Publish over the relay

Curate `~/.co/agent.json` and run one command. The relay receives a signed
ANNOUNCE that carries the alias, bio, and every skill marked
`publish: true` (with its full `SKILL.md` body inlined). Skills marked
`publish: false` (or missing the flag) never leave the machine.

You orchestrate; `co announce` does the crypto and networking.

## Prerequisites

```bash
ls ~/.co/keys/agent.key ~/.co/agent.json >/dev/null \
  || { echo "Run the oo-init skill first (or co setup directly)."; exit 1; }
co announce --help >/dev/null \
  || { echo "MISSING: pip install -U connectonion"; exit 1; }
```

## Phase A — Surface current state

Read `~/.co/agent.json`. Tell the user:

- Alias and bio (flag if bio still says "Edit ~/.co/agent.json to customize.").
- How many skills are in the library, and how many are already `publish: true`.

```bash
cat ~/.co/agent.json
```

If the bio is a placeholder, block until the user supplies a real one — a
vague bio is the most common reason a profile gets ignored.

## Phase B — Pick what to publish

Group `agent.json.skills` by purpose (writing / shipping / social / reviewers)
and ask the user which clusters to publish. First-time profiles should be
5–15 curated items, not the whole library.

`~/.co/agent.json` is a plain JSON file. Use the `Edit` tool (or `$EDITOR`)
to flip `"publish": false` → `"publish": true` on the chosen entries and
leave the rest alone. No script needed — it's a one-character edit per
skill, and keeping it manual means the user sees exactly what's going out.

## Phase C — Dry-run, then announce

`co announce --dry-run` is the validator. It reads `~/.co/agent.json`,
inlines every `publish: true` SKILL.md, signs the payload, and prints what
*would* be sent — without sending. If a description is missing or a
`SKILL.md` is gone, it surfaces there. Run it, scan the list, then send:

```bash
co announce --dry-run    # inspect the signed payload + skill list
co announce              # send it
```

`co announce` does:

- Reads `~/.co/agent.json`.
- Filters skills to `publish: true`, inlines each `SKILL.md` body.
- Builds `{alias, bio, version, skills:[{name, description, body}]}` and signs
  the whole ANNOUNCE with the Ed25519 key at `~/.co/keys/agent.key`.
- WebSocket → `wss://oo.openonion.ai/ws/announce`. Relay verifies the signature
  and persists the profile + bodies to its database.

## Phase D — Confirm

```
✓ Published <alias> (<address>).

Friends can subscribe with the oo-subscribe skill:
  "subscribe to <alias>"   or   "subscribe to <0xaddress>"
```

## Updates

To re-publish after editing skills or the bio: bump `version` in
`~/.co/agent.json` for meaningful changes, then run `co announce` again.
Each announce overwrites the relay-side profile.

## Anti-patterns

- **Don't `mkdir bundle/`, `mktemp`, or write a publish dir.** There is no
  bundle directory. `~/.co/` is the source of truth; `co announce` reads
  bodies from `~/.co/skills/<name>/SKILL.md` directly.
- **Don't sign in bash.** `co announce` signs once over the whole message.
  Don't add a second signature on a per-body basis.
- **Don't `gh pr create`.** Publishing is relay-based pub/sub, not a PR flow.
- **Don't modify `~/.co/skills/` to curate.** Curation lives in
  `agent.json.skills[].publish`. The library stays intact.
- **Don't publish every skill on first run.** 5–15 carefully chosen items
  beats 30 random ones.
- **Don't wrap `agent.json` edits in a python script.** It's a plain JSON
  file; the user (or the `Edit` tool) flips `publish` flags directly.
  `co announce --dry-run` does the validation — don't re-implement it in
  bash or python.
