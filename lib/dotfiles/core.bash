# shellcheck shell=bash
# shellcheck disable=SC2034  # globals shared with the other modules
# core.bash - shared state and helpers of bin/dotfiles (sourced, never run).
#
# Loads without .git and without the install modules: the bootstrap image
# layer copies only bin/dotfiles, this file, bootstrap.bash and env.bash.
# Helpers return an exit code instead of exiting; commands map them to the
# CLI codes (1 error, 3 consent needed, 4 legacy layout, 5 refused).

if [ -z "${HOME:-}" ]; then
    printf 'dotfiles: error: HOME is not set\n' >&2
    exit 1
fi

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}
# A relative XDG_* value is only warned about (__xdg_check). Resolving it here
# keeps the state files absolute, so a run from another directory shows up as
# drift instead of missing the links.
for __v in CFG DATA STATE CACHE; do
    case ${!__v} in
        /*) ;;
        *) printf -v "$__v" '%s/%s' "$PWD" "${!__v}" ;;
    esac
done
unset __v

STATE_DIR=$STATE/dotfiles
MANIFEST=$STATE_DIR/manifest.tsv
JOURNAL=$STATE_DIR/journal.tsv
KEPT=$STATE_DIR/kept.list
BLOCKS=$STATE_DIR/blocks.tsv
XDG_FILE=$STATE_DIR/xdg.env

# Old copy-installed entry files have this line above their per-host section.
LEGACY_MARKER_RE='^# Machine-specific settings below'

printf -v __RUN_TS '%(%Y%m%d-%H%M%S)T' -1
__RUN_ID=$__RUN_TS-$$
BACKUP_DIR=$STATE_DIR/backup/$__RUN_TS
if [ -e "$BACKUP_DIR" ]; then
    BACKUP_DIR=$BACKUP_DIR-$$
fi
BACKUP_LAST=
__TMP=
declare -gA __PHYS=()

__info() { printf '%s\n' "$*" >&2; }
__warn() { printf 'dotfiles: warning: %s\n' "$*" >&2; }
__err() { printf 'dotfiles: error: %s\n' "$*" >&2; }

# __die [CODE] MESSAGE: print MESSAGE and exit with CODE (default 1).
__die() {
    local rc=1
    case ${1-} in
        ''|*[!0-9]*) ;;
        *) rc=$1; shift ;;
    esac
    __err "$*"
    exit "$rc"
}

# __tilde PATH: PATH with a leading $HOME/ shown as ~/.
__tilde() {
    printf '%s' "${1/#"$HOME"\//"~/"}"
}

# __ask PROMPT [VAR]: read one line from the terminal. With VAR the reply is
# stored there; without, succeed only on y/yes. Fails without reading when
# stdin is not a terminal, and at end of input.
__ask() {
    local __ask_reply=
    [ -t 0 ] || return 1
    printf '%s' "$1" >&2
    if ! IFS= read -r __ask_reply; then
        printf '\n' >&2
        return 1
    fi
    if [ $# -ge 2 ]; then
        printf -v "$2" '%s' "$__ask_reply"
        return 0
    fi
    case $__ask_reply in
        [yY]|[yY][eE][sS]) return 0 ;;
    esac
    return 1
}

# The checkout may belong to another uid (read-only copies, containers).
__git() {
    git -c safe.directory="$REPO" -C "$REPO" "$@"
}

# __tmpdir: create this run's private temp dir $__TMP, removed on exit.
__tmpdir() {
    [ -z "$__TMP" ] || return 0
    __TMP=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXX") || {
        __err "cannot create a temp dir"
        return 1
    }
    trap '__tmp_cleanup' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

__tmp_cleanup() {
    if [ -n "$__TMP" ]; then
        rm -rf -- "$__TMP"
    fi
}

__state_dir_ensure() {
    if [ -d "$STATE_DIR" ]; then
        return 0
    fi
    if ! mkdir -p -- "$STATE" || ! (umask 077 && mkdir -p -- "$STATE_DIR"); then
        __err "cannot create $STATE_DIR"
        return 1
    fi
}

# __state_write FILE SRC: replace the state file FILE with SRC's content
# (mode 600, temp file and rename).
__state_write() {
    local tmp
    __state_dir_ensure || return
    tmp=$(mktemp "$STATE_DIR/.${1##*/}.XXXXXX") || return
    if ! cat -- "$2" >"$tmp" || ! mv -f -- "$tmp" "$1"; then
        rm -f -- "$tmp"
        __err "cannot write $1"
        return 1
    fi
}

