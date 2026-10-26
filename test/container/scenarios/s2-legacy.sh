#!/usr/bin/env bash
# s2-legacy: accounts with the old copied layout, installed from LEGACY_REF
# and given machine sections, debris and old state, go through
# `uninstall-legacy` and `install` (DD §7, PLAN C8, A18). Each variant is its
# own account under /tmp/accts:
#   a  wezterm entry with the two common-loader lines
#   b  monolithic wezterm entry, marker-less ~/.gitconfig and ~/.tmux.conf
#   c  a checkout whose HEAD and main hold the new layout
#   d  a shallow clone, so nothing can be matched against history (UNKNOWN)
#   e  a machine section shaped like a real host's: the bell/noti installer
#      blocks with that host's values, a guarded bell_skip line, a PATH line
#      that puts ~/.local/bin first
# Accounts i1 and i2 are like a; their first apply fails early (moving
# ~/.tmux.conf) or late (moving debris), and a plain re-run must finish it.
# Variant a is applied under umask 002; c first gets a dry run with an edited
# copy of the old ~/.local/bin/noti.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s2-legacy

LEG=$T_FIX/legacy

# Per machine-section fixture: the lines uninstall-legacy must drop from the
# migrated text and the ones it must keep (fixed strings), and the values a
# new shell gets for BELL_BASH_THRESHOLD, BELL_BASH_BACKENDS and NOTI_WEBHOOK.
S2_BASH_REMOVED=('>>> bell-bash >>>' '>>> noti-bash >>>' 'BELL_BASH_HOME' '/.bell-bash' '/.noti-bash' \
    'bell_skip add' 'export PATH="$HOME/.local/bin:$PATH"' 'export PATH="$HOME/.cargo/bin:$PATH"' \
    '.cargo/env' 'NVM_DIR' 'alias claude=' 'modern grep/find' 't-note-dropped')
S2_BASH_KEPT=('export BELL_BASH_THRESHOLD=30' "export BELL_BASH_BACKENDS='bel,notify-send,webhook'" \
    'export NOTI_WEBHOOK="https://hooks.example.invalid/t-s2"' 'claude-bsp' 'Xilinx' 'minicom' \
    'BUN_INSTALL' 'FZF_BASE' 'petalinux-run' '/opt/t-tools/bin' 'HISTFILESIZE=2000' \
    '# t-note-kept: explains the next two lines' 'export T_NOTE_KEPT=1')
S2_BASH_VALUES=(30 'bel,notify-send,webhook' 'https://hooks.example.invalid/t-s2')
S2_HOST_REMOVED=('>>> bell-bash >>>' '>>> noti-bash >>>' '/.bell-bash' '/.noti-bash' 'bell_skip add' \
    "# Skip fzf's interactive widgets from bell auto-triggers.")
S2_HOST_KEPT=('export BELL_BASH_THRESHOLD=5' "export BELL_BASH_BACKENDS='bel,webhook'" \
    'export PATH=~/.local/usr/bin:~/.local/bin:~/.local/sbin:$PATH' 'claude-bsp' 'function claude() {' \
    'source /tools/Xilinx/2025.2.1/Vitis/settings64.sh' 'export MINICOM="-c on"' \
    'run_petalinux_in_docker petalinux-build' 'mkdir -p /tmp/$USER/' 'export BUN_INSTALL="$HOME/.bun"')
S2_HOST_VALUES=(5 'bel,webhook' '')

s2_legacy_checkout() {
    [ -d /tmp/legacy/.git ] && return 0
    t_git clone -q --no-hardlinks "$T_REPO" /tmp/legacy &&
        t_git -C /tmp/legacy checkout -q "$LEGACY_REF"
}

