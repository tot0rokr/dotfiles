#!/usr/bin/env bash
# s5-live: live-migration rehearsal (DD §9, §11 scenario 5, PLAN C11, A23).
# An old copied layout (from LEGACY_REF) with old tool locations, the old
# noti copy in ~/.local/bin, a linked worktree of the checkout, two running
# tmux servers with the old TPM plugins (one is re-read with the new config
# before cleanup), idle shells, nvims (one with an old-layout file open), a
# long-running process and a fake claude (started in ~/dotfiles) is migrated
# step by step with the new code checked out at ~/dotfiles. Nothing the user
# runs is killed, old shells keep working through the compat links, and
# cleanup waits until they are gone, but not for a non-dumpable process or a
# zombie.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s5-live

OLD=$HOME/dotfiles
NEW=$HOME/.dotfiles
WT=$HOME/dotfiles-wt
O=$T_WORK/s5
FILES=/tmp/s5/files
SEMVER=7.6.0
COMPAT=(.cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash dotfiles)
# nvim undo file names encode the edited file's full path.
UNDO_OLD=${HOME//\//%}%dotfiles%README.md
UNDO_NEW=${HOME//\//%}%.dotfiles%README.md

# s5_tq SERVER ARGS... — tmux client for the default server or "other"
s5_tq() {
    local s=$1
    shift
    if [ "$s" = other ]; then tq -L other "$@"; else tq "$@"; fi
}

s5_send() {
    if [ "$1" = other ]; then t_pane_send -L other "$2" "$3"; else t_pane_send "$2" "$3"; fi
}

s5_run_in() {
    if [ "$1" = other ]; then t_pane_run -L other "$2" "$3" "$4" "${5:-60}"
    else t_pane_run "$2" "$3" "$4" "${5:-60}"; fi
}

s5_pane_pid() { s5_tq "$1" display -p -t "$2" '#{pane_pid}' 2>/dev/null; }
s5_pane_cmd() { s5_tq "$1" display -p -t "$2" '#{pane_current_command}' 2>/dev/null; }

# s5_at_prompt SERVER PANE — the pane's shell holds the terminal again. Not
# #{pane_current_command}: it is also "bash" while longrun.sh runs.
s5_at_prompt() {
    local pp fg
    pp=$(s5_pane_pid "$1" "$2")
    [ -n "$pp" ] || return 1
    fg=$(ps -o tpgid= -p "$pp")
    [ "${fg// /}" = "$pp" ]
}

# s5_show_panes — each remaining pane's processes and screen, for a failure
s5_show_panes() {
    local s p pp
    for s in default other; do
        for p in $(s5_tq "$s" list-panes -a -F '#{pane_id}' 2>/dev/null); do
            pp=$(s5_pane_pid "$s" "$p")
            printf '        %s pane %s (pid %s, command %s):\n' "$s" "$p" "$pp" "$(s5_pane_cmd "$s" "$p")"
            [ -z "$pp" ] || ps -o pid=,tpgid=,stat=,args= -p "$pp" --ppid "$pp" | sed 's/^/        | /'
            s5_tq "$s" capture-pane -p -t "$p" 2>/dev/null | grep -v '^[[:space:]~]*$' | sed 's/^/        | /'
        done
    done
}

# s5_wait_cmd SERVER PANE COMMAND — waits until COMMAND is the pane's foreground
s5_wait_cmd() {
    local i
    for ((i = 0; i < 120; i++)); do
        [ "$(s5_pane_cmd "$1" "$2")" = "$3" ] && return 0
        sleep 0.5
    done
    return 1
}

# s5_child PID NAME — the first child of PID named NAME
s5_child() { pgrep -P "$1" -x "$2" | head -n 1; }

# s5_editor_nvim PANE_PID — the nvim that git (a child of the pane shell)
# started as its editor. tmux names git as the pane's foreground command,
# since git leads the process group.
s5_editor_nvim() {
    local git
    git=$(s5_child "$1" git) && [ -n "$git" ] && s5_child "$git" nvim
}

# s5_new_window SERVER SESSION [DIR] — a new window (its shell in DIR); prints its pane
s5_new_window() {
    local c=()
    [ -z "${3:-}" ] || c=(-c "$3")
    s5_tq "$1" new-window -d -P -F '#{pane_id}' "${c[@]}" -t "$2:"
}

# s5_nvim_expr UI_PID EXPR — evaluates EXPR in the --embed server of that nvim
# over its RPC socket, as migrate does. The panes have no XDG_RUNTIME_DIR
# (t_env), so the socket is under /tmp/nvim.$USER.
s5_nvim_expr() {
    local k srv='' sock
    for k in $(pgrep -P "$1" -x nvim); do
        case " $(tr '\0' ' ' 2>/dev/null <"/proc/$k/cmdline")" in
            *' --embed '*) srv=$k; break ;;
        esac
    done
    [ -n "$srv" ] || return 1
    sock=$(compgen -G "/tmp/nvim.$T_USER/*/nvim.$srv.0" | head -n 1)
    [ -S "$sock" ] || return 1
    timeout 10 "/proc/$srv/exe" --clean --headless --server "$sock" --remote-expr "$2" </dev/null 2>/dev/null
}

# s5_nvim_start SERVER PANE COMMAND — runs COMMAND, which starts an nvim
# directly or as git's editor, in PANE and waits until coc's service in that
# nvim has started, the last of its startup work; sets S5_NV to its pid.
# One nvim at a time: of nvims started together on a cold cache, one has
# stopped at a startup error, and the migration's RPC calls (10 s timeouts)
# must not race a startup. The image has the coc extensions and the parsers,
# so no first-start install follows.
s5_nvim_start() {
    local pp end
    s5_send "$1" "$2" "$3"
    pp=$(s5_pane_pid "$1" "$2")
    end=$((SECONDS + 120))
    S5_NV=
    while [ "$SECONDS" -lt "$end" ]; do
        [ -n "$S5_NV" ] || S5_NV=$(s5_child "$pp" nvim)
        [ -n "$S5_NV" ] || S5_NV=$(s5_editor_nvim "$pp")
        if [ -n "$S5_NV" ] &&
            [ "$(s5_nvim_expr "$S5_NV" "get(g:, 'coc_service_initialized', 0)")" = 1 ]; then
            return 0
        fi
        sleep 0.5
    done
    printf 's5: no nvim with coc started in %s pane %s (nvim pid %s); its screen:\n' "$1" "$2" "${S5_NV:-none}"
    s5_tq "$1" capture-pane -p -t "$2" | grep -v '^[[:space:]~]*$' | sed 's/^/        | /'
    return 1
}

s5_setup() {
    local nodedir t i
    mkdir -p "$O" "$FILES" /tmp/s5/stash "$O/fakebin"
    # The new code at the legacy path, as after `git pull` in ~/dotfiles.
    mv "$NEW" "$OLD" || return 1
    T_REPO=$OLD
    t_git clone -q --no-hardlinks "$OLD" /tmp/legacy &&
        t_git -C /tmp/legacy checkout -q "$LEGACY_REF" || return 1
    t_env /tmp/legacy/install.sh --dest "$HOME" >"$O/legacy-install.log" 2>&1 || return 1
    # The noti copy the repo once shipped, still first on old PATHs, and a
    # linked worktree whose .git file names the checkout by its old path.
    t_git -C "$OLD" cat-file blob "$T_OLD_NOTI" >"$HOME/.local/bin/noti" &&
        chmod 755 "$HOME/.local/bin/noti" || return 1
    t_git -C "$OLD" worktree add -q --detach "$WT" >"$O/worktree-add.log" 2>&1 || return 1
    mkdir -p "$T_DATA/nvim/undo" &&
        printf 'undo\n' >"$T_DATA/nvim/undo/$UNDO_OLD" || return 1

    # The TPM plugins a real host has in ~/.tmux/plugins, which the old
    # servers load (tmux-cuecard's window-unlinked hook among them). The old
    # config's first start clones only TPM: the install_plugins it runs next
    # comes before TPM sets TMUX_PLUGIN_MANAGER_PATH and installs nothing. A
    # throwaway server runs it again once that is set.
    tq -L prep new-session -d -s prep >"$O/tmux-prep.log" 2>&1 || return 1
    for ((i = 0; i < 240; i++)); do
        tq -L prep show-environment -g TMUX_PLUGIN_MANAGER_PATH >/dev/null 2>&1 && break
        sleep 0.5
    done
    tq -L prep run-shell "$HOME/.tmux/plugins/tpm/bin/install_plugins" >>"$O/tmux-prep.log" 2>&1
    t_tmux_kill -L prep
    [ -f "$HOME/.tmux/plugins/tmux-cuecard/cuecard.tmux" ] || return 1

    # Tools where the old bootstrap put them. The full tier's real rustup and
    # cargo homes move back; the lite tier, which has none, gets fakes.
    mv "$HOME/.local/opt/fzf" "$HOME/.fzf" &&
        mv "$HOME/.local/opt/fzf-tab-completion" "$HOME/.fzf-tab-completion" &&
        mv "$HOME/.local/opt/bell-bash" "$HOME/.bell-bash" &&
        mv "$HOME/.local/opt/noti-bash" "$HOME/.noti-bash" || return 1
    for t in cargo rustup; do
        if [ -d "$T_DATA/$t" ]; then
            mv -T "$T_DATA/$t" "$HOME/.$t" || return 1
        fi
    done
    mkdir -p "$HOME/.cargo/bin" "$HOME/.rustup" || return 1
    for t in cargo eza; do
        [ -e "$HOME/.cargo/bin/$t" ] && continue
        printf '#!/bin/sh\necho "%s 0.0.0-legacy"\n' "$t" >"$HOME/.cargo/bin/$t" &&
            chmod 755 "$HOME/.cargo/bin/$t" || return 1
    done
    [ -e "$HOME/.rustup/settings.toml" ] ||
        printf 'default_toolchain = "legacy"\n' >"$HOME/.rustup/settings.toml" || return 1

    # node under nvm (the image's fnm default) with one global package.
    nodedir=$(readlink -f "$HOME/.local/share/fnm/aliases/default") || return 1
    NODE_V=$("$nodedir/bin/node" -v) || return 1
    mkdir -p "$HOME/.nvm/versions/node/$NODE_V" "$HOME/.nvm/alias"
    cp -a "$nodedir/." "$HOME/.nvm/versions/node/$NODE_V/" || return 1
    printf '%s\n' "$NODE_V" >"$HOME/.nvm/alias/default"
    cp "$T_FIX/legacy/nvm.sh" "$HOME/.nvm/nvm.sh"
    t_env PATH="$HOME/.nvm/versions/node/$NODE_V/bin:$BASE_PATH" npm_config_cache=/tmp/s5/npm-cache \
        npm install -g "semver@$SEMVER" >"$O/npm-legacy.log" 2>&1 || return 1
    # A legacy host has no fnm.
    mv "$HOME/.local/share/fnm" /tmp/s5/stash/fnm-data &&
        mv "$HOME/.local/opt/fnm" /tmp/s5/stash/fnm-opt &&
        mv "$HOME/.local/bin/fnm" /tmp/s5/stash/fnm-link || return 1

    install -m 755 "$T_FIX/bin/fake-claude" "$O/fakebin/claude"
    printf 'a\n' >"$FILES/a.txt"
    printf 'b\n' >"$FILES/b.txt"
    printf 'c\n' >"$FILES/c.txt"
    mkdir -p /tmp/s5/repo &&
        t_git -C /tmp/s5/repo init -q &&
        printf 'x\n' >/tmp/s5/repo/x &&
        t_git -C /tmp/s5/repo add x &&
        git -C /tmp/s5/repo config user.name tester &&
        git -C /tmp/s5/repo config user.email tester@example.invalid
}

s5_start_sessions() {
    local p
    t_tmux_start main || return 1
    t_tmux_start o -L other || return 1
    P_IDLE=$(s5_tq default list-panes -t main: -F '#{pane_id}' | head -n 1)
    P_OIDLE=$(s5_tq other list-panes -t o: -F '#{pane_id}' | head -n 1)
    P_ED=$(s5_new_window default main)
    P_MOD=$(s5_new_window default main)
    P_GIT=$(s5_new_window default main)
    P_LONG=$(s5_new_window default main)
    # As a Claude session working in the checkout: it keeps using that path.
    P_CLAUDE=$(s5_new_window default main "$OLD")
    P_OED=$(s5_new_window other o)
    for p in "$P_IDLE" "$P_ED" "$P_MOD" "$P_GIT" "$P_LONG" "$P_CLAUDE"; do
        s5_run_in default "$p" "$O/ready-${p#%}" ':' 180 || return 1
    done
    for p in "$P_OIDLE" "$P_OED"; do
        s5_run_in other "$p" "$O/ready-o${p#%}" ':' 180 || return 1
    done
    s5_send default "$P_LONG" "bash $T_FIX/longrun.sh"
    s5_send default "$P_CLAUDE" "FAKE_CLAUDE_SLEEP=100000 $O/fakebin/claude --session"
    s5_nvim_start default "$P_ED" "nvim $FILES/a.txt" && NV_ED=$S5_NV &&
        s5_nvim_start default "$P_MOD" "nvim $FILES/c.txt" && NV_MOD=$S5_NV &&
        s5_nvim_start default "$P_GIT" "cd /tmp/s5/repo && EDITOR=nvim git commit" && NV_GIT=$S5_NV &&
        s5_nvim_start other "$P_OED" "nvim $FILES/b.txt $HOME/.wezterm.common.lua" && NV_OED=$S5_NV || return 1

    GIT_PID=$(s5_child "$(s5_pane_pid default "$P_GIT")" git)
    LONG_PID=$(s5_child "$(s5_pane_pid default "$P_LONG")" bash)
    CLAUDE_PID=$(s5_child "$(s5_pane_pid default "$P_CLAUDE")" sleep)
    SERVERS="$(s5_tq default display -p '#{pid}') $(s5_tq other display -p '#{pid}')"
    { s5_tq default list-panes -a -F '#{pane_id} #{pane_pid}'; s5_tq other list-panes -a -F '#{pane_id} #{pane_pid}'; } |
        sort >"$O/panes.before"
    [ -n "$GIT_PID" ] && [ -n "$LONG_PID" ] && [ -n "$CLAUDE_PID" ] || return 1
    # Over RPC: keys typed into the pane can land in a window other than c.txt.
    s5_nvim_expr "$NV_MOD" "nvim_buf_set_lines(bufnr('$FILES/c.txt'), 0, 0, v:false, ['hello'])" >/dev/null
    if [ "$(s5_nvim_expr "$NV_MOD" "getbufvar(bufnr('$FILES/c.txt'), '&modified')")" != 1 ]; then
        printf 's5: nvim %s: c.txt is not modified\n' "$NV_MOD"
        return 1
    fi
}

# s5_fresh LABEL — new shells start cleanly and find tmux, node, fzf, cargo.
s5_fresh() {
    local o=$O/fresh-$1
    mkdir -p "$o"
    t_env bash -lc true >"$o/login.out" 2>&1
    assert_empty "A23 $1: a new bash -l starts silently" "$(cat "$o/login.out")"
    printf '%s\n' \
        "{ tmux -V && node -v && fzf --version && cargo --version; } >$o/run 2>&1; printf '%s\n' \"\$?\" >$o/run.rc" \
        "[ -d \"\${HISTFILE%/*}\" ] && printf 'ok\n' >$o/histdir" >"$o/cmds"
    t_ishell 120 "$o/cmds"
    assert_empty "A23 $1: a new bash -i starts without stderr" "$(cat "$o/cmds.err" 2>/dev/null)"
    assert_eq "A23 $1: a new shell runs tmux, node, fzf and cargo" 0 "$(cat "$o/run.rc" 2>/dev/null)"
    [ "$(cat "$o/run.rc" 2>/dev/null)" = 0 ] || __assert_show "$o/run"
    assert_eq "A23 $1: the HISTFILE dir exists" ok "$(cat "$o/histdir" 2>/dev/null)"
}

# s5_old_panes LABEL — the shells started before the migration still run
# cargo, fzf and node (through the compat links once tools moved).
s5_old_panes() {
    local o=$O/panes-$1 s p n
    mkdir -p "$o"
    for s in default other; do
        p=$P_IDLE
        [ "$s" = other ] && p=$P_OIDLE
        n=$o/$s
        if s5_run_in "$s" "$p" "$n.done" "{ cargo --version && fzf --version && node -v; } >$n.out 2>&1; printf '%s\n' \$? >$n.rc"; then
            assert_eq "A23 $1: an old $s-server shell runs cargo, fzf and node" 0 "$(cat "$n.rc" 2>/dev/null)"
            [ "$(cat "$n.rc" 2>/dev/null)" = 0 ] || __assert_show "$n.out"
        else
            _hardfail "A23 $1: the old $s-server shell did not answer"
        fi
    done
}

# s5_step LABEL ARGS... — runs `dotfiles ARGS` from the checkout, no TTY.
s5_step() {
    local label=$1
    shift
    t_env "$T_REPO/bin/dotfiles" "$@" </dev/null >"$O/step-$label.out" 2>&1
    S5_RC=$?
    printf '  [dotfiles %s] exit %s\n' "$*" "$S5_RC"
}

s5_alive() {   # LABEL PID
    if [ -n "$2" ] && kill -0 "$2" 2>/dev/null; then _pass "A23 $1 still runs (pid $2)"
    else _hardfail "A23 $1 is gone (pid $2)"; fi
}

# s5_fails — the number of hard and soft failures recorded so far
s5_fails() { grep -cE '^(FAIL|WARN)' "$ASSERT_RESULTS" 2>/dev/null; }

if [ -z "${LEGACY_REF:-}" ]; then
    _hardfail "LEGACY_REF is not set (test/run.sh passes it)"
    assert_summary
    exit 1
fi

group "s5 setup: old layout, old tool locations, live sessions"
if ! s5_setup; then
    _hardfail "s5 legacy setup"
    __assert_show "$O/legacy-install.log"
    __assert_show "$O/worktree-add.log"
    __assert_show "$O/tmux-prep.log"
    __assert_show "$O/npm-legacy.log"
    assert_summary
    exit 1
fi
if ! s5_start_sessions; then
    _hardfail "s5 sessions, shells and nvims did not all start, or c.txt is not modified"
    __assert_show "$T_WORK/tmux-start-main.log"
    assert_summary
    exit 1
fi
_pass "s5 two tmux servers with shells, nvims, a long-running process and a fake claude"

group "s5 step 1: migrate repo"
s5_step repo migrate repo --yes
assert_eq "migrate repo exits 0" 0 "$S5_RC"
if [ -d "$NEW" ] && [ ! -L "$NEW" ] && [ "$(readlink "$OLD")" = .dotfiles ]; then
    _pass "the checkout is ~/.dotfiles and ~/dotfiles is a compat link to it"
else
    _hardfail "the checkout is not ~/.dotfiles, or ~/dotfiles is not a link to .dotfiles"
fi
T_REPO=$NEW
assert_grep "$O/step-repo.out" "^WORKTREE ~/${WT#"$HOME"/}: its \.git file reaches the checkout through ~/dotfiles" \
    'A23 migrate repo reports the linked worktree'
assert_eq "A23 migrate repo points the worktree's .git file at ~/.dotfiles" \
    "gitdir: $HOME/.dotfiles/.git/worktrees/${WT##*/}" "$(cat "$WT/.git" 2>&1)"
assert_exit0 "A23 the linked worktree works after migrate repo" -- t_git -C "$WT" status --short
s5_fresh repo
s5_old_panes repo

group "s5 step 2: migrate tools while a process runs from ~/.cargo/bin"
cp /bin/sleep "$HOME/.cargo/bin/t-busy"
# Not t_env: a backgrounded function makes $! a subshell, and the kill below
# would miss t-busy. env execs it, so $! is t-busy.
env -i HOME="$HOME" PATH="$BASE_PATH" "$HOME/.cargo/bin/t-busy" 600 &
busy=$!
sleep 1
s5_step tools-busy migrate tools --yes
if [ -d "$HOME/.cargo" ] && [ ! -L "$HOME/.cargo" ]; then _pass "A23 migrate tools left the busy ~/.cargo in place"
else _hardfail "A23 migrate tools moved ~/.cargo while a process ran from it"; fi
assert_grep "$O/step-tools-busy.out" '\.cargo' 'A23 migrate tools reports the refused ~/.cargo'
kill "$busy" 2>/dev/null
wait "$busy" 2>/dev/null
rm -f "$HOME/.cargo/bin/t-busy"
s5_step tools migrate tools --yes
assert_eq "migrate tools exits 0 once nothing runs from ~/.cargo" 0 "$S5_RC"
# Left behind, it would make bootstrap user in step 5 refuse.
assert_absent "$T_STATE/dotfiles/migrate/node.pending"
assert_rel_link "$HOME/.cargo" "$T_DATA/cargo"
assert_rel_link "$HOME/.rustup" "$T_DATA/rustup"
for t in fzf fzf-tab-completion bell-bash noti-bash; do
    assert_rel_link "$HOME/.$t" "$HOME/.local/opt/$t"
done
assert_file "$T_DATA/fnm/aliases/default/bin/node"
s5_fresh tools
s5_old_panes tools

group "s5 step 3: migrate all (nvim-save, nvim-state, uninstall-legacy, nvim-restore)"
fails=$(s5_fails)
s5_step all migrate all --yes
assert_eq "migrate all exits 0" 0 "$S5_RC"
[ "$S5_RC" = 0 ] || __assert_show "$O/step-all.out" 40
assert_grep "$O/step-all.out" \
    '^New shells use the new layout; leave running tmux servers until they end and start new work in a new one\.$' \
    'A23 uninstall-legacy says to leave old tmux servers'
assert_no_grep "$O/step-all.out" 'switches with .tmux source' \
    'A23 uninstall-legacy does not advise reloading old tmux servers'
s5_alive "the modified nvim" "$NV_MOD"
s5_alive "the nvim git started as \$EDITOR" "$NV_GIT"
# A pane is named <server>:<pane id>: default and other each have a pane %1.
assert_grep "$O/step-all.out" "^SKIP pane default:$P_MOD nvim $NV_MOD: [1-9][0-9]* modified buffer" \
    'A23 migrate all skips the modified nvim for its modified buffer'
if grep -qF -- "default:$P_GIT" "$O/step-all.out"; then _pass "A23 migrate all reports the \$EDITOR nvim"
else _softfail "A23 migrate all does not name the \$EDITOR nvim's pane default:$P_GIT"; fi
assert_grep "$O/step-all.out" "^SAVE pane default:$P_ED nvim $NV_ED in " 'A23 nvim-save names the pane with its server'
assert_grep "$O/step-all.out" "^restored pane other:$P_OED\$" 'A23 nvim-restore names the pane with its server'
assert_no_grep "$O/step-all.out" '^(SAVE|SKIP|RESTORE|DROP|saved|restored) pane %' \
    'A23 migrate never prints a pane id without its server'
# uninstall-legacy moved ~/.wezterm.common.lua after that nvim's session was saved.
assert_grep "$O/step-all.out" \
    "^WARN pane other:$P_OED: its session opens ~/\.wezterm\.common\.lua, which dotfiles moved to" \
    'A23 nvim-restore warns about a session file whose file uninstall-legacy moved'
for pe in "default $P_ED $NV_ED" "other $P_OED $NV_OED"; do
    read -r s p old <<<"$pe"
    if kill -0 "$old" 2>/dev/null; then
        _hardfail "A23 the unmodified nvim in $s pane $p was not saved and quit"
        continue
    fi
    if s5_wait_cmd "$s" "$p" nvim; then
        new=$(s5_child "$(s5_pane_pid "$s" "$p")" nvim)
        if tr '\0' ' ' <"/proc/$new/cmdline" 2>/dev/null | grep -q -- "-S .*/dotfiles/migrate/"; then
            _pass "A23 the nvim in $s pane $p was restored from its session"
        else
            _hardfail "A23 the nvim in $s pane $p runs without the saved session"
        fi
    else
        _hardfail "A23 no nvim restored in $s pane $p"
    fi
done
# nvim-save's SAVE, SKIP and warning lines say why an nvim check above failed.
if [ "$(s5_fails)" != "$fails" ]; then
    grep -E 'nvim|pane ' "$O/step-all.out" >"$O/step-all.nvim"
    __assert_show "$O/step-all.nvim" 40
fi
s5_fresh all
s5_old_panes all
check_layout
# A new login shell puts ~/.local/bin first (skel ~/.profile), so the old
# noti copy must be out of the way for the clone's to run.
assert_absent "$HOME/.local/bin/noti"
if compgen -G "$T_STATE/dotfiles/backup/*/.local/bin/noti" >/dev/null; then
    _pass "A23 the old ~/.local/bin/noti is in the backup dir"
else
    _hardfail "A23 the old ~/.local/bin/noti is not in the backup dir"
fi
printf '%s\n' "type -P noti >$O/noti" >"$O/noti.cmds"
t_ishell -l 120 "$O/noti.cmds"
assert_eq "A23 a new login shell runs noti from the clone" "$HOME/.local/opt/noti-bash/bin/noti" \
    "$(cat "$O/noti" 2>/dev/null)"
# nvim-state copies the checkout's undo file under its new path.
assert_file "$T_STATE/nvim/undo/$UNDO_NEW"
assert_absent "$T_STATE/nvim/undo/$UNDO_OLD"

group "s5 step 4: install"
s5_step install install --yes
assert_eq "install after the migration exits 0" 0 "$S5_RC"
s5_fresh install
s5_old_panes install

group "s5 step 5: bootstrap user --only fnm"
s5_step bootstrap bootstrap user --only fnm
assert_eq "bootstrap user --only fnm exits 0" 0 "$S5_RC"
assert_match "A23 the fnm default is still the version nvm had" "/$NODE_V/" \
    "$(readlink -f "$T_DATA/fnm/aliases/default")/"
# semver's CLI has no --version: it prints the arguments that are valid versions.
printf '%s\n' "semver $SEMVER >$O/semver 2>&1" >"$O/semver.cmds"
t_ishell 60 "$O/semver.cmds"
assert_eq "A23 a new shell runs the global npm package from the fnm default" "$SEMVER" \
    "$(cat "$O/semver" 2>/dev/null)"
s5_fresh bootstrap
s5_old_panes bootstrap

group "A23 nothing killed"
assert_eq "A23 both tmux servers still run" "$SERVERS" \
    "$(s5_tq default display -p '#{pid}' 2>&1) $(s5_tq other display -p '#{pid}' 2>&1)"
assert_empty "A23 every pane and its shell are the same" \
    "$({ s5_tq default list-panes -a -F '#{pane_id} #{pane_pid}'; s5_tq other list-panes -a -F '#{pane_id} #{pane_pid}'; } | sort | diff "$O/panes.before" -)"
s5_alive "the modified nvim" "$NV_MOD"
s5_alive "git commit" "$GIT_PID"
s5_alive "the \$EDITOR nvim" "$NV_GIT"
s5_alive "the long-running process" "$LONG_PID"
s5_alive "the fake claude" "$CLAUDE_PID"
assert_file "$HOME/.tmux/plugins"
assert_file "$HOME/.nvm"

group "s5 cleanup while old shells live"
# One old server re-read with the new config: what the old config set stays,
# and tmux-cuecard adds its window-unlinked hook from the new plugin dir next
# to the one from ~/.tmux/plugins.
s5_tq other source-file "$HOME/.config/tmux/tmux.conf" >"$O/tmux-resource.log" 2>&1
for ((i = 0; i < 60; i++)); do
    hooks=$(s5_tq other show-hooks -g window-unlinked 2>&1)
    [[ $hooks == *"$T_DATA/tmux/plugins/"* ]] && break
    sleep 0.5
done
if [[ $hooks == *"$T_DATA/tmux/plugins/"* && $hooks == *"$HOME/.tmux/plugins/"* ]]; then
    _pass "A23 the re-read old server runs window-unlinked hooks from both plugin dirs"
else
    _hardfail "A23 the re-read old server lacks the old or the new window-unlinked hook"
    printf '%s\n' "$hooks" | sed 's/^/        | /'
fi
s5_step cleanup-busy migrate cleanup --yes
# The old pane shells have a terminal and started before the compat links and
# before ~/.bashrc was replaced, so any tool dir may be on their PATH (rc
# files add some after the start, where /proc does not show them). They have
# no RUSTUP_HOME: a rustup proxy in ~/.cargo/bin reads ~/.rustup. The fake
# claude and its shell were started in ~/dotfiles.
for c in "${COMPAT[@]}"; do
    if [ -L "$HOME/$c" ]; then _pass "A23 cleanup kept the compat link ~/$c in use by old shells"
    else _hardfail "A23 cleanup removed ~/$c while old shells use it"; fi
done
for c in bell-bash noti-bash fzf-tab-completion; do
    assert_grep "$O/step-cleanup-busy.out" "^STAY ~/\.$c: " "A23 cleanup reports why ~/.$c stays"
done
assert_grep "$O/step-cleanup-busy.out" '^STAY ~/dotfiles: ' 'A23 cleanup reports why ~/dotfiles stays'
assert_grep "$O/step-cleanup-busy.out" \
    '^STAY ~/\.tmux: a running tmux server still refers to ~/\.tmux/plugins \(a server started with the old config keeps such a hook even after .tmux source.; let it end\)$' \
    'A23 cleanup keeps ~/.tmux and says reloading does not help'
# Mentioning that `tmux source` keeps the old hooks is fine; advising it is not.
assert_no_grep "$O/step-cleanup-busy.out" "reload|tmux source[^']|source-file" \
    'A23 cleanup does not advise reloading an old tmux server'
assert_file "$HOME/.tmux/plugins"
assert_file "$HOME/.nvm"
assert_exit0 "A23 the linked worktree works while old shells live" -- t_git -C "$WT" status --short
s5_old_panes cleanup-busy

group "s5 end the old shells"
# One nvim at a time: nvims quitting together race on the shared ShaDa file,
# and the loser stops at a hit-enter prompt (E137/E136).
for pe in "default $P_ED" "default $P_MOD" "default $P_GIT" "other $P_OED"; do
    read -r s p <<<"$pe"
    s5_tq "$s" send-keys -t "$p" Escape
    s5_send "$s" "$p" ':qa!'
    end=$((SECONDS + 10))
    until s5_at_prompt "$s" "$p" || [ "$SECONDS" -ge "$end" ]; do
        sleep 0.5
    done
done
for p in "$P_LONG" "$P_CLAUDE"; do
    s5_tq default send-keys -t "$p" C-c
done
ENDS=("default $P_IDLE" "default $P_ED" "default $P_MOD" "default $P_GIT" "default $P_LONG"
    "default $P_CLAUDE" "other $P_OIDLE" "other $P_OED")
# `exit` typed while a program still holds the pane goes to that program, not
# the shell, so it waits for each shell's prompt and is repeated until the
# servers are gone.
end=$((SECONDS + 30))
for pe in "${ENDS[@]}"; do
    read -r s p <<<"$pe"
    until s5_at_prompt "$s" "$p" || [ "$SECONDS" -ge "$end" ]; do
        sleep 0.5
    done
done
for ((i = 0; i < 120; i++)); do
    s5_tq default has-session 2>/dev/null || s5_tq other has-session 2>/dev/null || break
    if ((i % 10 == 0)); then
        for pe in "${ENDS[@]}"; do
            read -r s p <<<"$pe"
            if s5_at_prompt "$s" "$p"; then s5_send "$s" "$p" exit 2>/dev/null; fi
        done
    fi
    sleep 0.5
done
if s5_tq default has-session 2>/dev/null || s5_tq other has-session 2>/dev/null; then
    _hardfail "s5 the old tmux servers did not exit after their shells"
    s5_show_panes
    t_tmux_kill
    t_tmux_kill -L other
fi

group "s5 cleanup after the old shells exited"
# Every ssh login of a real host has a non-dumpable `sshd: user@pts/N`
# process of the user's uid, whose /proc files nobody can read; a zombie is
# just as unreadable. Neither may keep anything in use.
nd='' zp=''
if t_nondumpable_start; then
    nd=$T_ND
else
    _hardfail "s5 cannot build the non-dumpable helper"
fi
t_zombie_start
zp=$T_ZP
sleep 1
if [ -n "$nd" ] && [ -e "/proc/$nd" ] && [ ! -O "/proc/$nd/environ" ]; then
    _pass "s5 a non-dumpable process of this uid runs (pid $nd)"
else
    _hardfail "s5 the non-dumpable helper does not run, or its environ is readable"
fi
case $(ps -o stat= --ppid "$zp") in
    *Z*) _pass "s5 a zombie of this uid exists (parent $zp)" ;;
    *) _hardfail "s5 the zombie helper made no zombie" ;;
