#!/usr/bin/env bash
# Shared helpers and assertion groups for the scenario scripts. Source after
# assert.sh, then call t_init. Every shell under test starts from t_env's fixed
# environment (no SHLVL, no LANG, only the XDG_* values the scenario chose), so
# results depend on the image and the dotfiles only. Missing SHLVL plus
# SSH_CLIENT makes `bash -c` behave like a shell started by sshd.

T_DIR=/opt/dotfiles-test
T_FIX=$T_DIR/fixtures
BASE_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
T_USER=$(id -un)
T_REPO=$HOME/.dotfiles
T_SNAP=/tmp/snap
T_TMUX=$HOME/.local/opt/tmux/bin/tmux
T_XDG=()
T_SSH=('SSH_CLIENT=1.2.3.4 1 22')
# The noti script the repo kept in .local/bin until noti-bash replaced it
# (8b9dc13); old accounts still have this copy in ~/.local/bin.
# shellcheck disable=SC2034  # the scenarios use it
T_OLD_NOTI=54f92f718d547d80e876481ac8b9c2b0ca58aa68

t_init() {
    T_NAME=$1
    T_WORK=/tmp/t/$1
    mkdir -p "$T_WORK" || exit 1
    ASSERT_RESULTS=$T_WORK/results.tsv
    : >"$ASSERT_RESULTS"
    T_TIER=$(cat "$T_DIR/build-checks/tier" 2>/dev/null)
    : "${T_TIER:=lite}"
    t_xdg
    declare -f __t_probe >"$T_WORK/probe.bash"
    cd "$HOME" || exit 1
    printf '=== scenario %s (tier %s) ===\n' "$T_NAME" "$T_TIER"
}

# t_xdg [XDG_*=VALUE...] — the XDG values every shell under test gets; also
# sets T_CFG, T_DATA, T_STATE and T_CACHE the way the dotfiles resolve them.
# shellcheck disable=SC2120  # the scenarios pass the values
t_xdg() {
    local kv
    T_XDG=("$@")
    T_CFG=$HOME/.config T_DATA=$HOME/.local/share T_STATE=$HOME/.local/state T_CACHE=$HOME/.cache
    for kv in "$@"; do
        case $kv in
            XDG_CONFIG_HOME=*) T_CFG=${kv#*=} ;;
            XDG_DATA_HOME=*) T_DATA=${kv#*=} ;;
            XDG_STATE_HOME=*) T_STATE=${kv#*=} ;;
            XDG_CACHE_HOME=*) T_CACHE=${kv#*=} ;;
        esac
    done
}

# t_home DIR — makes DIR the account under test. Call it in a subshell.
t_home() {
    export HOME=$1
    T_REPO=$HOME/.dotfiles
    T_TMUX=$HOME/.local/opt/tmux/bin/tmux
    t_xdg
    cd "$HOME" || exit 1
}

t_env() {
    env -i HOME="$HOME" USER="$T_USER" LOGNAME="$T_USER" SHELL=/bin/bash \
        PATH="$BASE_PATH" TERM=xterm-256color "${T_XDG[@]}" "$@"
}

