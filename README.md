# 🧅 oo

[oo Agent Skill](https://github.com/openonion/oo) | [ConnectOnion Official](https://github.com/openonion/connectonion) | [Production Ready](https://github.com/openonion/connectonion) | [Python 3.10+](https://python.org) | [License: MIT](https://opensource.org/licenses/MIT)

[Claude Code](https://claude.ai/code) | [Codex CLI](https://github.com/openai/codex) | [Cursor](https://cursor.com) | [Kiro](https://kiro.dev) | [VSCode Copilot](https://code.visualstudio.com)

[GitHub stars](https://github.com/openonion/connectonion) | [PyPI Downloads](https://pepy.tech/projects/connectonion) | [Discord](https://discord.gg/4xfD9k8AUF) | [Documentation](http://docs.connectonion.com)

**The agent networking skill for [ConnectOnion](https://github.com/openonion/connectonion) — connect your AI coding agent to any remote agent**

[📚 Documentation](http://docs.connectonion.com) • [💬 Discord](https://discord.gg/4xfD9k8AUF) • [⭐ Star ConnectOnion](https://github.com/openonion/connectonion) • [🧅 Chat UI](https://chat.openonion.ai)

---

> **`oo`** is the official companion skill for the [ConnectOnion](https://github.com/openonion/connectonion) framework. Install it in your AI coding agent, then talk to any remote ConnectOnion agent through natural language — delegate tasks, collaborate across agents, get results back.

```
You: /oo 0x3d4017c3e843895a92b70aa74d1b7ebc9c982... translate this doc to English

Agent: Connecting to remote agent...
       CO_METHOD: direct
       [Returns translated document]
```

## 🚀 Quick Start

### Prerequisites

- Python 3.10+
- `pip install connectonion`
- Agent identity: run `co init` in your project or home directory

### Installation

**Claude Code (Manual — recommended):**

```bash
mkdir -p ~/.claude/skills/oo
curl -o ~/.claude/skills/oo/SKILL.md \
  https://raw.githubusercontent.com/openonion/oo/main/skills/oo/SKILL.md
```


**Claude Code (Plugin):**

```bash
claude plugin marketplace add openonion/oo
claude plugin install oo
```


**OpenAI Codex CLI:**

```bash
mkdir -p ~/.codex/skills/oo
curl -o ~/.codex/skills/oo/SKILL.md \
  https://raw.githubusercontent.com/openonion/oo/main/codex/oo/SKILL.md
```

**Cursor:**

```bash
mkdir -p .cursor/rules
curl -o .cursor/rules/oo.mdc \
  https://raw.githubusercontent.com/openonion/oo/main/cursor/rules/oo.mdc
```

**Kiro:**

```bash
mkdir -p .kiro/steering
curl -o .kiro/steering/oo.md \
  https://raw.githubusercontent.com/openonion/oo/main/kiro/steering/oo.md
```

**Manual (any platform):** Copy `skills/oo/SKILL.md` to your agent's skill directory.

## 💬 Usage

### With agent address

> "Ask 0x3d4017c3e843895a92b70aa74d1b7ebc9c982... to review this pull request"

### With /oo command

> /oo 0x3d4017c3... research AI agent trends for 2026

### Setup only

> "Set up ConnectOnion environment for agent networking"

The skill auto-detects ConnectOnion agent addresses (`0x` + 64 hex chars) in your messages and triggers automatically.

## ⚙️ How It Works

1. Verifies `connectonion` is installed and agent identity exists
2. Resolves remote agent endpoints via relay API
3. Connects directly to the agent (with relay fallback)
4. Sends task via signed WebSocket protocol
5. Streams response, handles multi-turn conversation automatically
6. Returns the remote agent's response to you

### Connection Strategy

```
Target address (0x...)
    │
    ▼
Query relay API for endpoints
    │
    ▼
Try each endpoint directly (/info verification)
    │
    ├── Success → Direct WebSocket connection (fastest)
    │
    └── All fail → Relay fallback (wss://oo.openonion.ai)
```

### Multi-turn Conversations

When the remote agent asks a follow-up question, the skill handles it intelligently:

- **If answerable from context** (file contents, prior conversation) — answers automatically
- **If user input needed** — shows the question, waits for your reply
- Loops until task is complete or 10 rounds max

## 🔧 Error Handling


| Error                         | Cause             | Action                        |
| ----------------------------- | ----------------- | ----------------------------- |
| `ImportError: connectonion`   | Not installed     | `pip install connectonion`    |
| `address.load() returns None` | No identity       | `co init`                     |
| `TimeoutError`                | Agent unreachable | Verify address, check network |
| Both direct + relay fail      | Agent offline     | Contact remote agent operator |
| Trust/permission error        | Not authorized    | Contact remote agent admin    |


## 📁 Project Structure

```
.claude-plugin/
  plugin.json              # Plugin metadata
  marketplace.json         # Marketplace listing
skills/
  oo/
    SKILL.md               # Claude Code skill
codex/
  oo/
    SKILL.md               # Codex CLI skill
cursor/
  rules/
    oo.mdc                 # Cursor rule
kiro/
  steering/
    oo.md                  # Kiro steering file
commands/
  oo.md                    # /oo command alias
LICENSE
README.md
```

## 🧅 About ConnectOnion

[ConnectOnion](https://github.com/openonion/connectonion) is an open-source framework for building production-ready AI agents with built-in multi-agent networking.

> **"Keep simple things simple, make complicated things possible."**

Any agent built with ConnectOnion can be discovered and called by other agents through the `host()` / `connect()` protocol:

```python
from connectonion import Agent, host

agent = Agent(name="translator", tools=[translate])
host(agent)  # Now other agents can connect to this agent
```

**`oo`** is the bridge — install it in your AI coding agent, and it can talk to any hosted ConnectOnion agent. Together they form the complete stack:


| Component             | Role                                          | Link                                                                |
| --------------------- | --------------------------------------------- | ------------------------------------------------------------------- |
| **ConnectOnion**      | Framework — build, host, and connect agents   | [openonion/connectonion](https://github.com/openonion/connectonion) |
| **oo**                | Skill — let AI coding agents use ConnectOnion | [openonion/oo](https://github.com/openonion/oo)                     |
| **chat.openonion.ai** | Frontend — ready-to-use chat interface        | [chat.openonion.ai](https://chat.openonion.ai)                      |


## 📄 License

MIT License — use it anywhere, even commercially. See [LICENSE](LICENSE) file for details.

---

[Discord](https://discord.gg/4xfD9k8AUF) | [GitHub](https://github.com/openonion/connectonion) | [Documentation](http://docs.connectonion.com)

**Built with 🧅 by the [OpenOnion](https://github.com/openonion) community**

[⭐ Star ConnectOnion](https://github.com/openonion/connectonion) • [💬 Join Discord](https://discord.gg/4xfD9k8AUF) • [📖 Read Docs](http://docs.connectonion.com) • [⬆ Back to top](#-oo)
