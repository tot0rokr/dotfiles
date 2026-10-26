#!/usr/bin/env bash
# Build-time editor layer (test/Dockerfile stage editor). With XDG_CONFIG_HOME
# naming a copy of .config/nvim and .config/vim, installs the lazy.nvim and
# vim-plug plugins and the treesitter parsers into the default data dir and
# the coc extensions into ~/.config/coc, where the installed config finds them
# at run time. Fails when a plugin, parser or coc extension is missing, so no
# nvim in a scenario starts with a download.
set -o pipefail

CHECKS=/opt/dotfiles-test/build-checks

die() {
    printf 'editor.sh: %s\n' "$*" >&2
    exit 1
}

# missing NAME WHAT — fails when build-checks/NAME is absent or lists something
missing() {
    [ -f "$CHECKS/$1" ] || die "no $CHECKS/$1: the nvim check did not finish"
    [ ! -s "$CHECKS/$1" ] || die "$2 not installed: $(paste -sd' ' "$CHECKS/$1")"
}

if [ ! -d "${XDG_CONFIG_HOME:-}/nvim" ] || [ ! -d "$XDG_CONFIG_HOME/vim" ]; then
    die "XDG_CONFIG_HOME must name the copied editor config"
fi
# PATH for nvim, tree-sitter and node (plugin build hooks run npx).
# shellcheck source=.config/bash/env.bash
. /opt/dotfiles-bootstrap/.config/bash/env.bash

nvim --headless '+Lazy! sync' +qa || die "Lazy! sync failed"
rm -f "$CHECKS/ts-missing.txt" "$CHECKS/coc-missing.txt"
# coc's data home would be $XDG_CONFIG_HOME/coc here; an account without
# XDG_CONFIG_HOME reads ~/.config/coc. The timeout ends an nvim left running
# by an error in the -c script.
timeout 3600 nvim --headless --cmd "let g:coc_data_home = '$HOME/.config/coc'" \
    -c 'luafile /opt/dotfiles-test/build/nvim-plugins.lua' ||
    die "nvim plugins missing after Lazy! sync, or the parser and coc install failed"
missing ts-missing.txt 'treesitter parsers'
missing coc-missing.txt 'coc extensions'

# -N: -u with a file name leaves 'compatible' on, which breaks line continuations.
vim -N -es -i NONE -u "$XDG_CONFIG_HOME/vim/vimrc" +'PlugInstall --sync' +qa
vim -N -es -i NONE -u "$XDG_CONFIG_HOME/vim/vimrc" \
    +'exe empty(filter(values(get(g:, "plugs", {})), "!isdirectory(v:val.dir)")) ? "qa!" : "cq"' ||
    die "vim plugins missing after PlugInstall"
