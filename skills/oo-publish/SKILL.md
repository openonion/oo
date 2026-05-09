---
name: oo-publish
description: Use when the user wants to publish, share, ship, or release their agent bundle so others can subscribe. Triggers on phrases like "publish my agent", "share my skills", "ship my bundle", "announce my agent", "make my bundle subscribable".
allowed-tools: Bash, Read, Edit, Write, Glob
---

# Publish a bundle over the relay

Sign the user's `agent.json`, announce it to `oo.openonion.ai`, and upload
each skill body so subscribers can pull them on demand. There is no git/PR
step — distribution is relay-based pub/sub. You orchestrate; the
`connectonion` library does the crypto and networking.

## Prerequisites

```bash
python -c "import connectonion; print(connectonion.__version__)"
ls ~/.co/keys/agent.key
```

If either fails: `pip install connectonion` then `co init`. If the user has
no bundle yet, run the `oo-init` skill first.

## Phase A — Locate the bundle

Walk up from the current directory looking for `agent.json`:

```bash
p="$(pwd)"; while [ "$p" != "/" ]; do
  [ -f "$p/agent.json" ] && echo "BUNDLE: $p" && cd "$p" && break
  p="$(dirname "$p")"
done
[ -f agent.json ] || { echo "no agent.json — run oo-init first"; exit 1; }
```

Read `agent.json` and surface current state to the user (alias, bio, how
many files in `skills/`, `commands/`, `agents/`).

## Phase B — Curate content

Diff `~/.claude/{skills,commands,agents}` against the bundle. **Don't
blindly add everything.** Filter out:

- Plugin-namespaced items (directories or files containing `:` — they're
  someone else's plugin output, not the user's work).
- Items with `draft: true` in their frontmatter.
- Personal config (`CLAUDE.md`, `settings.json`).

Group what's left by purpose (writing / shipping / social / reviewers) and
ask the user which clusters to publish. For each chosen item:

```bash
cp -r ~/.claude/skills/<name>      skills/<name>      # skills are dirs
cp    ~/.claude/commands/<name>.md commands/<name>.md # commands are flat
cp    ~/.claude/agents/<name>.md   agents/<name>.md
```

## Phase C — Validate

Each `SKILL.md` needs `name` + `description` in frontmatter. `agent.json`
needs all identity fields filled with non-placeholder content.

```bash
for f in skills/*/SKILL.md commands/*.md agents/*.md; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -q '^---$' || echo "FAIL no frontmatter: $f"
  awk '/^---$/{c++; next} c==1 && /^description:/{d=1} c==1 && /^name:/{n=1} END{exit !(d&&n)}' "$f" \
    || echo "FAIL missing name/description: $f"
done
```

Common fixes:
- Missing description → draft from the body's first paragraph, ask user to confirm.
- Filename ↔ frontmatter `name` mismatch → ask which is correct, fix.
- Description > 240 chars → shorten.
- Bio still says "Edit me." → block; ask the user for a real bio.

## Phase D — Build `skills[]` and sign

Walk `skills/*/SKILL.md`, parse frontmatter, write each `{name,
description}` into `agent.json["skills"]`. Then canonicalize, sign, and
write back:

