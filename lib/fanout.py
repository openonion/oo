"""Per-tool fan-out helpers.

Given a directory containing a canonical bundle layout
(`skills/<name>/SKILL.md`, optional `commands/`, `agents/`,
`.claude-plugin/`), expose one function per supported coding agent that
materializes the bundle into that agent's expected location:

  install_claude(bundle, alias)    - ~/.claude/plugins/<alias>/  (symlink)
  install_skill_dirs(bundle, alias, tool)
                                    - ~/.<tool>/skills/<alias>-<skill>/ (symlink each)
  install_cursor(bundle, alias)    - ~/.cursor/rules/<alias>-<skill>.mdc
  install_kiro(bundle, alias)      - ~/.kiro/steering/<alias>-<skill>.md

Used by both `oo/install.py` (bootstrap install of the canonical `oo`
bundle) and `oo/skills/oo-subscribe/SKILL.md` (per-subscription install
of someone else's bundle from `~/.co/subs/<alias>/`).
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path

HOME = Path.home()
TOOLS = ("claude", "codex", "openclaw", "cursor", "kiro")
FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n(.*)$", re.DOTALL)


def detected_tools() -> list[str]:
    return [t for t in TOOLS if (HOME / f".{t}").is_dir()]


def _replace(dst: Path, src: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.is_symlink() or dst.exists():
        if dst.is_dir() and not dst.is_symlink():
            shutil.rmtree(dst)
        else:
            dst.unlink()
    dst.symlink_to(src)


def install_claude(bundle: Path, alias: str) -> int:
    _replace(HOME / ".claude" / "plugins" / alias, bundle)
    return 1


def install_skill_dirs(bundle: Path, alias: str, tool: str) -> int:
    n = 0
    for skill in sorted((bundle / "skills").iterdir()):
        if not skill.is_dir() or not (skill / "SKILL.md").exists():
            continue
        _replace(HOME / f".{tool}" / "skills" / f"{alias}-{skill.name}", skill)
        n += 1
    return n


def install_cursor(bundle: Path, alias: str) -> int:
    rules = HOME / ".cursor" / "rules"
    rules.mkdir(parents=True, exist_ok=True)
    n = 0
    for skill in sorted((bundle / "skills").iterdir()):
        md = skill / "SKILL.md"
        if not md.exists():
            continue
        m = FRONTMATTER_RE.match(md.read_text())
        if not m:
            continue
        fm, body = m.groups()
        desc = next(
            (l.split(":", 1)[1].strip() for l in fm.splitlines() if l.startswith("description:")),
            "",
        )
        (rules / f"{alias}-{skill.name}.mdc").write_text(
            f"---\ndescription: {desc}\nalwaysApply: false\n---\n{body}"
        )
        n += 1
    return n


def install_kiro(bundle: Path, alias: str) -> int:
    steering = HOME / ".kiro" / "steering"
    steering.mkdir(parents=True, exist_ok=True)
    n = 0
    for md in sorted((bundle / "skills").glob("*/SKILL.md")):
        shutil.copy(md, steering / f"{alias}-{md.parent.name}.md")
        n += 1
    return n


def install_all(bundle: Path, alias: str) -> dict[str, int]:
    """Install into every detected tool. Returns {tool: skill_count}."""
    handlers = {
        "claude":   lambda: install_claude(bundle, alias),
        "codex":    lambda: install_skill_dirs(bundle, alias, "codex"),
        "openclaw": lambda: install_skill_dirs(bundle, alias, "openclaw"),
        "cursor":   lambda: install_cursor(bundle, alias),
        "kiro":     lambda: install_kiro(bundle, alias),
    }
    return {tool: handlers[tool]() for tool in detected_tools()}


def uninstall_all(alias: str, skill_names: list[str] | None = None) -> None:
    """Remove every per-tool install for `alias`. If skill_names given, only
    those skill files; otherwise wipe everything matching the alias prefix."""
    targets: list[Path] = [HOME / ".claude" / "plugins" / alias]
    for tool in ("codex", "openclaw"):
        skills_dir = HOME / f".{tool}" / "skills"
        if skill_names is not None:
            targets += [skills_dir / f"{alias}-{n}" for n in skill_names]
        elif skills_dir.is_dir():
            targets += [p for p in skills_dir.iterdir() if p.name.startswith(f"{alias}-")]
    for ext, base in (("mdc", HOME / ".cursor" / "rules"),
                      ("md",  HOME / ".kiro" / "steering")):
        if skill_names is not None:
            targets += [base / f"{alias}-{n}.{ext}" for n in skill_names]
        elif base.is_dir():
            targets += [p for p in base.iterdir() if p.name.startswith(f"{alias}-")]
    for t in targets:
        if t.is_symlink() or t.is_file():
            t.unlink()
        elif t.is_dir():
            shutil.rmtree(t)
