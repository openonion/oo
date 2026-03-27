# ConnectOnion Agent Networking

Connect to remote ConnectOnion agents, delegate tasks, and handle multi-turn collaboration.

## When to Activate

- User message contains a ConnectOnion address: regex `0x[0-9a-fA-F]{64}`
- User asks to connect/delegate to a remote agent
- User mentions ConnectOnion setup

## Prerequisites

- Python 3.10+, `pip install connectonion`, agent identity via `co init`

## Environment Check

Run sequentially, stop on first failure:

1. `python -c "import connectonion; print(connectonion.__version__)"` — if ImportError: `pip install connectonion`
2. `ls .co/keys/agent.key 2>/dev/null || ls ~/.co/keys/agent.key 2>/dev/null` — if missing: `co init`
3. Verify identity loads: `python -c "from connectonion import address; from pathlib import Path; a = address.load(Path('.co')) or address.load(Path.home() / '.co'); print(a['address'])"`

Note: `import connectonion` prints `[env] ...` lines. Parse only the last line.

## Connecting

Extract target address (`0x...` 66 chars) and task description from user message.

Generate and execute the Python connection script:
- Discovers direct endpoints via relay API
- Tries direct WebSocket connection first
- Falls back to relay (`wss://oo.openonion.ai`) if direct fails
- Uses signed CONNECT + INPUT protocol

Parse stdout — only `CO_` prefixed lines matter:
- `CO_DONE: True` → return `CO_RESPONSE` (JSON-encoded) to user
- `CO_DONE: False` → remote agent asked follow-up; answer from context or ask user
- `CO_DIRECT_FAIL` + `CO_RELAY_FAIL` → both failed, report error

Full connection script: https://github.com/openonion/oo/blob/main/skills/oo/SKILL.md
