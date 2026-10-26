#!/usr/bin/env bash
# s6-cli: `dotfiles` command semantics on fresh accounts under /tmp/accts
# (DD §7, PLAN C3-C7, C11): old tmux warning (A15), install without a TTY,
# backups, managed blocks, entry modes, uninstall and __path_in_use (A17),
# interactive conflicts and apply-time re-checks (A25), update (A26), status
# (A27), config dirs that lead elsewhere or into the checkout (A28, also for
# migrate), and the resume and safety paths of `dotfiles migrate` (A23),
# including the refusals of bootstrap user and uninstall-legacy while its node
# move is pending.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s6-cli

# s6_dot HOME ARGS... — runs that account's `dotfiles ARGS` without a TTY;
# output goes to $T_WORK/last.out, the exit status is returned.
s6_dot() {
    local h=$1
    shift
    (t_home "$h"; t_dot "$@") </dev/null >"$T_WORK/last.out" 2>&1
}

# s6_dotenv HOME NAME=VALUE... ARGS... — s6_dot with extra environment.
s6_dotenv() {
    local h=$1
    shift
    __t_assigns "$@"
    shift "$T_NASSIGNS"
    (t_home "$h"; t_env "${T_ASSIGNS[@]}" "$T_REPO/bin/dotfiles" "$@") </dev/null >"$T_WORK/last.out" 2>&1
}

# s6_pty_install HOME HOOK — that account's `dotfiles install` in a pty; once
# it asks "Apply?", runs HOOK, then answers y. The session goes to
# $T_WORK/pty.out; returns install's exit status.
s6_pty_install() {
    local fifo=$T_WORK/pty.fifo out=$T_WORK/pty.out sp i rc
    rm -f "$fifo" "$out"
    mkfifo "$fifo" || return 1
    exec 7<>"$fifo"
    (t_home "$1"; t_env timeout 120 script -qfec "$T_REPO/bin/dotfiles install" "$out") <"$fifo" >/dev/null 2>&1 &
    sp=$!
    for ((i = 0; i < 240; i++)); do
        grep -q 'Apply?' "$out" 2>/dev/null && break
        sleep 0.25
    done
    "$2"
    printf 'y\n' >&7
    wait "$sp"
    rc=$?
    exec 7>&-
    rm -f "$fifo"
    return "$rc"
}

# s6_conflicts HOME — two regular files where install wants links.
s6_conflicts() {
    mkdir -p "$1/.config/btop" "$1/.config/fd"
    printf 'local btop\n' >"$1/.config/btop/btop.conf"
    printf 'local fd\n' >"$1/.config/fd/ignore"
}

check_a15() {
    local h fb=$T_WORK/fake-tmux
    group "A15 tmux older than 3.2 on PATH"
    h=$(t_acct a15) || { _hardfail "A15 account"; return; }
    mkdir -p "$fb"
    install -m 755 "$T_FIX/fake-tmux-3.0a/tmux" "$fb/tmux"
    (t_home "$h"; t_env PATH="$fb:$BASE_PATH" "$T_REPO/bin/dotfiles" install --yes) >"$T_WORK/a15-install.out" 2>&1
    assert_grep "$T_WORK/a15-install.out" '3\.2' 'A15 install warns about tmux < 3.2'
    (t_home "$h"; t_env PATH="$fb:$BASE_PATH" "$T_REPO/bin/dotfiles" status) >"$T_WORK/a15-status.out" 2>&1
    assert_grep "$T_WORK/a15-status.out" '3\.2' 'A15 status warns about tmux < 3.2'
}