# Leading NAME=VALUE arguments of a helper, for t_env.
__t_assigns() {
    T_ASSIGNS=()
    while [[ ${1:-} =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; do
        T_ASSIGNS+=("$1")
        shift
    done
    T_NASSIGNS=${#T_ASSIGNS[@]}
}

# t_login [NAME=VALUE...] CMD... — runs CMD from a non-interactive login
# shell, so PATH and the tool variables come from the installed dotfiles.
t_login() {
    __t_assigns "$@"
    shift "$T_NASSIGNS"
    t_env "${T_ASSIGNS[@]}" bash -lc '"$@"' t_login "$@"
}

# t_pty [NAME=VALUE...] SECONDS CMDSTRING — runs CMDSTRING in a pty.
t_pty() {
    __t_assigns "$@"
    shift "$T_NASSIGNS"
    t_env "${T_ASSIGNS[@]}" timeout "$1" script -qec "$2" /dev/null </dev/null
}

# t_ishell [-l] SECONDS FILE — an interactive bash (login with -l) in a pty
# sources FILE once its startup is done; stderr of both goes to FILE.err.
t_ishell() {
    local flags=-i
    [ "$1" = -l ] && { flags="-l -i"; shift; }
    t_pty "$1" "bash $flags -c '. $2' 2>$2.err" >"$2.pty" 2>&1
}

t_dot() { t_env "$T_REPO/bin/dotfiles" "$@"; }

# git for the harness itself: no user or system config, any owner.
t_git() {
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c user.name=tester \
        -c user.email=tester@example.invalid -c safe.directory='*' \
        -c init.defaultBranch=main "$@"
}

# A committed copy of the image checkout, which has the new layout only
# staged, so clones carry it. The image checkout itself is never committed.
t_snapshot() {
    [ -d "$T_SNAP/.git" ] && return 0
    cp -a "$T_REPO" "$T_SNAP" &&
        t_git -C "$T_SNAP" add -A &&
        t_git -C "$T_SNAP" commit -qm 'test snapshot'
}

# t_acct NAME — a fresh account home under /tmp/accts with the skel files and
# a clone of the snapshot at ~/.dotfiles; prints its path.
t_acct() {
    local h=/tmp/accts/$1
    if [ -e "$h" ]; then
        printf 't_acct: %s exists\n' "$h" >&2
        return 1
    fi
    mkdir -p "$h" && cp -a /etc/skel/. "$h/" &&
        t_git clone -q "$T_SNAP" "$h/.dotfiles" &&
        printf '%s\n' "$h"
}

# t_marker — a fresh file to compare mtimes with. The sleep outlasts the
# kernel's coarse timestamp tick, so a write right after it is newer.
t_marker() {
    local m
    m=$(mktemp "$T_WORK/marker.XXXXXX") || return 1
    sleep 0.05
    printf '%s\n' "$m"
}

# t_changed MARKER DIR — paths under DIR modified after MARKER. The checkout
# is skipped: git may refresh its index on a read.
t_changed() {
    find "$2" -path "$2/.dotfiles" -prune -o -newer "$1" -print
}

t_wait_file() {
    local i n=$((${2:-60} * 4))
    for ((i = 0; i < n; i++)); do
        [ -e "$1" ] && return 0
        sleep 0.25
    done
    return 1
}

# t_kv FILE KEY — the value of KEY in a key=value file
t_kv() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1; }

# t_expect_empty LABEL RESULT — RESULT exists and is empty; each of its lines
# is a problem found by the probe that wrote it.
t_expect_empty() {
    if [ ! -e "$2" ]; then
        _hardfail "$1 (the probe wrote no result)"
        __assert_show "$2.log"
    elif [ -s "$2" ]; then
        _hardfail "$1"
        head -n 20 "$2" | sed 's/^/        | /'
    else
        _pass "$1"
    fi
}

# t_nondumpable_start — starts a process of this uid that is not dumpable,
# as sshd's per-login process on a real host: its /proc files belong to root.
# Sets T_ND to its pid.
t_nondumpable_start() {
    local bin=$T_WORK/nondumpable
    if [ ! -x "$bin" ]; then
        printf '%s\n' '#include <sys/prctl.h>' '#include <unistd.h>' \
            'int main(void) { prctl(PR_SET_DUMPABLE, 0); sleep(600); return 0; }' >"$bin.c" &&
            cc -o "$bin" "$bin.c" || return 1
    fi
    "$bin" &
    # shellcheck disable=SC2034  # the scenarios use it
    T_ND=$!
}

# t_zombie_start — a sleep whose exited child it never reaps, so a zombie of
# this uid exists. Sets T_ZP to the sleep's pid.
t_zombie_start() {
    bash -c 'sleep 0.1 & exec sleep 600' &
    # shellcheck disable=SC2034  # the scenarios use it
    T_ZP=$!
}

# t_pair FILE A B — FILE has line A immediately followed by line B
t_pair() {
    awk -v a="$2" -v b="$3" 'prev == a && $0 == b { found = 1 } { prev = $0 } END { exit !found }' "$1"
}

# Puts LINE into the local env zone of ~/.bashrc, right after the env block.
t_bashrc_env_zone() {
    local f=$HOME/.bashrc tmp
    if ! grep -qxF '# <<< dotfiles env <<<' "$f"; then
        _hardfail "no env block end marker in $f"
        return 1
    fi
    tmp=$(mktemp) &&
        awk -v line="$1" '{ print } $0 == "# <<< dotfiles env <<<" { print line }' "$f" >"$tmp" &&
        cat "$tmp" >"$f"
    rm -f "$tmp"
}

# Appends LINE to the interactive local zone at the end of ~/.bashrc.
t_bashrc_local() { printf '%s\n' "$1" >>"$HOME/.bashrc"; }

# t_outside_blocks FILE [PREFIX] — FILE without its managed blocks, marker
# lines included. PREFIX is the markers' comment leader ('# ' or '-- ').
# GNU sed keeps a missing final newline, so the bytes outside stay exact.
t_outside_blocks() {
    local p=${2:-# }
    sed -e "/^${p}>>> dotfiles env >>>\$/,/^${p}<<< dotfiles env <<<\$/d" \
        -e "/^${p}>>> dotfiles >>>\$/,/^${p}<<< dotfiles <<<\$/d" "$1"
}

# t_inventory DIR OUT — every file and link under DIR (minus the checkout and
# the dotfiles state) as path, kind, content hash or link text.
t_inventory() {
    local p
    (cd "$1" && find . \( -path ./.dotfiles -o -path ./.local/state/dotfiles \) -prune \
        -o \( -type f -o -type l \) -printf '%P\n') | sort | while IFS= read -r p; do
        if [ -L "$1/$p" ]; then
            printf '%s\tl\t%s\n' "$p" "$(readlink "$1/$p")"
        else
            printf '%s\tf\t%s\n' "$p" "$(sha256sum <"$1/$p" | cut -d' ' -f1)"
        fi
    done >"$2"
}

# t_same PATH KIND VALUE — PATH matches an inventory entry
t_same() {
    if [ "$2" = l ]; then
        [ -L "$1" ] && [ "$(readlink "$1")" = "$3" ]
    else
        [ -f "$1" ] && [ ! -L "$1" ] && [ "$(sha256sum <"$1" | cut -d' ' -f1)" = "$3" ]
    fi
}

# t_time_median N CMD... — median wall time of CMD over N runs, in ms
t_time_median() {
    local n=$1 i t0 t1
    shift
    for ((i = 0; i < n; i++)); do
        t0=${EPOCHREALTIME/./}
        "$@" >/dev/null 2>&1
        t1=${EPOCHREALTIME/./}
        printf '%s\n' $(((t1 - t0) / 1000))
    done | sort -n | sed -n "$((n / 2 + 1))p"
}

# --- probes ---------------------------------------------------------------

# Runs inside the shell under test (sourced from $T_WORK/probe.bash), where
# the dotfiles' aliases are active: external commands go through `command`.
__t_probe() {
    local d=$1 v c
    command mkdir -p "$d" || return 1
    printf '%s\n' "$-" >"$d/flags.txt"
    declare -F >"$d/functions.txt"
    alias >"$d/aliases.txt"
    { bind -p; bind -s; bind -X; } >"$d/bindings.txt" 2>&1
    for v in PATH HISTFILE HISTSIZE HISTFILESIZE INPUTRC CLAUDE_PLUGIN_DIRS \
        CLAUDE_SETTINGS_FILES BELL_BASH_BACKENDS DOTFILES_T_ENVZONE DOTFILES_T_LOCAL; do
        declare -p "$v" 2>/dev/null || printf '%s=<unset>\n' "$v"
    done >"$d/vars.txt"
    for c in tmux fzf node cargo nvim git starship zoxide fnm bell-send noti; do
        printf '%s=%s\n' "$c" "$(type -P "$c")"
    done >"$d/paths.txt"
    : >"$d/.done"
}

# t_probe_shell NAME [login] — probes a real interactive shell (in a pty) into
# $T_WORK/probe/NAME.
t_probe_shell() {
    local d=$T_WORK/probe/$1 flags=-i
    [ "${2:-}" = login ] && flags="-l -i"
    mkdir -p "$d"
    t_pty 120 "bash $flags -c '. $T_WORK/probe.bash && __t_probe $d' 2>$d/startup.stderr" \
        >"$d/pty.txt" 2>&1
}

# t_nvim_lua SCRIPT RESULT — runs SCRIPT in a headless nvim started from a
# login shell; SCRIPT writes to $T_RESULT. nvim's own output goes to RESULT.log.
t_nvim_lua() {
    rm -f "$2"
    t_login T_RESULT="$2" timeout 180 nvim --headless -c "luafile $1" >"$2.log" 2>&1
}

# --- tmux -----------------------------------------------------------------

# tq ARGS — the tmux client under test. A UTF-8 locale keeps tmux from
# printing '_' for non-ASCII characters; plugin scripts find tmux on PATH.
tq() { t_env LANG=C.UTF-8 PATH="${T_TMUX%/*}:$BASE_PATH" "$T_TMUX" "$@"; }

# t_tmux_start SESSION [-L SOCKET] — starts a server from a login interactive
# shell, as from a terminal or an ssh login, and waits for the session.
t_tmux_start() {
    local s=$1 sock=() i
    [ "${2:-}" = -L ] && sock=(-L "$3")
    t_env bash -l -i -c "timeout 900 $T_TMUX ${sock[*]} new-session -d -s $s -x 200 -y 50" \
        </dev/null >"$T_WORK/tmux-start-$s.log" 2>&1
    for ((i = 0; i < 240; i++)); do
        tq "${sock[@]}" has-session -t "$s" 2>/dev/null && return 0
        sleep 0.5
    done
    return 1
}

# The socket options of the tmux helpers below: -L NAME or -S PATH, or none
# for the default socket.
__t_sock() {
    T_SOCK=()
    case ${1:-} in
        -L | -S) T_SOCK=("$1" "$2") ;;
    esac
}

# t_tmux_kill [-L NAME | -S PATH]
t_tmux_kill() {
    local i
    __t_sock "$@"
    tq "${T_SOCK[@]}" kill-server 2>/dev/null
    for ((i = 0; i < 40; i++)); do
        tq "${T_SOCK[@]}" has-session 2>/dev/null || return 0
        sleep 0.25
    done
    return 1
}

# t_pane_send [-L NAME | -S PATH] TARGET COMMAND — types COMMAND and Enter
# into the pane; the leading space keeps it out of the history.
t_pane_send() {
    __t_sock "$@"
    shift "${#T_SOCK[@]}"
    tq "${T_SOCK[@]}" send-keys -t "$1" -l " $2" && tq "${T_SOCK[@]}" send-keys -t "$1" Enter
}

# t_pane_run [-L NAME | -S PATH] TARGET DONE COMMAND [SECONDS] — t_pane_send,
# then waits until the command has created DONE.
t_pane_run() {
    local -a sock
    __t_sock "$@"
    sock=("${T_SOCK[@]}")
    shift "${#sock[@]}"
    rm -f "$2"
    t_pane_send "${sock[@]}" "$1" "$3; : >$2" && t_wait_file "$2" "${4:-60}"
}

# --- assertion groups -----------------------------------------------------

# check_manifest — every manifest link exists, resolves and is relative.
check_manifest() {
    local m=$T_STATE/dotfiles/manifest.tsv target text _src n=0 bad=''
    if [ ! -s "$m" ]; then
        _hardfail "manifest $m missing or empty"
        return
    fi
    while IFS=$'\t' read -r target text _src; do
        n=$((n + 1))
        case $text in
            /*) bad+="$target -> $text (absolute)"$'\n'; continue ;;
        esac
        if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$text" ] || [ ! -e "$target" ]; then
            bad+="$target -> $(readlink "$target") (want $text)"$'\n'
        fi
    done <"$m"
    assert_empty "manifest: all $n links in place, resolving and relative" "$bad"
}

# check_layout [no-wezterm] — the layout `install` leaves (DD §3-§5).
# shellcheck disable=SC2120  # the argument is optional
check_layout() {
    local b=$HOME/.bashrc env_l main_l f bad
    group "layout after install ($HOME)"
    env_l=$(grep -nxF '# >>> dotfiles env >>>' "$b" | head -n 1 | cut -d: -f1)
    main_l=$(grep -nxF '# >>> dotfiles >>>' "$b" | head -n 1 | cut -d: -f1)
    if [ -n "$env_l" ] && [ -n "$main_l" ] && [ "$env_l" -lt "$main_l" ]; then
        _pass "the env block (line $env_l) comes before the main block (line $main_l) in $b"
    else
        _hardfail "the env block (${env_l:-none}) and main block (${main_l:-none}) of $b missing or out of order"
    fi
    assert_grep "$b" 'bash/env\.bash' 'the ~/.bashrc env block loads env.bash'
    assert_grep "$b" 'bash/common\.bash' 'the ~/.bashrc main block loads common.bash'
    for f in bash fzf readline; do
        assert_rel_link "$T_CFG/$f" "$T_REPO/.config/$f"
    done
    for f in git tmux tmux/themes wezterm noti vim nvim nvim/lua; do
        if [ -d "$T_CFG/$f" ] && [ ! -L "$T_CFG/$f" ]; then _pass "$T_CFG/$f is a real directory"
        else _hardfail "$T_CFG/$f is not a real directory"; fi
    done
    for f in git/common tmux/common.conf tmux/themes/github.conf wezterm/common.lua \
        noti/noti.conf noti/noti.preset vim/vimrc vim/common.vim vim/plugins.vim \
        nvim/init.vim nvim/coc-settings.json btop/btop.conf starship.toml \
        environment.d/kime.conf; do
        assert_rel_link "$T_CFG/$f" "$T_REPO/.config/$f"
    done
    for f in "$T_REPO"/.local/share/fonts/*.ttf; do
        assert_rel_link "$T_DATA/fonts/${f##*/}" "$f"
    done
    assert_rel_link "$HOME/.local/bin/dotfiles" "$T_REPO/bin/dotfiles"
    assert_grep "$T_CFG/git/config" '^[[:space:]]*path = common[[:space:]]*$' 'git entry includes common'
    assert_grep "$T_CFG/tmux/tmux.conf" '^source-file -F "#\{d:current_file\}/common\.conf"$' \
        'tmux entry loads common.conf next to itself'
    if [ "${1:-}" != no-wezterm ]; then
        assert_grep "$T_CFG/wezterm/wezterm.lua" 'dofile\(wezterm\.config_dir' 'wezterm entry loads common.lua'
    fi
    for f in "$b" "$T_CFG/git/config" "$T_CFG/tmux/tmux.conf" "$T_CFG/wezterm/wezterm.lua"; do
        if [ -f "$f" ] && [ ! -L "$f" ]; then _pass "entry file $f is a regular file"
        else _hardfail "entry file $f is missing or a link"; fi
    done
    f=$T_CFG/git/credentials
    if [ -f "$f" ] && [ "$(stat -c %a "$f")" = 600 ]; then _pass "$f exists with mode 600"
    else _hardfail "$f missing or not mode 600"; fi
    for f in .gitconfig .tmux.conf .wezterm.lua .inputrc .vimrc .bashrc.common .git-credentials; do
        assert_absent "$HOME/$f"
    done
    check_manifest
    # ~/.claude* belongs to the agents harness, never to the dotfiles.
    bad=$(find "$HOME" -maxdepth 1 -name '*.bak*' ! -name '.claude*'; find "$T_CFG" -name '*.bak*' 2>/dev/null)
    assert_empty "no .bak files in \$HOME or $T_CFG" "$bad"
}

check_a01_loading() {
    local d=$T_WORK/probe/a01 o=$T_WORK/a01 f
    group "A01 real loading"
    mkdir -p "$o"
    t_probe_shell a01 login
    if [ ! -e "$d/.done" ]; then
        _hardfail "A01: the login interactive shell probe did not finish"
        __assert_show "$d/pty.txt"
        return
    fi
    assert_empty "A01 login interactive shell starts without stderr" "$(cat "$d/startup.stderr")"
    for f in bootstrap_user_tools bootstrap_system_tools bootstrap_agents claude; do
        assert_line "$d/functions.txt" "declare -f $f" "A01 function $f defined"
    done
    assert_line "$d/aliases.txt" "alias vim='nvim'" 'A01 aliases.bash loaded'
    assert_grep "$d/bindings.txt" '__fzf_history__' 'A01 fzf Ctrl-R binding'
    assert_grep "$d/bindings.txt" 'fzf-file-widget|__fzf_select__' 'A01 fzf Ctrl-T binding'
    assert_grep "$d/bindings.txt" '__fzf_cd__' 'A01 fzf Alt-C binding'
    for f in .cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash dotfiles; do
        assert_absent "$HOME/$f"
    done
    (cd /tmp && t_env git config --show-origin --get alias.st) >"$o/git-alias" 2>&1
    assert_grep "$o/git-alias" '^file:.*/git/common[[:space:]]+status$' 'A01 git alias.st is status, from common'
    t_nvim_lua "$T_FIX/editor/nvim-loading.lua" "$o/nvim"
    t_expect_empty "A01 nvim: every lazy plugin installed; :Conflicted, fzf#run(), :LS exist" "$o/nvim"
}

check_a02_noninteractive() {
    local o=$T_WORK/a02.out
    group "A02 non-interactive shell (ssh host cmd)"
    t_env "${T_SSH[@]}" 'SSH_CONNECTION=1.2.3.4 1 5.6.7.8 22' DISPLAY=localhost:10.0 bash -c 'for v in CARGO_HOME RUSTUP_HOME FNM_DIR npm_config_cache INPUTRC NOTI_CONFIG NOTI_PRESET STARSHIP_CONFIG LOCAL_OPT_PATH DISPLAY DOTFILES_T_ENVZONE; do printf "%s=%s\n" "$v" "${!v-<unset>}"; done; for c in tmux fzf bell-send noti; do printf "%s=%s\n" "$c" "$(command -v "$c")"; done' \
        >"$o" 2>&1
    assert_line "$o" "CARGO_HOME=$T_DATA/cargo"
    assert_line "$o" "RUSTUP_HOME=$T_DATA/rustup"
    assert_line "$o" "FNM_DIR=$T_DATA/fnm"
    assert_line "$o" "npm_config_cache=$T_CACHE/npm"
    assert_line "$o" "INPUTRC=$T_CFG/readline/inputrc"
    assert_line "$o" "NOTI_CONFIG=$T_CFG/noti/noti.conf"
    assert_line "$o" "NOTI_PRESET=$T_CFG/noti/noti.preset"
    assert_line "$o" "STARSHIP_CONFIG=$T_CFG/starship.toml"
    assert_line "$o" "LOCAL_OPT_PATH=$HOME/.local/opt"
    assert_line "$o" "DISPLAY=localhost:10.0" 'A02 ssh commands keep the X11 forwarding DISPLAY sshd set'
    for c in fzf/bin/fzf bell-bash/bin/bell-send noti-bash/bin/noti; do
        assert_line "$o" "${c##*/}=$HOME/.local/opt/$c" "A02 ssh commands find ${c##*/} of the ${c%%/*} clone"
    done
    # A tmux server keeps the environment of the shell that started it, here
    # a non-interactive ssh one, and hands it to what it runs without a shell:
    # run-shell jobs (tmux-fzf) and the windows they open (fork-session).
    t_env "${T_SSH[@]}" bash -c "tmux -L a02 -f /dev/null new-session -d 'sleep 60' &&
        tmux -L a02 run-shell 'command -v fzf >$o.run-shell' &&
        tmux -L a02 run-shell \"tmux -L a02 new-window -d 'command -v fzf bell-send >$o.window; tmux wait-for -S a02'\" &&
        timeout 20 tmux -L a02 wait-for a02
        tmux -L a02 kill-server" >"$o.tmux" 2>&1
    assert_line "$o.run-shell" "$HOME/.local/opt/fzf/bin/fzf" \
        'A02 run-shell of a tmux server an ssh command started finds the fzf clone'
    assert_line "$o.window" "$HOME/.local/opt/fzf/bin/fzf" \
        'A02 a window that run-shell opens finds the fzf clone'
    assert_line "$o.window" "$HOME/.local/opt/bell-bash/bin/bell-send" \
        'A02 a window that run-shell opens finds bell-send of the bell clone'
    if grep -q DOTFILES_T_ENVZONE "$HOME/.bashrc"; then
        assert_line "$o" 'DOTFILES_T_ENVZONE=1' 'A02 the local env zone reaches ssh commands'
    fi
    assert_line "$o" "tmux=$HOME/.local/opt/tmux/bin/tmux" 'A02 ssh commands find the user-local tmux'
    assert_no_output "A02 bash -c true with SSH_CLIENT set" -- t_env "${T_SSH[@]}" bash -c true
}

check_a16_silence() {
    group "A16 non-interactive shells print nothing"
    assert_no_output "A16 bash -c true (SSH_CLIENT set)" -- t_env "${T_SSH[@]}" bash -c true
    assert_no_output "A16 bash -lc true (SSH_CLIENT set)" -- t_env "${T_SSH[@]}" bash -lc true
}

# t_status_right_once LABEL — each status-right append of common.conf is there once
t_status_right_once() {
    local sr tok n
    sr=$(tq show -gv status-right)
    for tok in '#{?@greenroom_alert,' '#{?#{@cuecard-count},'; do
        n=$(grep -oF -- "$tok" <<<"$sr" | wc -l)
        assert_eq "A03 status-right has '$tok' once ($1)" 1 "$n"
    done
}

# check_a03_tmux [full|subset] — subset skips the option values and TPM's
# clean_plugins (the tmux32 image).
# shellcheck disable=SC2120  # the argument is optional
check_a03_tmux() {
    local mode=${1:-full} plug=$T_DATA/tmux/plugins conf=$T_CFG/tmux/tmux.conf o=$T_WORK/a03 p v want popup_t=1
    local plugins=(tpm tmux-sensible tmux-fzf tmux-jump tmux-yank tmux-cuecard tmux-greenroom tmux-sessionist)
    local tpath=("PATH=${T_TMUX%/*}:$BASE_PATH")
    group "A03 tmux ($mode, $("$T_TMUX" -V 2>&1))"
    mkdir -p "$o"
    if [ ! -x "$T_TMUX" ]; then
        _hardfail "A03 tmux binary $T_TMUX missing"
        return
    fi
    # A machine-local plugin goes above the managed block (DD §5).
    grep -q 'tmux-sessionist' "$conf" || sed -i "1i set -g @plugin 'tmux-plugins/tmux-sessionist'" "$conf"
    if ! t_tmux_start a03; then
        _hardfail "A03 first tmux server start"
        __assert_show "$T_WORK/tmux-start-a03.log"
        return
    fi
    if [ ! -d "$plug/tmux-sensible" ] && [ -x "$plug/tpm/bin/install_plugins" ]; then
        # What prefix+I does, against the live server.
        t_env LANG=C.UTF-8 "${tpath[@]}" timeout 600 "$plug/tpm/bin/install_plugins" \
            >"$o/install_plugins.log" 2>&1
    fi
    t_tmux_kill
    if ! t_tmux_start a03; then
        _hardfail "A03 second tmux server start"
        __assert_show "$T_WORK/tmux-start-a03.log"
        return
    fi
    sleep 2
    for p in "${plugins[@]}"; do
        assert_file "$plug/$p"
    done
    tq list-keys >"$o/list-keys.txt" 2>&1
    # tmux-cuecard binds display-popup -T, which tmux has since 3.3; before
    # that its bind-key fails, and the plugin is not the dotfiles'.
    [[ $("$T_TMUX" -V 2>&1) =~ ([0-9]+)\.([0-9]+) ]] &&
        [ $((BASH_REMATCH[1] * 100 + BASH_REMATCH[2])) -lt 303 ] && popup_t=0
    for p in tmux-yank tmux-fzf tmux-jump tmux-greenroom tmux-cuecard tmux-sessionist; do
        if [ "$p" = tmux-cuecard ] && [ "$popup_t" = 0 ] && ! grep -q "$p" "$o/list-keys.txt"; then
            finding "A03 no tmux-cuecard binding on $("$T_TMUX" -V 2>&1): its display-popup -T needs tmux >= 3.3"
            continue
        fi
        assert_grep "$o/list-keys.txt" "$p" "A03 list-keys has a $p binding"
    done
    v=$(tq show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>&1)
    assert_eq "A03 TMUX_PLUGIN_MANAGER_PATH" "TMUX_PLUGIN_MANAGER_PATH=$plug" "${v%/}"
    assert_eq "A03 @tpm_plugins lists the common plugins" \
        'tmux-plugins/tpm tmux-plugins/tmux-sensible sainnhe/tmux-fzf schasse/tmux-jump tmux-plugins/tmux-yank tot0rokr/tmux-cuecard tot0rokr/tmux-greenroom' \
        "$(tq show -gv @tpm_plugins 2>&1)"
    want=$(sed -n 's/^set -g status-style "\(.*\)"$/\1/p' "$T_CFG/tmux/themes/github.conf")
    assert_eq "A03 github theme status-style" "$want" "$(tq show -gv status-style 2>&1)"
    t_status_right_once "first load"
    tq source-file "$conf" >"$o/reload.log" 2>&1
    t_status_right_once "after source-file of tmux.conf"
    if [ "$mode" = full ]; then
        assert_eq "A01 tmux escape-time" 10 "$(tq show -sv escape-time 2>&1)"
        assert_eq "A01 tmux pane-border-lines" heavy "$(tq show -gwv pane-border-lines 2>&1)"
        assert_eq "A06 tmux bell-action" other "$(tq show -gv bell-action 2>&1)"
        assert_eq "A06 tmux visual-bell" off "$(tq show -gv visual-bell 2>&1)"
        assert_eq "A06 tmux monitor-bell" on "$(tq show -gwv monitor-bell 2>&1)"
        t_env LANG=C.UTF-8 "${tpath[@]}" timeout 300 "$plug/tpm/bin/clean_plugins" \
            >"$o/clean_plugins.log" 2>&1
        for p in "${plugins[@]}"; do
            if [ -d "$plug/$p" ]; then _pass "A03 clean_plugins kept $p"
            else _hardfail "A03 clean_plugins removed $p"; fi
        done
    fi
    assert_absent "$HOME/.tmux"
    assert_absent "$T_CFG/tmux/plugins"
    printf '  TPM revision: %s\n' "$(t_git -C "$plug/tpm" rev-parse HEAD 2>&1)"
    t_tmux_kill
}

# check_a04_nvim [full|provider]
# shellcheck disable=SC2120  # the argument is optional
check_a04_nvim() {
    local mode=${1:-full} o=$T_WORK/a04 lua=$T_CFG/nvim/lua state k
    group "A04 nvim ($mode)"
    mkdir -p "$o/local-plugin" "$lua/plugins"
    if [ "$mode" = full ]; then
        printf '%s\n' 'vim.g.dotfiles_t_local = 1' >"$lua/local.lua"
        printf 'return { { name = "dotfiles-t-local", dir = "%s", lazy = false, init = function() vim.g.dotfiles_t_plugins_local = 1 end } }\n' \
            "$o/local-plugin" >"$lua/plugins/local.lua"
    fi
    t_nvim_lua "$T_FIX/editor/nvim-state.lua" "$o/state"
    if [ ! -s "$o/state" ]; then
        _hardfail "A04 nvim wrote no state"
        __assert_show "$o/state.log"
        return
    fi
    if [ "$mode" = full ]; then
        state=$(t_kv "$o/state" state)
        assert_eq "A04 lua/local.lua ran" 1 "$(t_kv "$o/state" local)"
        assert_eq "A04 lua/plugins/local.lua was imported" 1 "$(t_kv "$o/state" plugins_local)"
        assert_eq "A04 v:errmsg after startup" "" "$(t_kv "$o/state" errmsg)"
        assert_eq "A04 stdpath('state')" "$T_STATE/nvim" "$state"
        for k in undodir directory backupdir obsession_dir; do
            assert_prefix "A04 nvim $k under stdpath('state')" "$state/" "$(t_kv "$o/state" "$k")"
        done
        assert_eq "A04 runtimepath has ~/.local/opt/fzf" true "$(t_kv "$o/state" rtp_fzf)"
        assert_no_output "A04 nvim --headless +qa with lua/local.lua" -- t_login timeout 120 nvim --headless +qa
        rm -f "$lua/local.lua"
        assert_no_output "A04 nvim --headless +qa without lua/local.lua" -- t_login timeout 120 nvim --headless +qa
        rm -f "$lua/plugins/local.lua"
    fi
    assert_eq "A04 python3 provider works" 1 "$(t_kv "$o/state" python3)"
    assert_eq "A04 g:python3_host_prog" "$T_DATA/nvim/venv/bin/python" "$(t_kv "$o/state" python3_host_prog)"
}

check_a05_git() {
    local cfg=$T_CFG/git/config o=$T_WORK/a05 got
    group "A05 git"
    mkdir -p "$o"
    sed -n '/^# >>> dotfiles >>>$/,/^# <<< dotfiles <<<$/p' "$cfg" >"$o/block.before"
    grep '^#' "$cfg" >"$o/comments.before"
    (cd /tmp && t_env git config --global user.name 'Dotfiles Tester' &&
        t_env git config --global user.email tester@example.invalid) >"$o/write.log" 2>&1
    assert_grep "$cfg" 'name = Dotfiles Tester' 'A05 git config --global writes the XDG entry'
    sed -n '/^# >>> dotfiles >>>$/,/^# <<< dotfiles <<<$/p' "$cfg" >"$o/block.after"
    assert_exit0 "A05 managed block unchanged by git config --global" -- cmp -s "$o/block.before" "$o/block.after"
    assert_empty "A05 comments kept by git config --global" "$(grep -vxF -f <(grep '^#' "$cfg") "$o/comments.before")"
    assert_absent "$HOME/.gitconfig"
    # petalinux pattern: another HOME that gets only a copy of ~/.config/git
    # (the common link dangles there) still sees the identity.
    rm -rf "$o/other"
    mkdir -p "$o/other/.config"
    cp -a "$T_CFG/git" "$o/other/.config/git"
    got=$(cd /tmp && env -i HOME="$o/other" XDG_CONFIG_HOME="$o/other/.config" PATH="$BASE_PATH" git config user.name 2>&1)
    assert_eq "A05 a copy of ~/.config/git carries the identity" 'Dotfiles Tester' "$got"
}

check_a06_bell() {
    local o=$T_WORK/a06 bell=$HOME/.local/opt/bell-bash noti=$HOME/.local/opt/noti-bash f a
    group "A06 bell/noti wiring"
    mkdir -p "$o/fake1" "$o/fake2"
    install -m 755 "$T_FIX/bin/fake-claude" "$o/fake1/claude"
    install -m 755 "$T_FIX/bin/fake-claude" "$o/fake2/claude-auto"
    f=$o/cmds.bash
    printf '%s\n' \
        "if ! command -v claude-auto >/dev/null 2>&1; then" \
        "    FAKE_CLAUDE_LOG=$o/via-claude.args PATH=$o/fake1:\$PATH claude --t-arg" \
        "fi" \
        "FAKE_CLAUDE_LOG=$o/via-claude-auto.args PATH=$o/fake2:$o/fake1:\$PATH claude --t-arg" \
        "declare -F bell_skip >$o/bell_skip" \
        "( set -o posix; set ) >>$o/hooks 2>&1" \
        "type -P bell-send >$o/bell-send" \
        "printf '%s\n' \"\$BELL_BASH_BACKENDS\" >$o/backends" \
        "if declare -F __bell_bash_dispatch >/dev/null; then" \
        "    __bell_bash_backend_bel() { printf 'bel\n' >>$o/dispatch; }" \
        "    __bell_bash_backend_notify_send() { printf 'notify-send\n' >>$o/dispatch; }" \
        "    bell t-a06 >/dev/null 2>&1" \
        "fi" >"$f"
    # Without set -T, `.` hides the DEBUG trap while FILE runs, so the traps
    # are listed before it (t_ishell -l, plus that).
    t_pty 120 "bash -l -i -c 'trap -p >$o/hooks; . $f' 2>$f.err" >"$f.pty" 2>&1
    for a in "$o/via-claude.args" "$o/via-claude-auto.args"; do
        [ -e "$a" ] || continue
        assert_line "$a" "argv0=$(basename "$a" .args | sed 's/^via-//')" "A06 wrapper ran ${a##*/via-}"
        if t_pair "$a" --plugin-dir "$bell"; then _pass "A06 --plugin-dir $bell (${a##*/})"
        else _hardfail "A06 --plugin-dir $bell (${a##*/})"; fi
        if t_pair "$a" --plugin-dir "$noti"; then _pass "A06 --plugin-dir $noti (${a##*/})"
        else _hardfail "A06 --plugin-dir $noti (${a##*/})"; fi
        if [ -f "$bell/claude-settings.json" ]; then
            if t_pair "$a" --settings "$bell/claude-settings.json"; then _pass "A06 --settings for bell (${a##*/})"
            else _hardfail "A06 --settings for bell (${a##*/})"; fi
        else
            finding "A06 the bell clone has no claude-settings.json"
        fi
        assert_no_grep "$a" "^$noti/.*settings" "A06 no --settings for noti (${a##*/})"
        assert_eq "A06 user arguments come last (${a##*/})" --t-arg "$(tail -n 1 "$a")"
    done
    assert_file "$o/via-claude-auto.args"
    if [ -s "$o/bell_skip" ]; then _pass "A06 bell functions defined"
    else _hardfail "A06 bell functions defined"; fi
    assert_grep "$o/hooks" '__bell_bash_(pre_debug|preexec)' 'A06 bell preexec hook registered'
    assert_grep "$o/hooks" '__bell_bash_(prompt_command|precmd)' 'A06 bell precmd hook registered'
    assert_eq "A06 bell-send on PATH" "$bell/bin/bell-send" "$(cat "$o/bell-send" 2>/dev/null)"
    assert_absent "$HOME/.claude/skills/bell"
    assert_absent "$HOME/.claude/skills/noti"
    if [ -f "$HOME/.claude/settings.json" ]; then
        assert_no_grep "$HOME/.claude/settings.json" 'bell-send' 'A06 no bell hooks in ~/.claude/settings.json'
    fi
    if grep -qx 'export BELL_BASH_BACKENDS=bel' "$HOME/.bashrc"; then
        assert_eq "A06 local zone override of BELL_BASH_BACKENDS" bel "$(cat "$o/backends" 2>/dev/null)"
        if [ ! -e "$o/dispatch" ]; then
            finding "A06 could not observe which backends bell uses (internals changed?)"
        elif [ "$(cat "$o/dispatch")" != bel ]; then
            finding "A06 bell used '$(paste -sd, "$o/dispatch")', not the local zone's BELL_BASH_BACKENDS=bel"
        else
            _pass "A06 bell uses the local zone's BELL_BASH_BACKENDS"
        fi
    fi
}

# check_a06_prompt_hooks — PROMPT_COMMAND of a non-login `bash -i` (login
# shells get bash-preexec from the image's /etc/profile.d, which hides the
# order) after start-up and after `. ~/.bashrc`: bell wraps the finished
# chain, and no hook is installed twice. With a hook in the chain twice,
# running PROMPT_COMMAND recurses until bash crashes. Then the same for an
# old shell whose machine section sourced the bell clone at its old path,
# after the clone moved back. ~/.bashrc and the clone are restored.
check_a06_prompt_hooks() {
    local o=$T_WORK/a06p rc=$HOME/.bashrc bell=$HOME/.local/opt/bell-bash f
    group "A06 prompt hooks of non-login shells"
    mkdir -p "$o"
    printf '%s\n' \
        "declare -p PROMPT_COMMAND __bell_bash_prev_pc >$o/first 2>&1" \
        '. ~/.bashrc' \
        "declare -p PROMPT_COMMAND STARSHIP_PROMPT_COMMAND __bell_bash_prev_pc >$o/second 2>&1" \
        'eval "${PROMPT_COMMAND[*]}"; eval "${PROMPT_COMMAND[*]}"' \
        "echo survived >$o/alive" >"$o/rc.bash"
    t_ishell 120 "$o/rc.bash"
    assert_line "$o/first" 'declare -- PROMPT_COMMAND="__bell_bash_prompt_command"' \
        'A06 bell wraps the finished prompt chain (non-login)'
    assert_grep "$o/first" '__bell_bash_prev_pc=".*starship_precmd' 'A06 bell loads after starship'
    assert_grep "$o/first" '__bell_bash_prev_pc=".*__zoxide_hook' 'A06 bell loads after zoxide'
    if [ -e "$o/alive" ]; then _pass "A06 prompt hooks do not recurse after . ~/.bashrc"
    else
        _hardfail "A06 prompt hooks do not recurse after . ~/.bashrc"
        __assert_show "$o/rc.bash.pty"
    fi
    assert_line "$o/second" 'declare -- PROMPT_COMMAND="__bell_bash_prompt_command"' \
        'A06 bell still wraps the chain after . ~/.bashrc'
    assert_eq "A06 one history hook after . ~/.bashrc" 1 "$(grep -o 'history -a' "$o/second" | wc -l)"
    assert_eq "A06 one starship hook after . ~/.bashrc" 1 "$(grep -o starship_precmd "$o/second" | wc -l)"
    assert_no_grep "$o/second" 'STARSHIP_PROMPT_COMMAND=.*__bell_bash_prompt_command' 'A06 starship does not wrap bell'

    cp "$rc" "$o/bashrc.save" || return
    if ! mv "$bell" "$HOME/.bell-bash"; then
        _hardfail "A06 cannot move $bell to ~/.bell-bash"
        return
    fi
    printf '%s\n' '. "$HOME/.bell-bash/bell"' >>"$rc"
    f=$o/old.bash
    printf '%s\n' \
        "command mv ~/.bell-bash ~/.local/opt/bell-bash; command cp -f $o/bashrc.save ~/.bashrc" \
        '. ~/.bashrc' \
        "declare -p PROMPT_COMMAND STARSHIP_PROMPT_COMMAND __bell_bash_prev_pc >$o/old-second 2>&1" \
        'eval "${PROMPT_COMMAND[*]}"; eval "${PROMPT_COMMAND[*]}"' \
        "echo survived >$o/alive-old" >"$f"
    t_ishell 120 "$f"
    [ ! -d "$HOME/.bell-bash" ] || [ -e "$bell" ] || mv "$HOME/.bell-bash" "$bell"
    cat "$o/bashrc.save" >"$rc"
    if [ -e "$o/alive-old" ]; then _pass "A06 a pre-migration shell survives . ~/.bashrc"
    else
        _hardfail "A06 a pre-migration shell survives . ~/.bashrc"
        __assert_show "$f.pty"
    fi
    assert_line "$o/old-second" 'declare -- PROMPT_COMMAND="__bell_bash_prompt_command"' \
        'A06 a pre-migration shell: bell wraps the chain after . ~/.bashrc'
    assert_eq "A06 a pre-migration shell: one history hook after . ~/.bashrc" 1 \
        "$(grep -o 'history -a' "$o/old-second" | wc -l)"
}

# __t_bell_shell DIR NAME MODE — types the shell.exp lines of DIR/NAME.steps
# into an interactive bash in a pty (MODE i: bash -i, li: bash -l -i).
__t_bell_shell() {
    local sh=(bash -i)
    [ "$3" = li ] && sh=(bash -l -i)
    t_env timeout 300 expect "$T_FIX/expect/shell.exp" 0 "$1/$2.steps" -- "${sh[@]}" >"$1/$2.pty" 2>&1
}

# __t_bell_sent LABEL LOG WANT — the commands bell notified about while LOG
# was the log, joined with '|', are WANT (empty: none).
__t_bell_sent() { assert_eq "$1" "$3" "$(paste -sd'|' "$2" 2>/dev/null)"; }

# __t_bell_alive LABEL DIR NAME — the shell had the same pid before and after
# it sourced ~/.bashrc again, and answered after it.
__t_bell_alive() {
    local a b
    a=$(cat "$2/$3.pid1" 2>/dev/null)
    b=$(cat "$2/$3.pid2" 2>/dev/null)
    if [ -n "$a" ] && [ "$a" = "$b" ]; then
        _pass "$1 (pid $a)"
    else
        _hardfail "$1 (pid '$a' before, '$b' after)"
        __assert_show "$2/$3.pty"
    fi
}

# check_a06_bell_runtime — bell's auto-trigger in live shells. `bash -i`
# loads no bash-preexec, so bell runs its own DEBUG trap and PROMPT_COMMAND
# hook; `bash -l -i` gets bash-preexec where the image's WezTerm shell
# integration loads it. A __bell_bash_dispatch in the local zone logs the
# command of every notification instead of sending it. ~/.bashrc and the
# bell clone are back in place afterwards.
check_a06_bell_runtime() {
    local o=$T_WORK/a06r rc=$HOME/.bashrc bell=$HOME/.local/opt/bell-bash m d n
    group "A06 bell auto-trigger in live shells"
    mkdir -p "$o"
    if [ ! -f "$bell/bell" ]; then
        _hardfail "A06 no bell clone at $bell"
        return
    fi
    cp "$rc" "$o/bashrc.orig" || return
    printf '%s\n' 'BELL_BASH_THRESHOLD=2' \
        '__bell_bash_dispatch() { printf "%s\n" "$5" >>"${__t_bell_log:-/dev/null}"; }' >"$o/zone"
    cat "$o/bashrc.orig" "$o/zone" >"$o/bashrc.new"
    # An old shell: its machine section sourced the clone at the old path,
    # after the shared config.
    {
        cat "$o/bashrc.orig"
        printf '%s\n' 'export PATH="$HOME/.bell-bash/bin:$PATH"' 'source "$HOME/.bell-bash/bell"'
        cat "$o/zone"
    } >"$o/bashrc.old"
    for m in i li; do
        d='bash -i'
        [ "$m" = li ] && d='bash -l -i'

        n=new-$m
        cat "$o/bashrc.new" >"$rc"
        printf '%s\n' \
            "{ declare -p preexec_functions >/dev/null 2>&1 && echo bash-preexec || echo debug-trap; } >$o/$n.hooks" \
            "__t_bell_log=$o/$n.idle" '#idle 3' 'true' \
            "__t_bell_log=$o/$n.sleep" 'sleep 3' \
            "__t_bell_log=$o/$n.resource" "printf '%s\n' \$\$ >$o/$n.pid1" '. ~/.bashrc' \
            "printf '%s\n' \$\$ >$o/$n.pid2" \
            "__t_bell_log=$o/$n.idle2" '#idle 3' 'true' \
            "__t_bell_log=$o/$n.sleep2" 'sleep 3' >"$o/$n.steps"
        __t_bell_shell "$o" "$n" "$m"
        if [ "$m" = i ]; then
            assert_eq "A06 bash -i runs bell's own DEBUG-trap hooks" debug-trap "$(cat "$o/$n.hooks" 2>/dev/null)"
        else
            printf '  bell hooks in bash -l -i: %s\n' "$(cat "$o/$n.hooks" 2>/dev/null)"
        fi
        __t_bell_sent "A06 $d: true after 3 s at the prompt notifies nothing" "$o/$n.idle" ''
        __t_bell_sent "A06 $d: sleep 3 notifies once, as 'sleep 3'" "$o/$n.sleep" 'sleep 3'
        __t_bell_alive "A06 $d: the shell survives '. ~/.bashrc'" "$o" "$n"
        __t_bell_sent "A06 $d, after '. ~/.bashrc': true after 3 s at the prompt notifies nothing" "$o/$n.idle2" ''
        __t_bell_sent "A06 $d, after '. ~/.bashrc': sleep 3 notifies once, as 'sleep 3'" "$o/$n.sleep2" 'sleep 3'

        # The old shell moves the clone as `migrate tools` does, then sources
        # the new ~/.bashrc.
        n=old-$m
        cat "$o/bashrc.old" >"$rc"
        if ! mv "$bell" "$HOME/.bell-bash"; then
            _hardfail "A06 cannot move $bell to ~/.bell-bash"
            break
        fi
        printf '%s\n' \
            "printf '%s\n' \$\$ >$o/$n.pid1" \
            'command mv ~/.bell-bash ~/.local/opt/bell-bash' 'command ln -s .local/opt/bell-bash ~/.bell-bash' \
            "command cp $o/bashrc.new ~/.bashrc" \
            "__t_bell_log=$o/$n.resource" '. ~/.bashrc' "printf '%s\n' \$\$ >$o/$n.pid2" \
            "__t_bell_log=$o/$n.sleep" 'sleep 3' >"$o/$n.steps"
        __t_bell_shell "$o" "$n" "$m"
        [ ! -L "$HOME/.bell-bash" ] || rm -f "$HOME/.bell-bash"
        [ ! -d "$HOME/.bell-bash" ] || [ -e "$bell" ] || mv "$HOME/.bell-bash" "$bell"
        __t_bell_alive "A06 $d, an old shell: survives '. ~/.bashrc' after the clone moved" "$o" "$n"
        __t_bell_sent "A06 $d, an old shell, after '. ~/.bashrc': sleep 3 notifies once, as 'sleep 3'" \
            "$o/$n.sleep" 'sleep 3'
    done
    cat "$o/bashrc.orig" >"$rc"
}

check_a07_allowlist() {
    local e bad=''
    group "A07 home top level"
    while IFS= read -r e; do
        case $e in
            .bashrc | .profile | .bash_logout | .config | .local | .cache | .dotfiles) ;;
            .python_history | .lesshst | .ssh | .bun | package.json | node_modules) ;;
            agents | .claude* | .agents | .codex | .gemini) [ "$T_TIER" = full ] || bad+=" $e" ;;
            *) bad+=" $e" ;;
        esac
    done < <(find "$HOME" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
    assert_empty "A07 nothing outside the allow-list at the top of $HOME" "${bad# }"
}

