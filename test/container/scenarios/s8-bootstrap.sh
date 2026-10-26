#!/usr/bin/env bash
# s8-bootstrap: failure paths of `dotfiles bootstrap user` (PLAN C9) on the
# tools of the image account. It downloads GitHub release files (no API
# lookups): a tmux replace that fails leaves the installed binary and a
# running server alone, and one that works renames the new binary over the
# old one, so no client ever finds tmux missing; a failed final install of a
# downloaded tool fails its step; an fzf clone whose binary download failed
# is completed by the next run; claude is installed before the switcher; an
# absolute tmux or nvim link of an older bootstrap becomes relative.
# Stand-ins go into ~/.local/bin, which env.bash puts first on the
# bootstrap's PATH.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s8-bootstrap

B=$HOME/.local/bin
TD=$HOME/.local/opt/tmux/bin
O=$T_WORK/s8
# Back-to-back replaces racing a client loop; the code before the atomic
# rename left the binary missing or half-written dozens of times in 150.
RACE_RUNS=150
mkdir -p "$O"

# s8_boot NAME ARGS... — `dotfiles bootstrap user ARGS` without a TTY;
# output in $O/NAME.out, its exit status returned.
s8_boot() {
    local n=$1
    shift
    t_dot bootstrap user "$@" </dev/null >"$O/$n.out" 2>&1
}

# s8_stub NAME LINE... — the script LINEs as the stand-in ~/.local/bin/NAME.
s8_stub() {
    local n=$1
    shift
    printf '%s\n' "$@" >"$B/$n" && chmod 755 "$B/$n"
}

# s8_tmux_kept LABEL — the installed tmux and the running server are as before.
s8_tmux_kept() {
    assert_eq "$1: the tmux binary is unchanged" "$S0" "$(sha256sum <"$TD/tmux")"
    assert_eq "$1: the tmux binary keeps mode 755" 755 "$(stat -c %a "$TD/tmux" 2>&1)"
    assert_eq "$1: tmux -V" "$V0" "$("$TD/tmux" -V 2>&1)"
    assert_empty "$1: no staged copy left" "$(find "$TD" -name '.tmux.new.*')"
    if kill -0 "$P" 2>/dev/null; then _pass "$1: the tmux server still runs (pid $P)"
    else _hardfail "$1: the tmux server is gone (pid $P)"; fi
    assert_exit0 "$1: a new client reaches the server" -- tq -L t5b ls
}

group "s8 bootstrap user names its steps in run order"
s8_boot nosuch --only nosuch
assert_eq "bootstrap user --only nosuch exits 2" 2 "$?"
assert_grep "$O/nosuch.out" 'bell noti claude switcher\)' 'claude comes before switcher in the known steps'

group "s8 tmux: a replace that fails leaves the installed tmux and its server alone"
if ! tq -L t5b -f /dev/null new-session -d -s keep; then
    _hardfail "s8 tmux server for the replace checks did not start"
    assert_summary
    exit 1
fi
P=$(tq -L t5b display -p '#{pid}')
S0=$(sha256sum <"$TD/tmux")
V0=$("$TD/tmux" -V)
# A file size limit makes the copy stop part-way, as a full disk or quota does.
s8_stub install '#!/bin/bash' "trap '' XFSZ" 'ulimit -f 500' 'exec /usr/bin/install "$@"'
s8_boot tmux-efbig --only tmux --force
assert_eq "a partial copy: bootstrap user exits 1" 1 "$?"
rm -f "$B/install"
assert_line "$O/tmux-efbig.out" 'dotfiles bootstrap user: failed: tmux' 'a partial copy: the tmux step fails'
assert_line "$O/tmux-efbig.out" 'tmux install failed; existing install left untouched.' 'a partial copy: tmux says so'
assert_no_grep "$O/tmux-efbig.out" '^Installed: ' 'a partial copy: nothing reported installed'
s8_tmux_kept "a partial copy"

