---
name: oo
description: Use when user mentions a ConnectOnion agent address (0x...), asks to delegate to/connect to a remote agent, asks to subscribe/follow/update an agent, or uses /oo command.
argument-hint: <0xAddress> <task> | subscribe <id> | update [id] | list | info <id> | unsubscribe <id> | init <name>
allowed-tools: Bash, Read
---

# /oo — OpenOnion agent dispatcher

Two modes, dispatched on the first argument.

## Mode 1 — Networking (talk to a remote agent)

If the first argument matches `0x[0-9a-fA-F]{64}` (a 66-char ConnectOnion address), this is the existing networking flow. Follow the **`oo` skill** (`skills/oo/SKILL.md`) to connect to the agent and delegate the task.

```
/oo 0x3d4017c3e843...c982 translate this document to English
```

## Mode 2 — Subscription management (run the `oo` CLI)

For everything else, run the `oo` shell binary and report its output verbatim.

**Six core verbs — three intents:**

*Consume someone else's agent:*
| Subcommand | Purpose |
|---|---|
| `oo subscribe <id>` | Install a bundle into Claude/Codex/Cursor/Kiro/OpenClaw. `<id>` = alias, 0x address, or `github:owner/repo`. |
| `oo update [id]` | `git pull` the cached bundle(s). No arg = everything. |
| `oo list` | Show current subscriptions and item counts. |

*Be your own agent:*
| Subcommand | Purpose |
|---|---|
| `oo publish [<name>]` | Self-healing author command. With `<name>` and no bundle: scaffolds `./<name>/`. Without: validates + tags + pushes + opens directory PR. So a typical user only ever types `oo publish`. |
| `oo self` | Show status of the current bundle (where am I, what's in it). |

*Advanced (`/oo:publish` skill calls these for the user):*
| Subcommand | Purpose |
|---|---|
| `oo info <id>` | Preview a bundle without installing. |
| `oo unsubscribe <id>` | Remove a bundle and all its symlinks. |
| `oo add <kind> <name>` | Pull skill/command/agent from `~/.claude` into the bundle. |
| `oo validate` | Schema-check the bundle. Auto-run by `oo publish`. |

**For the guided publishing flow, prefer the `oo-publish` skill** — it walks the user through state detection, suggests what to add from `~/.claude`, fixes validation errors, and writes the PR description.

Examples:
```
/oo subscribe changxing                # install someone's bundle
/oo update                             # refresh what I'm subscribed to
/oo list                               # what am I subscribed to?
/oo publish my-agent                   # first time: scaffolds ./my-agent/
/oo publish                            # later: releases the current bundle
/oo self                               # status of my current bundle
/oo info 0x3d40...c982                 # preview without installing
```

### Implementation
For Mode 2, run the binary directly via Bash:
```
oo "$@"
```

The binary is installed by the OpenOnion installer (`curl -fsSL agent.openonion.ai/install | sh`) at `~/.local/bin/oo`. If it isn't on PATH, fall back to `~/.oo/cache/oo/bin/oo`.