check_a08_relative_links() {
    local l t n=0 bad='' list=$T_WORK/a08.links
    group "A08 no absolute symlinks"
    {
        cut -f1 "$T_STATE/dotfiles/manifest.tsv" 2>/dev/null
        for l in dotfiles fnm nvim tmux clangd btop; do
            [ ! -L "$HOME/.local/bin/$l" ] || printf '%s\n' "$HOME/.local/bin/$l"
        done
        for l in .cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash dotfiles; do
            [ ! -L "$HOME/$l" ] || printf '%s\n' "$HOME/$l"
        done
        find "$T_CFG" -path "$T_CFG/opencode" -prune -o -type l -print
    } >"$list"
    while IFS= read -r l; do
        n=$((n + 1))
        t=$(readlink "$l")
        case $t in
            /*) bad+="$l -> $t"$'\n' ;;
        esac
    done <"$list"
    assert_empty "A08 $n links checked, none absolute" "$bad"
}

# check_a09_repo_clean [REPO [portable]]
# shellcheck disable=SC2120  # the arguments are optional
check_a09_repo_clean() {
    local repo=${1:-$T_REPO} b=$T_DIR/baseline
    group "A09 checkout unchanged by install and tool use ($repo)"
    if [ "${2:-}" = portable ]; then
        assert_empty "A09 portable checkout: git status clean" "$(t_git -C "$repo" status --porcelain 2>&1)"
        assert_empty "A09 portable checkout: no ignored files in the whole-dir-linked dirs" \
            "$(t_git -C "$repo" ls-files -o -i --exclude-standard -- .config/bash .config/fzf .config/readline 2>&1)"
        return
    fi
    assert_empty "A09 git status equals the image baseline" \
        "$(diff "$b/status.txt" <(t_git -C "$repo" status --porcelain 2>&1))"
    assert_eq "A09 staged diff equals the image baseline" "$(cat "$b/diff-cached.sha256")" \
        "$(t_git -C "$repo" diff --cached | sha256sum)"
    assert_empty "A09 ignored files equal the image baseline" \
        "$(diff "$b/ignored.txt" <(t_git -C "$repo" ls-files -o -i --exclude-standard 2>&1))"
}

check_a10_history() {
    local hf=$T_STATE/bash/history o=$T_WORK/a10 n h out
    group "A10 history"
    mkdir -p "$o"
    rm -f "$hf"
    t_pty 60 "bash -i -c 'printf %s \"\$HISTFILE\" >$o/histfile; history -s t-a10; history -a'" >/dev/null 2>&1
    assert_eq "A10 HISTFILE" "$hf" "$(cat "$o/histfile" 2>/dev/null)"
    assert_eq "A10 bash creates the history file with mode 600" 600 "$(stat -c %a "$hf" 2>&1)"
    seq -f 'echo hist-%g' 5000 >>"$hf"
    t_pty 60 "bash -i -c true" >/dev/null 2>&1
    n=$(wc -l <"$hf")
    if [ "$n" -ge 5000 ]; then _pass "A10 a 5000-line history survives an interactive start and exit ($n lines)"
    else _hardfail "A10 history truncated to $n lines"; fi
    t_pty XDG_STATE_HOME="$o/fresh-state" 60 "bash -i -c true" >/dev/null 2>&1
    assert_file "$o/fresh-state/bash"

    # An "anything else" ~/.bashrc with a small HISTFILESIZE, on an account
    # whose old ~/.bash_history has 5000 lines.
    t_snapshot || { _hardfail "A10 snapshot of the checkout"; return; }
    h=$(t_acct a10) || { _hardfail "A10 account setup"; return; }
    printf '%s\n' '# hand-written bashrc' 'HISTSIZE=2000' 'HISTFILESIZE=2000' 'alias t-a10=true' >"$h/.bashrc"
    seq -f 'echo old-%g' 5000 >"$h/.bash_history"
    out=$( (t_home "$h"; t_env "$T_REPO/install.sh" --yes) 2>&1)
    assert_match "A10 install warns about the small HISTFILESIZE" 'HISTFILESIZE' "$out"
    (
        t_home "$h"
        for _ in 1 2 3; do
            t_pty 60 "bash -i -c true" >/dev/null 2>&1
        done
    )
    n=$(wc -l <"$h/.local/state/bash/history" 2>/dev/null)
    if [ "${n:-0}" -ge 5000 ]; then _pass "A10 old history imported and kept across three starts ($n lines)"
    else _hardfail "A10 imported history has ${n:-0} lines after three starts"; fi
    assert_absent "$h/.bash_history"
}

# The major version in a file holding `node -v` output.
__t_major() {
    local v
    v=$(cat "$1" 2>/dev/null)
    v=${v#v}
    printf '%s' "${v%%.*}"
}

check_a12_fnm() {
    local o=$T_WORK/a12 dir=/tmp/nodeswitch/v20 server=t-a12 def rt cmd ms path p
    group "A12 fnm auto-switch and multishell location"
    mkdir -p "$o" "$dir"
    printf '20\n' >"$dir/.node-version"
    printf '{ "name": "t-home" }\n' >"$HOME/package.json"
    def=$(t_login node -v 2>&1)
    assert_match "A12 a default node exists" '^v[0-9]+\.' "$def"
    t_login zoxide add "$dir" >/dev/null 2>&1
    # A pane shell gets real prompts, so PROMPT_COMMAND hooks run between lines.
    tq -L "$server" -f /dev/null new-session -d -s a12 -x 200 -y 50
    if ! t_pane_run -L "$server" a12: "$o/ready" ':' 120; then
        _hardfail "A12 pane shell did not start"
        t_tmux_kill -L "$server"
        return
    fi
    # One command per line, so a prompt (and its hooks) runs between them.
    for cmd in "node -v >$o/home0" "type -t cd >$o/cd-type" "cd $dir" "node -v >$o/cd" "cd ~" \
        "z nodeswitch v20 >/dev/null" "node -v >$o/z" "cd ~" \
        "pushd $dir >/dev/null" "node -v >$o/pushd" "popd >/dev/null" \
        "cd /tmp" "cd ~ >$o/cdhome.out 2>$o/cdhome.err" ": >$o/done"; do
        t_pane_send -L "$server" a12: "$cmd"
    done
    t_wait_file "$o/done" 120 || _hardfail "A12 pane commands did not finish"
    tq -L "$server" capture-pane -p -J -S - -t a12: >"$o/pane.txt" 2>&1
    # A shell that starts in the dir switches at its first prompt.
    p=$(tq -L "$server" new-window -d -P -F '#{pane_id}' -c "$dir" -t a12:)
    t_pane_run -L "$server" "$p" "$o/startdir.done" "node -v >$o/startdir" 120 ||
        _hardfail "A12 the shell started in the dir did not answer"
    t_tmux_kill -L "$server"
    rm -f "$HOME/package.json"
    def=${def#v}
    assert_eq "A12 cd ~ uses the default node" "${def%%.*}" "$(__t_major "$o/home0")"
    assert_eq "A12 cd is the builtin (no fnm alias)" builtin "$(cat "$o/cd-type" 2>/dev/null)"
    assert_eq "A12 cd into a .node-version 20 dir switches" 20 "$(__t_major "$o/cd")"
    assert_eq "A12 z into it switches" 20 "$(__t_major "$o/z")"
    assert_eq "A12 pushd into it switches" 20 "$(__t_major "$o/pushd")"
    assert_eq "A12 a shell started in it uses 20" 20 "$(__t_major "$o/startdir")"
    assert_empty "A12 cd ~ with a package.json without engines prints nothing" \
        "$(cat "$o/cdhome.out" "$o/cdhome.err" 2>&1)"
    assert_empty "A12 no fnm messages in the pane" "$(grep -iE 'error|warn|engines|can.t' "$o/pane.txt")"

    rt=$o/runtime
    mkdir -m 700 "$rt"
    t_pty XDG_RUNTIME_DIR="$rt" 60 "bash -i -c 'printf %s \"\$FNM_MULTISHELL_PATH\" >$o/ms-runtime'" >/dev/null 2>&1
    t_pty 60 "bash -i -c 'printf \"%s\n\" \"\$FNM_MULTISHELL_PATH\" \"\$PATH\" >$o/ms-state'" >/dev/null 2>&1
    assert_prefix "A12 multishell dir under XDG_RUNTIME_DIR when it is set" \
        "$rt/fnm_multishells/" "$(cat "$o/ms-runtime" 2>/dev/null)"
    ms=$(sed -n 1p "$o/ms-state" 2>/dev/null)
    assert_prefix "A12 multishell dir under the state dir when XDG_RUNTIME_DIR is unset" \
        "$T_STATE/fnm_multishells/" "$ms"
    # The default version stays reachable when the multishell dir vanishes.
    path=:$(sed -n 2p "$o/ms-state" 2>/dev/null):
    path=${path%%":$T_DATA/fnm/aliases/default/bin:"*}:
    if [ -n "$ms" ] && [[ $path == *":$ms/bin:"* ]]; then
        _pass "A12 the multishell bin comes before the fnm default bin on PATH"
    else
        _hardfail "A12 the multishell bin does not come before the fnm default bin on PATH"
    fi
}

# t_btop CONFIG_HOME LOG — runs btop in a sized pty and quits it with q.
t_btop() {
    (sleep 4; printf q) | t_env LANG=C.UTF-8 XDG_CONFIG_HOME="$1" timeout 30 \
        script -qec "stty rows 40 cols 120; exec $HOME/.local/bin/btop" /dev/null >"$2" 2>&1
}

check_a13_btop() {
    local o=$T_WORK/a13 repo=$T_REPO/.config/btop/btop.conf s h m
    group "A13 btop and its config link"
    mkdir -p "$o"
    h=$(sha256sum <"$repo")
    t_btop "$T_CFG" "$o/run.log"
    assert_rel_link "$T_CFG/btop/btop.conf" "$repo"
    assert_eq "A13 btop left the repo btop.conf unchanged" "$h" "$(sha256sum <"$repo")"
    # Write probe: a linked copy that asks btop to save, minus one option it
    # will write back.
    s=$o/probe-config
    rm -rf "$s"
    mkdir -p "$s/btop"
    sed -e 's/^save_config_on_exit = .*/save_config_on_exit = true/' -e '/^proc_tree = /d' \
        "$repo" >"$s/btop.conf.copy"
    ln -s ../btop.conf.copy "$s/btop/btop.conf"
    m=$(t_marker)
    t_btop "$s" "$o/probe.log"
    if [ -L "$s/btop/btop.conf" ]; then _pass "A13 btop kept a linked config a link when saving"
    else _hardfail "A13 btop replaced a linked config with a file"; fi
    if [ "$s/btop.conf.copy" -nt "$m" ] && grep -q '^proc_tree = ' "$s/btop.conf.copy"; then
        _pass "A13 btop wrote through the link"
    else
        _hardfail "A13 btop did not write through the link (probe inconclusive)"
    fi
}