chmod a-w "$TD"
s8_boot tmux-ro --only tmux --force
assert_eq "a read-only tmux dir: bootstrap user exits 1" 1 "$?"
chmod u+w "$TD"
assert_line "$O/tmux-ro.out" 'dotfiles bootstrap user: failed: tmux' 'a read-only tmux dir: the tmux step fails'
s8_tmux_kept "a read-only tmux dir"

group "s8 tmux: a replace renames the new binary over the running one"
s8_boot tmux-ok --only tmux --force
assert_eq "bootstrap user --only tmux --force exits 0" 0 "$?"
assert_eq "the new tmux -V" "$V0" "$("$TD/tmux" -V 2>&1)"
assert_match "the running server keeps the replaced binary" ' \(deleted\)$' "$(readlink "/proc/$P/exe" 2>&1)"
if kill -0 "$P" 2>/dev/null; then _pass "the tmux server still runs (pid $P)"
else _hardfail "the tmux server is gone (pid $P)"; fi
assert_exit0 "a new client reaches the old server" -- tq -L t5b ls
assert_empty "no staged copy left" "$(find "$TD" -name '.tmux.new.*')"
assert_eq "the tmux link in ~/.local/bin is relative" ../opt/tmux/bin/tmux "$(readlink "$B/tmux")"

group "s8 absolute links an older bootstrap made become relative"
ln -sfn "$TD/tmux" "$B/tmux"
s8_boot relink-tmux --only tmux
assert_eq "bootstrap user --only tmux exits 0" 0 "$?"
assert_eq "the absolute tmux link is relative now" ../opt/tmux/bin/tmux "$(readlink "$B/tmux")"
nv=$(readlink -f "$B/nvim")
if [ -x "$nv" ]; then
    ln -sfn "$nv" "$B/nvim"
    s8_boot relink-nvim --only neovim
    assert_eq "bootstrap user --only neovim exits 0" 0 "$?"
    assert_match "the absolute nvim link is relative now" '^\.\./opt/nvim-linux-[^/]+/bin/nvim$' "$(readlink "$B/nvim")"
    if [ "$B/nvim" -ef "$nv" ]; then _pass "the nvim link still reaches $nv"
    else _hardfail "the nvim link no longer reaches $nv"; fi
else
    _hardfail "s8 the image has no nvim behind ~/.local/bin/nvim"
fi

group "s8 tmux: clients never find tmux missing or broken during replaces"
# The archive comes from a cache after the first download.
s8_stub curl '#!/bin/bash' 'args=("$@") out= url=' \
    'while [ $# -gt 0 ]; do' \
    '    case $1 in' \
    '        -o) out=$2; shift 2 ;;' \
    '        -*) shift ;;' \
    '        *) url=$1; shift ;;' \
    '    esac' \
    'done' \
    'case $url in' \
    "    *build-static-tmux*)" \
    "        [ -s $O/tmux.gz ] || /usr/bin/curl -fsSL -o $O/tmux.gz \"\$url\" || exit 1" \
    "        exec cp $O/tmux.gz \"\$out\"" \
    '        ;;' \
    'esac' \
    'exec /usr/bin/curl "${args[@]}"'
rm -f "$O/stop"
(
    n=0 miss=0 bad=0
    while [ ! -e "$O/stop" ]; do
        n=$((n + 1))
        [ -e "$TD/tmux" ] || miss=$((miss + 1))
        "$TD/tmux" -V >/dev/null 2>&1 || bad=$((bad + 1))
    done
    printf '%s %s %s\n' "$n" "$miss" "$bad" >"$O/race"
) &
checker=$!
fails=0
for ((i = 0; i < RACE_RUNS; i++)); do
    s8_boot race --only tmux --force || fails=$((fails + 1))
done
: >"$O/stop"
wait "$checker"
rm -f "$B/curl"
read -r n miss bad <"$O/race"
printf '  %s client checks during %s replaces\n' "$n" "$RACE_RUNS"
assert_eq "every one of $RACE_RUNS replaces succeeds" 0 "$fails"
assert_eq "no client check found tmux missing" 0 "$miss"
assert_eq "no client check failed to run tmux -V" 0 "$bad"
if kill -0 "$P" 2>/dev/null; then _pass "the tmux server still runs after the replaces"
else _hardfail "the tmux server is gone after the replaces"; fi
t_tmux_kill -L t5b

