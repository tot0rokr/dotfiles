#!/usr/bin/env bash
# s1-fresh: a fresh account (DD §11 scenario 1). install.sh replaces the skel
# ~/.bashrc; the common.bash wrappers run the bootstrap in a pty; then every
# tool is exercised. The home allow-list and the checkout check come last.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s1-fresh

group "s1 fresh account"
assert_exit0 "the skel ~/.bashrc is in place" -- cmp -s "$HOME/.bashrc" /etc/skel/.bashrc
assert_absent "$HOME/.gitconfig"

group "s1 install"
assert_exit0 "install.sh --yes" -- t_env "$T_REPO/install.sh" --yes
check_layout
skel=$(find "$T_STATE/dotfiles/backup" -path '*/.bashrc' -type f 2>/dev/null | head -n 1)
if [ -n "$skel" ] && cmp -s "$skel" /etc/skel/.bashrc; then
    _pass "the skel ~/.bashrc is in the backup dir ($skel)"
else
    _hardfail "the skel ~/.bashrc is not in $T_STATE/dotfiles/backup"
fi

t_bashrc_env_zone 'export DOTFILES_T_ENVZONE=1'
t_bashrc_local 'export DOTFILES_T_LOCAL=1'
t_bashrc_local 'export BELL_BASH_BACKENDS=bel'
check_a02_noninteractive
check_a16_silence

group "s1 bootstrap through the common.bash wrappers (A19)"
o=$T_WORK/bootstrap
mkdir -p "$o"
sha256sum "$HOME/.bashrc" "$HOME/.profile" >"$o/rc.before"
if [ "$T_TIER" = full ]; then
    # In the pty, a clone that needs credentials (the switcher's private repo)
    # would wait at git's username prompt until the timeout.
    printf '%s\n' \
        "export GIT_TERMINAL_PROMPT=0" \
        "bootstrap_user_tools >$o/user.log 2>&1; printf '%s\n' \"\$?\" >$o/user.rc" \
        "bootstrap_agents >$o/agents.log 2>&1; printf '%s\n' \"\$?\" >$o/agents.rc" >"$o/cmds.bash"
    # Below the scenario limit (test/run.sh), so a hang fails the assertions.
    t_ishell 2400 "$o/cmds.bash"
    assert_eq "bootstrap_agents exits 0" 0 "$(cat "$o/agents.rc" 2>/dev/null)"
else
    # The tools the lite tier installed at build time (build/tools.sh).
    lite=$(cat "$T_DIR/build-checks/lite-tools" 2>/dev/null)
    [ -n "$lite" ] || _hardfail "no lite tool list in $T_DIR/build-checks"
    printf '%s\n' \
        "bootstrap_user_tools --only $lite >$o/user.log 2>&1; printf '%s\n' \"\$?\" >$o/user.rc" \
        >"$o/cmds.bash"
    t_ishell 900 "$o/cmds.bash"
fi
rc=$(cat "$o/user.rc" 2>/dev/null)
if [ "$rc" = 0 ]; then
    _pass "bootstrap_user_tools exits 0"
elif [ "$T_TIER" = full ] && [ "$rc" = 1 ] &&
    [ "$(grep '^dotfiles bootstrap user: failed:' "$o/user.log")" = 'dotfiles bootstrap user: failed: switcher' ] &&
    grep -q "could not read Username for 'https://github.com'" "$o/user.log"; then
    _pass "bootstrap_user_tools: every step but the switcher succeeded"
    finding "the switcher's private repository cannot be cloned without credentials in the container"
else
    _hardfail "bootstrap_user_tools exits 0 (got '$rc')"
    __assert_show "$o/user.log"
    __assert_show "$o/cmds.bash.err"
fi
if [ "$T_TIER" = full ]; then
    # The switcher's installer writes ~/.claude/settings.json, and only the
    # Claude CLI installer creates ~/.claude.
    a=$(grep -nE '^(Installing Claude Code CLI|claude already installed)' "$o/user.log" | head -n 1 | cut -d: -f1)
    b=$(grep -n 'claude-account-switcher' "$o/user.log" | head -n 1 | cut -d: -f1)
    if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
        _pass "the claude step runs before the switcher step (lines $a and $b of user.log)"
    else
        _hardfail "the claude step runs before the switcher step (claude line '${a:-none}', switcher line '${b:-none}')"
    fi
fi
sha256sum "$HOME/.bashrc" "$HOME/.profile" >"$o/rc.after"
assert_empty "A19 the wrappers' bootstrap left ~/.bashrc and ~/.profile unchanged" \
    "$(diff "$o/rc.before" "$o/rc.after")"
assert_absent "$HOME/.gitconfig"
check_a19_build

check_a01_loading
check_a03_tmux
check_a04_nvim
check_a05_git
check_a06_bell
check_a06_prompt_hooks
check_a06_bell_runtime
check_a10_history
check_a12_fnm
check_a13_btop
check_a14_startup
check_a20_vim
check_a21_wezterm
if [ "$T_TIER" = full ]; then
    check_a24_tools
    check_a24_fd_ignore
fi
check_a08_relative_links
check_a09_repo_clean
check_a07_allowlist

assert_summary