# __journal ACTION [PATH [DETAIL]]: append a line to journal.tsv before the
# action it names, so an interrupted run can be traced and undone.
__journal() {
    local now a=${1//[$'\t\n']/ } p=${2:--} d=${3:--}
    p=${p//[$'\t\n']/ }
    d=${d//[$'\t\n']/ }
    __state_dir_ensure || return
    printf -v now '%(%Y-%m-%dT%H:%M:%S)T' -1
    if [ ! -e "$JOURNAL" ] && ! (umask 077 && : >>"$JOURNAL"); then
        __err "cannot create $JOURNAL"
        return 1
    fi
    if ! printf '%s\t%s\t%s\t%s\t%s\n' "$__RUN_ID" "$now" "$a" "$p" "$d" >>"$JOURNAL"; then
        __err "cannot write $JOURNAL"
        return 1
    fi
}

__journal_begin() { __journal begin "$*"; }
__journal_done() { __journal 'done'; }

# __backup_dir: print this run's backup dir, creating it (mode 700) first.
__backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        __state_dir_ensure || return
        (umask 077 && mkdir -p -- "$BACKUP_DIR") || {
            __err "cannot create $BACKUP_DIR"
            return 1
        }
    fi
    printf '%s\n' "$BACKUP_DIR"
}

# __backup_dest PATH: where PATH goes in the backup dir (relative to $HOME,
# or under _abs/ for paths outside it); never an existing name.
__backup_dest() {
    local rel dest n=1
    case $1 in
        "$HOME"/*) rel=${1#"$HOME"/} ;;
        /*) rel=_abs$1 ;;
        *) rel=_abs$PWD/$1 ;;
    esac
    dest=$BACKUP_DIR/$rel
    while [ -e "$dest" ] || [ -L "$dest" ]; do
        dest=$BACKUP_DIR/$rel.$n
        n=$((n + 1))
    done
    printf '%s\n' "$dest"
}

# __backup_move PATH: move PATH into the backup dir (nothing is deleted) and
# print where it went; BACKUP_LAST holds it too.
__backup_move() {
    local dest
    if [ ! -e "$1" ] && [ ! -L "$1" ]; then
        __err "cannot back up $1: it does not exist"
        return 1
    fi
    __backup_dir >/dev/null || return
    dest=$(__backup_dest "$1") || return
    __journal backup-move "$1" "$dest" || return
    if ! mkdir -p -- "${dest%/*}" || ! mv -T -- "$1" "$dest"; then
        __err "cannot move $1 to $dest"
        return 1
    fi
    BACKUP_LAST=$dest
    printf '%s\n' "$dest"
}

# __backup_copy PATH: copy PATH (cp -a) into the backup dir and print where.
__backup_copy() {
    local dest
    if [ ! -e "$1" ] && [ ! -L "$1" ]; then
        __err "cannot back up $1: it does not exist"
        return 1
    fi
    __backup_dir >/dev/null || return
    dest=$(__backup_dest "$1") || return
    __journal backup-copy "$1" "$dest" || return
    if ! mkdir -p -- "${dest%/*}" || ! cp -aT -- "$1" "$dest"; then
        __err "cannot copy $1 to $dest"
        return 1
    fi
    BACKUP_LAST=$dest
    printf '%s\n' "$dest"
}

# __phys_dir DIR VAR: store in VAR the physical path of DIR. Components that
# do not exist yet are appended to the physical path of the existing prefix.
__phys_dir() {
    local d=$1 rest='' p
    [ -n "$1" ] || return 1
    if [ -n "${__PHYS[$1]+x}" ]; then
        printf -v "$2" '%s' "${__PHYS[$1]}"
        return 0
    fi
    while [ ! -d "$d" ]; do
        case $d in
            */*)
                rest=/${d##*/}$rest
                d=${d%/*}
                [ -n "$d" ] || d=/
                ;;
            *)
                rest=/$d$rest
                d=.
                ;;
        esac
    done
    p=$(cd -P -- "$d" && pwd -P) || return 1
    p=${p%/}$rest
    __PHYS[$1]=$p
    printf -v "$2" '%s' "$p"
}

# __portable_link_hint PHYS_HOME [COMMAND]: in enter.sh's DIR mode HOME holds
# a real link install, which only a run without DOTFILES_PORTABLE changes.
__portable_link_hint() {
    if [ "$1" != "$REPO" ] && [ -f "$MANIFEST" ]; then
        __info "$HOME has its own link install, which portable mode leaves alone; run 'env -u DOTFILES_PORTABLE dotfiles ${2:-<command>}' for it (or run it outside this shell)"
    fi
}

# __gate_portable: refuse (5) in portable mode, where $HOME is a checkout.
__gate_portable() {
    local home_p
    home_p=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || {
        __err "HOME=$HOME is not a directory"
        return 5
    }
    if [ -n "${DOTFILES_PORTABLE:-}" ]; then
        __err "refusing in portable mode (DOTFILES_PORTABLE=$DOTFILES_PORTABLE)"
        __portable_link_hint "$home_p"
        return 5
    fi
    if [ "$home_p" = "$REPO" ]; then
        __err "HOME is this checkout (portable mode); refusing"
        return 5
    fi
    if [ "$(git -C "$home_p" rev-parse --is-inside-work-tree 2>/dev/null)" = true ]; then
        __err "HOME ($HOME) is inside a git work tree; refusing"
        return 5
    fi
}

# __gate_repo_path: refuse (5) while the checkout is at the legacy ~/dotfiles;
# warn when it is anywhere but ~/.dotfiles.
__gate_repo_path() {
    local home_p
    home_p=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || {
        __err "HOME=$HOME is not a directory"
        return 5
    }
    case $REPO in
        "$home_p/dotfiles")
            __err "the checkout is at the legacy path ~/dotfiles; run '$REPO/bin/dotfiles migrate repo' first"
            return 5
            ;;
        "$home_p/.dotfiles") ;;
        *) __warn "the checkout is at $REPO, not $home_p/.dotfiles" ;;
    esac
}

# __gate_targets: refuse (5) when a dir links are made in (the config dir,
# the data dir, ~/.local/bin) is the checkout or inside it, through XDG_* or a
# symlink: tracked files would be replaced with links to themselves.
__gate_targets() {
    local base phys rc=0
    for base in "$CFG" "$DATA" "$HOME/.local/bin"; do
        __phys_dir "$base" phys || continue
        case $phys/ in
            "$REPO"/*)
                [ "$phys" = "$base" ] || base="$base (= $phys)"
                __err "$base is inside this checkout; refusing to link the repo onto itself (check XDG_* and symlinks)"
                rc=5
                ;;
        esac
    done
    return "$rc"
}

__glob_escape() {
    local s=$1 out='' c i
    for ((i = 0; i < ${#s}; i++)); do
        c=${s:i:1}
        case $c in
            '*'|'?'|'['|']'|\\) out+=\\$c ;;
            *) out+=$c ;;
        esac
    done
    printf -v "$2" '%s' "$out"
}

# __path_in_use PATH: true when a process of this uid (other than this one)
# uses PATH: its exe, cwd, an open fd or a mapped file is PATH or below it,
# its PATH variable lists PATH or a dir below it, or its environment cannot be
# read although this uid owns it. PATH itself may be a symlink (a compat
# link); its parent is compared both as given and physically. Sees only this
# host's processes.
__path_in_use() {
    local p=${1%/} d pp gp gpp pid kv path e ok
    local -a pids=() links=() maps=()
    [ -n "$p" ] || return 1
    d=${p%/*}
    [ -n "$d" ] || d=/
    __phys_dir "$d" pp || pp=$d
    pp=${pp%/}/${p##*/}
    for d in /proc/[0-9]*; do
        [ -O "$d" ] || continue
        # A non-dumpable process (sshd's per-session process, ssh-agent) or a
        # zombie keeps this uid on its dir but has root-owned files, so
        # nothing about it can be read. Counting it as in use would make
        # every path busy while an ssh login is open.
        [ -O "$d/environ" ] || continue
        pid=${d#/proc/}
        if [ "$pid" = "$$" ] || [ "$pid" = "$BASHPID" ]; then
            continue
        fi
        pids+=("$pid")
        links+=("$d/exe" "$d/cwd" "$d/fd")
        maps+=("$d/maps")
    done
    [ ${#pids[@]} -gt 0 ] || return 1
    __glob_escape "$p" gp
    __glob_escape "$pp" gpp
    if [ -n "$(find "${links[@]}" -maxdepth 1 \( -lname "$gp" -o -lname "$gp/*" \
        -o -lname "$gpp" -o -lname "$gpp/*" \) -print -quit 2>/dev/null)" ]; then
        return 0
    fi
    if grep -qsF -e "$p/" -e "$pp/" -- "${maps[@]}"; then
        return 0
    fi
    for pid in "${pids[@]}"; do
        ok=0
        path=
        {
            ok=1
            while IFS= read -r -d '' kv; do
                case $kv in
                    PATH=*) path=${kv#PATH=}; break ;;
                esac
            done
        } 2>/dev/null <"/proc/$pid/environ"
        if [ "$ok" = 0 ]; then
            # Gone or turned non-dumpable in the meantime: skip it. Owned by
            # this uid and still unreadable: assume in use.
            [ -O "/proc/$pid/environ" ] || continue
            return 0
        fi
        while [ -n "$path" ]; do
            e=${path%%:*}
            case $path in
                *:*) path=${path#*:} ;;
                *) path= ;;
            esac
            case $e in
                "$p"|"$p"/*|"$pp"|"$pp"/*) return 0 ;;
            esac
        done
    done
    return 1
}

# __legacy_signals [--all]: print "<kind><TAB><path><TAB><reason>" for each
# sign of the old layout. Kinds:
#   legacy  old copy-installed layout (blocking; uninstall-legacy migrates it)
#   prexdg  a file that shadows the XDG location (blocking)
#   shadow  a non-blocking shadow on an account without legacy files; only
#           printed with --all
# True when anything blocking was found.
__legacy_signals() {
    local f blocking=1 legacy=0
    for f in .bashrc.common .gitconfig.common .wezterm.common.lua; do
        if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then
            printf 'legacy\t%s\t%s\n' "$HOME/$f" "copy from the old dotfiles layout"
            blocking=0
            legacy=1
        fi
    done
    for f in .bashrc .tmux.conf .gitconfig; do
        if grep -qs -- "$LEGACY_MARKER_RE" "$HOME/$f"; then
            printf 'legacy\t%s\t%s\n' "$HOME/$f" "old entry file with a machine-specific section"
            blocking=0
            legacy=1
        elif [ "$f" = .gitconfig ] && { [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; }; then
            printf 'prexdg\t%s\t%s\n' "$HOME/$f" "git reads it instead of ~/.config/git/config"
            blocking=0
        elif [ "$f" = .tmux.conf ] && { [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; }; then
            printf 'prexdg\t%s\t%s\n' "$HOME/$f" "tmux loads it as well as ~/.config/tmux/tmux.conf"
            blocking=0
        fi
    done
    if [ "${1-}" = --all ] && [ "$legacy" = 0 ]; then
        for f in .vimrc .vim/vimrc; do
            if [ -e "$HOME/$f" ] || [ -L "$HOME/$f" ]; then
                printf 'shadow\t%s\t%s\n' "$HOME/$f" "vim reads it instead of ~/.config/vim/vimrc"
            fi
        done
        if [ -e "$HOME/.wezterm.lua" ] || [ -L "$HOME/.wezterm.lua" ]; then
            printf 'shadow\t%s\t%s\n' "$HOME/.wezterm.lua" \
                "wezterm reads it instead of ~/.config/wezterm/wezterm.lua"
        fi
    fi
    return "$blocking"
}

# __tmux_check: print a line when the tmux on PATH is older than 3.2, which
# loads no XDG config and lacks source-file -F / #{d:current_file}.
__tmux_check() {
    local v
    command -v tmux >/dev/null 2>&1 || return 1
    v=$(tmux -V 2>/dev/null) || return 1
    [[ $v =~ ([0-9]+)\.([0-9]+) ]] || return 1
    if [ "${BASH_REMATCH[1]}" -lt 3 ] \
        || { [ "${BASH_REMATCH[1]}" -eq 3 ] && [ "${BASH_REMATCH[2]}" -lt 2 ]; }; then
        printf '%s (%s) is older than 3.2 and cannot load ~/.config/tmux/tmux.conf; run '\''dotfiles bootstrap user'\''\n' \
            "$v" "$(command -v tmux)"
        return 0
    fi
    return 1
}

# __xdg_check: print a line for each XDG base variable set to a relative path.
__xdg_check() {
    local v found=1
    for v in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME; do
        case ${!v-} in
            ''|/*) ;;
            *)
                printf '%s=%s is relative; tools that follow the XDG spec ignore it\n' "$v" "${!v}"
                found=0
                ;;
        esac
    done
    return "$found"
}