group "s8 a failed final install fails the step (gdu)"
chmod a-w "$B"
s8_boot gdu-ro --only gdu
assert_eq "gdu into a read-only ~/.local/bin: bootstrap user exits 1" 1 "$?"
chmod u+w "$B"
assert_line "$O/gdu-ro.out" 'dotfiles bootstrap user: failed: gdu' 'a read-only ~/.local/bin: the gdu step fails'
assert_absent "$B/gdu"
s8_stub install '#!/bin/sh' 'exit 1'
s8_boot gdu-install --only gdu
assert_eq "gdu with a failing install: bootstrap user exits 1" 1 "$?"
rm -f "$B/install"
assert_line "$O/gdu-install.out" 'dotfiles bootstrap user: failed: gdu' 'a failing install: the gdu step fails'
assert_absent "$B/gdu"

group "s8 fzf: the next run completes a clone whose binary download failed"
if t_env bash -c 'command -v go' >/dev/null 2>&1; then
    # fzf's installer builds the binary with go when the download fails.
    finding "s8 go is on PATH; the fzf download-failure checks need an image without it"
else
    rm -rf "$HOME/.local/opt/fzf"
    s8_stub curl '#!/bin/sh' 'exit 6'
    s8_stub wget '#!/bin/sh' 'exit 6'
    s8_boot fzf1 --only fzf
    assert_eq "fzf without downloads: bootstrap user exits 1" 1 "$?"
    rm -f "$B/curl" "$B/wget"
    assert_line "$O/fzf1.out" 'dotfiles bootstrap user: failed: fzf' 'fzf without downloads: the fzf step fails'
    assert_file "$HOME/.local/opt/fzf/.git"
    assert_absent "$HOME/.local/opt/fzf/bin/fzf"
    s8_boot fzf2 --only fzf
    assert_eq "fzf with downloads again: bootstrap user exits 0" 0 "$?"
    assert_no_grep "$O/fzf2.out" 'Installing fzf under' 'the existing clone is reused'
    assert_grep "$O/fzf2.out" 'Downloading bin/fzf' 'the missing binary is downloaded'
    assert_exit0 "the fzf binary runs" -- "$HOME/.local/opt/fzf/bin/fzf" --version
    s8_boot fzf3 --only fzf
    assert_eq "fzf once complete: bootstrap user exits 0" 0 "$?"
    assert_no_grep "$O/fzf3.out" 'Downloading|Installing fzf' 'a complete fzf is left alone'
fi

group "s8 claude is installed before the switcher, whose installer writes ~/.claude"
# A fresh account without claude and ~/.claude: a local switcher clone whose
# installer writes ~/.claude/settings.json as the real one does, and a curl
# stand-in that serves a Claude installer which only creates ~/.claude.
if ! t_snapshot || ! h=$(t_acct s8-claude); then
    _hardfail "s8 account for the claude and switcher steps"
else
    sw=$h/.local/opt/claude-account-switcher
    mkdir -p "$sw" "$h/.local/bin"
    t_git init -q "$sw"
    printf '%s\n' 'set -euo pipefail' 'echo "{}" >"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"' >"$sw/install.sh"
    printf '%s\n' '#!/bin/bash' \
        'for a; do' \
        '    if [ "$a" = https://claude.ai/install.sh ]; then' \
        "        printf '%s\n' 'mkdir -p \"\$HOME/.claude/downloads\"'" \
        '        exit 0' \
        '    fi' \
        'done' \
        'exec /usr/bin/curl "$@"' >"$h/.local/bin/curl"
    chmod 755 "$h/.local/bin/curl"
    (t_home "$h"; t_env GIT_TERMINAL_PROMPT=0 "$T_REPO/bin/dotfiles" bootstrap user --only switcher,claude) \
        </dev/null >"$O/claude.out" 2>&1
    rc=$?
    assert_eq "bootstrap user --only switcher,claude exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$O/claude.out"
    assert_file "$h/.claude/settings.json"
fi

assert_summary
