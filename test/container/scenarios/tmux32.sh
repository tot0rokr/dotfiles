#!/usr/bin/env bash
# tmux32: the oldest supported tmux, the static 3.2 build (image
# dotfiles-xdg-test:tmux32): the config loads with #{d:current_file},
# @tpm_plugins, the %if plugin path, the theme and the status-right appends
# (A03 subset).
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init tmux32

group "tmux32 install"
assert_eq "the user-local tmux is 3.2" "tmux 3.2" "$("$T_TMUX" -V 2>&1)"
assert_exit0 "install.sh --yes" -- t_env "$T_REPO/install.sh" --yes
check_a03_tmux subset

assert_summary
