#!/usr/bin/env bash
# s4-portable: a checkout used as the home through enter.sh (DD §8, A22):
# checkout mode twice (create, then ensure), tmux mode with a shell in a pane,
# and DIR mode on ~/box, which delegates to an interactive `dotfiles install`.
# The checkout gets copies of tmux, fzf and fnm so nothing is downloaded.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s4-portable

MY=$HOME/.myhome
ENTRIES=(.bashrc .profile .config/git/config .config/tmux/tmux.conf)
# As from an installed account: its own `dotfiles` CLI is on PATH.
OUTER_PATH=$HOME/.local/bin:$BASE_PATH

# s4_enter CMDFILE YES_COUNT ARGS... — runs enter.sh ARGS in a pty driven by
# shell.exp, from a plain environment.
s4_enter() {
    local cmds=$1 yes=$2
    shift 2
    t_env PATH="$OUTER_PATH" timeout 600 expect "$T_FIX/expect/shell.exp" "$yes" "$cmds" -- "$MY/enter.sh" "$@"
}

# s4_probe_cmds OUTDIR — shell lines that record what A22 checks.
s4_probe_cmds() {
    printf '%s\n' \
        "printf '%s\n' \"\$HOME\" >$1/home" \
        "type -P tmux >$1/tmux" \
        "type -P fzf >$1/fzf" \
        "type -P node >$1/node" \
        "type -P dotfiles >$1/dotfiles" \
        "dotfiles status 2>&1 | head -n 1 >$1/status" \
        "printf '%s\n' \"\$CARGO_HOME\" \"\$RUSTUP_HOME\" >$1/cargo-vars"
}

# s4_resolved LABEL OUTDIR — the probed commands resolve inside the checkout.
s4_resolved() {
    local c
    assert_eq "A22 $1: HOME is the checkout" "$MY" "$(cat "$2/home" 2>/dev/null)"
    for c in tmux fzf node; do
        assert_prefix "A22 $1: $c resolves inside the checkout first" "$MY/" "$(cat "$2/$c" 2>/dev/null)"
    done
    assert_eq "A22 $1: dotfiles is the checkout's CLI, not the outer account's" "$MY/bin/dotfiles" \
        "$(cat "$2/dotfiles" 2>/dev/null)"
    assert_eq "A22 $1: dotfiles status reports the checkout" "repo: $MY" "$(cat "$2/status" 2>/dev/null)"
    if [ "$T_TIER" = full ]; then
        assert_eq "A22 $1: CARGO_HOME and RUSTUP_HOME inside the checkout" \
            "$MY/.local/share/cargo $MY/.local/share/rustup" "$(paste -sd' ' "$2/cargo-vars" 2>/dev/null)"
    fi
}

group "s4 portable checkout"
if ! t_snapshot || ! t_git clone -q --no-hardlinks "$T_SNAP" "$MY"; then
    _hardfail "s4 clone of the checkout"
    assert_summary
    exit 1
fi
mkdir -p "$MY/.local/opt" "$MY/.local/share" "$MY/.local/bin"
cp -a "$HOME/.local/opt/tmux" "$HOME/.local/opt/fzf" "$HOME/.local/opt/fnm" "$MY/.local/opt/"
cp -a "$HOME/.local/share/fnm" "$MY/.local/share/"
cp -a "$HOME/.local/bin/fnm" "$MY/.local/bin/"
# The outer account's CLI link, as `dotfiles install` makes it.
ln -sfn ../../.dotfiles/bin/dotfiles "$HOME/.local/bin/dotfiles"

group "A22 checkout mode, first entry"
o=$T_WORK/enter1
mkdir -p "$o"
s4_probe_cmds "$o" >"$o/cmds"
assert_exit0 "enter.sh (checkout mode) runs an interactive shell" -- s4_enter "$o/cmds" 0
s4_resolved "checkout mode" "$o"
for f in "${ENTRIES[@]}"; do
    assert_file "$MY/$f"
    if t_git -C "$MY" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
        _hardfail "A22 entry file $f is tracked"
    else
        _pass "A22 entry file $f is untracked"
    fi
