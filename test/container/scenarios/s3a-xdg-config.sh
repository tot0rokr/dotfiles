#!/usr/bin/env bash
# s3a-xdg-config: only XDG_CONFIG_HOME is set (DD §11 scenario 3), for every
# shell, as it would be before ~/.bashrc runs. Everything loads from there;
# a later shell with another value gets the drift warning.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s3a-xdg-config
t_xdg XDG_CONFIG_HOME="$HOME/alt-config"

group "s3a install with XDG_CONFIG_HOME=$T_CFG"
assert_exit0 "install.sh --yes" -- t_env "$T_REPO/install.sh" --yes
check_layout
assert_absent "$HOME/.config/bash"
t_bashrc_env_zone 'export DOTFILES_T_ENVZONE=1'

check_a01_loading
check_a02_noninteractive
check_a03_tmux
check_a04_nvim
check_a05_git
check_a20_vim
check_a21_wezterm

group "s3a XDG drift"
out=$(t_env XDG_CONFIG_HOME="$HOME/alt-config2" "$T_REPO/bin/dotfiles" status 2>&1)
assert_match "status warns that XDG_CONFIG_HOME differs from the install" 'XDG_CONFIG_HOME' "$out"
out=$(t_env XDG_CONFIG_HOME="$HOME/alt-config2" "$T_REPO/bin/dotfiles" install --dry-run 2>&1)
assert_match "install warns that XDG_CONFIG_HOME differs from the last install" 'XDG_CONFIG_HOME' "$out"

assert_summary
