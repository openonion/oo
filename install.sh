#!/bin/sh
# oo — shell entry point for the ConnectOnion agent networking bundle.
#
# Thin shim: clones the repo into ~/.connectonion/bundles/oo and hands off
# to install.py, which is the canonical installer. All install logic lives
# in install.py so the shell and python entry points stay in sync.
#
#   Install:    curl -fsSL agent.openonion.ai/install | sh
#   Uninstall:  curl -fsSL agent.openonion.ai/install | sh -s -- --uninstall
#   Local dev:  OO_SOURCE_DIR=/path/to/repo sh install.sh

set -eu

REPO="${OO_REPO:-openonion/oo}"
BRANCH="${OO_BRANCH:-main}"
SOURCE_DIR="${OO_SOURCE_DIR:-}"
CACHE_DIR="$HOME/.connectonion/bundles/oo"

red() { printf '\033[31m%s\033[0m\n' "$1" >&2; }

PY=""
for cmd in python3 python; do
  if command -v "$cmd" >/dev/null 2>&1; then PY="$cmd"; break; fi
done
[ -n "$PY" ] || { red "python3 is required but not installed"; exit 1; }

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

exec "$PY" "$CACHE_DIR/install.py" "$@"