done
(cd "$MY" && sha256sum "${ENTRIES[@]}") >"$o/entries.sha" 2>&1

group "A22 checkout mode, second entry"
o2=$T_WORK/enter2
mkdir -p "$o2"
s4_probe_cmds "$o2" >"$o2/cmds"
assert_exit0 "enter.sh again" -- s4_enter "$o2/cmds" 0
assert_empty "A22 a second entry leaves the entry files unchanged" \
    "$(cd "$MY" && sha256sum "${ENTRIES[@]}" 2>&1 | diff "$o/entries.sha" -)"

group "A22 tmux mode"
o3=$T_WORK/enter-tmux
mkdir -p "$o3"
T_TMUX=$MY/.local/opt/tmux/bin/tmux
t_env PATH="$OUTER_PATH" TERM=xterm-256color timeout 600 script -qec "$MY/enter.sh tmux" /dev/null </dev/null \
    >"$o3/client.log" 2>&1 &
client=$!
socket=
for ((i = 0; i < 240; i++)); do
    socket=$(find "/tmp/tmux-$(id -u)" -maxdepth 1 -name 'portable-*' 2>/dev/null | head -n 1)
    [ -n "$socket" ] && tq -S "$socket" has-session 2>/dev/null && break
    sleep 0.5
done
session=
[ -z "$socket" ] || session=$(tq -S "$socket" list-sessions -F '#{session_name}' 2>/dev/null | head -n 1)
if [ -n "$session" ] && t_pane_run -S "$socket" "$session:" "$o3/ready" ':' 120; then
    while IFS= read -r line; do
        t_pane_send -S "$socket" "$session:" "$line"
    done < <(s4_probe_cmds "$o3")
    t_pane_run -S "$socket" "$session:" "$o3/done" ':' 60
    s4_resolved "tmux pane" "$o3"
    tq -S "$socket" kill-server 2>/dev/null
else
    _hardfail "A22 the portable tmux server or its pane shell did not come up"
    __assert_show "$o3/client.log"
    [ -z "$socket" ] || tq -S "$socket" kill-server 2>/dev/null
fi
wait "$client" 2>/dev/null

group "A22 DIR mode on ~/box"
o4=$T_WORK/enter-box
mkdir -p "$o4" "$HOME/box"
# The box has a real link install, which portable mode leaves alone: update
# and install say how to change it.
printf '%s\n' "printf '%s\n' \"\$HOME\" >$o4/home" \
    "dotfiles update --yes >$o4/update 2>&1; echo \$? >>$o4/update" \
    "dotfiles install --yes >$o4/install 2>&1; echo \$? >>$o4/install" \
    "env -u DOTFILES_PORTABLE dotfiles install --yes; echo \$? >$o4/install2" >"$o4/cmds"
assert_exit0 "enter.sh ~/box offers install, installs, then enters" -- s4_enter "$o4/cmds" 2 "$HOME/box"
assert_eq "A22 DIR mode: HOME is the box" "$HOME/box" "$(cat "$o4/home" 2>/dev/null)"
assert_file "$HOME/box/.local/state/dotfiles/manifest.tsv"
assert_grep "$HOME/box/.bashrc" '^# >>> dotfiles >>>$' 'A22 DIR mode: install wrote the ~/.bashrc entry'
assert_absent "$HOME/box/.profile"
assert_grep "$o4/update" 'env -u DOTFILES_PORTABLE dotfiles install' 'A22 DIR mode: update names the command for the box install'
assert_eq "A22 DIR mode: update exits 0" 0 "$(tail -n 1 "$o4/update" 2>/dev/null)"
assert_grep "$o4/install" 'env -u DOTFILES_PORTABLE' 'A22 DIR mode: install refuses and names the command'
assert_eq "A22 DIR mode: install refuses (exit 5)" 5 "$(tail -n 1 "$o4/install" 2>/dev/null)"
assert_eq "A22 DIR mode: install without DOTFILES_PORTABLE exits 0" 0 "$(cat "$o4/install2" 2>/dev/null)"

check_a09_repo_clean "$MY" portable

assert_summary
