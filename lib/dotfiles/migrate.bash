# shellcheck shell=bash
# shellcheck disable=SC2016,SC2088  # messages show literal ~, $VARs and commands
# migrate.bash - `dotfiles migrate <step>`: move a live legacy account to the
# XDG layout without stopping tmux servers, shells or Claude sessions.
#
# Order on a legacy host: repo, tools, nvim-save, nvim-state, uninstall-legacy,
# install, nvim-restore; much later cleanup. Every step previews, asks (or
# needs --yes without a terminal), records the host name and refuses in
# portable mode; all but repo also refuse while the checkout is still at
# ~/dotfiles. Nothing here kills a process or deletes user data: old
# directories move into the backup dir, and only our own compat links are
# removed.

__MG_NVIM_STATE_EXPR="json_encode([len(filter(getbufinfo({'bufmodified': 1}), {_, b -> index(['', 'acwrite'], getbufvar(b.bufnr, '&buftype')) >= 0})), len(filter(getbufinfo(), {_, b -> getbufvar(b.bufnr, '&buftype') ==# 'terminal'})), len(filter(nvim_list_chans(), {_, c -> get(c, 'stream', '') ==# 'job' && get(c, 'mode', '') !=# 'rpc'}))])"

__mg_usage() {
    cat <<'EOF'
Usage: dotfiles migrate <step> [--yes] [--dry-run]

Moves a running legacy account to the XDG layout without killing tmux
servers, shells or editors. Each step previews and asks; without a terminal
it needs --yes. --dry-run only previews.

  repo          rename ~/dotfiles to ~/.dotfiles, leave a ~/dotfiles link
  tools         move ~/.cargo and ~/.rustup to the XDG data dir and ~/.fzf,
                ~/.fzf-tab-completion, ~/.bell-bash, ~/.noti-bash to
                ~/.local/opt (compat links stay); move node from nvm to fnm
                with its global npm packages
  nvim-save     save a session of every nvim running in a tmux pane, quit it
  nvim-state    copy nvim undo history and sessions to the XDG state dir
  nvim-restore  start the saved sessions again in their panes
  history       merge a ~/.bash_history that old shells recreated
  cleanup       remove compat links, ~/.tmux and ~/.nvm once nothing uses them
  all           tools, nvim-save, nvim-state, uninstall-legacy, install,
                nvim-restore; also takes --accept-dropped-edits,
                --replace-all and --keep-all
EOF
}

__cmd_migrate() {
    local step=${1-}
    [ $# -eq 0 ] || shift
    case $step in
        repo) __mg_repo "$@" ;;
        tools) __mg_tools "$@" ;;
        nvim-save) __mg_nvim_save "$@" ;;
        nvim-state) __mg_nvim_state "$@" ;;
        nvim-restore) __mg_nvim_restore "$@" ;;
        history) __mg_history "$@" ;;
        cleanup) __mg_cleanup "$@" ;;
        all) __mg_all "$@" ;;
        -h|--help) __mg_usage ;;
        *)
            [ -z "$step" ] || __err "migrate: unknown step '$step'"
            __mg_usage >&2
            return 2
            ;;
    esac
}

# Parse the flags every step takes into __mg_yes and __mg_dry.
__mg_flags() {
    __mg_yes=0 __mg_dry=0
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes) __mg_yes=1 ;;
            -n|--dry-run) __mg_dry=1 ;;
            *)
                __err "migrate: unknown option '$1'"
                __mg_usage >&2
                return 2
                ;;
        esac
        shift
    done
}

# Returns 0 to apply, 1 when declined, 3 when consent is needed and there is
# no terminal.
__mg_confirm() {
    [ "$__mg_yes" = 0 ] || return 0
    if [ ! -t 0 ]; then
        __err "no terminal to confirm; re-run with --yes (nothing changed)"
        return 3
    fi
    __ask "$1 [y/N] " && return 0
    __info "Cancelled; nothing changed."
    return 1
}

__mg_record_host() {
    local f=$STATE_DIR/hosts h=${HOSTNAME:-}
    [ -n "$h" ] || h=$(uname -n)
    grep -qxF -- "$h" "$f" 2>/dev/null && return 0
    __journal host "$f" "$h" || return
    (umask 077 && printf '%s\n' "$h" >>"$f")
}

__mg_home_phys() {
    (cd -P -- "$HOME" && pwd -P)
}