# s2_account VARIANT — sets up the legacy account; prints its home.
s2_account() {
    local v=$1 h=/tmp/accts/s2$1 kind p
    mkdir -p "$h" && cp -a /etc/skel/. "$h/" || return 1
    case $v in
        c) t_git clone -q "$T_SNAP" "$h/.dotfiles" && t_git -C "$h/.dotfiles" branch -f main HEAD ;;
        d) t_git clone -q --depth 1 "file://$T_SNAP" "$h/.dotfiles" ;;
        *) cp -a "$T_REPO" "$h/.dotfiles" ;;
    esac || return 1
    (t_home "$h"; t_env /tmp/legacy/install.sh --dest "$h") >"$T_WORK/s2$v-legacy-install.log" 2>&1 ||
        return 1

    if [ "$v" = e ]; then
        sed "s|@HOME@|$h|g" "$LEG/bashrc-section-host.bash" >>"$h/.bashrc"
    else
        cat "$LEG/bashrc-section.bash" >>"$h/.bashrc"
    fi
    chmod 600 "$h/.bashrc"
    if [ "$v" = b ]; then
        cp "$LEG/gitconfig-nomarker" "$h/.gitconfig"
        cp "$LEG/tmux-nomarker.conf" "$h/.tmux.conf"
        cp "$LEG/wezterm-monolithic.lua" "$h/.wezterm.lua"
    else
        cat "$LEG/gitconfig-section" >>"$h/.gitconfig"
        cat "$LEG/tmux-section.conf" >>"$h/.tmux.conf"
    fi
    seq -f 'echo hist-%g' 5000 >"$h/.bash_history"
    while IFS=$'\t' read -r kind p; do
        case $kind in
            f) mkdir -p "$(dirname "$h/$p")" && printf 'debris\n' >"$h/$p" ;;
            d) mkdir -p "$h/$p" && printf 'debris\n' >"$h/$p/file" ;;
        esac
    done <"$LEG/debris.tsv"
    printf 'not ours\n' >"$h/.claude.bak.x"
    mkdir -p "$h/.local/share/nvim/undo" "$h/.local/share/nvim/obsession"
    printf 'undo\n' >"$h/.local/share/nvim/undo/%tmp%t-s2.txt"
    printf '" session\n' >"$h/.local/share/nvim/obsession/-tmp-Session.vim"
    printf 'set bell-style none\n' >>"$h/.inputrc"
    printf 'https://t:secret@example.invalid\n' >"$h/.git-credentials"
    chmod 600 "$h/.git-credentials"
    # The clones where `migrate tools` puts them, and the noti copy old
    # accounts kept in ~/.local/bin (only a checkout with history knows it).
    mkdir -p "$h/.local/opt" &&
        cp -a "$HOME/.local/opt/bell-bash" "$HOME/.local/opt/noti-bash" "$h/.local/opt/" || return 1
    if [ "$v" != d ]; then
        mkdir -p "$h/.local/bin" &&
            t_git -C "$T_REPO" cat-file blob "$T_OLD_NOTI" >"$h/.local/bin/noti" &&
            chmod 755 "$h/.local/bin/noti" || return 1
    fi
    printf '%s\n' "$h"
}