```python
python -c "
import json, re
from pathlib import Path
from connectonion import address

bundle = Path('.').resolve()
profile = json.loads((bundle / 'agent.json').read_text())

# Rebuild skills[] from on-disk SKILL.md frontmatter
fm_re = re.compile(r'^---\n(.*?)\n---\n', re.DOTALL)
skills = []
for d in sorted((bundle / 'skills').iterdir()):
    md = d / 'SKILL.md'
    if not md.exists():
        continue
    m = fm_re.match(md.read_text())
    if not m:
        continue
    fm = m.group(1)
    name = next((l.split(':', 1)[1].strip() for l in fm.splitlines() if l.startswith('name:')), d.name)
    desc = next((l.split(':', 1)[1].strip() for l in fm.splitlines() if l.startswith('description:')), '')
    skills.append({'name': name, 'description': desc})
profile['skills'] = skills

# Strip any prior signature, canonicalize, sign
profile.pop('signature', None)
profile.pop('signer', None)
canonical = json.dumps(profile, sort_keys=True, separators=(',', ':')).encode()

keys = address.load(Path.home() / '.co')
profile['signer'] = keys['address']
profile['signature'] = address.sign(keys, canonical).hex()

# Sanity-check round-trip before writing
check = dict(profile); check.pop('signature'); check.pop('signer')
assert address.verify(
    profile['signer'],
    json.dumps(check, sort_keys=True, separators=(',', ':')).encode(),
    bytes.fromhex(profile['signature']),
), 'signature did not verify'

(bundle / 'agent.json').write_text(json.dumps(profile, indent=2))
print('signed agent.json for', profile['signer'])
print('skills:', [s['name'] for s in skills])
"
```

## Phase E — Announce + upload

Send the signed profile via the connectonion announce protocol; then PUT
each `SKILL.md` body to the relay so subscribers can fetch on demand.

```python
python -c "
import json, asyncio, httpx, websockets
from pathlib import Path
from connectonion import address
from connectonion.network.announce import create_announce_message, get_endpoints

RELAY_HTTPS = 'https://oo.openonion.ai'
RELAY_WSS = 'wss://oo.openonion.ai'

bundle = Path('.').resolve()
profile = json.loads((bundle / 'agent.json').read_text())
keys = address.load(Path.home() / '.co')
assert keys['address'] == profile['signer'], 'identity mismatch'

# 1) Build + send ANNOUNCE with embedded profile
msg = create_announce_message(
    address_data=keys,
    summary=profile['bio'][:1000],
    endpoints=get_endpoints(),
    relay=RELAY_WSS,
    profile=profile,                        # extended announce field
)

async def send():
    async with websockets.connect(f'{RELAY_WSS}/ws/announce', proxy=None) as ws:
        await ws.send(json.dumps(msg))
        ack = json.loads(await ws.recv())
        if ack.get('type') == 'ERROR':
            raise SystemExit(f'relay rejected: {ack}')
        print('ANNOUNCE ack:', ack.get('type', ack))
asyncio.run(send())

# 2) Upload each SKILL.md body. Auth = signed PUT (signer == profile.address).
for skill_dir in sorted((bundle / 'skills').iterdir()):
    md = skill_dir / 'SKILL.md'
    if not md.exists():
        continue
    body = md.read_bytes()
    sig = address.sign(keys, body).hex()
    r = httpx.put(
        f'{RELAY_HTTPS}/api/relay/agents/{keys[\"address\"]}/skills/{skill_dir.name}',
        content=body,
        headers={
            'X-CO-Signer': keys['address'],
            'X-CO-Signature': sig,
            'Content-Type': 'text/markdown',
        },
        timeout=30,
    )
    r.raise_for_status()
    print(f'  uploaded skill: {skill_dir.name}')

print('published.')
"
```

## Phase F — Confirm

Tell the user:

```
✓ Published <alias> (<address>).

Friends can subscribe with the oo-subscribe skill:
  "subscribe to <alias>"   or   "subscribe to <0xaddress>"

You'll get a SUBSCRIBE request on this address. Run the oo-accept skill
to review and accept incoming subscribers.
```

## Updates

To re-publish after editing the bundle: just re-run this skill. Phase D
re-signs `agent.json`; Phase E re-announces and re-uploads each
`SKILL.md`. Bump `version` in `agent.json` when you make a meaningful
change so subscribers can tell something moved. The relay notifies online
subscribers; offline ones pick the update up next time they connect.

## Anti-patterns

- **Don't `gh pr create`.** There is no `agent-directory` PR workflow.
- **Don't bundle 30 skills on first publish.** First-time bundles should
  be 5–15 carefully chosen items. v0.2 is cheap.
- **Don't ship without verifying signature locally.** The Phase D snippet
  asserts `address.verify` round-trips before writing — keep it.
