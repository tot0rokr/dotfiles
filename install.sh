#!/usr/bin/env bash
# install.sh - first install from a fresh checkout: runs `bin/dotfiles install`
# (see `install.sh --help`). Afterwards use `dotfiles` from ~/.local/bin.

# Physical path: through a symlinked checkout the links would go via the link.
SRC="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
exec "$SRC/bin/dotfiles" install "$@"