# Every file or link of the inventory is in place unchanged, in the backup
# dir, or at its migration destination: nothing was deleted.
s2_nothing_deleted() {
    local h=$1 p kind val c missing=
    while IFS=$'\t' read -r p kind val; do
        t_same "$h/$p" "$kind" "$val" && continue
        for c in "$h"/.local/state/dotfiles/backup/*/"$p"; do
            t_same "$c" "$kind" "$val" && continue 2
        done
        case $p in
            .git-credentials) t_same "$h/.config/git/credentials" "$kind" "$val" && continue ;;
            .wezterm.lua) t_same "$h/.config/wezterm/wezterm.lua" "$kind" "$val" && continue ;;
        esac
        missing+="$p"$'\n'
    done <"$2"
    assert_empty "A18 every old file is in place, in the backup dir or at its destination" "$missing"
}

# The A18 checks after the apply, in a subshell with HOME set to the account.
s2_after() {
    local v=$1 hf n s k f b=$HOME/.local/state/dotfiles/backup p kind o=$T_WORK/s2$1
    local -a kept removed want
    if [ "$v" = e ]; then
        kept=("${S2_HOST_KEPT[@]}") removed=("${S2_HOST_REMOVED[@]}") want=("${S2_HOST_VALUES[@]}")
    else
        kept=("${S2_BASH_KEPT[@]}") removed=("${S2_BASH_REMOVED[@]}") want=("${S2_BASH_VALUES[@]}")
    fi
    if [ "$v" = b ]; then check_layout no-wezterm; else check_layout; fi
    group "A18 s2$v after uninstall-legacy"
    for f in "$HOME/.bashrc" "$T_CFG/git/config" "$T_CFG/tmux/tmux.conf"; do
        assert_no_grep "$f" '^# =+$' "no '# ====' separator in $f"
    done
    s=$(sed -n '/^# <<< dotfiles <<<$/,$p' "$HOME/.bashrc")
    for k in "${kept[@]}"; do
        if grep -qF -- "$k" <<<"$s"; then _pass "A18 kept in the interactive local zone: $k"
        else _hardfail "A18 kept in the interactive local zone: $k"; fi
    done
    for k in "${removed[@]}"; do
        if grep -qF -- "$k" "$HOME/.bashrc"; then _hardfail "A18 remove-candidate still in ~/.bashrc: $k"
        else _pass "A18 remove-candidate dropped: $k"; fi
    done
    if [ "$v" = e ]; then
        assert_empty "A18 s2e no doubled blank line where lines were dropped" \
            "$(sed -n '/^# <<< dotfiles <<<$/,$p' "$HOME/.bashrc" | awk 'NR > 1 && p == "" && $0 == "" {print NR} {p = $0}')"
    fi
    assert_eq "A18 s2$v ~/.bashrc keeps mode 600" 600 "$(stat -c %a "$HOME/.bashrc" 2>&1)"
    if [ "$v" = b ]; then
        assert_grep "$T_CFG/tmux/tmux.conf" "@t-nomarker" 'A18 marker-less ~/.tmux.conf content migrated'
        assert_grep "$T_CFG/git/config" 'Nomarker Tester' 'A18 marker-less ~/.gitconfig content migrated'
    else
        assert_grep "$T_CFG/tmux/tmux.conf" '@t-machine' 'A18 tmux machine section migrated'
        assert_grep "$T_CFG/tmux/tmux.conf" 'M-t' 'A18 tmux machine binding migrated'
        assert_no_grep "$T_CFG/tmux/tmux.conf" '>>> bell-bash >>>' 'A18 tmux bell-bash block dropped'
        assert_grep "$T_CFG/git/config" 'Legacy Tester' 'A18 git machine section migrated'
        assert_grep "$T_CFG/git/config" '/srv/t-shared-repo' 'A18 git safe.directory migrated'
    fi
    assert_no_grep "$T_CFG/tmux/tmux.conf" 'source-file ~/\.tmux\.common\.conf' 'A18 old common source-file dropped'
    assert_no_grep "$T_CFG/git/config" '\.gitconfig\.common' 'A18 old common include dropped'

    hf=$T_STATE/bash/history
    n=$(wc -l <"$hf" 2>/dev/null)
    assert_eq "A18 history moved into the new HISTFILE" 5000 "${n:-0}"
    assert_absent "$HOME/.bash_history"
    if [ "$v" != d ]; then
        assert_exit0 "A18 ~/.profile is the skel copy" -- cmp -s "$HOME/.profile" /etc/skel/.profile
    fi
    assert_output_eq "A18 a login shell reads ~/.bashrc (env.bash)" "$T_DATA/cargo" -- \
        t_env bash -lc 'printf %s "$CARGO_HOME"'
    while IFS=$'\t' read -r kind p; do
        case $kind in f | d) ;; *) continue ;; esac
        assert_absent "$HOME/$p"
        if compgen -G "$b/*/$p" >/dev/null; then _pass "A18 debris $p is in the backup dir"
        else _hardfail "A18 debris $p is not in the backup dir"; fi
    done <"$LEG/debris.tsv"
    assert_exit0 "A18 ~/.claude.bak.x untouched" -- grep -qx 'not ours' "$HOME/.claude.bak.x"
    assert_rel_link "$T_CFG/nvim/coc-settings.json" "$T_REPO/.config/vim/coc-settings.json"
    if compgen -G "$b/*/.config/nvim/coc-settings.json" >/dev/null &&
        [ -L "$(compgen -G "$b/*/.config/nvim/coc-settings.json" | head -n 1)" ]; then
        _pass "A18 the old coc-settings.json link is in the backup dir"
    else
        _hardfail "A18 the old coc-settings.json link is not in the backup dir"
    fi
    assert_file "$T_STATE/nvim/undo/%tmp%t-s2.txt"
    assert_file "$T_STATE/nvim/obsession/-tmp-Session.vim"
    assert_absent "$HOME/.vim"
    assert_absent "$HOME/.tmux"
    assert_absent "$HOME/.git-credentials"
    assert_exit0 "A18 ~/.git-credentials moved to ~/.config/git/credentials" -- \
        grep -qx 'https://t:secret@example.invalid' "$T_CFG/git/credentials"
    case $v in
        b)
            assert_exit0 "A18 monolithic wezterm.lua moved unchanged" -- \
                cmp -s "$LEG/wezterm-monolithic.lua" "$T_CFG/wezterm/wezterm.lua"
            assert_grep "$T_STATE/dotfiles/blocks.tsv" 'wezterm\.lua.*unmanaged' 'A18 wezterm entry recorded unmanaged'
            ;;
        *)
            assert_eq "A18 wezterm.lua has exactly one dofile" 1 "$(grep -c 'dofile' "$T_CFG/wezterm/wezterm.lua")"
            assert_exit0 "A18 migrated wezterm.lua loads with the stub" -- \
                lua5.4 "$T_FIX/wezterm/load.lua" "$T_FIX/wezterm" "$T_CFG/wezterm" "$HOME" "$T_CFG/wezterm/wezterm.lua"
            ;;
    esac

    if [ "$v" != d ]; then
        assert_absent "$HOME/.local/bin/noti"
        if compgen -G "$b/*/.local/bin/noti" >/dev/null; then _pass "A18 the old ~/.local/bin/noti is in the backup dir"
        else _hardfail "A18 the old ~/.local/bin/noti is not in the backup dir"; fi
    fi
    # A new login shell, run last: the generic section's HISTFILESIZE=2000
    # truncates the history file. The skel ~/.profile puts ~/.local/bin first,
    # after ~/.bashrc, so an old noti there would shadow the clone's.
    printf '%s\n' "printf '%s\n' \"\$BELL_BASH_THRESHOLD\" \"\$BELL_BASH_BACKENDS\" \"\${NOTI_WEBHOOK-}\" \"\$(type -P noti)\" >$o/values" \
        >"$o/values.cmds"
    t_ishell -l 120 "$o/values.cmds"
    assert_eq "A18 s2$v a new shell gets the machine's BELL_BASH_THRESHOLD" "${want[0]}" "$(sed -n 1p "$o/values" 2>/dev/null)"
    assert_eq "A18 s2$v a new shell gets the machine's BELL_BASH_BACKENDS" "${want[1]}" "$(sed -n 2p "$o/values" 2>/dev/null)"
    assert_eq "A18 s2$v a new shell gets the machine's NOTI_WEBHOOK" "${want[2]}" "$(sed -n 3p "$o/values" 2>/dev/null)"
    assert_eq "A18 s2$v a new login shell runs noti from the clone" "$HOME/.local/opt/noti-bash/bin/noti" \
        "$(sed -n 4p "$o/values" 2>/dev/null)"
}

s2_run() {
    local v=$1 h o=$T_WORK/s2$1 m rc k n
    group "s2$v: legacy account"
    mkdir -p "$o"
    if ! h=$(s2_account "$v"); then
        _hardfail "s2$v: legacy account setup"
        __assert_show "$T_WORK/s2$v-legacy-install.log"
        return
    fi
    t_inventory "$h" "$o/before.tsv"

    if [ "$v" = c ]; then
        # A copy of the old noti edited by hand matches no repo version: it
        # stays where it is, with a warning.
        cp -p "$h/.local/bin/noti" "$o/noti.orig"
        printf '# edited\n' >>"$h/.local/bin/noti"
        (t_home "$h"; t_dot uninstall-legacy --dry-run) </dev/null >"$o/noti-edited.out" 2>&1
        assert_grep "$o/noti-edited.out" \
            "^WARN ~/\.local/bin/noti matches no version of the repo's \.local/bin/noti, so it stays" \
            'A18 s2c an edited ~/.local/bin/noti stays, with a warning'
        assert_no_grep "$o/noti-edited.out" '^MOVE ~/\.local/bin/noti' 'A18 s2c an edited ~/.local/bin/noti is not moved'
        cat "$o/noti.orig" >"$h/.local/bin/noti"
    fi

    m=$(t_marker)
    (t_home "$h"; t_dot uninstall-legacy) </dev/null >"$o/preview.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v preview without a TTY exits 3" 3 "$rc"
    assert_empty "A18 s2$v preview changed nothing" "$(t_changed "$m" "$h")"
    for k in MOVE DEBRIS MIGRATE REMOVE-CANDIDATE FIX-SUGGESTION KEEP; do
        assert_grep "$o/preview.out" "(^|[[:space:]])$k([[:space:]]|$)" "A18 s2$v preview lists $k"
    done
    case $v in
        a)
            assert_grep "$o/preview.out" '^REMOVE-CANDIDATE ~/\.bashrc:[0-9]+: export BELL_BASH_HOME=' \
                "A18 s2a preview drops the bell installer's BELL_BASH_HOME"
            assert_grep "$o/preview.out" '^FIX-SUGGESTION ~/\.bashrc:[0-9]+: export NOTI_WEBHOOK=.*noti/webhook' \
                'A18 s2a preview points NOTI_WEBHOOK to ~/.config/noti/webhook'
            ;;
        e)
            assert_grep "$o/preview.out" "^KEEP ~/\.bashrc:[0-9]+: export BELL_BASH_BACKENDS='bel,webhook'" \
                "A18 s2e preview keeps the host's BELL_BASH_BACKENDS"
            assert_grep "$o/preview.out" '^REMOVE-CANDIDATE ~/\.bashrc:[0-9]+: declare -F bell_skip' \
                'A18 s2e preview drops the guarded bell_skip line'
            assert_grep "$o/preview.out" \
                "^REMOVE-CANDIDATE ~/\.bashrc:[0-9]+: # Skip fzf's interactive widgets from bell auto-triggers\.  \[common\.bash already adds these bell_skip entries\]\$" \
                'A18 s2e preview drops the comment of the dropped bell_skip line'
            ;;
    esac
    assert_exit0 "A18 s2$v REMOVE-CANDIDATE lines of ~/.bashrc are in line order" -- \
        sh -c "grep '^REMOVE-CANDIDATE ~/\.bashrc:' '$o/preview.out' | cut -d: -f2 | sort -nc"
    if [ "$v" = d ]; then
        assert_grep "$o/preview.out" '(^|[[:space:]])UNKNOWN([[:space:]]|$)' "A18 s2$v preview lists UNKNOWN"
    else
        assert_grep "$o/preview.out" 'LOCALLY-EDITED.*\.inputrc' "A18 s2$v the edited ~/.inputrc is LOCALLY-EDITED"
    fi
    assert_no_grep "$o/preview.out" 'DEBRIS.*\.claude\.bak' "A18 s2$v ~/.claude.bak.x is not debris"

    m=$(t_marker)
    (t_home "$h"; t_dot uninstall-legacy --yes) </dev/null >"$o/apply-without-accept.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v apply without --accept-dropped-edits exits 3" 3 "$rc"
    assert_empty "A18 s2$v that changed nothing" "$(t_changed "$m" "$h")"

    # Under umask 002 the migrated ~/.bashrc must still keep the old file's
    # mode 600 (s2_account sets it): its machine section may hold secrets.
    (t_home "$h"; [ "$v" != a ] || umask 002; t_dot uninstall-legacy --yes --accept-dropped-edits) </dev/null \
        >"$o/apply.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v apply exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$o/apply.out"
    s2_nothing_deleted "$h" "$o/before.tsv"
    (t_home "$h"; s2_after "$v")

    (t_home "$h"; t_dot install --yes) </dev/null >"$o/install.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v install afterwards exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$o/install.out"
    assert_eq "A18 s2$v ~/.bashrc is still mode 600 after install" 600 "$(stat -c %a "$h/.bashrc" 2>&1)"
    if [ "$v" = b ]; then
        assert_exit0 "A18 s2b install left the unmanaged wezterm.lua alone" -- \
            cmp -s "$LEG/wezterm-monolithic.lua" "$h/.config/wezterm/wezterm.lua"
        (t_home "$h"; t_dot status) </dev/null >"$o/status.out" 2>&1
        assert_grep "$o/status.out" 'wezterm\.lua: recorded unmanaged' \
            'A18 s2b status reports wezterm.lua as recorded unmanaged'
    fi

    n=$(wc -l <"$h/.local/state/bash/history" 2>/dev/null)
    m=$(t_marker)
    (t_home "$h"; t_dot uninstall-legacy --yes --accept-dropped-edits) </dev/null >"$o/second.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v a second uninstall-legacy exits 0" 0 "$rc"
    assert_empty "A18 s2$v a second uninstall-legacy changes nothing" "$(t_changed "$m" "$h")"
    assert_eq "A18 s2$v history line count unchanged by the second run" "$n" \
        "$(wc -l <"$h/.local/state/bash/history" 2>/dev/null)"
}