check_a14_startup() {
    local base ssh i t0 t1 runs=
    group "A14 start-up time"
    base=$(t_time_median 20 t_env bash --norc --noprofile -c true)
    ssh=$(t_time_median 20 t_env "${T_SSH[@]}" bash -c true)
    if [ $((ssh - base)) -lt 20 ]; then
        _pass "A14 ssh-style bash -c true ${ssh}ms vs bash --norc ${base}ms (median of 20)"
    else
        _hardfail "A14 ssh-style bash -c true ${ssh}ms is 20ms or more above bash --norc ${base}ms"
    fi
    for i in 1 2 3 4 5; do
        t0=${EPOCHREALTIME/./}
        t_pty 60 "bash -l -i -c exit" >/dev/null 2>&1
        t1=${EPOCHREALTIME/./}
        runs+=" $(((t1 - t0) / 1000))"
    done
    printf '  login interactive start-up (ms, pty, tier %s):%s\n' "$T_TIER" "$runs"
}

check_a19_build() {
    local c=$T_DIR/build-checks t
    group "A19 rc files untouched by the build-time bootstrap"
    assert_file "$c/rc-lite.before"
    for t in lite full; do
        [ -e "$c/rc-$t.before" ] || continue
        assert_empty "A19 $t tool layer left ~/.bashrc and ~/.profile unchanged" \
            "$(diff "$c/rc-$t.before" "$c/rc-$t.after" 2>&1)"
    done
}

