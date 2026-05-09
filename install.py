#!/usr/bin/env python3
"""Bootstrap-install the canonical `oo` bundle into every coding agent on
this machine. Pure Python (stdlib + connectonion). Run:

    curl -fsSL agent.openonion.ai/install | python3 -
    python3 install.py
    python3 install.py --uninstall

After install:
    Claude Code      → ~/.claude/plugins/oo/         (symlinked to the bundle)
    Codex / OpenClaw → ~/.<tool>/skills/oo-<skill>/  (per-skill symlinks)
    Cursor           → ~/.cursor/rules/oo-<skill>.mdc
    Kiro             → ~/.kiro/steering/oo-<skill>.md

This installer is the bridge before the user has any `oo` skill available.
Once installed, ongoing subscriptions to other agents go through the
`oo-subscribe` skill (which uses the same per-tool fan-out via
`oo/lib/fanout.py`).
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

REPO = "https://github.com/openonion/oo"
HOME = Path.home()
ALIAS = "oo"
CACHE = HOME / ".connectonion" / "bundles" / ALIAS

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from fanout import install_all, uninstall_all  # noqa: E402


def _print(msg: str, color: str = "") -> None:
    codes = {"green": "32", "blue": "34", "yellow": "33", "red": "31"}
    if color and sys.stdout.isatty():
        print(f"\033[{codes[color]}m{msg}\033[0m")
    else:
        print(msg)


def ensure_connectonion() -> None:
    try:
        import connectonion  # noqa: F401
    except ImportError:
        _print("Installing connectonion (required)…", "blue")
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "--user", "--quiet", "connectonion"]
        )


def clone_or_update() -> None:
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    if (CACHE / ".git").is_dir():
        _print(f"Updating bundle at {CACHE}…", "blue")
        subprocess.check_call(["git", "-C", str(CACHE), "fetch", "--quiet", "origin"])
        subprocess.check_call(["git", "-C", str(CACHE), "reset", "--quiet", "--hard", "origin/main"])
    else:
        _print(f"Cloning {REPO} → {CACHE}…", "blue")
        subprocess.check_call(["git", "clone", "--quiet", "--depth", "1", REPO, str(CACHE)])


def install() -> None:
    ensure_connectonion()
    clone_or_update()

    results = install_all(CACHE, ALIAS)
    if not results:
        _print("No coding agents detected (~/.claude, ~/.codex, ~/.cursor, ~/.kiro, ~/.openclaw).", "yellow")
        _print("Install one of them, then re-run this installer.", "yellow")
        return

    for tool, n in results.items():
        _print(f"✓ {tool}: installed {n} skill(s)", "green")

    if not (HOME / ".co" / "keys" / "agent.key").exists():
        _print("\n→ No ConnectOnion identity yet. Create one with:", "yellow")
        _print("    co init", "yellow")

    _print("\nDone. Open your coding agent and try:", "green")
    _print("  /oo 0x<address> <task>", "")


def uninstall() -> None:
    uninstall_all(ALIAS, skill_names=["oo", "oo-init", "oo-subscribe", "oo-publish", "oo-accept"])
    if CACHE.exists():
        shutil.rmtree(CACHE)
    _print("✓ Removed oo from all detected coding agents.", "green")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--uninstall", action="store_true", help="remove oo from all coding agents")
    args = parser.parse_args()
    uninstall() if args.uninstall else install()
    return 0


if __name__ == "__main__":
    sys.exit(main())