check_a17() {
    local h m rc f orig b n
    group "A17 install without a TTY, backups, idempotence"
    h=$(t_acct a17) || { _hardfail "A17 account"; return; }
    s6_conflicts "$h"
    m=$(t_marker)
    s6_dot "$h" install
    assert_eq "A17 conflicts without a TTY exit 3" 3 "$?"
    assert_empty "A17 that changed nothing" "$(t_changed "$m" "$h")"

    s6_dot "$h" install --replace-all
    rc=$?
    assert_eq "A17 install --replace-all exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_rel_link "$h/.config/btop/btop.conf" "$h/.dotfiles/.config/btop/btop.conf"
    b=$(compgen -G "$h/.local/state/dotfiles/backup/*/.config/btop/btop.conf" | head -n 1)
    if [ -n "$b" ] && grep -qx 'local btop' "$b"; then _pass "A17 the replaced file is in backup/<ts>/"
    else _hardfail "A17 the replaced btop.conf is not in the backup dir"; fi
    assert_empty "A17 no .bak files outside the backup dir" \
        "$(find "$h" \( -path "$h/.dotfiles" -o -path "$h/.local/state/dotfiles" \) -prune -o -name '*.bak*' -print)"

    m=$(t_marker)
    s6_dot "$h" install --yes
    assert_eq "A17 a second install exits 0" 0 "$?"
    assert_empty "A17 a second install changes nothing" "$(t_changed "$m" "$h")"

    h=$(t_acct a17-noyes) || { _hardfail "A17 account"; return; }
    m=$(t_marker)
    s6_dot "$h" install
    assert_eq "A17 install with work but no conflicts and no --yes exits 3 without a TTY" 3 "$?"
    assert_empty "A17 that changed nothing" "$(t_changed "$m" "$h")"

    # Entry files the managed blocks go into: CRLF lines, backslashes, no final
    # newline, mode 600. Everything outside the blocks must keep its bytes.
    h=$(t_acct a17-blocks) || { _hardfail "A17 account"; return; }
    mkdir -p "$h/.config/git" "$h/.config/tmux" "$T_WORK/a17-orig"
    printf '[user]\r\n\tname = a\\b\r\n\temail = t@example.invalid' >"$h/.config/git/config"
    chmod 600 "$h/.config/git/config"
    printf 'set -g @t-bs "a\\\\b"\nbind-key x display-message "\\\\"\n# no final newline' >"$h/.config/tmux/tmux.conf"
    printf '# hand-written\r\nalias t-crlf=true\r\nT_BS="a\\\\b"' >"$h/.bashrc"
    cp -p "$h/.config/git/config" "$T_WORK/a17-orig/gitconfig"
    cp -p "$h/.config/tmux/tmux.conf" "$T_WORK/a17-orig/tmux.conf"
    cp -p "$h/.bashrc" "$T_WORK/a17-orig/bashrc"
    s6_dot "$h" install --yes
    rc=$?
    assert_eq "A17 install into existing entry files exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_grep "$h/.config/git/config" '^# >>> dotfiles >>>$' 'A17 block added to the git entry'
    assert_exit0 "A17 git entry: bytes outside the block unchanged" -- \
        cmp -s <(t_outside_blocks "$h/.config/git/config") "$T_WORK/a17-orig/gitconfig"
    assert_exit0 "A17 tmux entry: bytes outside the block unchanged" -- \
        cmp -s <(t_outside_blocks "$h/.config/tmux/tmux.conf") "$T_WORK/a17-orig/tmux.conf"
    # The main block goes at the end, so a missing final newline gets one.
    if cmp -s <(t_outside_blocks "$h/.bashrc") "$T_WORK/a17-orig/bashrc" ||
        cmp -s <(t_outside_blocks "$h/.bashrc") <(cat "$T_WORK/a17-orig/bashrc"; printf '\n'); then
        _pass "A17 ~/.bashrc: bytes outside the blocks unchanged"
    else
        _hardfail "A17 ~/.bashrc: bytes outside the blocks changed"
    fi
    assert_eq "A17 mode 600 of the git entry kept" 600 "$(stat -c %a "$h/.config/git/config")"

    h=$(t_acct a17-nul) || { _hardfail "A17 account"; return; }
    mkdir -p "$h/.config/tmux"
    printf 'set -g @t 1\n\0\n' >"$h/.config/tmux/tmux.conf"
    cp -p "$h/.config/tmux/tmux.conf" "$T_WORK/a17-nul.orig"
    m=$(t_marker)
    s6_dot "$h" install --yes
    assert_eq "A17 an entry file with a NUL byte is refused (exit 5)" 5 "$?"
    assert_exit0 "A17 the NUL file is unchanged" -- cmp -s "$h/.config/tmux/tmux.conf" "$T_WORK/a17-nul.orig"
    if [ -z "$(t_changed "$m" "$h")" ]; then _pass "A17 the refusal changed nothing"
    else _softfail "A17 the refusal changed: $(t_changed "$m" "$h" | paste -sd' ')"; fi

    # uninstall removes the blocks, then the manifest links, nothing else.
    h=/tmp/accts/a17
    printf 'T=1\n' >"$h/.config/secrets.env"
    cut -f1 "$h/.local/state/dotfiles/manifest.tsv" >"$T_WORK/a17-manifest"
    s6_dot "$h" uninstall
    assert_eq "A17 uninstall exits 0" 0 "$?"
    n=0
    while IFS= read -r f; do
        if [ -L "$f" ] && [[ $(readlink -f "$f") == "$h/.dotfiles/"* ]]; then n=$((n + 1)); fi
    done <"$T_WORK/a17-manifest"
    assert_eq "A17 no manifest link left after uninstall" 0 "$n"
    for f in "$h/.bashrc" "$h/.config/git/config" "$h/.config/tmux/tmux.conf"; do
        assert_no_grep "$f" '>>> dotfiles' "A17 uninstall removed the blocks from $f"
    done
    assert_file "$h/.config/secrets.env"
    assert_file "$h/.local/state/dotfiles/backup"
    orig=$(compgen -G "$h/.local/state/dotfiles/backup/*/.config/btop/btop.conf" | head -n 1)
    assert_file "$orig"
}

check_a17_entries() {
    local h b rc
    group "A17 the mode of a replaced ~/.bashrc, and a broken managed block"
    h=$(t_acct a17-mode) || { _hardfail "A17 account"; return; }
    cp /etc/skel/.bashrc "$h/.bashrc" && chmod 600 "$h/.bashrc"
    (umask 002; t_home "$h"; t_dot install --yes) </dev/null >"$T_WORK/last.out" 2>&1
    rc=$?
    assert_eq "A17 install over a mode 600 skel ~/.bashrc under umask 002 exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_eq "A17 the new ~/.bashrc keeps mode 600" 600 "$(stat -c %a "$h/.bashrc" 2>&1)"
    b=$(compgen -G "$h/.local/state/dotfiles/backup/*/.bashrc" | head -n 1)
    if [ -n "$b" ] && cmp -s "$b" /etc/skel/.bashrc; then _pass "A17 the skel ~/.bashrc is in the backup dir"
    else _hardfail "A17 the skel ~/.bashrc is not in the backup dir"; fi

    printf '%s\n' '# >>> dotfiles >>>' 'echo dup' '# <<< dotfiles <<<' >>"$h/.bashrc"
    s6_dot "$h" install --yes
    assert_eq "A17 a second dotfiles block in ~/.bashrc stops install (exit 1)" 1 "$?"
    assert_grep "$T_WORK/last.out" "$h/\.bashrc: broken managed block 'dotfiles'" \
        'A17 the broken-block message names ~/.bashrc'
    assert_no_grep "$T_WORK/last.out" '/tmp/dotfiles\.' 'A17 the broken-block message names no temp file'
}

