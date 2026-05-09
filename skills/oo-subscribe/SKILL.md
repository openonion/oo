---
name: oo-subscribe
description: Use when the user wants to subscribe, follow, or install someone else's published agent bundle. Triggers on phrases like "subscribe to alice", "follow @bob", "install alice's skills", "add 0x... as a subscription".
allowed-tools: Bash, Read, Write
---

# Subscribe to a published agent bundle

Send a signed SUBSCRIBE request to a publisher's address, wait for them to
accept, then mirror their bundle into `~/.co/subs/<alias>/` and symlink-fan-out
into every coding agent on this machine. Distribution is relay-based, not
git — there is no `git clone` step.

## Prerequisites

```bash
python -c "import connectonion; print(connectonion.__version__)"
ls ~/.co/keys/agent.key
```

If missing: `pip install connectonion` then `co init`.

## Phase A — Resolve the target

The user gives you one of:
- An **alias** like `alice`
- A **0x address** (66 chars)

Resolve via the relay:

```bash
# alias → profile
curl -fsSL "https://oo.openonion.ai/api/relay/agents/by-alias/<alias>"
# 0x address → profile
curl -fsSL "https://oo.openonion.ai/api/relay/agents/<0xaddress>/profile"
```

This returns the signed `agent.json`. Verify the signature locally before
trusting any field on it:

```python
python -c "
import json, sys
from connectonion import address
profile = json.load(sys.stdin)
sig = bytes.fromhex(profile.pop('signature'))
signer = profile.pop('signer')
canonical = json.dumps(profile, sort_keys=True, separators=(',', ':')).encode()
assert address.verify(signer, canonical, sig), 'invalid signature'
assert signer == profile['address'], 'signer ≠ address'
print('VERIFIED', signer, profile['alias'])
"
```

Stop on any failure; the relay does not get to vouch for itself.

## Phase B — Send SUBSCRIBE

```python
python -c "
import json, time, httpx
from pathlib import Path
from connectonion import address

PUBLISHER = '<0xaddress>'
keys = address.load(Path.home() / '.co')

ts = int(time.time())
payload = {'subscriber': keys['address'], 'publisher': PUBLISHER, 'timestamp': ts}
canonical = json.dumps(payload, sort_keys=True, separators=(',', ':')).encode()
sig = address.sign(keys, canonical).hex()

r = httpx.post(
    f'https://oo.openonion.ai/api/relay/agents/{PUBLISHER}/subscribe',
    json={**payload, 'signature': sig},
    timeout=30,
)
r.raise_for_status()
print('subscribe sent — waiting for', PUBLISHER, 'to accept')
"
```

Tell the user: "Request sent. The publisher needs to accept (they run their
`oo-accept` skill). I'll poll for ~60 seconds; if no answer, you can re-run
this skill later — the request stays pending."

## Phase C — Wait for acceptance

Poll the relay every few seconds:

```python
python -c "
import json, time, httpx
from pathlib import Path
from connectonion import address

keys = address.load(Path.home() / '.co')
PUBLISHER = '<0xaddress>'
deadline = time.time() + 60

while time.time() < deadline:
    r = httpx.get(
        f'https://oo.openonion.ai/api/relay/agents/{keys[\"address\"]}/subscriptions/status',
        params={'publisher': PUBLISHER},
        timeout=10,
    )
    status = r.json().get('status')
    if status == 'accepted':
        print('ACCEPTED'); break
    if status == 'rejected':
        print('REJECTED'); raise SystemExit(1)
    time.sleep(3)
else:
    print('PENDING')   # not accepted yet; user can re-run later
    raise SystemExit(2)
"
```

If `PENDING`, stop here and tell the user to re-run when the publisher has
had time to accept. Don't install anything for an un-accepted subscription.

## Phase D — Mirror the bundle into `~/.co/subs/<alias>/`

Once accepted, pull the (re-verified) profile and every skill body:

