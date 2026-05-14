#!/bin/sh
# oo — shell entry point for the ConnectOnion agent networking bundle.
#
# 1. Downloads a self-contained CPython into ~/.co/env (no system python
#    required), 2. clones the repo into ~/.connectonion/bundles/oo, then
#    3. hands off to install.py running on the bundled CPython.
#
#   Install:    curl -fsSL agent.openonion.ai/install | sh
#   Uninstall:  curl -fsSL agent.openonion.ai/install | sh -s -- --uninstall
#   Local dev:  OO_SOURCE_DIR=/path/to/repo sh install.sh

set -eu

REPO="${OO_REPO:-openonion/oo}"
BRANCH="${OO_BRANCH:-main}"
SOURCE_DIR="${OO_SOURCE_DIR:-}"
CACHE_DIR="$HOME/.connectonion/bundles/oo"

CO_ENV="$HOME/.co/env"
CO_PY="$CO_ENV/python/bin/python3"

PBS_RELEASE="${OO_PBS_RELEASE:-20241016}"
PBS_PYTHON="${OO_PBS_PYTHON:-3.12.7}"

red() { printf '\033[31m%s\033[0m\n' "$1" >&2; }

# ----- ensure prerequisites ----------------------------------------------
command -v git >/dev/null 2>&1 || { red "git is required but not installed"; exit 1; }
command -v curl >/dev/null 2>&1 || { red "curl is required but not installed"; exit 1; }
command -v tar >/dev/null 2>&1 || { red "tar is required but not installed"; exit 1; }

# ----- ensure self-contained python at ~/.co/env/python ------------------
if [ ! -x "$CO_PY" ]; then
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"
  case "$uname_m" in arm64|aarch64) ARCH=aarch64 ;; *) ARCH=x86_64 ;; esac
  case "$uname_s" in
    Darwin) TRIPLE="$ARCH-apple-darwin" ;;
    Linux)  TRIPLE="$ARCH-unknown-linux-gnu" ;;
    *) red "unsupported platform: $uname_s/$uname_m"; exit 1 ;;
  esac
  ASSET="cpython-${PBS_PYTHON}+${PBS_RELEASE}-${TRIPLE}-install_only.tar.gz"
  URL="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_RELEASE}/${ASSET}"

  echo "Downloading Python ${PBS_PYTHON} → $CO_ENV..."
  mkdir -p "$CO_ENV"
  # tarball contains a top-level "python/" directory.
  curl -fsSL "$URL" | tar -xzf - -C "$CO_ENV"
  [ -x "$CO_PY" ] || { red "python bootstrap failed: $CO_PY not found after extract"; exit 1; }
fi

# ----- fetch the bundle --------------------------------------------------
mkdir -p "$(dirname "$CACHE_DIR")"

if [ -n "$SOURCE_DIR" ]; then
  [ -d "$SOURCE_DIR" ] || { red "OO_SOURCE_DIR=$SOURCE_DIR not found"; exit 1; }
  echo "Installing from local path $SOURCE_DIR..."
  rm -rf "$CACHE_DIR"
  ln -s "$SOURCE_DIR" "$CACHE_DIR"
else
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

exec "$CO_PY" "$CACHE_DIR/install.py" "$@"