check_a17_uninstall_xdg() {
    local h m n f rc st
    group "A17 uninstall under another XDG_STATE_HOME, and a relative XDG_CONFIG_HOME"
    h=$(t_acct a17-st) || { _hardfail "A17 account"; return; }
    st=$h/.local/state/dotfiles
    s6_dot "$h" install --yes
    assert_eq "A17 install exits 0" 0 "$?"
    cut -f1 "$st/manifest.tsv" >"$T_WORK/a17-st-manifest"
    m=$(t_marker)
    s6_dotenv "$h" XDG_STATE_HOME="$h/st" uninstall
    assert_eq "A17 uninstall under another XDG_STATE_HOME refuses (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.out" 'XDG_STATE_HOME' 'A17 the refusal names XDG_STATE_HOME'
    assert_empty "A17 the refusal changed nothing" "$(t_changed "$m" "$h")"
    assert_grep "$h/.bashrc" '>>> dotfiles' 'A17 the refusal left the ~/.bashrc blocks'
    n=0
    while IFS= read -r f; do
        [ -L "$f" ] || n=$((n + 1))
    done <"$T_WORK/a17-st-manifest"
    assert_eq "A17 the refusal left every manifest link" 0 "$n"
    s6_dot "$h" uninstall
    assert_eq "A17 uninstall with the state dir install used exits 0" 0 "$?"

    h=$(t_acct a17-rel) || { _hardfail "A17 account"; return; }
    st=$h/.local/state/dotfiles
    s6_dotenv "$h" XDG_CONFIG_HOME=cfg install --yes
    rc=$?
    assert_eq "A17 install with XDG_CONFIG_HOME=cfg exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_grep "$T_WORK/last.out" 'relative' 'A17 install warns about the relative XDG_CONFIG_HOME'
    assert_eq "A17 manifest.tsv holds absolute targets" 0 "$(cut -f1 "$st/manifest.tsv" | grep -vc '^/')"
    assert_eq "A17 blocks.tsv holds absolute targets" 0 "$(cut -f1 "$st/blocks.tsv" | grep -vc '^/')"
    assert_eq "A17 xdg.env records the resolved XDG_CONFIG_HOME" "XDG_CONFIG_HOME=$h/cfg" \
        "$(grep '^XDG_CONFIG_HOME=' "$st/xdg.env")"
    (t_home "$h"; cd /tmp && t_env XDG_CONFIG_HOME=cfg "$T_REPO/bin/dotfiles" uninstall) </dev/null \
        >"$T_WORK/last.out" 2>&1
    rc=$?
    assert_eq "A17 uninstall from another dir with the same relative value exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_empty "A17 that uninstall removed every link under $h/cfg" "$(find "$h/cfg" -type l)"
    assert_no_grep "$h/cfg/git/config" '>>> dotfiles' 'A17 that uninstall removed the git entry block'
}

# __path_in_use skips what it cannot read: an ssh login's non-dumpable
# `sshd: user@pts/N` process and zombies, whose /proc files belong to root.
check_a17_path_in_use() {
    local d=$T_WORK/inuse
    group "A17 __path_in_use next to a non-dumpable process and a zombie"
    mkdir -p "$d/unused" "$d/used"
    if ! t_nondumpable_start; then
        _hardfail "A17 cannot build the non-dumpable helper"
        return
    fi
    t_zombie_start
    sleep 1
    (
        REPO=$T_REPO
        # shellcheck source=lib/dotfiles/core.bash
        . "$T_REPO/lib/dotfiles/core.bash"
        __path_in_use "$d/unused"
        assert_eq "A17 an unused dir is not in use" 1 "$?"
        __path_in_use /nonexistent/x
        assert_eq "A17 a missing path is not in use" 1 "$?"
        (cd "$d/used" && exec sleep 60) &
        sleep 0.3
        __path_in_use "$d/used"
        assert_eq "A17 the cwd of a process is in use" 0 "$?"
        kill "$!"
    )
    kill "$T_ND" "$T_ZP" 2>/dev/null
}

check_a25() {
    local h exp=$T_FIX/expect/install-answers.exp m rc
    group "A25 interactive install"
    h=$(t_acct a25-keep) || { _hardfail "A25 account"; return; }
    s6_conflicts "$h"
    (t_home "$h"; t_env timeout 300 expect "$exp" dkk y -- "$T_REPO/bin/dotfiles" install) >"$T_WORK/a25-keep.out" 2>&1
    assert_eq "A25 diff, keep, keep, confirm: exit 0" 0 "$?"
    assert_grep "$T_WORK/a25-keep.out" '^[-+@]{1,3}' 'A25 show diff printed a diff'
    assert_exit0 "A25 the kept btop.conf is untouched" -- grep -qx 'local btop' "$h/.config/btop/btop.conf"
    assert_grep "$h/.local/state/dotfiles/kept.list" 'btop/btop\.conf' 'A25 keep is recorded'
    m=$(t_marker)
    s6_dot "$h" install --yes
    assert_eq "A25 kept files are not asked again (no TTY, exit 0)" 0 "$?"
    assert_empty "A25 that run changed nothing" "$(t_changed "$m" "$h")"
    s6_dot "$h" status
    assert_grep "$T_WORK/last.out" 'btop\.conf' 'A25 status lists the kept file'

    h=$(t_acct a25-replace-all) || { _hardfail "A25 account"; return; }
    s6_conflicts "$h"
    (t_home "$h"; t_env timeout 300 expect "$exp" R y -- "$T_REPO/bin/dotfiles" install) >"$T_WORK/a25-replace-all.out" 2>&1
    assert_eq "A25 replace all remaining from the first prompt: exit 0" 0 "$?"
    assert_rel_link "$h/.config/btop/btop.conf"
    assert_rel_link "$h/.config/fd/ignore"

    h=$(t_acct a25-keep-all) || { _hardfail "A25 account"; return; }
    s6_conflicts "$h"
    (t_home "$h"; t_env timeout 300 expect "$exp" K y -- "$T_REPO/bin/dotfiles" install) >"$T_WORK/a25-keep-all.out" 2>&1
    assert_eq "A25 keep all remaining from the first prompt: exit 0" 0 "$?"
    assert_exit0 "A25 keep all kept btop.conf" -- grep -qx 'local btop' "$h/.config/btop/btop.conf"
    assert_exit0 "A25 keep all kept fd/ignore" -- grep -qx 'local fd' "$h/.config/fd/ignore"

    h=$(t_acct a25-cancel) || { _hardfail "A25 account"; return; }
    s6_conflicts "$h"
    m=$(t_marker)
    (t_home "$h"; t_env timeout 300 expect "$exp" c - -- "$T_REPO/bin/dotfiles" install) >"$T_WORK/a25-cancel.out" 2>&1
    rc=$?
    if [ "$rc" -lt 90 ]; then _pass "A25 cancel at a conflict prompt ends install (exit $rc)"
    else _hardfail "A25 cancel at a conflict prompt (expect exit $rc)"; __assert_show "$T_WORK/a25-cancel.out"; fi
    assert_empty "A25 cancel changed nothing" "$(t_changed "$m" "$h")"
    m=$(t_marker)
    (t_home "$h"; t_env timeout 300 expect "$exp" rr n -- "$T_REPO/bin/dotfiles" install) >"$T_WORK/a25-no.out" 2>&1
    rc=$?
    if [ "$rc" -lt 90 ]; then _pass "A25 no at the final confirmation ends install (exit $rc)"
    else _hardfail "A25 no at the final confirmation (expect exit $rc)"; __assert_show "$T_WORK/a25-no.out"; fi
    assert_empty "A25 declining the confirmation changed nothing" "$(t_changed "$m" "$h")"
}

