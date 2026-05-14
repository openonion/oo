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
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = "https://github.com/openonion/oo"
HOME = Path.home()
ALIAS = "oo"
CACHE = HOME / ".connectonion" / "bundles" / ALIAS

# Self-contained user environment. install.sh / install.ps1 downloaded a
# relocatable CPython (python-build-standalone) into ~/.co/env/python and
# re-exec'd us under it — so sys.executable is already the bundled python.
# We just install connectonion into it and drop a shim on PATH.
CO_HOME = HOME / ".co"
CO_ENV = CO_HOME / "env"
CO_PY_ROOT = CO_ENV / "python"
CO_BIN = CO_HOME / "bin"

sys.path.insert(0, str(Path(__file__).parent / "lib"))
from fanout import install_all, uninstall_all  # noqa: E402


def _print(msg: str, color: str = "") -> None:
    codes = {"green": "32", "blue": "34", "yellow": "33", "red": "31"}
    if color and sys.stdout.isatty():
        print(f"\033[{codes[color]}m{msg}\033[0m")
    else:
        print(msg)


def _env_co() -> Path:
    if os.name == "nt":
        return CO_PY_ROOT / "Scripts" / "co.exe"
    return CO_PY_ROOT / "bin" / "co"


def ensure_connectonion() -> None:
    """Install connectonion into the bundled ~/.co/env python and place
    a PATH-friendly `co` shim at ~/.co/bin/co."""
    co = _env_co()
    if not co.exists():
        _print("Installing connectonion into ~/.co/env…", "blue")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "--upgrade", "pip"])
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "connectonion"])

    CO_BIN.mkdir(parents=True, exist_ok=True)
    shim = CO_BIN / ("co.bat" if os.name == "nt" else "co")
    if shim.exists() or shim.is_symlink():
        shim.unlink()
    if os.name == "nt":
        shim.write_text(f'@echo off\r\n"{co}" %*\r\n')
    else:
        shim.symlink_to(co)


def clone_or_update() -> None:
    # install.sh / install.ps1 own the bundle clone+update path (and the
    # OO_SOURCE_DIR symlink for local dev). We only fall back to cloning
    # here when install.py is run directly (e.g. `curl ... | python3 -`).
    if CACHE.exists() or CACHE.is_symlink():
        return
    CACHE.parent.mkdir(parents=True, exist_ok=True)
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

    path_dirs = os.environ.get("PATH", "").split(os.pathsep)
    if str(CO_BIN) not in path_dirs:
        _print(f"\n→ Add {CO_BIN} to your PATH so `co` resolves to ~/.co/env:", "yellow")
        _print(f'    export PATH="{CO_BIN}:$PATH"', "yellow")

    if not (HOME / ".co" / "keys" / "agent.key").exists():
        _print("\n→ No ConnectOnion identity yet. Create one with:", "yellow")
        _print("    co init", "yellow")

    _print("\nDone. Open your coding agent and try:", "green")
    _print("  /oo 0x<address> <task>", "")


def uninstall() -> None:
    uninstall_all(ALIAS, skill_names=["oo", "oo-init", "oo-subscribe", "oo-publish", "oo-accept"])
    if CACHE.is_symlink():
        CACHE.unlink()
    elif CACHE.exists():
        shutil.rmtree(CACHE)
    shim = CO_BIN / ("co.bat" if os.name == "nt" else "co")
    if shim.is_symlink() or shim.exists():
        shim.unlink()
    if CO_ENV.exists():
        shutil.rmtree(CO_ENV)
    _print("✓ Removed oo from all detected coding agents.", "green")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--uninstall", action="store_true", help="remove oo from all coding agents")
    args = parser.parse_args()
    uninstall() if args.uninstall else install()
    return 0


if __name__ == "__main__":
    sys.exit(main())