esac
s5_step cleanup migrate cleanup --yes
kill ${nd:+"$nd"} "$zp" 2>/dev/null
assert_eq "migrate cleanup exits 0" 0 "$S5_RC"
[ "$S5_RC" = 0 ] || __assert_show "$O/step-cleanup.out" 40
for c in "${COMPAT[@]}"; do
    assert_absent "$HOME/$c"
done
assert_absent "$HOME/.tmux"
assert_absent "$HOME/.nvm"
if compgen -G "$T_STATE/dotfiles/backup/*/.tmux" >/dev/null && compgen -G "$T_STATE/dotfiles/backup/*/.nvm" >/dev/null; then
    _pass "A23 ~/.tmux and ~/.nvm were moved into the backup dir"
else
    _hardfail "A23 ~/.tmux or ~/.nvm is not in the backup dir"
fi
assert_exit0 "A23 the linked worktree works after cleanup removed ~/dotfiles" -- t_git -C "$WT" status --short
assert_absent "$HOME/.bash_history" soft

group "s5 cleanup again after ~/dotfiles is gone"
s5_step cleanup-again migrate cleanup --yes
assert_eq "a second migrate cleanup exits 0" 0 "$S5_RC"
assert_grep "$O/step-cleanup-again.out" '^Nothing to clean up now\.$' 'A23 a second cleanup is a no-op'
assert_absent "$T_STATE/nvim/undo/$UNDO_OLD"

assert_summary