# Hooks of s6_pty_install for check_a25_recheck, on the account S6_H.
__s6_put_precious() { mkdir -p "$S6_H/.config/git" && printf 'precious\n' >"$S6_H/.config/git/common"; }
__s6_put_mine() { rm -f "$S6_H/.config/t-gone/x.conf" && printf 'mine\n' >"$S6_H/.config/t-gone/x.conf"; }
__s6_nothing() { :; }

# __s6_gone_link — a manifest link of S6_H to a repo file no longer tracked.
__s6_gone_link() {
    mkdir -p "$S6_H/.config/t-gone" &&
        rm -f "$S6_H/.config/t-gone/x.conf" &&
        ln -s ../../.dotfiles/.config/t-gone/x.conf "$S6_H/.config/t-gone/x.conf" &&
        printf '%s\t%s\t%s\n' "$S6_H/.config/t-gone/x.conf" ../../.dotfiles/.config/t-gone/x.conf \
            .config/t-gone/x.conf >>"$S6_H/.local/state/dotfiles/manifest.tsv"
}

# What install planned can change before it applies: a new link target that
# appeared meanwhile stays, and so does a dangling link to prune that became
# a file.
check_a25_recheck() {
    local f man
    group "A25 install re-checks each target when it applies"
    S6_H=$(t_acct a25-appear) || { _hardfail "A25 account"; return; }
    f=$S6_H/.config/git/common
    s6_pty_install "$S6_H" __s6_put_precious
    assert_eq "A25 a file that appears where a link goes stops install (exit 1)" 1 "$?"
    assert_grep "$T_WORK/pty.out" 'appeared while dotfiles was running' 'A25 install names the file that appeared'
    if [ -f "$f" ] && [ ! -L "$f" ] && grep -qx precious "$f"; then _pass "A25 the file that appeared is untouched"
    else _hardfail "A25 the file that appeared was replaced or changed"; fi

    S6_H=$(t_acct a25-prune) || { _hardfail "A25 account"; return; }
    f=$S6_H/.config/t-gone/x.conf
    man=$S6_H/.local/state/dotfiles/manifest.tsv
    s6_dot "$S6_H" install --yes
    assert_eq "A25 install exits 0" 0 "$?"
    __s6_gone_link || _hardfail "A25 manifest link setup"
    s6_pty_install "$S6_H" __s6_put_mine
    assert_eq "A25 a link to prune that became a file: install exits 0" 0 "$?"
    assert_grep "$T_WORK/pty.out" 'not pruning' 'A25 install says it does not prune the changed target'
    if [ -f "$f" ] && [ ! -L "$f" ] && grep -qx mine "$f"; then _pass "A25 the file that replaced the link is untouched"
    else _hardfail "A25 the file that replaced the link was removed or changed"; fi
    assert_no_grep "$man" 't-gone' 'A25 its manifest row is gone'
    __s6_gone_link || _hardfail "A25 manifest link setup"
    s6_pty_install "$S6_H" __s6_nothing
    assert_eq "A25 an unchanged link to prune: install exits 0" 0 "$?"
    assert_absent "$f"
    assert_no_grep "$man" 't-gone' 'A25 the pruned link left the manifest'
}

check_a26() {
    local bare=/tmp/a26-remote.git work=/tmp/a26-work h head rc
    group "A26 update"
    h=$(t_acct a26) || { _hardfail "A26 account"; return; }
    rm -rf "$h/.dotfiles" "$bare" "$work"
    if ! t_git clone -q --bare "$T_SNAP" "$bare" || ! t_git clone -q "$bare" "$h/.dotfiles" ||
        ! t_git clone -q "$bare" "$work"; then
        _hardfail "A26 remote setup"
        return
    fi
    s6_dot "$h" install --yes
    assert_eq "A26 install exits 0" 0 "$?"

    mkdir -p "$work/.config/t-a26"
    printf 'added\n' >"$work/.config/t-a26/added.conf"
    t_git -C "$work" add -f .config/t-a26/added.conf && t_git -C "$work" commit -qm 'add a file' &&
        t_git -C "$work" push -q origin HEAD
    s6_dot "$h" update --yes
    assert_eq "A26 update exits 0" 0 "$?"
    assert_rel_link "$h/.config/t-a26/added.conf" "$h/.dotfiles/.config/t-a26/added.conf"

    t_git -C "$work" rm -q .config/t-a26/added.conf && t_git -C "$work" commit -qm 'remove it' &&
        t_git -C "$work" push -q origin HEAD
    s6_dot "$h" update --yes
    assert_eq "A26 update after a deletion exits 0" 0 "$?"
    assert_absent "$h/.config/t-a26/added.conf"

    printf 'remote change\n' >>"$work/README.md"
    t_git -C "$work" commit -qam 'touch README' && t_git -C "$work" push -q origin HEAD
    printf 'local change\n' >>"$h/.dotfiles/README.md"
    head=$(t_git -C "$h/.dotfiles" rev-parse HEAD)
    s6_dot "$h" update --yes
    rc=$?
    if [ "$rc" != 0 ]; then _pass "A26 a local modification stops the merge (exit $rc)"
    else _hardfail "A26 update merged over a local modification"; fi
    assert_grep "$T_WORK/last.out" 'README\.md' 'A26 the blocking file is listed'
    assert_eq "A26 HEAD unchanged" "$head" "$(t_git -C "$h/.dotfiles" rev-parse HEAD)"
    t_git -C "$h/.dotfiles" checkout -q -- README.md
    s6_dot "$h" update --yes
    assert_eq "A26 update after reverting the local change exits 0" 0 "$?"

    printf 'if then\n' >>"$work/.config/bash/aliases.bash"
    t_git -C "$work" commit -qam 'break aliases.bash' && t_git -C "$work" push -q origin HEAD
    head=$(t_git -C "$h/.dotfiles" rev-parse HEAD)
    s6_dot "$h" update --yes
    rc=$?
    if [ "$rc" != 0 ]; then _pass "A26 a syntax error in an incoming shell file aborts (exit $rc)"
    else _hardfail "A26 update merged a shell file with a syntax error"; fi
    assert_grep "$T_WORK/last.out" 'aliases\.bash' 'A26 the broken file is named'
    assert_eq "A26 HEAD unchanged by the aborted update" "$head" "$(t_git -C "$h/.dotfiles" rev-parse HEAD)"
}