check_a20_vim() {
    local o=$T_WORK/a20/state k
    group "A20 vim (XDG-capable build)"
    mkdir -p "${o%/*}"
    rm -f "$o"
    t_pty T_RESULT="$o" 120 "vim -S $T_FIX/editor/vim-state.vim" >"$o.log" 2>&1
    if [ ! -s "$o" ]; then
        _hardfail "A20 vim wrote no state"
        return
    fi
    assert_eq "A20 vim has patch 9.1.0327" 1 "$(t_kv "$o" patch-9.1.0327)"
    assert_eq "A20 vim read the XDG vimrc" "$T_CFG/vim/vimrc" "$(t_kv "$o" initvim)"
    assert_prefix "A20 vim-plug home under the data dir" "$T_DATA/vim/plugged" "$(t_kv "$o" plug_home)"
    assert_match "A20 vim-plug has plugins" '^[1-9]' "$(t_kv "$o" plugs)"
    assert_eq "A20 every vim plugin installed" "" "$(t_kv "$o" plugs_missing)"
    for k in undodir directory backupdir; do
        assert_prefix "A20 vim $k under the state dir" "$T_STATE/vim/" "$(t_kv "$o" "$k")"
    done
    assert_eq "A20 vim viminfofile" "$T_STATE/vim/viminfo" "$(t_kv "$o" viminfofile)"
    assert_eq "A20 coc config home is the vim config dir" "$T_CFG/vim" "$(t_kv "$o" coc_config_home)"
    assert_eq "A01 vim: fzf#run() exists" 1 "$(t_kv "$o" fzf_run)"
    assert_eq "A01 vim: :LS exists" 2 "$(t_kv "$o" ls_cmd)"
    assert_eq "A01 vim: :Conflicted exists" 2 "$(t_kv "$o" conflicted)"
    assert_absent "$HOME/.vim"
    assert_absent "$HOME/.viminfo"
}

