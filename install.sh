#!/bin/sh
# oo — one-line installer for the ConnectOnion agent networking skill
# https://github.com/openonion/oo
#
#   Install:    curl -fsSL openonion.ai/install | sh
#   Update:     re-run the same command
#   Uninstall:  curl -fsSL openonion.ai/install | sh -s uninstall
#   Local dev:  OO_SOURCE_DIR=/path/to/repo sh install.sh
#
# Clones github.com/openonion/oo and links the skill into every coding
# agent we know about: Claude Code, Codex CLI, Cursor, Kiro. Installs
# only for agents you actually have (detected via their config dirs).

set -eu

REPO="${OO_REPO:-openonion/oo}"
BRANCH="${OO_BRANCH:-main}"
SOURCE_DIR="${OO_SOURCE_DIR:-}"
CACHE_DIR="$HOME/.oo/cache"

green()  { printf '\033[32m%s\033[0m\n' "$1"; }
red()    { printf '\033[31m%s\033[0m\n' "$1" >&2; }
ok()     { printf '  \033[32m✓\033[0m %s\n' "$1"; }
skip()   { printf '  \033[2m·\033[0m %s\n' "$1"; }

# ----- targets: platform | source-in-repo | install-path-under-$HOME -------
# Each line: <label>|<repo-relative-source>|<HOME-relative-destination>
# Claude Code's slash command is provided by the skill itself (frontmatter
# `name: oo` exposes /oo), so we do not link commands/oo.md separately.
TARGETS='
Claude Code|skills/oo|.claude/skills/oo
Codex CLI|codex/oo|.codex/skills/oo
Cursor|cursor/rules/oo.mdc|.cursor/rules/oo.mdc
Kiro|kiro/steering/oo.md|.kiro/steering/oo.md
'

uninstall() {
  echo "Uninstalling oo..."
  echo "$TARGETS" | while IFS='|' read -r label src dst; do
    [ -z "$label" ] && continue
    full="$HOME/$dst"
    if [ -L "$full" ]; then
      rm "$full"
      ok "removed $label  ($full)"
    fi
  done
  rm -rf "$CACHE_DIR"
  green "✓ Uninstalled"
  exit 0
}

[ "${1:-}" = "uninstall" ] && uninstall

# ----- fetch the repo -----------------------------------------------------
mkdir -p "$(dirname "$CACHE_DIR")"

if [ -n "$SOURCE_DIR" ]; then
  [ -d "$SOURCE_DIR" ] || { red "OO_SOURCE_DIR=$SOURCE_DIR not found"; exit 1; }
  echo "Installing from local path $SOURCE_DIR..."
  rm -rf "$CACHE_DIR"
  ln -s "$SOURCE_DIR" "$CACHE_DIR"
else
  command -v git >/dev/null 2>&1 || { red "git is required but not installed"; exit 1; }
  if [ -L "$CACHE_DIR" ]; then rm -f "$CACHE_DIR"; fi
  if [ -d "$CACHE_DIR/.git" ]; then
    echo "Updating $REPO..."
    git -C "$CACHE_DIR" fetch --quiet --depth 1 origin "$BRANCH"
    git -C "$CACHE_DIR" reset --quiet --hard "origin/$BRANCH"
  else
    echo "Installing $REPO..."
    git clone --quiet --depth 1 --branch "$BRANCH" "https://github.com/$REPO.git" "$CACHE_DIR"
  fi
fi

# ----- link into every supported agent ------------------------------------
echo
echo "Linking into supported coding agents:"
linked=0
echo "$TARGETS" | while IFS='|' read -r label src dst; do
  [ -z "$label" ] && continue
  src_path="$CACHE_DIR/$src"
  dst_path="$HOME/$dst"

  if [ ! -e "$src_path" ]; then
    skip "$label — source $src missing in repo"
    continue
  fi

  mkdir -p "$(dirname "$dst_path")"
  rm -rf "$dst_path"
  ln -s "$src_path" "$dst_path"
  ok "$label  ->  ~/${dst}"
  linked=$((linked + 1))
done

echo
green "✓ Done. The /oo command is ready in every linked agent."
echo
echo "Try in Claude Code:"
echo "  /oo 0x<address> <task>"