# Fill __mg_comm and __mg_kids (space-separated child pids), indexed by pid,
# for every process of this user.
__mg_scan_procs() {
    local p pid stat ppid comm
    __mg_comm=() __mg_kids=()
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        pid=${p#/proc/}
        read -r stat 2>/dev/null <"$p/stat" || continue
        read -r comm 2>/dev/null <"$p/comm" || continue
        # comm inside stat may hold spaces; the fields after ") " do not.
        ppid=${stat##*) }
        ppid=${ppid#* }
        ppid=${ppid%% *}
        __mg_comm[pid]=$comm
        __mg_kids[ppid]+="$pid "
    done
}

# Fill __mg_args with the argv of PID.
__mg_argv() {
    __mg_args=()
    mapfile -d '' -t __mg_args 2>/dev/null <"/proc/$1/cmdline"
}

# Print the pids of this user's nvim processes, one per line.
__mg_nvim_pids() {
    local p comm
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        read -r comm 2>/dev/null <"$p/comm" || continue
        [ "$comm" != nvim ] || printf '%s\n' "${p#/proc/}"
    done
}

# True while PID runs; a zombie counts as gone.
__mg_alive() {
    local stat
    read -r stat 2>/dev/null <"/proc/$1/stat" || return 1
    stat=${stat##*) }
    [ "${stat%% *}" != Z ]
}

# Fill __mg_f with the fields of /proc/PID/stat from the third (state) on, so
# field N is __mg_f[N-3]: ppid [1], tty_nr [4], tpgid [5], starttime [19].
# comm, the second field, may hold spaces; the fields after its ") " do not.
__mg_statf() {
    local s
    __mg_f=()
    read -r s 2>/dev/null <"/proc/$1/stat" || return 1
    read -ra __mg_f <<<"${s##*) }"
}

# Fill __mg_self with this command's own pids: $$ and the subshells between it
# and the caller.
__mg_self_load() {
    local p=$BASHPID
    declare -gA __mg_self=()
    while [ -n "$p" ]; do
        __mg_self[$p]=1
        if [ "$p" = "$$" ] || ! __mg_statf "$p"; then
            break
        fi
        p=${__mg_f[1]}
    done
}

# Boot time (seconds since the epoch) and clock ticks per second, which turn
# the starttime of /proc/PID/stat into a time.
__mg_clock() {
    local k v
    [ -z "${__mg_hz-}" ] || return 0
    __mg_btime=0
    while read -r k v _; do
        if [ "$k" = btime ]; then
            __mg_btime=$v
            break
        fi
    done </proc/stat
    __mg_hz=$(getconf CLK_TCK 2>/dev/null) || __mg_hz=100
}

# Print, in seconds since the epoch, when the journal last recorded ACTION on
# PATH. Journal times come from this host's clock; a file's mtime on NFS
# comes from the server's.
__mg_journal_time() {
    local t a p last=''
    [ -f "$JOURNAL" ] || return 1
    while IFS=$'\t' read -r _ t a p _; do
        if [ "$a" = "$1" ] && [ "$p" = "$2" ]; then
            last=$t
        fi
    done <"$JOURNAL"
    [ -n "$last" ] && date -d "$last" +%s 2>/dev/null
}

# Print where the journal last says PATH was moved into a backup dir.
__mg_journal_dest() {
    local a p d dest=''
    [ -f "$JOURNAL" ] || return 1
    while IFS=$'\t' read -r _ _ a p d; do
        if [ "$a" = backup-move ] && [ "$p" = "$1" ]; then
            dest=$d
        fi
    done <"$JOURNAL"
    [ -n "$dest" ] && printf '%s\n' "$dest"
}

# True when the journal's last record of OLD (now missing) is its move to DST
# or the compat link meant to follow it: a run stopped between the two, or
# ln failed. A fresh account, or one cleanup already cleared, has neither as
# the last record.
__mg_link_lost() {
    local a p d last=''
    [ -f "$JOURNAL" ] || return 1
    while IFS=$'\t' read -r _ _ a p d; do
        [ "$p" != "$1" ] || last=$a$'\t'$d
    done <"$JOURNAL"
    case $last in
        mv$'\t'"$2"|symlink$'\t'*) return 0 ;;
    esac
    return 1
}

# Create the compat link OLD -> TEXT, journaled; on failure name the command.
__mg_compat_link() {
    __journal symlink "$1" "$2" || return
    if ! ln -s -- "$2" "$1"; then
        __err "cannot create the compat link $(__tilde "$1"); create it by hand: ln -s $(printf '%q %q' "$2" "$1")"
        return 1
    fi
}

# Print "pid (comm)" of this user's processes whose executable or working
# directory is DIR or below it (DIR physical); this command's own processes
# are left out.
__mg_procs_under() {
    local dir=$1 p exe cwd comm
    __mg_self_load
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        [ -z "${__mg_self[${p#/proc/}]-}" ] || continue
        exe=$(readlink -- "$p/exe" 2>/dev/null)
        cwd=$(readlink -- "$p/cwd" 2>/dev/null)
        case $exe in
            "$dir"|"$dir"/*) ;;
            *)
                case $cwd in
                    "$dir"|"$dir"/*) ;;
                    *) continue ;;
                esac
                ;;
        esac
        read -r comm 2>/dev/null <"$p/comm" || comm='?'
        printf '%s (%s)\n' "${p#/proc/}" "$comm"
    done
}

# Fill __mg_tsock and __mg_tbin with every live tmux server of this user: its
# socket and a client binary that speaks its protocol. The server's own
# /proc/<pid>/exe works even when the binary on disk was replaced since.
# Client commands get no stdin: callers loop over other commands' output.
__mg_tmux_servers() {
    local dir=${TMUX_TMPDIR:-/tmp}/tmux-$UID p comm sock bin out
    local -a pids=()
    __mg_tsock=() __mg_tbin=()
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        read -r comm 2>/dev/null <"$p/comm" || continue
        [ "$comm" != 'tmux: server' ] || pids+=("${p#/proc/}")
    done
    for sock in "$dir"/*; do
        if [ ! -S "$sock" ] || [ ! -O "$sock" ]; then
            continue
        fi
        bin=
        for p in "${pids[@]}"; do
            out=$(timeout 5 "/proc/$p/exe" -S "$sock" display-message -p '#{pid}' </dev/null 2>/dev/null) ||
                continue
            if [ "$out" = "$p" ]; then
                bin=/proc/$p/exe
                break
            fi
        done
        if [ -z "$bin" ] && command -v tmux >/dev/null 2>&1 &&
            timeout 5 tmux -S "$sock" display-message -p '#{pid}' </dev/null >/dev/null 2>&1; then
            bin=tmux
        fi
        [ -n "$bin" ] || continue
        __mg_tsock+=("$sock")
        __mg_tbin+=("$bin")
    done
}

# Print the client binary for the live server on SOCK (after
# __mg_tmux_servers); fails when no server answers there.
__mg_tmux_bin() {
    local i
    for i in "${!__mg_tsock[@]}"; do
        if [ "${__mg_tsock[i]}" = "$1" ]; then
            printf '%s\n' "${__mg_tbin[i]}"
            return 0
        fi
    done
    return 1
}

# True when a live tmux server of this user still refers to ~/.tmux/plugins
# in its key bindings, hooks, options or environment (the old TPM set them
# up). A server that does not answer counts as referring to it.
__mg_tmux_refs_old() {
    local i cmd out
    __mg_tmux_servers
    for i in "${!__mg_tsock[@]}"; do
        for cmd in list-keys show-hooks show-options show-environment; do
            if [ "$cmd" = list-keys ]; then
                out=$(timeout 5 "${__mg_tbin[i]}" -S "${__mg_tsock[i]}" "$cmd" </dev/null 2>/dev/null) ||
                    return 0
            else
                out=$(timeout 5 "${__mg_tbin[i]}" -S "${__mg_tsock[i]}" "$cmd" -g </dev/null 2>/dev/null) ||
                    return 0
            fi
            case $out in *'/.tmux/plugins'*) return 0 ;; esac
        done
    done
    return 1
}

# Print the RPC socket of nvim server PID when this user owns it.
__mg_nvim_socket() {
    local pid=$1 e xrd='' s=''
    while IFS= read -r -d '' e; do
        case $e in XDG_RUNTIME_DIR=*) xrd=${e#*=} ;; esac
    done 2>/dev/null <"/proc/$pid/environ"
    if [ -n "$xrd" ] && [ -S "$xrd/nvim.$pid.0" ]; then
        s=$xrd/nvim.$pid.0
    else
        for s in /tmp/nvim."${USER:-$(id -un)}"/*/nvim."$pid".0; do
            [ ! -S "$s" ] || break
            s=
        done
    fi
    if [ -n "$s" ] && [ -O "$s" ]; then
        printf '%s\n' "$s"
    fi
}

# Run the nvim client of server PID against SOCK with ARGS, without stdin.
__mg_nvim_remote() {
    local pid=$1 sock=$2
    shift 2
    timeout 10 "/proc/$pid/exe" --clean --headless --server "$sock" "$@" </dev/null 2>/dev/null
}

# Print a SKIP line naming pane AT for each nvim deeper than a direct child of
# its shell PID (after __mg_scan_procs), except the --embed server of another
# nvim: the $EDITOR of git, crontab, sudoedit or Claude, which stays untouched.
__mg_nvim_nested() {
    local at=$1 i=0 p c
    local -a todo=() kids=()
    read -ra todo <<<"${__mg_kids[$2]-}"
    while [ "$i" -lt ${#todo[@]} ]; do
        p=${todo[i]}
        i=$((i + 1))
        read -ra kids <<<"${__mg_kids[p]-}"
        for c in "${kids[@]}"; do
            todo+=("$c")
            if [ "${__mg_comm[c]-}" = nvim ] && [ "${__mg_comm[p]-}" != nvim ]; then
                printf 'SKIP pane %s nvim %s: started by %s (pid %s), not by the pane shell; left alone\n' \
                    "$at" "$c" "${__mg_comm[p]-?}" "$p"
            fi
        done
    done
}

# ---------------------------------------------------------------------------
# repo

# For each linked worktree of the checkout CO whose .git file reaches it
# through ~/dotfiles, print a WORKTREE line and, unless DRY is 1, point that
# file at ~/.dotfiles. Once the compat link goes, git finds no repository
# there, and `git worktree repair` changes nothing while the link resolves.
__mg_worktrees() {
    local dry=$1 co=$2 hp line wt g abs to tmp rc=0
    hp=$(__mg_home_phys) || return 1
    while IFS= read -r line; do
        case $line in
            'worktree '*) wt=${line#worktree } ;;
            *) continue ;;
        esac
        # The main worktree has a .git directory.
        [ -f "$wt/.git" ] || continue
        IFS= read -r g 2>/dev/null <"$wt/.git" || continue
        case $g in
            'gitdir: '*) g=${g#gitdir: } ;;
            *) continue ;;
        esac
        abs=$g
        [ "${g#/}" != "$g" ] || abs=$(realpath -m -s -- "$wt/$g")
        case $abs in
            "$HOME/dotfiles/.git/worktrees/"*|"$hp/dotfiles/.git/worktrees/"*) ;;
            *) continue ;;
        esac
        to=$hp/.dotfiles/.git/worktrees/${abs##*/}
        [ "${g#/}" != "$g" ] || to=$(realpath -m -s --relative-to="$wt" -- "$to")
        printf 'WORKTREE %s: its .git file reaches the checkout through ~/dotfiles; it now names %s\n' \
            "$(__tilde "$wt")" "$(__tilde "$to")"
        [ "$dry" = 0 ] || continue
        __journal worktree "$wt/.git" "$g" || return
        tmp=
        if ! tmp=$(mktemp "$wt/.git.dotfiles.XXXXXX") || ! printf 'gitdir: %s\n' "$to" >"$tmp" ||
            ! chmod --reference="$wt/.git" -- "$tmp" || ! mv -f -- "$tmp" "$wt/.git"; then
            [ -z "$tmp" ] || rm -f -- "$tmp"
            __err "cannot rewrite $wt/.git; after 'dotfiles migrate cleanup' run: git -C ~/.dotfiles worktree repair"
            rc=1
        fi
    done < <(git -c safe.directory="$co" -C "$co" worktree list --porcelain 2>/dev/null)
    return "$rc"
}

__mg_repo() {
    local hp old=$HOME/dotfiles new=$HOME/.dotfiles pids rc=0
    __mg_flags "$@" || return
    __gate_portable || return
    hp=$(__mg_home_phys) || return 1
    if [ -L "$old" ] && [ "$(readlink -- "$old")" = .dotfiles ]; then
        printf '~/dotfiles already links to .dotfiles; nothing to do.\n'
        return 0
    fi
    if [ "$REPO" != "$hp/dotfiles" ]; then
        if [ -d "$old" ] && [ ! -L "$old" ] && [ -d "$new" ]; then
            __err "both ~/dotfiles and ~/.dotfiles are directories; resolve it by hand:"
            ls -ld -- "$old" "$new" >&2
            return 5
        fi
        if [ "$REPO" = "$hp/.dotfiles" ] && [ ! -e "$old" ] && [ ! -L "$old" ] &&
            __mg_link_lost "$old" "$new"; then
            printf "LINK ~/dotfiles -> .dotfiles (missing: an earlier run stopped after the rename; removed later by 'dotfiles migrate cleanup')\n"
            __mg_worktrees 1 "$REPO"
            [ "$__mg_dry" = 0 ] || return 0
            __mg_confirm 'Create the link?' || return
            __journal_begin migrate-repo || return
            __mg_compat_link "$old" .dotfiles || return 1
            __mg_worktrees 0 "$REPO" || rc=1
            __mg_record_host || return
            __journal_done || return
            return "$rc"
        fi
        printf 'The checkout is at %s; nothing to rename.\n' "$(__tilde "$REPO")"
        return 0
    fi
    if [ -e "$new" ] || [ -L "$new" ]; then
        __err "~/.dotfiles already exists; resolve it by hand:"
        ls -ld -- "$old" "$new" >&2
        return 5
    fi
    printf 'MOVE ~/dotfiles -> ~/.dotfiles\n'
    printf "LINK ~/dotfiles -> .dotfiles (removed later by 'dotfiles migrate cleanup')\n"
    if [ -n "$(__git --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        printf 'Uncommitted changes in the checkout (they move along):\n'
        __git --no-optional-locks status --short 2>/dev/null | sed 's/^/  /'
    fi
    pids=$(__mg_procs_under "$REPO")
    if [ -n "$pids" ]; then
        printf 'Processes running inside the checkout (they keep working through the link):\n'
        printf '%s\n' "$pids" | sed 's/^/  /'
    fi
    __mg_worktrees 1 "$REPO"
    [ "$__mg_dry" = 0 ] || return 0
    __mg_confirm 'Rename the checkout?' || return
    __journal_begin migrate-repo || return
    __journal mv "$old" "$new" || return
    mv -T -- "$old" "$new" || return 1
    if ! __mg_compat_link "$old" .dotfiles; then
        __err "the checkout is now $new"
        return 1
    fi
    # cleanup retries a worktree left unfixed, before it removes the link.
    __mg_worktrees 0 "$new" || rc=1
    __mg_record_host || return
    __journal_done || return
    printf 'Done. Continue with ~/.dotfiles/bin/dotfiles.\n'
    return "$rc"
}

# ---------------------------------------------------------------------------
# tools

# Print the device number of PATH or of its nearest existing ancestor.
__mg_dev() {
    local p=$1
    until [ -e "$p" ]; do
        p=${p%/*}
        [ -n "$p" ] || p=/
    done
    stat -c %d -- "$p"
}

# Print the node version the nvm default resolves to, or nothing.
__mg_nvm_version() {
    local nvm=$HOME/.nvm v='' n p
    [ ! -r "$nvm/alias/default" ] || v=$(<"$nvm/alias/default")
    # Aliases chain through files: default -> lts/* -> lts/iron -> vX.Y.Z.
    for n in 1 2 3 4 5 6; do
        case $v in
            ''|v[0-9]*.[0-9]*.[0-9]*) break ;;
        esac
        if [ -r "$nvm/alias/$v" ]; then
            v=$(<"$nvm/alias/$v")
        else
            v=
        fi
    done
    case $v in
        v[0-9]*.[0-9]*.[0-9]*) ;;
        *)
            v=
            if p=$(command -v node 2>/dev/null) && p=$(readlink -f -- "$p"); then
                case $p in
                    "$(cd -P -- "$nvm" 2>/dev/null && pwd -P)"/*) v=$(node -v 2>/dev/null) ;;
                esac
            fi
            ;;
    esac
    case $v in
        v[0-9]*.[0-9]*.[0-9]*) [ ! -d "$nvm/versions/node/$v" ] || printf '%s\n' "$v" ;;
    esac
}

# Print name@version of every global npm package of nvm node VERSION but npm
# and corepack.
__mg_npm_globals() {
    local dir=$HOME/.nvm/versions/node/$1/lib/node_modules pj name ver
    for pj in "$dir"/*/package.json "$dir"/@*/*/package.json; do
        [ -f "$pj" ] || continue
        name=${pj#"$dir"/}
        name=${name%/package.json}
        case $name in npm|corepack) continue ;; esac
        ver=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$pj" | head -n 1)
        [ -z "$ver" ] || printf '%s@%s\n' "$name" "$ver"
    done
}

__mg_tools() {
    local hp i src dst probe busy text had fnm_dir=$DATA/fnm v='' node=0 pkg rc=0 refused=0
    local mark=$STATE_DIR/migrate/node.pending inst cur
    local -a srcs=() dsts=() probes=() globals=() todo=() relinks=() relink_to=()
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    __gate_targets || return
    hp=$(__mg_home_phys) || return 1
    set -- \
        "$HOME/.cargo" "$DATA/cargo" bin/cargo \
        "$HOME/.rustup" "$DATA/rustup" settings.toml \
        "$HOME/.fzf" "$HOME/.local/opt/fzf" bin \
        "$HOME/.fzf-tab-completion" "$HOME/.local/opt/fzf-tab-completion" bash \
        "$HOME/.bell-bash" "$HOME/.local/opt/bell-bash" bell \
        "$HOME/.noti-bash" "$HOME/.local/opt/noti-bash" bin
    while [ $# -ge 3 ]; do
        src=$1 dst=$2 probe=$3
        shift 3
        if [ ! -e "$src" ] && [ ! -L "$src" ] && [ -d "$dst" ] && __mg_link_lost "$src" "$dst"; then
            printf 'LINK %s -> %s (the compat link is missing: an earlier run stopped after the move)\n' \
                "$(__tilde "$src")" "$(__tilde "$dst")"
            relinks+=("$src")
            relink_to+=("$dst")
            continue
        fi
        if [ ! -d "$src" ] || [ -L "$src" ]; then
            continue
        fi
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            printf 'REFUSE %s: %s already exists\n' "$(__tilde "$src")" "$(__tilde "$dst")"
            refused=1
            continue
        fi
        if [ "$(__mg_dev "${src%/*}")" != "$(__mg_dev "${dst%/*}")" ]; then
            printf 'REFUSE %s: %s is on another filesystem\n' "$(__tilde "$src")" "$(__tilde "$dst")"
            refused=1
            continue
        fi
        # Only processes running from or inside it block the move; shells that
        # merely have it on PATH keep working through the compat link.
        busy=$(__mg_procs_under "$(cd -P -- "$src" && pwd -P)")
        if [ -n "$busy" ]; then
            printf 'REFUSE %s: in use by %s\n' "$(__tilde "$src")" "$(printf '%s\n' "$busy" | paste -sd ' ' -)"
            refused=1
            continue
        fi
        printf 'MOVE %s -> %s (compat link left behind)\n' "$(__tilde "$src")" "$(__tilde "$dst")"
        srcs+=("$src")
        dsts+=("$dst")
        probes+=("$probe")
    done
    # Same condition as the relocation gate of bootstrap and uninstall-legacy,
    # which an fnm default clears even when nvm names no usable version. The
    # first run sets that default to the LTS before it installs the nvm
    # version, so the rest is resumed from the pending file, not from the
    # missing default.
    if [ -s "$mark" ]; then
        node=1
        { IFS= read -r v; mapfile -t globals; } <"$mark"
        printf 'NODE finish moving node %s from nvm to fnm (an earlier run stopped; ~/.nvm stays)\n' "$v"
    elif [ -e "$HOME/.nvm" ] && [ ! -e "$fnm_dir/aliases/default" ] && [ ! -L "$fnm_dir/aliases/default" ]; then
        node=1
        v=$(__mg_nvm_version)
        if [ -n "$v" ]; then
            printf 'NODE install fnm (with the current LTS node, as bootstrap does), then node %s as the fnm default (~/.nvm stays)\n' "$v"
            mapfile -t globals < <(__mg_npm_globals "$v")
        else
            printf 'NODE no usable nvm default found; install fnm with the current LTS node as the fnm default (~/.nvm stays)\n'
        fi
    fi
    for pkg in "${globals[@]}"; do
        [ -f "$fnm_dir/node-versions/$v/installation/lib/node_modules/${pkg%@*}/package.json" ] ||
            printf 'NPM  npm install -g %s (with the fnm node %s)\n' "$pkg" "$v"
    done
    if [ ${#srcs[@]} -eq 0 ] && [ ${#relinks[@]} -eq 0 ] && [ "$node" = 0 ]; then
        printf 'Nothing to relocate.\n'
        [ "$refused" = 0 ] || return 5
        return 0
    fi
    [ "$__mg_dry" = 0 ] || return 0
    __mg_confirm 'Relocate these tools?' || return

    __journal_begin migrate-tools || return
    for i in "${!relinks[@]}"; do
        dst=$(cd -P -- "${relink_to[i]}" && pwd -P) || return 1
        text=$(realpath -m --relative-to="$hp" "$dst") || return 1
        __mg_compat_link "${relinks[i]}" "$text" || return 1
        printf 'linked %s -> %s\n' "$(__tilde "${relinks[i]}")" "$text"
    done
    for i in "${!srcs[@]}"; do
        src=${srcs[i]} dst=${dsts[i]} probe=${probes[i]}
        had=0
        [ ! -e "$src/$probe" ] || had=1
        if [ ! -d "${dst%/*}" ]; then
            __journal mkdir "${dst%/*}" || return
            mkdir -p -- "${dst%/*}" || return 1
        fi
        __journal mv "$src" "$dst" || return
        mv -T -- "$src" "$dst" || return 1
        dst=$(cd -P -- "$dst" && pwd -P) || return 1
        text=$(realpath -m --relative-to="$hp" "$dst") || return 1
        __mg_compat_link "$src" "$text" || return 1
        if { [ "$had" = 1 ] && [ ! -e "$src/$probe" ]; } || [ ! -d "$src/" ]; then
            __err "$(__tilde "$src") does not resolve after the move; fix it before going on"
            return 1
        fi
        printf 'moved %s -> %s\n' "$(__tilde "$src")" "$(__tilde "${dsts[i]}")"
    done

    if [ -n "$v" ] && [ ! -s "$mark" ]; then
        __journal state "$mark" "$v" || return
        if ! (umask 077 && mkdir -p -- "${mark%/*}" && printf '%s\n' "$v" "${globals[@]}" >"$mark"); then
            __err "cannot write $mark"
            return 1
        fi
    fi
    if [ "$node" = 1 ]; then
        __bs_init || return 1
        if ! install_fnm_user; then
            __err "the fnm install failed; re-run 'dotfiles migrate tools'"
            return 1
        fi
        if ! command -v fnm >/dev/null 2>&1; then
            __err "fnm is not on PATH after its install"
            return 1
        fi
    fi
    if [ -n "$v" ]; then
        fnm_dir=${FNM_DIR:-$fnm_dir}
        inst=$fnm_dir/node-versions/$v/installation
        if [ ! -d "$fnm_dir/node-versions/$v" ] && ! fnm install "$v"; then
            __err "fnm install $v failed; re-run 'dotfiles migrate tools'"
            return 1
        fi
        # Only replace the LTS default install_fnm_user set, never one chosen
        # since.
        cur=$(readlink -f -- "$fnm_dir/aliases/default" 2>/dev/null)
        if [ -z "$cur" ] || [ "$cur" = "$(readlink -f -- "$fnm_dir/aliases/lts-latest" 2>/dev/null)" ]; then
            if ! fnm default "$v"; then
                __err "fnm default $v failed; re-run 'dotfiles migrate tools'"
                return 1
            fi
        elif [ "$cur" != "$(readlink -f -- "$inst")" ]; then
            __warn "the fnm default is $(__tilde "$cur"), not node $v; left as it is"
        fi
        for pkg in "${globals[@]}"; do
            [ -f "$inst/lib/node_modules/${pkg%@*}/package.json" ] || todo+=("$pkg")
        done
        # The calling shell may still have nvm's node first on PATH, and npm is
        # a node script: put that version's bin ahead of it.
        if [ ${#todo[@]} -gt 0 ] && ! PATH="$inst/bin:$PATH" npm install -g "${todo[@]}"; then
            __err "npm install -g failed; re-run 'dotfiles migrate tools', or by hand: PATH=$(printf '%q' "$inst/bin"):\$PATH npm install -g ${todo[*]}"
            rc=1
        fi
        if [ "$rc" = 0 ] && [ -e "$mark" ]; then
            __journal state "$mark" || return
            rm -f -- "$mark" || return 1
        fi
    fi
    __mg_record_host || return
    __journal_done || return
    [ "$refused" = 0 ] || return 5
    return "$rc"
}

# ---------------------------------------------------------------------------
# nvim-save, nvim-state, nvim-restore

__mg_nvim_save() {
    local i sock bin pane at ppid cwd c k srv nsock r m t j why dir file q
    local -a a_sock=() a_pane=() a_cwd=() a_ui=() a_srv=() a_nsock=() a_ppid=()
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    __mg_tmux_servers
    __mg_scan_procs
    for i in "${!__mg_tsock[@]}"; do
        sock=${__mg_tsock[i]} bin=${__mg_tbin[i]}
        # Space-separated: a tmux client without a UTF-8 locale prints every
        # control character, tabs included, as '_'.
        while read -r pane ppid cwd; do
            case $ppid in ''|*[!0-9]*) continue ;; esac
            # Pane ids restart at %0 on every server: name the server too.
            at=${sock##*/}:$pane
            # Only an nvim the pane's shell started itself: an $EDITOR child
            # of git, crontab or sudoedit has another parent.
            for c in ${__mg_kids[ppid]-}; do
                [ "${__mg_comm[c]-}" = nvim ] || continue
                __mg_argv "$c"
                why=
                for k in "${__mg_args[@]:1}"; do
                    case $k in
                        -d|--headless|--embed) why="started with $k" ;;
                        *file://*) why='opened a file:// URL' ;;
                    esac
                done
                if [ -n "$why" ]; then
                    printf 'SKIP pane %s nvim %s: %s\n' "$at" "$c" "$why"
                    continue
                fi
                # nvim 0.9+ runs its server as an `nvim --embed` child of the UI.
                srv=$c
                for k in ${__mg_kids[c]-}; do
                    [ "${__mg_comm[k]-}" = nvim ] || continue
                    __mg_argv "$k"
                    case " ${__mg_args[*]} " in
                        *' --embed '*)
                            srv=$k
                            break
                            ;;
                    esac
                done
                nsock=$(__mg_nvim_socket "$srv")
                if [ -z "$nsock" ]; then
                    printf 'SKIP pane %s nvim %s: no RPC socket of this user found\n' "$at" "$c"
                    continue
                fi
                r=$(__mg_nvim_remote "$srv" "$nsock" --remote-expr "$__MG_NVIM_STATE_EXPR")
                r=${r//[^0-9,]/}
                m=${r%%,*} r=${r#*,}
                t=${r%%,*} j=${r#*,}
                case "$m,$t,$j" in
                    *[!0-9,]*|,*|*,,*|*,)
                        printf 'SKIP pane %s nvim %s: no answer over %s\n' "$at" "$c" "$nsock"
                        continue
                        ;;
                esac
                if [ "$m" -gt 0 ] || [ "$t" -gt 0 ] || [ "$j" -gt 0 ]; then
                    printf 'SKIP pane %s nvim %s: %s modified buffer(s), %s terminal(s), %s running job(s)\n' \
                        "$at" "$c" "$m" "$t" "$j"
                    continue
                fi
                printf 'SAVE pane %s nvim %s in %s: session file, then :qa\n' "$at" "$c" "$(__tilde "$cwd")"
                a_sock+=("$sock") a_pane+=("$pane") a_cwd+=("$cwd") a_ppid+=("$ppid")
                a_ui+=("$c") a_srv+=("$srv") a_nsock+=("$nsock")
            done
            __mg_nvim_nested "$at" "$ppid"
        done < <(timeout 5 "$bin" -S "$sock" list-panes -a \
            -F '#{pane_id} #{pane_pid} #{pane_current_path}' </dev/null 2>/dev/null)
    done
    if [ ${#a_ui[@]} -eq 0 ]; then
        printf 'No nvim to save.\n'
        return 0
    fi
    [ "$__mg_dry" = 0 ] || return 0
    __mg_confirm 'Save these sessions and quit those nvims?' || return

    __journal_begin migrate-nvim-save || return
    dir=$STATE_DIR/migrate
    if [ ! -d "$dir" ]; then
        __journal mkdir "$dir" || return
        (umask 077 && mkdir -p -- "$dir") || return 1
    fi
    for i in "${!a_ui[@]}"; do
        file=$dir/nvim-$__RUN_TS-${a_srv[i]}.vim
        q=${file//\'/\'\'}
        at=${a_sock[i]##*/}:${a_pane[i]}
        __journal nvim-session "$file" "$at" || return
        __mg_nvim_remote "${a_srv[i]}" "${a_nsock[i]}" \
            --remote-expr "execute('mksession! ' .. fnameescape('$q'))" >/dev/null
        if [ ! -s "$file" ]; then
            __warn "pane $at: no session written; nvim ${a_ui[i]} keeps running"
            continue
        fi
        # The pane's shell pid tells nvim-restore a pane id that a restarted
        # server on the same socket reuses.
        (umask 077 && printf '%s\t%s\t%s\t%s\t%s\n' "${a_sock[i]}" "${a_pane[i]}" "${a_cwd[i]}" "$file" \
            "${a_ppid[i]}" >>"$dir/nvim.tsv") || return 1
        __mg_nvim_remote "${a_srv[i]}" "${a_nsock[i]}" --remote-send '<C-\><C-n>:qa<CR>' >/dev/null
        for ((k = 0; k < 20; k++)); do
            __mg_alive "${a_ui[i]}" || break
            sleep 0.5
        done
        if __mg_alive "${a_ui[i]}"; then
            __warn "pane $at: nvim ${a_ui[i]} did not quit within 10 s; its session stays in $file"
        else
            printf 'saved pane %s -> %s\n' "$at" "$(__tilde "$file")"
        fi
    done
    __mg_record_host || return
    __journal_done
}

# Fill __mg_ns_src/__mg_ns_dst with nvim undo files and sessions still to
# copy, and __mg_ns_diff with copied files whose source changed since.
__mg_nvim_state_scan() {
    local old=$HOME/.local/share/nvim new=$STATE/nvim enc=${HOME//\//%} renamed=0 sub f name to
    __mg_ns_src=() __mg_ns_dst=() __mg_ns_diff=()
    if [ -L "$HOME/dotfiles" ] && [ "$(readlink -- "$HOME/dotfiles")" = .dotfiles ]; then
        renamed=1
    # cleanup removes the compat link; later copies must still rename.
    elif [ ! -e "$HOME/dotfiles" ] && [ ! -L "$HOME/dotfiles" ] &&
        [ "$REPO" = "$(__mg_home_phys)/.dotfiles" ]; then
        renamed=1
    fi
    for sub in undo obsession; do
        [ -d "$old/$sub" ] || continue
        for f in "$old/$sub"/*; do
            if [ ! -f "$f" ] || [ -L "$f" ]; then
                continue
            fi
            name=${f##*/}
            if [ "$sub" = obsession ]; then
                case $name in *.swp) continue ;; esac
            elif [ "$renamed" = 1 ]; then
                # Undo file names encode the edited file's full path.
                case $name in
                    "$enc%dotfiles%"*) name=$enc%.dotfiles%${name#"$enc%dotfiles%"} ;;
                esac
            fi
            to=$new/$sub/$name
            if [ -e "$to" ] || [ -L "$to" ]; then
                if [ "$f" -nt "$to" ] && ! cmp -s -- "$f" "$to"; then
                    __mg_ns_diff+=("$f")
                fi
            else
                __mg_ns_src+=("$f")
                __mg_ns_dst+=("$to")
            fi
        done
    done
}

__mg_nvim_state_preview() {
    local f pids
    if [ ${#__mg_ns_src[@]} -gt 0 ]; then
        printf 'COPY %d nvim undo file(s) and session(s) from ~/.local/share/nvim to %s (existing files are kept)\n' \
            "${#__mg_ns_src[@]}" "$(__tilde "$STATE/nvim")"
        printf '     undo history and sessions of files inside the checkout only partly survive the ~/dotfiles -> ~/.dotfiles rename\n'
    fi
    for f in "${__mg_ns_diff[@]}"; do
        printf 'DIFFER %s changed after it was copied; the copy is kept\n' "$(__tilde "$f")"
    done
    pids=$(__mg_nvim_pids | paste -sd ' ' -)
    if [ -n "$pids" ]; then
        printf "WARN nvim still runs (pid %s): its later writes are picked up when 'dotfiles migrate cleanup' copies again\n" "$pids"
    fi
}

__mg_nvim_state_copy() {
    local k fail=0
    [ ${#__mg_ns_src[@]} -gt 0 ] || return 0
    __journal copy "$HOME/.local/share/nvim" "$STATE/nvim" || return
    (umask 077 && mkdir -p -- "$STATE/nvim/undo" "$STATE/nvim/obsession") || return 1
    for k in "${!__mg_ns_src[@]}"; do
        cp -n -p -- "${__mg_ns_src[k]}" "${__mg_ns_dst[k]}" 2>/dev/null
        [ -e "${__mg_ns_dst[k]}" ] || fail=$((fail + 1))
    done
    if [ "$fail" -gt 0 ]; then
        __err "$fail nvim state file(s) could not be copied"
        return 1
    fi
    printf 'copied %d nvim state file(s) to %s\n' "${#__mg_ns_src[@]}" "$(__tilde "$STATE/nvim")"
}

__mg_nvim_state() {
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    __mg_nvim_state_scan
    __mg_nvim_state_preview
    if [ ${#__mg_ns_src[@]} -eq 0 ]; then
        printf 'No nvim state to copy.\n'
        return 0
    fi
    [ "$__mg_dry" = 0 ] || return 0
    __mg_confirm 'Copy the nvim state?' || return
    __journal_begin migrate-nvim-state || return
    __mg_nvim_state_copy || return
    __mg_record_host || return
    __journal_done
}

# Print the path that the text T of a session file names (fnameescape'd, maybe
# ~-relative) when the session's current directory is DIR.
__mg_vim_path() {
    local t=$1 out='' i c
    for ((i = 0; i < ${#t}; i++)); do
        c=${t:i:1}
        if [ "$c" = "\\" ] && [ $((i + 1)) -lt ${#t} ]; then
            i=$((i + 1))
            c=${t:i:1}
        fi
        out+=$c
    done
    case $out in
        '~') out=$HOME ;;
        '~/'*) out=$HOME/${out#'~/'} ;;
        /*) ;;
        *) out=${2%/}/$out ;;
    esac
    printf '%s\n' "$out"
}

# Print a WARN line for each file the session FILE of pane AT (saved in DIR)
# opens that is gone, e.g. an old-layout file uninstall-legacy moved since
# nvim-save: nvim shows an empty new buffer for it without a word, and saving
# that buffer recreates the old path.
__mg_session_check() {
    local at=$1 file=$2 dir=$3 line p dest
    local -A seen=()
    while IFS= read -r line; do
        case $line in
            'cd '*)
                dir=$(__mg_vim_path "${line#cd }" "$dir")
                continue
                ;;
            'badd '*|'edit '*|'balt '*) p=${line#* } ;;
            *) continue ;;
        esac
        case $p in '+'*) p=${p#* } ;; esac
        p=$(__mg_vim_path "$p" "$dir")
        if [ -n "${seen[$p]-}" ] || [ -e "$p" ] || [ -L "$p" ]; then
            continue
        fi
        seen[$p]=1
        if dest=$(__mg_journal_dest "$p"); then
            printf 'WARN pane %s: its session opens %s, which dotfiles moved to %s; nvim shows it as an empty new buffer, and saving that buffer recreates the old file\n' \
                "$at" "$(__tilde "$p")" "$(__tilde "$dest")"
        else
            printf 'WARN pane %s: its session opens %s, which no longer exists\n' "$at" "$(__tilde "$p")"
        fi
    done <"$file"
}

# True when PANE on SOCK can take a typed command now: it exists, still runs
# the shell SPID (when recorded), that shell holds the terminal, and the pane
# is not in copy mode. #{pane_current_command} alone says "bash" while a bash
# script runs there too. Otherwise __mg_why says why not.
__mg_pane_ready() {
    local sock=$1 pane=$2 spid=$3 bin info in_mode ppid cur
    __mg_why=
    if ! bin=$(__mg_tmux_bin "$sock") ||
        ! info=$(timeout 5 "$bin" -S "$sock" display-message -p -t "$pane" \
            '#{pane_in_mode} #{pane_pid} #{pane_current_command}' </dev/null 2>/dev/null); then
        __mg_why='it no longer exists'
        return 1
    fi
    read -r in_mode ppid cur <<<"$info"
    if [ -n "$spid" ] && [ "$ppid" != "$spid" ]; then
        __mg_why="it runs another shell (pid $ppid) than the one nvim was saved from (pid $spid)"
        return 1
    fi
    case ${cur#-} in
        bash|sh|dash|zsh|fish|ksh|mksh|tcsh|csh) ;;
        *)
            __mg_why="it runs $cur, not a shell prompt"
            return 1
            ;;
    esac
    if ! __mg_statf "$ppid" || [ "${__mg_f[5]}" != "$ppid" ]; then
        __mg_why='a program its shell started holds the terminal'
        return 1
    fi
    if [ "$in_mode" != 0 ]; then
        __mg_why='it is in copy mode'
        return 1
    fi
}

__mg_nvim_restore() {
    local tsv=$STATE_DIR/migrate/nvim.tsv line sock pane at cwd file spid bin cmd rc=0 i n=0
    local -a rows=() go=() keep=()
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    if [ ! -s "$tsv" ]; then
        printf 'No saved nvim sessions.\n'
        return 0
    fi
    __mg_tmux_servers
    while IFS= read -r line; do
        IFS=$'\t' read -r sock pane cwd file spid <<<"$line"
        [ -n "$pane" ] || continue
        rows+=("$line")
        at=${sock##*/}:$pane
        printf -v cmd 'nvim -S %q' "$file"
        if [ ! -f "$file" ]; then
            printf 'DROP pane %s: its session file %s is gone\n' "$at" "$(__tilde "$file")"
            go+=(drop)
            continue
        fi
        __mg_session_check "$at" "$file" "$cwd"
        if ! __mg_pane_ready "$sock" "$pane" "$spid"; then
            printf 'SKIP pane %s: %s; run by hand later: %s\n' "$at" "$__mg_why" "$cmd"
            go+=(skip)
            continue
        fi
        printf 'RESTORE pane %s in %s: %s\n' "$at" "$(__tilde "$cwd")" "$cmd"
        go+=(restore)
        n=$((n + 1))
    done <"$tsv"
    [ "$__mg_dry" = 0 ] || return 0
    if [ "$n" -gt 0 ] && [ "$__mg_yes" = 0 ] && [ ! -t 0 ]; then
        __err "no terminal to confirm; re-run with --yes (nothing changed)"
        return 3
    fi
    __journal_begin migrate-nvim-restore || return
    for i in "${!rows[@]}"; do
        IFS=$'\t' read -r sock pane cwd file spid <<<"${rows[i]}"
        case ${go[i]} in
            drop) continue ;;
            skip)
                keep+=("${rows[i]}")
                continue
                ;;
        esac
        at=${sock##*/}:$pane
        printf -v cmd 'nvim -S %q' "$file"
        # Typed text in the pane stays: no C-u before the command.
        if [ "$__mg_yes" = 0 ] && ! __ask "Run '$cmd' in pane $at? [y/N] "; then
            keep+=("${rows[i]}")
            continue
        fi
        # Again: the pane may have started something since the preview.
        if ! __mg_pane_ready "$sock" "$pane" "$spid" || ! bin=$(__mg_tmux_bin "$sock"); then
            __warn "pane $at: ${__mg_why:-its tmux server is gone}; run by hand later: $cmd"
            keep+=("${rows[i]}")
            continue
        fi
        __journal nvim-restore "$file" "$at" || return
        if timeout 5 "$bin" -S "$sock" send-keys -t "$pane" -l "$cmd" </dev/null &&
            timeout 5 "$bin" -S "$sock" send-keys -t "$pane" Enter </dev/null; then
            printf 'restored pane %s\n' "$at"
        else
            __warn "pane $at: send-keys failed; run by hand: $cmd"
            keep+=("${rows[i]}")
            rc=1
        fi
    done
    __journal state "$tsv" || return
    if ! (umask 077 && { [ ${#keep[@]} -eq 0 ] || printf '%s\n' "${keep[@]}"; } >"$tsv.tmp") ||
        ! mv -fT -- "$tsv.tmp" "$tsv"; then
        __err "cannot write $tsv"
        return 1
    fi
    __mg_record_host || return
    __journal_done || return
    return "$rc"
}

# ---------------------------------------------------------------------------
# history

__mg_history() {
    local old=$HOME/.bash_history
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    if ! __hist_pending "$old"; then
        printf 'No unmerged ~/.bash_history.\n'
        return 0
    fi
    printf 'MIGRATE ~/.bash_history -> %s (%s line(s) appended; the file moves to the backup dir)\n' \
        "$(__tilde "$(__hist_file)")" "$(wc -l <"$old")"
    [ "$__mg_dry" = 0 ] || return 0
    __mg_confirm 'Merge the history?' || return
    __journal_begin migrate-history || return
    __hist_import "$old" || return
    __mg_record_host || return
    __journal_done
}

# ---------------------------------------------------------------------------
# cleanup

# Print the pids of this user's shells on a terminal that started at or before
# CUTOFF (seconds since the epoch). Their PATH may hold dirs their rc files
# added after the start, which /proc/PID/environ does not show; the programs
# they start do show it. Shells without a terminal are scripts, and daemons
# started before the migration never end on a lingering account.
__mg_old_shells() {
    local cutoff=$1 p pid comm
    local -a out=()
    __mg_clock
    __mg_self_load
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        pid=${p#/proc/}
        [ -z "${__mg_self[$pid]-}" ] || continue
        read -r comm 2>/dev/null <"$p/comm" || continue
        case $comm in
            bash|sh|dash|zsh|fish|ksh|mksh|tcsh|csh) ;;
            *) continue ;;
        esac
        if ! __mg_statf "$pid" || [ "${__mg_f[4]:-0}" = 0 ]; then
            continue
        fi
        [ $((__mg_btime + __mg_f[19] / __mg_hz)) -gt "$cutoff" ] || out+=("$pid")
    done
    [ ${#out[@]} -eq 0 ] || printf '%s\n' "${out[*]}"
}

# Print when new shells stopped needing the old tool path P (seconds since
# the epoch): the later of its compat link and the switch of ~/.bashrc to
# the new layout, before which new shells still read the old rc files.
__mg_old_cutoff() {
    local t b
    t=$(__mg_journal_time symlink "$1") || t=$(stat -c %Y -- "$1" 2>/dev/null) || return 1
    b=$(__mg_journal_time entry-replace "$HOME/.bashrc") || b=0
    [ "$b" -le "$t" ] || t=$b
    printf '%s\n' "$t"
}

# Print the pids of processes that still reach the checkout by the name of
# the compat link LINK: their PWD names it, or they started before the rename
# with a cwd or executable inside the checkout, which /proc now shows under
# the new name. Claude Code, for one, returns to its project dir by that name
# for every command.
__mg_checkout_users() {
    local link=$1 alt phys cutoff p pid e pwd cwd exe
    local -a out=()
    phys=$(cd -P -- "$link" 2>/dev/null && pwd -P) || return 0
    alt=$(__mg_home_phys)/${link##*/}
    cutoff=$(__mg_journal_time symlink "$link") || cutoff=$(stat -c %Y -- "$link" 2>/dev/null) || cutoff=0
    __mg_clock
    __mg_self_load
    for p in /proc/[0-9]*; do
        [ -O "$p" ] || continue
        pid=${p#/proc/}
        [ -z "${__mg_self[$pid]-}" ] || continue
        pwd=
        while IFS= read -r -d '' e; do
            case $e in
                PWD=*)
                    pwd=${e#PWD=}
                    break
                    ;;
            esac
        done 2>/dev/null <"$p/environ"
        case $pwd in
            "$link"|"$link"/*|"$alt"|"$alt"/*)
                out+=("$pid")
                continue
                ;;
        esac
        cwd=$(readlink -- "$p/cwd" 2>/dev/null)
        exe=$(readlink -- "$p/exe" 2>/dev/null)
        case $cwd/ in
            "$phys"/*) ;;
            *)
                case $exe in
                    "$phys"/*) ;;
                    *) continue ;;
                esac
                ;;
        esac
        __mg_statf "$pid" || continue
        [ $((__mg_btime + __mg_f[19] / __mg_hz)) -gt "$cutoff" ] || out+=("$pid")
    done
    [ ${#out[@]} -eq 0 ] || printf '%s\n' "${out[*]}"
}

__mg_cleanup() {
    local n p why m hosts pids cut t rc=0 prompt='Clean up?' cargo_stays=0 wt=''
    local -a rm_links=() moves=() stays=()
    __mg_flags "$@" || return
    __gate_portable || return
    __gate_repo_path || return
    # rustup's proxies in an old ~/.cargo/bin read ~/.rustup in shells
    # without RUSTUP_HOME.
    if [ -d "$HOME/.cargo" ] && [ ! -L "$HOME/.cargo" ]; then
        cargo_stays=1
    fi
    for n in .cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash dotfiles; do
        p=$HOME/$n
        [ -L "$p" ] || continue
        why=
        if __path_in_use "$p"; then
            why='still in use (on the PATH of a process, or its executable, cwd, a mapping or an open file)'
        elif [ "$n" = dotfiles ]; then
            pids=$(__mg_checkout_users "$p")
            if [ -n "$pids" ]; then
                why="processes started in the checkout before the rename still use this path (pids $pids)"
            elif [ -f "$MANIFEST" ]; then
                while IFS=$'\t' read -r _ m _; do
                    case /$m in
                        */dotfiles/*)
                            why="the link $m goes through it"
                            break
                            ;;
                    esac
                done <"$MANIFEST"
            fi
        elif [ "$n" = .rustup ] && [ "$cargo_stays" = 1 ]; then
            why="~/.cargo stays, and its rustup proxies read ~/.rustup in shells without RUSTUP_HOME"
        elif cut=$(__mg_old_cutoff "$p"); then
            pids=$(__mg_old_shells "$cut")
            [ -z "$pids" ] || why="shells started before the migration may have it on PATH (pids $pids)"
        fi
        if [ -n "$why" ]; then
            stays+=("~/$n: $why")
            [ "$n" != .cargo ] || cargo_stays=1
        else
            rm_links+=("$p")
            [ "$n" != dotfiles ] || wt=$(__mg_worktrees 1 "$REPO")
        fi
    done
    if [ -e "$HOME/.tmux" ] || [ -L "$HOME/.tmux" ]; then
        if __mg_tmux_refs_old; then
            stays+=("~/.tmux: a running tmux server still refers to ~/.tmux/plugins (a server started with the old config keeps such a hook even after 'tmux source'; let it end)")
        else
            moves+=("$HOME/.tmux")
        fi
    fi
    if [ -e "$HOME/.nvm" ] || [ -L "$HOME/.nvm" ]; then
        # New shells stopped loading nvm when ~/.bashrc switched layouts.
        cut=$(__mg_journal_time begin migrate-tools) || cut=0
        t=$(__mg_journal_time entry-replace "$HOME/.bashrc") || t=0
        [ "$t" -le "$cut" ] || cut=$t
        pids=
        [ "$cut" = 0 ] || pids=$(__mg_old_shells "$cut")
        if __path_in_use "$HOME/.nvm"; then
            stays+=('~/.nvm: a process still runs node from it or has it on PATH')
        elif [ -n "$pids" ]; then
            stays+=("~/.nvm: shells started before the migration may have its node on PATH (pids $pids)")
        else
            moves+=("$HOME/.nvm")
        fi
    fi
    __mg_nvim_state_scan

    for p in "${rm_links[@]}"; do
        printf 'REMOVE compat link %s -> %s\n' "$(__tilde "$p")" "$(readlink -- "$p")"
    done
    [ -z "$wt" ] || printf '%s\n' "$wt"
    for p in "${moves[@]}"; do
        printf 'MOVE %s -> the backup dir\n' "$(__tilde "$p")"
    done
    for why in "${stays[@]}"; do
        printf 'STAY %s\n' "$why"
    done
    if __hist_pending "$HOME/.bash_history"; then
        printf 'MIGRATE ~/.bash_history -> %s\n' "$(__tilde "$(__hist_file)")"
    fi
    __mg_nvim_state_preview
    [ "$__mg_dry" = 0 ] || return 0
    if [ ${#rm_links[@]} -eq 0 ] && [ ${#moves[@]} -eq 0 ] && [ ${#__mg_ns_src[@]} -eq 0 ] &&
        ! __hist_pending "$HOME/.bash_history"; then
        printf 'Nothing to clean up now.\n'
        return 0
    fi
    case $(stat -f -c %T -- "$HOME" 2>/dev/null) in
        nfs*)
            # The checks above only see this host's processes.
            hosts=$(paste -sd ' ' - 2>/dev/null <"$STATE_DIR/hosts")
            printf 'This home is on NFS. Hosts that ran a migrate step: %s.\n' "${hosts:-none recorded}"
            prompt='Have old shells, tmux servers and nvims ended on all of those hosts? Clean up?'
            ;;
    esac
    __mg_confirm "$prompt" || return

    __journal_begin migrate-cleanup || return
    for p in "${rm_links[@]}"; do
        [ -L "$p" ] || continue
        if [ "$p" = "$HOME/dotfiles" ] && ! __mg_worktrees 0 "$REPO" >/dev/null; then
            printf 'stayed: ~/dotfiles: a linked worktree still needs it\n'
            rc=1
            continue
        fi
        __journal unlink "$p" "$(readlink -- "$p")" || return
        rm -f -- "$p" || rc=1
    done
    for p in "${moves[@]}"; do
        __backup_move "$p" >/dev/null || rc=1
    done
    __hist_import "$HOME/.bash_history" || rc=1
    __mg_nvim_state_copy || rc=1
    for why in "${stays[@]}"; do
        printf 'stayed: %s\n' "$why"
    done
    __mg_record_host || return
    __journal_done || return
    return "$rc"
}

# ---------------------------------------------------------------------------
# all

__mg_all() {
    local hp a rc=0 step dry=0 cli=$REPO/bin/dotfiles
    local -a base=() legacy=() inst=()
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes) base+=(--yes) legacy+=(--yes) inst+=(--yes) ;;
            -n|--dry-run) dry=1 base+=(--dry-run) legacy+=(--dry-run) inst+=(--dry-run) ;;
            --accept-dropped-edits) legacy+=("$1") ;;
            --replace-all|--keep-all) legacy+=("$1") inst+=("$1") ;;
            *)
                __err "migrate: unknown option '$1'"
                __mg_usage >&2
                return 2
                ;;
        esac
        shift
    done
    __gate_portable || return
    hp=$(__mg_home_phys) || return 1
    if [ "$REPO" != "$hp/.dotfiles" ]; then
        __err "the checkout is at $REPO; run 'dotfiles migrate repo' first"
        return 5
    fi
    __gate_targets || return
    for step in tools nvim-save nvim-state uninstall-legacy install nvim-restore; do
        printf '==> dotfiles %s\n' "$step"
        case $step in
            uninstall-legacy) "$cli" uninstall-legacy "${legacy[@]}" ;;
            install) "$cli" install "${inst[@]}" ;;
            *) "$cli" migrate "$step" "${base[@]}" ;;
        esac
        a=$?
        if [ "$a" -ne 0 ]; then
            # A dry run still previews the later steps; a real run stops here.
            [ "$dry" = 1 ] || return "$a"
            rc=$a
        fi
    done
    return "$rc"
}
