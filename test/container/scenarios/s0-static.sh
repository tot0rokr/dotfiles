#!/usr/bin/env bash
# s0-static: checks on the checkout itself, before any install — old-path
# references (A11), syntax of every shell, Lua and tmux file (A32) and the
# env.bash properties (A30).
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
# shellcheck source=test/container/props/env-bash.sh
. /opt/dotfiles-test/props/env-bash.sh
t_init s0-static

check_a11_oldpath() {
    group "A11 old-path references"
    ASSERT_SHOW_LINES=80 assert_exit0 "A11 self-test: every sample form is reported, whole tokens only" -- \
        bash "$T_DIR/static/oldpath.sh" --selftest "$T_DIR/static/oldpath-selftest.txt"
    ASSERT_SHOW_LINES=200 assert_exit0 "A11 no old-path reference outside the allow-list" -- \
        bash "$T_DIR/static/oldpath.sh" "$T_REPO"
}

check_a32_static() {
    local repo=$T_REPO f first hits shells=() luas=() tmuxes=()
    group "A32 static checks"
    while IFS= read -r f; do
        if [ ! -f "$repo/$f" ] || [ -L "$repo/$f" ]; then
            continue
        fi
        case $f in
            .local/share/fonts/*) continue ;;
            *.lua) luas+=("$f"); continue ;;
            .config/tmux/*.conf | lib/templates/tmux.conf) tmuxes+=("$f"); continue ;;
            *.sh | *.bash | bin/dotfiles | lib/templates/bashrc | lib/templates/profile-portable)
                shells+=("$f"); continue ;;
        esac
        first=
        IFS= read -r first <"$repo/$f"
        case $first in
            '#!'*bash* | '#!'*/sh) shells+=("$f") ;;
        esac
    done < <(t_git -C "$repo" ls-files)

    for f in "${shells[@]}"; do
        assert_exit0 "A32 bash -n $f" -- bash -n "$repo/$f"
    done
    for f in "${luas[@]}"; do
        assert_exit0 "A32 luac5.4 -p $f" -- luac5.4 -p "$repo/$f"
    done
    if tq -L s0-parse -f /dev/null new-session -d -s parse; then
        for f in "${tmuxes[@]}"; do
            assert_exit0 "A32 tmux source-file -n $f" -- tq -L s0-parse source-file -n "$repo/$f"
        done
        t_tmux_kill -L s0-parse
    else
        _hardfail "A32 tmux server for the parse checks did not start"
    fi
    # `:lua`, `:python`, `:perl` and `:ruby` take the rest of the line, a `|`
    # included, so a one-line `if ... | lua ... | endif` breaks (PLAN B9).
    hits=$(cd "$repo" && grep -nE '\|[[:space:]]*(lua|py3?|python3?|perl|ruby)\b' \
        .config/vim/*.vim .config/vim/vimrc .config/nvim/init.vim | grep -vE '^[^:]+:[0-9]+:[[:space:]]*"')
    assert_empty "A32 no one-line vim command swallowed by :lua and friends" "$hits"
}

check_a11_oldpath
check_a32_static
check_a30_env_bash "$T_REPO/.config/bash/env.bash"

assert_summary