# s2_resume NAME SUFFIX — an apply whose move of the path ending in SUFFIX
# fails (a mv stand-in first on PATH), then a plain re-run, which must finish
# the migration without merging a machine section twice.
s2_resume() {
    local v=$1 h o=$T_WORK/s2$1 rc m
    group "s2$v: an apply that fails moving *$2, then a re-run"
    mkdir -p "$o/shim"
    if ! h=$(s2_account "$v"); then
        _hardfail "s2$v: legacy account setup"
        __assert_show "$T_WORK/s2$v-legacy-install.log"
        return
    fi
    t_inventory "$h" "$o/before.tsv"
    install -m 755 "$T_FIX/bin/mv-fail" "$o/shim/mv"
    (t_home "$h"; t_env PATH="$o/shim:$BASE_PATH" T_MV_FAIL="$2" "$T_REPO/bin/dotfiles" \
        uninstall-legacy --yes --accept-dropped-edits) </dev/null >"$o/apply-failed.out" 2>&1
    rc=$?
    if [ "$rc" != 0 ] && grep -q 'injected mv failure' "$o/apply-failed.out"; then
        _pass "A18 s2$v the first apply stops at the failed move (exit $rc)"
    else
        _hardfail "A18 s2$v the first apply did not stop at the failed move (exit $rc)"
        __assert_show "$o/apply-failed.out"
    fi
    (t_home "$h"; t_dot uninstall-legacy --yes --accept-dropped-edits) </dev/null >"$o/apply.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v the re-run exits 0" 0 "$rc"
    [ "$rc" = 0 ] || __assert_show "$o/apply.out"
    s2_nothing_deleted "$h" "$o/before.tsv"
    assert_eq "A18 s2$v one [user] section in the git entry" 1 \
        "$(grep -c '^\[user\]' "$h/.config/git/config" 2>/dev/null)"
    assert_eq "A18 s2$v the tmux machine section is there once" 1 \
        "$(grep -c '@t-machine' "$h/.config/tmux/tmux.conf" 2>/dev/null)"
    assert_eq "A18 s2$v the bash machine section is there once" 1 \
        "$(grep -c 'HISTFILESIZE=2000' "$h/.bashrc" 2>/dev/null)"
    if [ "$v" = i1 ]; then
        # The first apply wrote the new entry files before it stopped.
        assert_grep "$o/apply.out" \
            '^MOVE ~/\.tmux\.conf \(its machine section is already in ~/\.config/tmux/tmux\.conf\)' \
            'A18 s2i1 the re-run only moves ~/.tmux.conf'
        assert_grep "$o/apply.out" '^MOVE ~/\.gitconfig \(its machine section is already in' \
            'A18 s2i1 the re-run only moves ~/.gitconfig'
        assert_no_grep "$o/apply.out" '^MIGRATE-MERGE ' 'A18 s2i1 the re-run merges no machine section'
        assert_no_grep "$o/apply.out" 'LOCALLY-EDITED ~/\.wezterm\.lua' \
            'A18 s2i1 the re-run does not take the migrated wezterm.lua for an edit'
    else
        # The old files that marked the layout are gone; the journal says so.
        assert_grep "$o/apply.out" '^WARN the last uninstall-legacy run did not finish' \
            "A18 s2$v the re-run says it completes the unfinished run"
    fi
    (t_home "$h"; s2_after "$v")
    m=$(t_marker)
    (t_home "$h"; t_dot uninstall-legacy --yes) </dev/null >"$o/third.out" 2>&1
    rc=$?
    assert_eq "A18 s2$v a third uninstall-legacy exits 0" 0 "$rc"
    assert_grep "$o/third.out" '^No old layout found; nothing to do\.$' "A18 s2$v a third run finds no old layout"
    assert_empty "A18 s2$v a third run changes nothing" "$(t_changed "$m" "$h")"
}

if [ -z "${LEGACY_REF:-}" ]; then
    _hardfail "LEGACY_REF is not set (test/run.sh passes it)"
    assert_summary
    exit 1
fi
if ! s2_legacy_checkout || ! t_snapshot; then
    _hardfail "s2 setup: legacy checkout at $LEGACY_REF or snapshot"
    assert_summary
    exit 1
fi
for v in a b c d e; do
    s2_run "$v"
done
s2_resume i1 /.tmux.conf
s2_resume i2 /.config/nvim/lua/.bak

assert_summary
