#!/usr/bin/env bash
# s3b-xdg-all: all four XDG_* base dirs non-default. Checks where everything
# lands, then runs `bootstrap user --only fnm,pynvim` under those values (only
# nodejs.org and PyPI are contacted) and nvim's python provider (A04).
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s3b-xdg-all
x=$HOME/xdg
t_xdg XDG_CONFIG_HOME="$x/config" XDG_DATA_HOME="$x/data" XDG_STATE_HOME="$x/state" XDG_CACHE_HOME="$x/cache"

group "s3b install with every XDG_* under $x"
assert_exit0 "install.sh --yes" -- t_env "$T_REPO/install.sh" --yes
check_layout

group "s3b paths"
assert_absent "$HOME/.local/state/dotfiles"
assert_absent "$HOME/.local/share/fonts"
assert_absent "$HOME/.config/bash"
assert_line "$T_STATE/dotfiles/xdg.env" "XDG_DATA_HOME=$T_DATA" 'xdg.env records XDG_DATA_HOME'
t_probe_shell s3b login
assert_line "$T_WORK/probe/s3b/vars.txt" "declare -- HISTFILE=\"$T_STATE/bash/history\"" 'HISTFILE under XDG_STATE_HOME'
assert_file "$T_STATE/bash"
check_a02_noninteractive

group "s3b bootstrap user --only fnm,pynvim"
ASSERT_SHOW_LINES=40 assert_exit0 "dotfiles bootstrap user --only fnm,pynvim" -- \
    t_dot bootstrap user --only fnm,pynvim
assert_file "$T_DATA/fnm/aliases/default/bin/node"
assert_file "$T_DATA/nvim/venv/bin/python"
assert_eq "node of a login shell is the fnm default under XDG_DATA_HOME" \
    "$T_DATA/fnm/aliases/default/bin/node" "$(t_login type -P node 2>&1)"
# Offline nvim start: the plugins and parsers the image holds in the default
# data dir, so lazy.nvim does not clone them again.
mkdir -p "$T_DATA/nvim"
cp -a "$HOME/.local/share/nvim/lazy" "$T_DATA/nvim/lazy"
[ ! -d "$HOME/.local/share/nvim/site" ] || cp -a "$HOME/.local/share/nvim/site" "$T_DATA/nvim/site"
check_a04_nvim provider

assert_summary