check_a27() {
    local h m out=$T_WORK/a27-status.out
    group "A27 status warnings, read-only"
    h=$(t_acct a27) || { _hardfail "A27 account"; return; }
    mkdir -p "$h/.config/kanata"
    printf 'local kanata\n' >"$h/.config/kanata/tenkeyless.key"
    s6_dot "$h" install --keep-all
    assert_eq "A27 install --keep-all exits 0" 0 "$?"
    mkdir -p "$h/.claude/skills" "$h/.local/state/fnm_multishells/111_1" "$h/.local/state/fnm_multishells/222_2"
    ln -s /nonexistent/bell-bash/skills/bell "$h/.claude/skills/bell"
    printf '%s\n' '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"bell-send done"}]}]}}' \
        >"$h/.claude/settings.json"
    printf 'alias claude=claude-auto\n' >>"$h/.bashrc"
    printf 'legacy\n' >"$h/.bashrc.common"
    m=$(t_marker)
    (t_home "$h"; t_env XDG_DATA_HOME="$h/.data-moved" XDG_CACHE_HOME=relative/cache "$T_REPO/bin/dotfiles" status) \
        </dev/null >"$out" 2>&1
    assert_grep "$out" 'skills/bell' 'A27 leftover skill link'
    assert_grep "$out" 'settings\.json' 'A27 bell hooks in ~/.claude/settings.json'
    assert_grep "$out" 'alias claude' 'A27 alias claude= in ~/.bashrc'
    assert_grep "$out" 'tenkeyless\.key' 'A27 kept file'
    assert_grep "$out" 'XDG_DATA_HOME' 'A27 XDG drift'
    assert_grep "$out" 'XDG_CACHE_HOME' 'A27 relative XDG value'
    assert_grep "$out" '\.bashrc\.common' 'A27 legacy leftover'
    assert_grep "$out" 'fnm_multishells' 'A27 multishell dirs under the state fallback'
    assert_grep "$out" '(^|[^0-9])2([^0-9]|$).*fnm_multishells|fnm_multishells.*(^|[^0-9])2([^0-9]|$)' \
        'A27 the multishell dir count'
    assert_empty "A27 status changed nothing" "$(t_changed "$m" "$h")"
    assert_file "$h/.local/state/fnm_multishells/111_1"
}

check_a28() {
    local h m
    group "A28 a config dir that is a link to elsewhere"
    h=$(t_acct a28) || { _hardfail "A28 account"; return; }
    mkdir -p "$T_WORK/other-nvim" "$h/.config"
    ln -s "$T_WORK/other-nvim" "$h/.config/nvim"
    m=$(t_marker)
    s6_dot "$h" install --yes
    assert_eq "A28 install stops with exit 5" 5 "$?"
    assert_grep "$T_WORK/last.out" '\.config/nvim' 'A28 the link is named'
    assert_empty "A28 nothing changed" "$(t_changed "$m" "$h")"
    assert_empty "A28 nothing written into the link target" "$(ls -A "$T_WORK/other-nvim")"

    # A config dir or ~/.local/bin that leads into the checkout: linking
    # there would replace tracked files with links to themselves.
    h=$(t_acct a28-self) || { _hardfail "A28 account"; return; }
    t_git -C "$h/.dotfiles" status --porcelain >"$T_WORK/a28-self.status" 2>&1
    s6_a28_links "$h" >"$T_WORK/a28-self.links"
    rm -rf "$h/.config"
    ln -s .dotfiles/.config "$h/.config"
    m=$(t_marker)
    s6_dot "$h" install --keep-all
    assert_eq "A28 ~/.config -> .dotfiles/.config: install stops with exit 5" 5 "$?"
    assert_grep "$T_WORK/last.out" 'inside this checkout' 'A28 install says the target is inside the checkout'
    s6_a28_unchanged "$h" "$m" ".config linked into the checkout"
    rm -f "$h/.config"
    m=$(t_marker)
    s6_dotenv "$h" XDG_CONFIG_HOME="$h/.dotfiles/.config" install --replace-all
    assert_eq "A28 XDG_CONFIG_HOME inside the checkout: install stops with exit 5" 5 "$?"
    s6_a28_unchanged "$h" "$m" "XDG_CONFIG_HOME inside the checkout"
    mkdir -p "$h/.local"
    [ ! -e "$h/.local/bin" ] || mv "$h/.local/bin" "$h/.local/bin.aside"
    ln -s ../.dotfiles/bin "$h/.local/bin"
    m=$(t_marker)
    s6_dot "$h" install --replace-all
    assert_eq "A28 ~/.local/bin -> ../.dotfiles/bin: install stops with exit 5" 5 "$?"
    s6_a28_unchanged "$h" "$m" ".local/bin linked into the checkout"
    if [ -f "$h/.dotfiles/bin/dotfiles" ] && [ ! -L "$h/.dotfiles/bin/dotfiles" ]; then
        _pass "A28 the checkout's bin/dotfiles is still a regular file"
    else
        _hardfail "A28 the checkout's bin/dotfiles was replaced"
    fi
}

s6_a28_links() { find "$1/.dotfiles" -path "$1/.dotfiles/.git" -prune -o -type l -print | sort; }

# s6_a28_unchanged HOME MARKER LABEL — the checkout has the git status and
# the symlinks recorded before, and nothing in HOME is newer than MARKER.
s6_a28_unchanged() {
    assert_empty "A28 $3: the checkout's git status is unchanged" \
        "$(t_git -C "$1/.dotfiles" status --porcelain 2>&1 | diff "$T_WORK/a28-self.status" -)"
    assert_empty "A28 $3: the checkout has the same symlinks" \
        "$(s6_a28_links "$1" | diff "$T_WORK/a28-self.links" -)"
    assert_empty "A28 $3: nothing changed" "$(t_changed "$2" "$1")"
}