check_a21_wezterm() {
    local w=$T_CFG/wezterm o=$T_WORK/a21 f
    group "A21 wezterm"
    mkdir -p "$o"
    assert_exit0 "A21 luac5.4 -p wezterm.lua" -- luac5.4 -p "$w/wezterm.lua"
    assert_exit0 "A21 luac5.4 -p common.lua" -- luac5.4 -p "$w/common.lua"
    assert_exit0 "A21 a stub wezterm loads wezterm.lua; apply() runs once" -- \
        lua5.4 "$T_FIX/wezterm/load.lua" "$T_FIX/wezterm" "$w" "$HOME" "$w/wezterm.lua"
    # The managed block placed after `return config` must not pass.
    {
        t_outside_blocks "$w/wezterm.lua" '-- '
        sed -n '/^-- >>> dotfiles >>>$/,/^-- <<< dotfiles <<<$/p' "$w/wezterm.lua"
    } >"$o/block-after-return.lua"
    assert_exit 1 "A21 a block after return config is rejected" -- luac5.4 -p "$o/block-after-return.lua"
    for f in "$T_REPO"/.local/share/fonts/*.ttf; do
        assert_rel_link "$T_DATA/fonts/${f##*/}" "$f"
    done
    t_env fc-cache >/dev/null 2>&1
    if t_env fc-list 2>/dev/null | grep -qi d2coding; then _pass "A21 fc-list finds D2Coding"
    else _hardfail "A21 fc-list finds D2Coding"; fi
}

