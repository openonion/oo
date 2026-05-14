---
name: oo-publish
description: Use when the user wants to publish, share, ship, or release their agent so others can subscribe. Triggers on phrases like "publish my agent", "share my skills", "ship my agent", "announce my agent", "make my setup subscribable".
allowed-tools: Bash, Read, Edit
---

# Publish over the relay

Run `co announce`. That's it. The CLI reads `~/.co/agent.json`, signs it
with `~/.co/keys/agent.key`, and pushes to the relay over WebSocket.

Every skill in the library defaults to **private** (`publish: false`).
A first announce therefore publishes only the profile **metadata** — alias,
bio, version, address — plus the names+descriptions of any skills the user
has explicitly opted in. Skill *bodies* (`SKILL.md` contents) never leave
the machine unless `publish: true` is set on that skill.

## Prerequisites

```bash
ls ~/.co/keys/agent.key ~/.co/agent.json >/dev/null \
  || { echo "Run the oo-init skill first (or co setup directly)."; exit 1; }
co announce --help >/dev/null \
  || { echo "MISSING: pip install -U connectonion"; exit 1; }
```

## Phase A — Show + confirm

```bash
cat ~/.co/agent.json
```

Tell the user, in plain language:

> "I'm about to publish your profile metadata — alias, bio, version, and
> address — to the relay so others can discover you. Your skills stay
> **private by default**: only their names and descriptions go out, never
> the actual `SKILL.md` contents. Continue? [Y/n]"

If the bio is still the default placeholder
(`Edit ~/.co/agent.json to customize.`), block until they give a real one —
a vague bio is the most common reason a profile gets ignored.

## Phase B — Announce

```bash
co announce
```

`co announce` filters skills to `publish: true`, inlines those bodies,
signs the whole message with the Ed25519 key at `~/.co/keys/agent.key`,
and sends it to `wss://oo.openonion.ai/ws/announce`. It prints the alias,
address, and the names of any skills whose bodies were included.

Use `co announce --dry-run` first if the user wants to inspect the signed
payload before sending.

## Phase C — Confirm + next step

```
✓ Published <alias> (<address>).

Friends can subscribe with the oo-subscribe skill:
  "subscribe to <alias>"   or   "subscribe to <0xaddress>"
```

If the user later wants to share specific skill bodies (not just names),
they edit `~/.co/agent.json` and set `publish: true` on those entries,
then re-run this skill.

## Updates

Bump `version` in `~/.co/agent.json` for meaningful changes, then run
`co announce` again. Each announce overwrites the relay-side profile.

## Anti-patterns

- **Don't reimplement `co announce` in bash or python.** No `mktemp`, no
  manual signing, no direct WebSocket calls. The CLI is the source of truth.
- **Don't auto-flip `publish: true` on the user's skills.** Private-by-default
  is the contract. Opting in is the user's call, not the skill's.
- **Don't `mkdir bundle/`.** There is no bundle directory. `~/.co/` is it.
- **Don't `gh pr create`.** Publishing is relay pub/sub, not a PR flow.
