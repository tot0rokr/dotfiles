#!/usr/bin/env bash
# Container entrypoint (runs as the `tester` user). Obtains the dotfiles tree,
# installs it into $HOME via install.sh, then hands off to tests.sh.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DOTFILES_SOURCE=${DOTFILES_SOURCE:-remote}          # remote | local
DOTFILES_REF=${DOTFILES_REF:-main}
DOTFILES_REPO=${DOTFILES_REPO:-https://github.com/tot0rokr/dotfiles.git}

echo "==================================================================="
echo " dotfiles bootstrap test"
echo "   source=$DOTFILES_SOURCE  ref=$DOTFILES_REF  run_user_tools=${RUN_USER_TOOLS:-0}"
echo "==================================================================="

if [ "$DOTFILES_SOURCE" = local ]; then
  # The working tree is bind-mounted read-only at /mnt/dotfiles. install.sh
  # resolves SRC as its own dir and only READS from it, so running it straight
  # from the mount is fine — and SRC(/mnt/dotfiles) != DEST($HOME) satisfies the
  # install.sh SRC==DEST guard.
  [ -f /mnt/dotfiles/install.sh ] || { echo "ERROR: --local but /mnt/dotfiles/install.sh not mounted" >&2; exit 2; }
  DOTFILES_DIR=/mnt/dotfiles
  echo "[using mounted working tree at $DOTFILES_DIR]"
else
  DOTFILES_DIR=/tmp/dotfiles-src
  rm -rf "$DOTFILES_DIR"
  echo "[cloning $DOTFILES_REPO @ $DOTFILES_REF]"
  git clone --depth 1 --branch "$DOTFILES_REF" "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo "[install.sh --dest $HOME]"
"$DOTFILES_DIR/install.sh" --dest "$HOME"

echo "[handing off to tests.sh]"
exec bash "$HERE/tests.sh"