check_a24_tools() {
    local o=$T_WORK/a24 f line n p rc cargo_tools=" fd bat rg dust eza hyperfine difft tldr choose zoxide "
    group "A24 tools (full tier)"
    mkdir -p "$o"
    f=$o/cmds.bash
    printf '%s\n' \
        "a24=$o" \
        'for t in nvim:--version jq:--version lazygit:--version gh:--version lazydocker:--version delta:--version gdu:--version up:--help fzf:--version starship:--version clangd:--version btop:--version nnn:-V tmux:-V fd:--version bat:--version rg:--version dust:--version eza:--version hyperfine:--version difft:--version tldr:--version choose:--version zoxide:--version cargo:--version rustc:--version node:--version npm:--version fnm:--version; do' \
        '    n=${t%%:*}; p=$(type -P "$n"); "$n" "${t#*:}" >"$a24/out.$n" 2>&1; printf "%s\t%s\t%s\n" "$n" "$p" "$?"' \
        "done >$o/tools.tsv" \
        "type -P bell-send noti >$o/clones.txt" >"$f"
    t_ishell -l 600 "$f"
    if [ ! -s "$o/tools.tsv" ]; then
        _hardfail "A24 tool probe wrote nothing"
        __assert_show "$f.err"
        return
    fi
    while IFS=$'\t' read -r n p rc; do
        # up (akavel/up) prints its usage and exits 2 for --help, -h and --version alike.
        [ "$n" = up ] && [ "$rc" = 2 ] && grep -q '^Usage:' "$o/out.$n" && rc=0
        if [ -n "$p" ] && [ "$rc" = 0 ]; then _pass "A24 $n -> $p runs"
        else
            _hardfail "A24 $n (path '$p', exit $rc)"
            __assert_show "$o/out.$n" 5
        fi
        case $cargo_tools in
            *" $n "*) assert_prefix "A24 $n is a cargo tool under the data dir" "$T_DATA/cargo/bin/" "$p" ;;
        esac
    done <"$o/tools.tsv"
    assert_eq "A24 node of non-interactive shells is the fnm default" \
        "$T_DATA/fnm/aliases/default/bin/node" "$(t_login type -P node 2>&1)"
    assert_eq "A24 bell-send and noti from the clones" \
        "$HOME/.local/opt/bell-bash/bin/bell-send $HOME/.local/opt/noti-bash/bin/noti" \
        "$(paste -sd' ' "$o/clones.txt" 2>/dev/null)"
    for line in .cargo .rustup .nvm .npm .fzf .fzf-tab-completion; do
        assert_absent "$HOME/$line"
    done
}