```python
python -c "
import json, httpx
from pathlib import Path
from connectonion import address

PUBLISHER = '<0xaddress>'
ALIAS = '<alias>'
SUBS = Path.home() / '.co' / 'subs' / ALIAS
SUBS.mkdir(parents=True, exist_ok=True)

# Pull + verify profile
profile = httpx.get(f'https://oo.openonion.ai/api/relay/agents/{PUBLISHER}/profile', timeout=30).json()
sig = bytes.fromhex(profile.pop('signature'))
signer = profile.pop('signer')
canonical = json.dumps(profile, sort_keys=True, separators=(',', ':')).encode()
assert address.verify(signer, canonical, sig), 'profile sig'
assert signer == profile['address'] == PUBLISHER, 'identity mismatch'

# Re-attach for storage
profile['signer'] = signer
profile['signature'] = sig.hex()
(SUBS / 'agent.json').write_text(json.dumps(profile, indent=2))

# Pull each skill body
for skill in profile['skills']:
    name = skill['name']
    body = httpx.get(
        f'https://oo.openonion.ai/api/relay/agents/{PUBLISHER}/skills/{name}',
        timeout=30,
    ).text
    d = SUBS / 'skills' / name
    d.mkdir(parents=True, exist_ok=True)
    (d / 'SKILL.md').write_text(body)
    print(f'  pulled skill: {name}')
print('mirrored to', SUBS)
"
```

## Phase E — Fan-out symlinks into per-tool dirs

Use the shared helper from `oo/lib/fanout.py` so this code path stays in
sync with `oo/install.py`:

```python
python -c "
import sys
from pathlib import Path
oo_root = Path.home() / '.connectonion' / 'bundles' / 'oo'
sys.path.insert(0, str(oo_root / 'lib'))
from fanout import install_all

bundle = Path.home() / '.co' / 'subs' / '<alias>'
results = install_all(bundle, '<alias>')
for tool, n in results.items():
    print(f'  {tool}: {n} skill(s)')
"
```

If `~/.connectonion/bundles/oo/lib/fanout.py` is not on disk (the user
installed via a non-default path), fall back to inlining the same logic
from `oo/install.py`.

## Phase F — Record and report

Append the subscription to a tiny local index:

```python
python -c "
import json
from pathlib import Path
from datetime import datetime, timezone

idx = Path.home() / '.co' / 'subs' / 'index.json'
data = json.loads(idx.read_text()) if idx.exists() else {'subscriptions': {}}
data['subscriptions']['<alias>'] = {
    'address': '<0xaddress>',
    'version': '<version-from-profile>',
    'subscribed_at': datetime.now(timezone.utc).isoformat(timespec='seconds'),
}
idx.write_text(json.dumps(data, indent=2))
"
```

Tell the user:
- What was installed (skill count + into which tools).
- That they need to **restart their coding agent** to pick up new skills.

## Updates

A re-run of this skill is idempotent: Phase B re-sends SUBSCRIBE (no-op if
already accepted), Phase D re-pulls, Phase E re-symlinks. To pick up a
publisher's new version on demand, just run "subscribe to <alias>" again.
A persistent listener for `BUNDLE_UPDATE` push events from the relay is
out of scope for this skill — the user re-runs when they want updates.

## Unsubscribing

```python
python -c "
import sys, shutil
from pathlib import Path
oo_root = Path.home() / '.connectonion' / 'bundles' / 'oo'
sys.path.insert(0, str(oo_root / 'lib'))
from fanout import uninstall_all
uninstall_all('<alias>')
shutil.rmtree(Path.home() / '.co' / 'subs' / '<alias>', ignore_errors=True)
"
```

Then drop the entry from `~/.co/subs/index.json`.

## Anti-patterns

- **Don't `git clone` anything.** Bundles ride the relay.
- **Don't trust the relay's word.** Always verify the profile signature
  locally before installing any file. The relay is convenience, not authority.
- **Don't install on PENDING.** Wait for `accepted`.
