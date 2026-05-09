---
name: oo-accept
description: Use when the user wants to review or accept incoming subscription requests for their published bundle. Triggers on phrases like "accept subscribers", "who's trying to follow me", "review subscription requests", "approve oo subscriptions".
allowed-tools: Bash, Read, Write
---

# Accept incoming subscription requests

When someone runs `oo-subscribe` against this user's address, the relay
holds a pending SUBSCRIBE request. This skill lists those requests and
sends signed accept (or reject) responses.

## Prerequisites

```bash
python -c "import connectonion; print(connectonion.__version__)"
ls ~/.co/keys/agent.key
```

If missing: `pip install connectonion` then `co init`.

## Phase A — List pending requests

```python
python -c "
import httpx
from pathlib import Path
from connectonion import address

keys = address.load(Path.home() / '.co')
r = httpx.get(
    f'https://oo.openonion.ai/api/relay/agents/{keys[\"address\"]}/subscriptions/pending',
    timeout=15,
)
r.raise_for_status()
for sub in r.json().get('pending', []):
    print(f'  {sub[\"subscriber\"]}  requested at {sub.get(\"timestamp\")}')
"
```

If the list is empty, tell the user "no pending requests" and stop.

## Phase B — Show the user each request

For each pending subscriber, show their address and (if the relay returns
it) their alias / bio. Ask the user to **accept**, **reject**, or **skip**.
Don't auto-accept — the whole point of mutual handshake is human review.

## Phase C — Send the response

For each accepted (or rejected) request, send a signed message:

```python
python -c "
import json, time, httpx
from pathlib import Path
from connectonion import address

SUBSCRIBER = '<0xsubscriber>'
DECISION = 'accept'   # or 'reject'
keys = address.load(Path.home() / '.co')

ts = int(time.time())
payload = {
    'subscriber': SUBSCRIBER,
    'publisher': keys['address'],
    'decision': DECISION,
    'timestamp': ts,
}
canonical = json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()
sig = address.sign(keys, canonical).hex()

r = httpx.post(
    f'https://oo.openonion.ai/api/relay/agents/{keys[\"address\"]}/subscribe/accept',
    json={**payload, 'signature': sig},
    timeout=15,
)
r.raise_for_status()
print(DECISION.upper(), SUBSCRIBER)
"
```

## Phase D — Confirm

Tell the user how many requests were accepted vs rejected. Mention that
accepted subscribers will pull the bundle on their next run of
`oo-subscribe` and pick up future updates whenever they re-run it.

## Anti-patterns

- **Don't auto-accept everyone.** The handshake exists so the publisher
  can keep their bundle private to people they actually know. Surface each
  request to the user.
- **Don't accept without showing the subscriber address.** A user accepting
  requests should always see who they're letting in.
