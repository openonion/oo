---
name: oo
description: Use when user mentions a ConnectOnion agent address (0x...), asks to connect/delegate to a remote agent, or uses /oo command. Also triggers when user wants to set up ConnectOnion environment for agent networking.
---

# ConnectOnion Agent Networking

Connect to remote ConnectOnion agents, delegate tasks, and handle multi-turn collaboration.

## Environment Setup

Before any interaction, verify the environment is ready. Run these checks sequentially — stop on first failure:

**1. Check connectonion is installed:**
```bash
python -c "import connectonion; print(connectonion.__version__)"
```
If ImportError: run `pip install connectonion`, then re-check.

**2. Check agent identity exists:**
```bash
ls .co/keys/agent.key 2>/dev/null || ls ~/.co/keys/agent.key 2>/dev/null
```
If neither exists: run `co init` to generate identity.

**3. Verify identity is usable:**
```bash
python -c "
from connectonion import address
from pathlib import Path
a = address.load(Path('.co')) or address.load(Path.home() / '.co')
print(a['address'])
"
```
If fails: report the error and stop. The user needs to fix their `.co/` directory.

> **Note:** `import connectonion` prints `[env] ...` lines to stdout. For all environment checks, **parse only the last line** of stdout output. Ignore everything else.

Skip environment checks after the first successful run in a session.

## Connecting to a Remote Agent

### Parsing User Intent

Extract from the user's message:
- **Target address**: match regex `0x[0-9a-fA-F]{64}` (66 chars total)
- **Task description**: everything else

### Connection Strategy: Direct-First with Relay Fallback

1. Queries the relay API for the agent's registered endpoints
2. Tries each endpoint directly (verifying via `/info`)
3. Falls back to relay only if all direct endpoints fail

### One-shot Task

Generate and execute this Python script (fill in `{address}` and `{task}`):

```python
import sys, json, time, uuid, asyncio
import httpx, websockets
from connectonion import address
from pathlib import Path

TARGET = "{address}"
TASK = "{task}"
TIMEOUT = 60
RELAY_URL = "wss://oo.openonion.ai"

keys = address.load(Path(".co")) or address.load(Path.home() / ".co")

def _sort_endpoints(endpoints):
    def priority(url):
        if "localhost" in url or "127.0.0.1" in url:
            return 0
        if any(x in url for x in ("192.168.", "10.", "172.16.", "172.17.", "172.18.")):
            return 1
        return 2
    return sorted(endpoints, key=priority)

def discover_direct_ws(target, relay_url):
    """Query relay API for endpoints and find a working direct WebSocket."""
    https_relay = relay_url.replace("wss://", "https://").replace("ws://", "http://").rstrip("/")
    try:
        resp = httpx.get(f"{https_relay}/api/relay/agents/{target}", timeout=5)
        if resp.status_code != 200:
            return None
        info = resp.json()
    except Exception:
        return None

    endpoints = info.get("endpoints", [])
    if not endpoints:
        return None

    http_endpoints = [ep for ep in _sort_endpoints(endpoints)
                      if ep.startswith("http://") or ep.startswith("https://")]

    for http_url in http_endpoints:
        try:
            r = httpx.get(f"{http_url}/info", timeout=3, proxy=None)
            if r.status_code == 200 and r.json().get("address") == target:
                ws_url = http_url.replace("https://", "wss://").replace("http://", "ws://")
                if not ws_url.endswith("/ws"):
                    ws_url = ws_url.rstrip("/") + "/ws"
                return ws_url
        except Exception:
            continue
    return None

async def direct_connect(ws_url, target, keys, task, timeout):
    """Connect directly to agent WebSocket, send task, return result."""
    async with websockets.connect(ws_url, proxy=None) as ws:
        ts = int(time.time())
        payload = {"to": target, "timestamp": ts}
        canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        signature = address.sign(keys, canonical.encode())
        connect_msg = {
            "type": "CONNECT", "timestamp": ts, "to": target,
            "payload": payload, "from": keys["address"], "signature": signature.hex()
        }
        await ws.send(json.dumps(connect_msg))

        raw = await asyncio.wait_for(ws.recv(), timeout=10)
        event = json.loads(raw)
        if event.get("type") == "ERROR":
            raise ConnectionError(f"Auth error: {event.get('message', event.get('error'))}")
        if event.get("type") != "CONNECTED":
            raise ConnectionError(f"Unexpected: {event.get('type')}")

        ts2 = int(time.time())
        input_id = str(uuid.uuid4())
        input_payload = {"prompt": task, "timestamp": ts2}
        input_canonical = json.dumps(input_payload, sort_keys=True, separators=(",", ":"))
        input_sig = address.sign(keys, input_canonical.encode())
        input_msg = {
            "type": "INPUT", "input_id": input_id, "prompt": task, "timestamp": ts2,
            "payload": input_payload, "from": keys["address"], "signature": input_sig.hex()
        }
        await ws.send(json.dumps(input_msg))

        while True:
            msg = await asyncio.wait_for(ws.recv(), timeout=timeout)
            ev = json.loads(msg)
            t = ev.get("type")
            if t == "OUTPUT":
                return ev.get("result", ""), True
            elif t == "ask_user":
                return ev.get("text", ""), False
            elif t == "ERROR":
                raise ConnectionError(f"Agent error: {ev.get('message', ev.get('error'))}")

# --- Main ---
result_text, done = None, None

ws_url = discover_direct_ws(TARGET, RELAY_URL)
if ws_url:
    try:
        result_text, done = asyncio.run(direct_connect(ws_url, TARGET, keys, TASK, TIMEOUT))
        print(f"CO_METHOD: direct", flush=True)
    except Exception as e:
        print(f"CO_DIRECT_FAIL: {e}", flush=True)

if result_text is None:
    try:
        from connectonion import connect
        agent = connect(TARGET, keys=keys)
        response = agent.input(TASK, timeout=TIMEOUT)
        result_text, done = response.text, response.done
        print(f"CO_METHOD: relay", flush=True)
    except Exception as e:
        print(f"CO_RELAY_FAIL: {e}", flush=True)
        sys.exit(1)

print(f"CO_RESPONSE: {json.dumps(result_text)}", flush=True)
print(f"CO_DONE: {done}", flush=True)
```

Execute via shell. Parse stdout — **only lines starting with `CO_` matter**. The `CO_RESPONSE` value is JSON-encoded. Decode it before presenting.

- `CO_DONE: True` → return `CO_RESPONSE` to user. Done.
- `CO_DONE: False` → remote agent asking follow-up. Include prior context in next prompt.
- `CO_DIRECT_FAIL` + `CO_RELAY_FAIL` → both failed. Report error.

## Response Handling

- `CO_DONE: True` → return `CO_RESPONSE` content to the user. Done.
- `CO_DONE: False` → the remote agent asked a follow-up question:
  - **If you can answer from context** → answer automatically.
  - **If you need the user's input** → show `CO_RESPONSE`, wait for reply.
  - Loop until `CO_DONE: True` or 10 rounds.