# --- dotfiles migrate -----------------------------------------------------

# A first `migrate tools` run that stopped after it recorded node.pending:
# the next run finishes the node move from the marker. The account gets a
# copy of the image's fnm (an LTS default and node 20).
check_mg_node() {
    local h fd mark d v='' w='' def rc
    group "A23 migrate tools finishes an interrupted node move"
    h=$(t_acct mg-node) || { _hardfail "A23 account"; return; }
    fd=$h/.local/share/fnm
    mark=$h/.local/state/dotfiles/migrate/node.pending
    mkdir -p "$h/.local/opt" "$h/.local/share" "${mark%/*}"
    if ! cp -a "$HOME/.local/opt/fnm" "$h/.local/opt/" || ! cp -a "$HOME/.local/share/fnm" "$h/.local/share/"; then
        _hardfail "A23 copy of the image's fnm"
        return
    fi
    # The copied aliases name the image account's paths.
    for d in "$fd"/aliases/*; do
        def=$(readlink "$d")
        ln -sfn "${def/#"$HOME"\//$h/}" "$d"
    done
    def=$(readlink -f "$fd/aliases/default")
    for d in "$fd"/node-versions/*/; do
        d=${d%/}
        if [ "$(readlink -f "$d/installation")" = "$def" ]; then w=${d##*/}; else v=${d##*/}; fi
    done
    if [ -z "$v" ] || [ -z "$w" ]; then
        _hardfail "A23 two fnm node versions, one of them the default (default '$def')"
        return
    fi

    printf '%s\n' "$v" >"$mark"
    s6_dot "$h" migrate tools --yes
    rc=$?
    assert_eq "A23 migrate tools with node.pending ($v) exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_grep "$T_WORK/last.out" "^NODE finish moving node $v from nvm to fnm" 'A23 migrate tools resumes the node move'
    assert_eq "A23 the fnm default is the marker's version" "$(readlink -f "$fd/node-versions/$v/installation")" \
        "$(readlink -f "$fd/aliases/default")"
    assert_absent "$mark"
    s6_dot "$h" migrate tools --dry-run
    assert_grep "$T_WORK/last.out" '^Nothing to relocate\.$' 'A23 a finished node move leaves nothing to relocate'

    printf '%s\n' "$v" t-no-such-pkg-zz@0.0.0 >"$mark"
    s6_dotenv "$h" npm_config_fetch_retries=0 migrate tools --yes
    assert_eq "A23 a failed npm install -g fails migrate tools (exit 1)" 1 "$?"
    assert_grep "$T_WORK/last.out" "npm install -g failed; re-run 'dotfiles migrate tools'" \
        'A23 migrate tools says to re-run it'
    assert_file "$mark"
    s6_dot "$h" migrate tools --dry-run
    assert_grep "$T_WORK/last.out" '^NODE finish moving node' 'A23 the marker keeps the node move pending'
    s6_dot "$h" bootstrap user --only fnm
    assert_eq "A23 bootstrap user refuses while the node move is pending (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.out" 'node\.pending' 'A23 bootstrap user names node.pending'

    # A default the user picked since is not the LTS default the first run set.
    ln -sfn "$fd/node-versions/$w/installation" "$fd/aliases/default"
    rm -f "$fd/aliases/lts-latest"
    printf '%s\n' "$v" >"$mark"
    s6_dot "$h" migrate tools --yes
    assert_eq "A23 a user-chosen fnm default: migrate tools exits 0" 0 "$?"
    assert_grep "$T_WORK/last.out" 'left as it is' 'A23 migrate tools warns that it leaves the chosen default'
    assert_eq "A23 the user-chosen fnm default stays" "$(readlink -f "$fd/node-versions/$w/installation")" \
        "$(readlink -f "$fd/aliases/default")"
    assert_absent "$mark"
}

# As on a host whose first `migrate tools` set the LTS fnm default and then
# failed to move the nvm node: ~/.nvm and an fnm default exist, so only
# node.pending says the node move is unfinished. tldr is not on this
# account's PATH, so `bootstrap user --only tldr` installs nothing.
check_mg_node_gate() {
    local h mark rc
    group "A23 bootstrap user and uninstall-legacy wait for a pending node move"
    h=$(t_acct mg-node-gate) || { _hardfail "A23 account"; return; }
    mark=$h/.local/state/dotfiles/migrate/node.pending
    mkdir -p "${mark%/*}" "$h/.nvm" "$h/.local/share/fnm/aliases"
    ln -s ../node-versions/v24.15.0/installation "$h/.local/share/fnm/aliases/default"
    printf '%s\n' v24.21.0 semver@7.6.0 >"$mark"
    (t_home "$h"; t_dot bootstrap user --only tldr) </dev/null >"$T_WORK/last.out" 2>"$T_WORK/last.err"
    assert_eq "A23 bootstrap user refuses while node.pending names a version (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.err" \
        "migrate/node\.pending \(node v24\.21\.0 not moved to fnm yet; re-run 'dotfiles migrate tools'\)" \
        'A23 bootstrap user names the pending node move on stderr'
    assert_no_grep "$T_WORK/last.err" '\.nvm \(no fnm default' 'A23 the fnm default satisfies the ~/.nvm check'
    : >"$mark"
    s6_dot "$h" bootstrap user --only tldr
    rc=$?
    assert_eq "A23 an empty node.pending does not stop bootstrap user" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"

    printf '%s\n' v24.21.0 >"$mark"
    printf 'set -g mouse on\n' >"$h/.tmux.conf"
    s6_dot "$h" uninstall-legacy --dry-run
    assert_eq "A23 uninstall-legacy refuses while the node move is pending (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.out" \
        'not relocated yet: ~/\.local/state/dotfiles/migrate/node\.pending \(node v24\.21\.0' \
        'A23 uninstall-legacy names the pending node move'
    rm -f "$mark"
    s6_dot "$h" uninstall-legacy --dry-run
    rc=$?
    assert_eq "A23 without node.pending uninstall-legacy --dry-run exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_no_grep "$T_WORK/last.out" 'not relocated yet' 'A23 then uninstall-legacy finds nothing left to relocate'
}

# migrate refuses, before it moves anything, a data or config dir inside the
# checkout, as install does.
check_mg_targets() {
    local h m
    group "A28 migrate refuses a data or config dir inside the checkout"
    h=$(t_acct mg-targets) || { _hardfail "A28 account"; return; }
    mkdir -p "$h/.cargo/bin"
    m=$(t_marker)
    s6_dotenv "$h" XDG_DATA_HOME="$h/.dotfiles/.local/share" migrate tools --yes
    assert_eq "A28 migrate tools refuses a data dir inside the checkout (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.out" '\.local/share is inside this checkout' \
        'A28 migrate tools names the data dir inside the checkout'
    if [ -d "$h/.cargo" ] && [ ! -L "$h/.cargo" ]; then _pass "A28 migrate tools left ~/.cargo in place"
    else _hardfail "A28 migrate tools moved ~/.cargo despite the refusal"; fi
    assert_absent "$h/.dotfiles/.local/share/cargo"
    s6_dotenv "$h" XDG_CONFIG_HOME="$h/.dotfiles/.config" migrate all --yes
    assert_eq "A28 migrate all refuses a config dir inside the checkout (exit 5)" 5 "$?"
    assert_grep "$T_WORK/last.out" '\.config is inside this checkout' \
        'A28 migrate all names the config dir inside the checkout'
    assert_no_grep "$T_WORK/last.out" '^==> dotfiles tools' 'A28 migrate all refuses before running any step'
    assert_empty "A28 the refusals changed nothing" "$(t_changed "$m" "$h")"
    assert_empty "A28 the refusals left the checkout clean" "$(t_git -C "$h/.dotfiles" status --porcelain 2>&1)"
}

# A run that moved a dir but could not create its compat link: the next run
# creates the missing link, for the tools and for the checkout.
check_mg_relink() {
    local h shim=$T_WORK/mg-shim rc
    group "A23 migrate restores a compat link an earlier run failed to create"
    h=$(t_acct mg-link) || { _hardfail "A23 account"; return; }
    mkdir -p "$shim" "$h/.cargo/bin"
    # shellcheck disable=SC2016  # the shim expands them
    printf '%s\n' '#!/bin/bash' \
        'case ${!#} in */.cargo | */dotfiles) echo "injected ln failure" >&2; exit 1 ;; esac' \
        'exec /usr/bin/ln "$@"' >"$shim/ln"
    chmod 755 "$shim/ln"
    printf '#!/bin/sh\n' >"$h/.cargo/bin/cargo"
    chmod 755 "$h/.cargo/bin/cargo"
    s6_dotenv "$h" PATH="$shim:$BASE_PATH" migrate tools --yes
    assert_eq "A23 migrate tools whose ln fails exits 1" 1 "$?"
    assert_grep "$T_WORK/last.out" 'create it by hand: ln -s \.local/share/cargo' 'A23 it names the ln command to run'
    s6_dot "$h" migrate tools --yes
    rc=$?
    assert_eq "A23 the next migrate tools exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_grep "$T_WORK/last.out" '^LINK ~/\.cargo -> ' 'A23 the next migrate tools creates the missing link'
    assert_rel_link "$h/.cargo" "$h/.local/share/cargo"
    s6_dot "$h" migrate tools --dry-run
    assert_grep "$T_WORK/last.out" '^Nothing to relocate\.$' 'A23 then nothing is left to relocate'

    mv "$h/.dotfiles" "$h/dotfiles"
    (t_home "$h"; t_env PATH="$shim:$BASE_PATH" "$h/dotfiles/bin/dotfiles" migrate repo --yes) </dev/null \
        >"$T_WORK/last.out" 2>&1
    assert_eq "A23 migrate repo whose ln fails exits 1" 1 "$?"
    (t_home "$h"; t_env "$h/.dotfiles/bin/dotfiles" migrate repo --yes) </dev/null >"$T_WORK/last.out" 2>&1
    rc=$?
    assert_eq "A23 migrate repo from ~/.dotfiles exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$T_WORK/last.out"
    assert_grep "$T_WORK/last.out" '^LINK ~/dotfiles -> \.dotfiles' 'A23 it creates the missing ~/dotfiles link'
    assert_eq "A23 ~/dotfiles links to .dotfiles" .dotfiles "$(readlink "$h/dotfiles" 2>&1)"

    h=$(t_acct mg-none) || { _hardfail "A23 account"; return; }
    s6_dot "$h" migrate tools --dry-run
    assert_grep "$T_WORK/last.out" '^Nothing to relocate\.$' 'A23 no journal, no old dirs: nothing to relocate'
    s6_dot "$h" migrate repo --dry-run
    assert_grep "$T_WORK/last.out" 'nothing to rename' 'A23 no journal, no ~/dotfiles: nothing to rename'
}

# A shell on a terminal that started before the compat links may have the old
# dirs on PATH (its rc files add them after the start): cleanup keeps them
# until it ends. ~/.rustup stays while ~/.cargo does.
check_mg_old_shells() {
    local h tsrv=t-mg-old opid i
    group "A23 migrate cleanup waits for shells started before the migration"
    h=$(t_acct mg-shells) || { _hardfail "A23 account"; return; }
    mkdir -p "$h/.local/opt/fzf2" "$h/.local/share/cargo/bin" "$h/.local/share/rustup"
    tq -L "$tsrv" -f /dev/null new-session -d -s old -x 120 -y 30 -c "$h" \
        "env -i HOME=$h PATH=/usr/bin:/bin TERM=xterm bash --norc -i"
    opid=$(tq -L "$tsrv" display -p -t old: '#{pane_pid}' 2>/dev/null)
    if [ -z "$opid" ]; then
        _hardfail "A23 the old shell's tmux pane did not start"
        t_tmux_kill -L "$tsrv"
        return
    fi
    sleep 2
    (
        t_home "$h"
        REPO=$T_REPO
        # shellcheck source=lib/dotfiles/core.bash
        . "$T_REPO/lib/dotfiles/core.bash"
        __journal_begin migrate-tools
        for i in .fzf:.local/opt/fzf2 .cargo:.local/share/cargo .rustup:.local/share/rustup; do
            __journal symlink "$HOME/${i%%:*}" "${i#*:}" && ln -s "${i#*:}" "$HOME/${i%%:*}"
        done
        __journal_done
    )
    s6_dot "$h" migrate cleanup --dry-run
    cp "$T_WORK/last.out" "$T_WORK/mg-shells-busy.out"
    assert_grep "$T_WORK/mg-shells-busy.out" \
        "^STAY ~/\.cargo: shells started before the migration may have it on PATH \(pids ([0-9]+ )*$opid( [0-9]+)*\)" \
        'A23 cleanup keeps ~/.cargo for the old shell'
    assert_grep "$T_WORK/mg-shells-busy.out" '^STAY ~/\.rustup: ~/\.cargo stays' 'A23 cleanup keeps ~/.rustup with ~/.cargo'
    tq -L "$tsrv" kill-pane -t old:
    for ((i = 0; i < 40; i++)); do
        [ -e "/proc/$opid" ] || break
        sleep 0.25
    done
    s6_dot "$h" migrate cleanup --dry-run
    assert_grep "$T_WORK/last.out" '^REMOVE compat link ~/\.cargo' 'A23 once the old shell ended cleanup removes ~/.cargo'
    assert_grep "$T_WORK/last.out" '^REMOVE compat link ~/\.rustup' 'A23 and ~/.rustup'
    t_tmux_kill -L "$tsrv"
}

# nvim-restore types into a pane only when the shell nvim was saved from
# holds the terminal at its prompt, and warns about a file the session opens
# that dotfiles moved since.
check_mg_restore() {
    local h tsrv=t-mg-restore tsock pa pb ppa ppb i dir sess got=$T_WORK/mg-got rows
    group "A23 migrate nvim-restore checks the pane before it types"
    h=$(t_acct mg-restore) || { _hardfail "A23 account"; return; }
    tsock=/tmp/tmux-$(id -u)/$tsrv
    tq -L "$tsrv" -f /dev/null new-session -d -s r -x 120 -y 30 -c "$h" \
        "env -i HOME=$h PATH=/usr/bin:/bin TERM=xterm bash --norc -i"
    pa=$(tq -L "$tsrv" display -p -t r: '#{pane_id}' 2>/dev/null)
    pb=$(tq -L "$tsrv" new-window -d -P -F '#{pane_id}' -c "$h" -t r: \
        "env -i HOME=$h PATH=/usr/bin:/bin TERM=xterm bash --norc -i" 2>/dev/null)
    if [ -z "$pa" ] || [ -z "$pb" ] || ! t_pane_run -L "$tsrv" "$pa" "$T_WORK/mg-ready-a" ':' 60 ||
        ! t_pane_run -L "$tsrv" "$pb" "$T_WORK/mg-ready-b" ':' 60; then
        _hardfail "A23 the panes for nvim-restore did not start"
        t_tmux_kill -L "$tsrv"
        return
    fi
    ppa=$(tq -L "$tsrv" display -p -t "$pa" '#{pane_pid}')
    ppb=$(tq -L "$tsrv" display -p -t "$pb" '#{pane_pid}')
    # Pane A's shell runs a program that would read whatever is typed.
    t_pane_send -L "$tsrv" "$pa" "bash -c 'read -r l; printf %s \"\$l\" >$got; sleep 30'"
    for ((i = 0; i < 40; i++)); do
        [ "$(ps -o tpgid= -p "$ppa" | tr -d ' ')" = "$ppa" ] || break
        sleep 0.25
    done
    dir=$h/.local/state/dotfiles/migrate
    sess=$dir/nvim-t.vim
    mkdir -p "$dir"
    printf 'return {}\n' >"$h/.t-gone.lua"
    (cd "$h" && env -i HOME="$h" PATH="$BASE_PATH" TERM=xterm "$HOME/.local/bin/nvim" --headless --clean \
        "$h/.t-gone.lua" "+mksession! $sess" +qa) >"$T_WORK/mg-session.log" 2>&1
    (
        t_home "$h"
        REPO=$T_REPO
        # shellcheck source=lib/dotfiles/core.bash
        . "$T_REPO/lib/dotfiles/core.bash"
        __backup_move "$HOME/.t-gone.lua" >/dev/null
    )
    rows=$(printf '%s\t%s\t%s\t%s\t%s\n' "$tsock" "$pa" "$h" "$sess" "$ppa" "$tsock" "$pb" "$h" "$sess" 999999)
    printf '%s\n%s\t%s\t%s\t%s\t%s\n' "$rows" "$tsock" "$pb" "$h" "$sess" "$ppb" >"$dir/nvim.tsv"
    s6_dot "$h" migrate nvim-restore --yes
    cp "$T_WORK/last.out" "$T_WORK/mg-restore.out"
    # The pane is named <socket basename>:<pane id>; the -L name is that basename.
    assert_grep "$T_WORK/mg-restore.out" "^SKIP pane $tsrv:$pa: a program its shell started holds the terminal" \
        'A23 nvim-restore skips a pane whose shell runs a program'
    assert_grep "$T_WORK/mg-restore.out" "^SKIP pane $tsrv:$pb: it runs another shell" \
        'A23 nvim-restore skips a pane whose shell is not the saved one'
    assert_grep "$T_WORK/mg-restore.out" "^restored pane $tsrv:$pb\$" 'A23 nvim-restore restores the pane of the saved shell'
    assert_grep "$T_WORK/mg-restore.out" "^WARN pane $tsrv:$pb: its session opens ~/\.t-gone\.lua, which dotfiles moved to" \
        'A23 nvim-restore warns about a file of the session that dotfiles moved'
    assert_no_grep "$T_WORK/mg-restore.out" '^(SKIP|RESTORE|DROP|WARN|restored) pane %' \
        'A23 nvim-restore names every pane with its tmux server'
    sleep 1
    assert_absent "$got"
    assert_eq "A23 nvim.tsv keeps the two skipped rows" "$rows" "$(cat "$dir/nvim.tsv" 2>&1)"
    t_tmux_kill -L "$tsrv"
}

if ! t_snapshot; then
    _hardfail "s6 snapshot of the checkout"
    assert_summary
    exit 1
fi
check_a15
check_a17
check_a17_entries
check_a17_uninstall_xdg
check_a17_path_in_use
check_a25
check_a25_recheck
check_a26
check_a27
check_a28
check_mg_node
check_mg_node_gate
check_mg_targets
check_mg_relink
check_mg_old_shells
check_mg_restore

assert_summary