# check_a24_fd_ignore — ~/.config/fd/ignore keeps the tool trees out of what
# the fzf widgets list (fd with --follow) from any start dir, also through the
# compat links `migrate tools` leaves, without hiding lookalike project dirs.
# Run after check_a24_tools (it creates ~/.rustup and ~/.cargo for a while);
# everything it creates is removed again.
check_a24_fd_ignore() {
    local fd=$T_DATA/cargo/bin/fd ms=$T_STATE/fnm_multishells src=$HOME/t-a24 o=$T_WORK/a24fd
    local re='(^|/)(\.?rustup|\.?cargo/registry|fnm/aliases|fnm_multishells)/' r ms_new=0 reg_new=0
    group "A24 fd ignore file (full tier)"
    mkdir -p "$o"
    if [ ! -x "$fd" ]; then
        _hardfail "A24 no fd at $fd"
        return
    fi
    if [ -e "$HOME/.rustup" ] || [ -e "$HOME/.cargo" ] || [ -e "$src" ]; then
        _hardfail "A24 ~/.rustup, ~/.cargo or $src exists already"
        return
    fi
    ln -s .local/share/rustup "$HOME/.rustup"
    ln -s .local/share/cargo "$HOME/.cargo"
    # The image's registry is empty.
    [ -e "$T_DATA/cargo/registry/index" ] || reg_new=1
    mkdir -p "$T_DATA/cargo/registry/index/t-a24" && : >"$T_DATA/cargo/registry/index/t-a24/f"
    [ -d "$ms" ] || ms_new=1
    mkdir -p "$ms" && ln -s "$(readlink -f "$T_DATA/fnm/aliases/default")" "$ms/t-a24_1"
    mkdir -p "$src/p/registry" "$src/aliases" && : >"$src/p/registry/keep.txt" && : >"$src/aliases/keep.txt"
    for r in "$HOME" "$HOME/.local" "$T_DATA" "$T_STATE"; do
        (cd "$r" && t_env "$fd" --type file --follow --hidden --exclude .git) >"$o/rel" 2>&1
        t_env "$fd" --type file --follow --hidden --exclude .git . "$r" >"$o/abs" 2>&1
        (cd "$r" && t_env "$fd" --type d --follow --hidden --exclude .git) >"$o/dirs" 2>&1
        assert_eq "A24 fd lists no tool tree from $r (Ctrl-T)" 0 "$(grep -Ec "$re" "$o/rel")"
        assert_eq "A24 fd lists no tool tree under $r (** completion)" 0 "$(grep -Ec "$re" "$o/abs")"
        assert_eq "A24 fd lists no tool tree dir from $r (Alt-C)" 0 "$(grep -Ec "$re" "$o/dirs")"
    done
    if [ "$( (cd "$T_DATA/rustup" && t_env "$fd" --type file --follow --hidden --exclude .git) | wc -l)" -gt 0 ]; then
        _pass "A24 fd still lists files when it starts inside the rustup dir"
    else
        _hardfail "A24 fd lists nothing when it starts inside the rustup dir"
    fi
    (cd "$HOME" && t_env "$fd" --type file --follow --hidden --exclude .git keep.txt) >"$o/keep" 2>&1
    assert_line "$o/keep" "${src#"$HOME"/}/p/registry/keep.txt" 'A24 fd keeps a project dir named registry'
    assert_line "$o/keep" "${src#"$HOME"/}/aliases/keep.txt" 'A24 fd keeps a project dir named aliases'
    rm -f "$HOME/.rustup" "$HOME/.cargo" "$ms/t-a24_1"
    rm -rf "$src" "$T_DATA/cargo/registry/index/t-a24"
    [ "$reg_new" = 0 ] || rmdir "$T_DATA/cargo/registry/index"
    [ "$ms_new" = 0 ] || rmdir "$ms"
}
