# shellcheck shell=bash
# shellcheck disable=SC2016,SC2088  # regexes and messages hold literal ~ and $VARs
# legacy.bash - `dotfiles uninstall-legacy`: convert the old layout (dotfiles
# copied into $HOME, entry files split at "# Machine-specific settings below")
# and a pre-XDG ~/.gitconfig or ~/.tmux.conf into the XDG layout.
#
# Preview, confirm, apply. Nothing is deleted: old files move into the backup
# dir and machine sections move into the new local entries. Old copies are
# compared with every version the repo ever had, so a copy that matches none
# is shown with a diff and needs consent before it leaves the active config.

# The nvim-state copy and the tmux checks live in migrate.bash, the tool
# relocation check in bootstrap.bash.
# shellcheck source=lib/dotfiles/migrate.bash
declare -F __mg_nvim_state_scan >/dev/null || . "$LIB/migrate.bash" || return
# shellcheck source=lib/dotfiles/bootstrap.bash
declare -F __bs_relocation_pending >/dev/null || . "$LIB/bootstrap.bash" || return

# Top-level names the old installer placed in $HOME (for .bak debris).
__LG_TOP=(.bash_aliases .bash_logout .bashrc .bashrc.common .fzf-git.sh .fzf.bash
    .git-completion.bash .git-prompt.sh .gitconfig .gitconfig.common .inputrc
    .noti.conf .noti.preset .profile .tmux .tmux.common.conf .tmux.conf .vim .vimrc
    .wezterm.common.lua .wezterm.lua)
# Old copies of files the repo now links; same path in $HOME and in the repo.
__LG_COPIES=(.bash_aliases .bashrc.common .fzf-git.sh .fzf.bash .git-completion.bash
    .git-prompt.sh .gitconfig.common .inputrc .noti.conf .noti.preset .tmux.common.conf
    .vimrc .wezterm.common.lua)
__LG_VIM_COPIES=(.vim/common.vim .vim/plugins.vim .vim/python_fold.vim .vim/coc-settings.json)
# Repo paths the old installer copied under ~/.config and ~/.local/share/fonts.
__LG_CONFIG_RE='^\.(config/(btop|fd|gh-dash|kanata|kime|lazygit|nvim)/|config/starship\.toml$|local/share/fonts/)'

__LG_WEZ_WATCH='wezterm.add_to_config_reload_watch_list(home .. sep .. ".wezterm.common.lua")'
__LG_WEZ_LOAD='dofile(home .. sep .. ".wezterm.common.lua").apply(config, servers)'

__LG_RE_RULE='^# =+[[:space:]]*$'
__LG_RE_BLOCK='^[[:space:]]*# >>> (bell-bash|noti-bash|modern grep/find)'
# Start or end line of any installer's block (conda, bell-bash, ...).
__LG_RE_FENCE='^[[:space:]]*#[[:space:]]*(>>>|<<<)'
# Machine values the bell/noti installers write inside their blocks; they
# outlive the block (BELL_BASH_HOME only told the installer its clone path).
__LG_RE_BLOCK_KEEP='^[[:space:]]*(export[[:space:]]+)?(BELL_BASH_[A-Z0-9_]+|NOTI_WEBHOOK)='
__LG_RE_PATH='^[[:space:]]*(export[[:space:]]+)?PATH=(.*)$'
__LG_RE_CARGO_ENV='^[[:space:]]*(\[[^]]*\][[:space:]]*&&[[:space:]]*)?(\.|source)[[:space:]]+"?(\$HOME|\$\{HOME\}|~)/\.cargo/env"?[[:space:]]*$'
__LG_RE_NVM='^[[:space:]]*(export[[:space:]]+NVM_DIR=|(\[[^]]*\][[:space:]]*&&[[:space:]]*)?(\\?\.|source)[[:space:]]+"?\$\{?NVM_DIR\}?/(nvm\.sh|bash_completion))'
__LG_RE_NVM_NOTE='^[[:space:]]*#.*[Nn][Vv][Mm]'
__LG_RE_CLAUDE_ALIAS='^[[:space:]]*(command[[:space:]]+-v[[:space:]]+claude-auto.*&&[[:space:]]*)?alias[[:space:]]+claude='
__LG_RE_CLAUDE_NOTE='^[[:space:]]*# claude-account-switcher:'
# The names are BASH_REMATCH[3]; an optional "declare -F bell_skip ... &&"
# guard comes first.
__LG_RE_BELL_SKIP='^[[:space:]]*((declare[[:space:]]+-F|command[[:space:]]+-v)[[:space:]]+bell_skip[^|;]*&&[[:space:]]*)?bell_skip[[:space:]]+add[[:space:]]+(.*)$'
__LG_RE_IF_SKIP='^[[:space:]]*if[[:space:]].*bell_skip.*then[[:space:]]*$'
__LG_RE_FI='^[[:space:]]*fi[[:space:]]*$'
__LG_RE_TMUX_COMMON='^[[:space:]]*source(-file)?([[:space:]]+-[qFnv]+)*[[:space:]]+["'\'']?(~|\$HOME|\$\{HOME\})/\.tmux\.common\.conf'
__LG_RE_TMUX_PLUGIN='^[[:space:]]*set(-option)?[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*@plugin[[:space:]]'
__LG_RE_GIT_INC='^[[:space:]]*path[[:space:]]*=[[:space:]]*"?(~/|\$HOME/)?\.gitconfig\.common"?[[:space:]]*$'
__LG_RE_GIT_REL='^[[:space:]]*path[[:space:]]*=[[:space:]]*"?[^"/~[:space:]]'
__LG_RE_INCLUDE='^[[:space:]]*\[include\][[:space:]]*$'
__LG_RE_GIT_EMPTY='^[[:space:]]*([#;].*)?$'
__LG_RE_GIT_SECTION='^[[:space:]]*\['
__LG_RE_DOCKER_GIT='(~|\$HOME|\$\{HOME\})/\.gitconfig:'
__LG_RE_OLDREF='(~|\$HOME|\$\{HOME\})/\.(bell-bash|noti-bash|fzf-tab-completion|fzf|cargo|rustup|nvm|vimrc|vim|bashrc\.common|bash_aliases|bash_history|gitconfig\.common|gitconfig|tmux\.common\.conf|tmux\.conf|tmux|wezterm\.common\.lua|wezterm\.lua|inputrc|noti\.conf|noti\.preset)([^A-Za-z0-9_-]|$)'
__LG_RE_OLDREPO='(~|\$HOME|\$\{HOME\})/dotfiles([^A-Za-z0-9_.-]|$)'
__LG_RE_KEEP='BELL_BASH_[A-Z_]*=|NOTI_WEBHOOK=|^[[:space:]]*(function[[:space:]]+)?claude[[:space:]]*\(\)|[Xx]ilinx|[Pp]eta[Ll]inux|minicom|BUN_INSTALL|/\.bun/'
__LG_RE_HIST='^[[:space:]]*(export[[:space:]]+)?(HISTSIZE|HISTFILESIZE)=["'\'']?([0-9]+)'
__LG_RE_COMMENT='^[[:space:]]*(#|$)'
__LG_RE_NOTE='^[[:space:]]*(#|;|--)'
__LG_RE_PROFILE_FIX='LANG=|GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS|PATH'
__LG_RE_BLANK='^[[:space:]]*$'

__lg_usage() {
    cat <<'EOF'
Usage: dotfiles uninstall-legacy [--dry-run] [--yes] [--accept-dropped-edits]
                                 [--replace-all | --keep-all]

Converts the old copy-installed layout (and a pre-XDG ~/.gitconfig or
~/.tmux.conf) into this one. It previews every change, asks, then links the
repo's files, writes the local entry files with the old machine sections,
merges ~/.bash_history and moves every old file into the backup dir. Nothing
is deleted. On a live host run 'dotfiles migrate tools' first.

  -n, --dry-run           only preview
  -y, --yes               apply without the final confirmation
      --accept-dropped-edits
                          without a terminal, let locally edited old copies
                          leave the active config (the preview shows diffs)
      --replace-all       replace other conflicting files (backed up)
      --keep-all          keep other conflicting files (left unlinked)
EOF
}

__cmd_uninstall_legacy() {
    __lg_dry=0 __lg_yes=0 __lg_accept=0 __lg_mode=
    while [ $# -gt 0 ]; do
        case $1 in
            -n|--dry-run) __lg_dry=1 ;;
            -y|--yes) __lg_yes=1 ;;
            --accept-dropped-edits) __lg_accept=1 ;;
            --replace-all|--keep-all)
                if [ "$1" = --replace-all ]; then
                    set -- replace "${@:2}"
                else
                    set -- keep "${@:2}"
                fi
                if [ -n "$__lg_mode" ] && [ "$__lg_mode" != "$1" ]; then
                    __err "uninstall-legacy: --replace-all and --keep-all exclude each other"
                    return 2
                fi
                __lg_mode=$1
                ;;
            -h|--help)
                __lg_usage
                return 0
                ;;
            *)
                __err "uninstall-legacy: unknown option '$1'"
                __lg_usage >&2
                return 2
                ;;
        esac
        shift
    done
    __gate_portable || return
    __lg_detect
    if [ "$__lg_legacy" = 0 ] && [ "$__lg_prexdg" = 0 ]; then
        printf 'No old layout found; nothing to do.\n'
        return 0
    fi
    __gate_repo_path || return
    if __lg_tools_pending; then
        __err "run 'dotfiles migrate tools' first"
        return 5
    fi
    __tmpdir || return
    __lg_run "$__TMP"
}

__lg_exists() {
    [ -e "$1" ] || [ -L "$1" ]
}

__lg_item() {
    __lg_items+=("$1"$'\t'"$2")
}

__lg_lines_out() {
    [ $# -eq 0 ] || printf '%s\n' "$@"
}

# __lg_legacy: the old copy-installed layout. __lg_prexdg: a ~/.gitconfig or
# ~/.tmux.conf, which would shadow the XDG entry files. __lg_resume: only an
# unfinished earlier run says the layout is old.
__lg_detect() {
    __lg_legacy=0 __lg_prexdg=0 __lg_resume=0
    if __lg_exists "$HOME/.bashrc.common" || __lg_exists "$HOME/.gitconfig.common" ||
        __lg_exists "$HOME/.wezterm.common.lua" ||
        grep -qs -- "$LEGACY_MARKER_RE" "$HOME/.bashrc" "$HOME/.tmux.conf" "$HOME/.gitconfig"; then
        __lg_legacy=1
    elif __lg_unfinished; then
        __lg_legacy=1 __lg_resume=1
    fi
    if __lg_exists "$HOME/.gitconfig" || __lg_exists "$HOME/.tmux.conf"; then
        __lg_prexdg=1
    fi
}

# True when the last uninstall-legacy run began on an old layout and never
# finished. The old files it moved first were the only signs of that layout,
# so its later steps (debris, ~/.profile, credentials) would never run.
__lg_unfinished() {
    local id action path detail last='' kind=''
    local -A fin=()
    [ -f "$JOURNAL" ] || return 1
    while IFS=$'\t' read -r id _ action path detail; do
        case $action in
            begin) [ "$path" != uninstall-legacy ] || last=$id kind=$detail ;;
            done) fin[$id]=1 ;;
        esac
    done <"$JOURNAL"
    [ -n "$last" ] && [ "$kind" = legacy ] && [ -z "${fin[$last]-}" ]
}

# True (reasons on stderr) while tool dirs are still at their old paths: the
# CARGO_HOME etc. that env.bash exports would not find them yet.
__lg_tools_pending() {
    local p pending
    # FNM_DIR as env.bash sets it; this command does not source env.bash.
    pending=$(FNM_DIR=$DATA/fnm __bs_relocation_pending) || return 1
    while IFS= read -r p; do
        __err "not relocated yet: $(__tilde "$p")"
    done <<<"$pending"
}

__lg_reset() {
    __lg_items=() __lg_moves=() __lg_vim_files=() __lg_tmux_files=() __lg_fresh=() __lg_modes=()
    declare -gA __lg_kind=() __lg_occ=() __lg_blobs=()
    __lg_edits=0 __lg_fatal=0 __lg_shallow=0 __lg_filled=0
    __lg_mode_bash='' __lg_mode_tmux='' __lg_mode_git='' __lg_mode_wez='' __lg_bash_mode=''
    __lg_sec_bash=() __lg_sec_tmux=() __lg_sec_git=() __lg_wez=()
    __lg_cred=0 __lg_profile_skel=0 __lg_tmux_rmdir=0 __lg_hist=0 __lg_nvim_state=0
    __lg_lines=() __lg_kept=() __lg_kept_no=() __lg_gone=() __lg_mark=0 __lg_start=0
}

__lg_run() {
    local tmp=$1
    __lg_reset
    if [ "$__lg_resume" = 1 ]; then
        __lg_item WARN "the last uninstall-legacy run did not finish (see $(__tilde "$JOURNAL")); this run completes it"
    fi
    __install_plan "$tmp/plan" || return
    __lg_load_plan "$tmp/plan"
    __lg_load_history
    __lg_entry_bash || return
    __lg_entry_file tmux "$HOME/.tmux.conf" "$CFG/tmux/tmux.conf" || return
    __lg_entry_file git "$HOME/.gitconfig" "$CFG/git/config" || return
    __lg_credentials
    if [ "$__lg_legacy" = 1 ]; then
        __lg_entry_wezterm || return
        __lg_copies
        __lg_config_copies
        __lg_local_bin
        __lg_vim_dir
        __lg_tmux_dir
        __lg_profile
        __lg_debris
        __lg_keeps
        __lg_history_state
    fi
    __lg_mark_plan "$tmp/plan" || return
    __entries_prepare "$tmp/entries" "${__lg_fresh[@]}" || return
    __lg_fill_entries "$tmp/entries" || return
    __lg_preview "$tmp"
    [ "$__lg_dry" = 0 ] || return 0
    __lg_consent "$tmp/plan" || return
    __lg_apply "$tmp"
}

# ---------------------------------------------------------------------------
# Repo history

# Index install's plan by target: __lg_kind[target]=state.
__lg_load_plan() {
    local line t
    while IFS= read -r line || [ -n "$line" ]; do
        t=${line#*$'\t'}
        t=${t%%$'\t'*}
        if [ "$t" != "$line" ] && [ -n "$t" ]; then
            __lg_kind[$t]=${line%%$'\t'*}
        fi
    done <"$1"
}

# __lg_blobs[repo path]: every blob the path had in any ref, newest first.
__lg_load_history() {
    local meta path x old new b
    [ "$(__git rev-parse --is-shallow-repository 2>/dev/null)" != true ] || __lg_shallow=1
    while IFS=$'\t' read -r meta path; do
        [ -n "$path" ] || continue
        # meta: ":<mode> <mode> <old blob> <new blob> <status>"
        x=${meta#* } x=${x#* }
        old=${x%% *} x=${x#* }
        new=${x%% *}
        for b in "$new" "$old"; do
            case $b in *[!0]*) ;; *) continue ;; esac
            case " ${__lg_blobs[$path]-} " in
                *" $b "*) ;;
                *) __lg_blobs[$path]+="$b " ;;
            esac
        done
    done < <(__git log --all -m --no-renames --raw --no-abbrev --format= -- \
        .bashrc .tmux.conf .gitconfig .wezterm.lua .profile .tmux .vim "${__LG_COPIES[@]}" \
        .config/btop .config/fd .config/gh-dash .config/kanata .config/kime .config/lazygit \
        .config/nvim .config/starship.toml .local/share/fonts .local/bin 2>/dev/null)
}

# True when FILE holds a version repo path RPATH once had.
__lg_is_blob() {
    local h
    h=$(__git hash-object --no-filters -- "$1" 2>/dev/null) || return 1
    case " ${__lg_blobs[$2]-} " in
        *" $h "*) return 0 ;;
    esac
    return 1
}

__lg_above() {
    sed -n "/$LEGACY_MARKER_RE/q;p"
}

# Report FILE, a copy of repo path RPATH that matches none of its versions,
# with a diff against the newest one (ABOVE=1: the parts above the marker).
__lg_edited() {
    local f=$1 rpath=$2 above=${3-0} kind=LOCALLY-EDITED newest d
    [ "$__lg_shallow" = 0 ] || kind=UNKNOWN
    __lg_edits=$((__lg_edits + 1))
    newest=${__lg_blobs[$rpath]-}
    newest=${newest%% *}
    if [ -z "$newest" ]; then
        __lg_item "$kind" "$(__tilde "$f") (the repo history has no version of $rpath)"
        return 0
    fi
    if [ "$above" = 1 ]; then
        d=$(diff -u --label "$rpath (newest repo version, above the marker)" --label "$(__tilde "$f")" \
            <(__git cat-file blob "$newest" | __lg_above) <(__lg_above <"$f"))
    else
        d=$(diff -u --label "$rpath (newest repo version)" --label "$(__tilde "$f")" \
            <(__git cat-file blob "$newest") "$f")
    fi
    __lg_item "$kind" "$(__tilde "$f") matches no version of $rpath; diff against the newest:"$'\n'"$(printf '%s\n' "$d" | sed 's/^/    /')"
}

# Report the old copy FILE of repo path RPATH; it moves either way.
__lg_copy() {
    local f=$1 rpath=$2
    if [ -L "$f" ]; then
        __lg_item MOVE "$(__tilde "$f") (old link -> $(readlink -- "$f"))"
    elif [ -f "$f" ] && ! __lg_is_blob "$f" "$rpath"; then
        __lg_item MOVE "$(__tilde "$f") (locally edited)"
        __lg_edited "$f" "$rpath"
    else
        __lg_item MOVE "$(__tilde "$f")"
    fi
}

# Read FILE into __lg_lines. __lg_mark is the 1-based line of the legacy
# marker (0 when absent), __lg_start the index where its section starts: the
# old templates close the marker with a "# ====" line.
__lg_read() {
    local i
    __lg_lines=() __lg_mark=0 __lg_start=0
    mapfile -t __lg_lines <"$1" || return 1
    for i in "${!__lg_lines[@]}"; do
        if [[ ${__lg_lines[i]} =~ $LEGACY_MARKER_RE ]]; then
            __lg_mark=$((i + 1)) __lg_start=$((i + 1))
            if [[ ${__lg_lines[i + 1]-} =~ $__LG_RE_RULE ]]; then
                __lg_start=$((i + 2))
            fi
            break
        fi
    done
}

# Report FILE when the part above its marker matches no version of RPATH.
__lg_check_above() {
    local f=$1 rpath=$2 mine b
    mine=$(__lg_above <"$f")
    for b in ${__lg_blobs[$rpath]-}; do
        [ "$(__git cat-file blob "$b" | __lg_above)" != "$mine" ] || return 0
    done
    __lg_edited "$f" "$rpath" 1
}

# ---------------------------------------------------------------------------
# Machine sections

__lg_hint() {
    case $1 in
        bell-bash|noti-bash|fzf|fzf-tab-completion) echo "now ~/.local/opt/$1" ;;
        cargo) echo 'now $CARGO_HOME' ;;
        rustup) echo 'now $RUSTUP_HOME' ;;
        nvm) echo 'node now comes from fnm ($FNM_DIR)' ;;
        vim) echo 'now ~/.config/vim; vim state and plugins live in the XDG state and data dirs' ;;
        vimrc) echo 'now ~/.config/vim/vimrc' ;;
        bashrc.common) echo 'now ~/.config/bash/common.bash' ;;
        bash_aliases) echo 'now ~/.config/bash/aliases.bash' ;;
        bash_history) echo 'now $XDG_STATE_HOME/bash/history' ;;
        gitconfig) echo 'now ~/.config/git/config' ;;
        gitconfig.common) echo 'now ~/.config/git/common' ;;
        tmux.conf) echo 'now ~/.config/tmux/tmux.conf' ;;
        tmux.common.conf) echo 'now ~/.config/tmux/common.conf' ;;
        tmux) echo '~/.tmux goes to the backup dir; TPM plugins now live in $XDG_DATA_HOME/tmux/plugins' ;;
        wezterm.lua) echo 'now ~/.config/wezterm/wezterm.lua' ;;
        wezterm.common.lua) echo 'now ~/.config/wezterm/common.lua' ;;
        inputrc) echo 'now ~/.config/readline/inputrc' ;;
        noti.conf|noti.preset) echo "now ~/.config/noti/$1" ;;
        *) echo 'old path' ;;
    esac
}

# True when LINE assigns PATH and only adds dirs env.bash now puts on PATH.
__lg_path_owned() {
    local v e rest self=0 owned=0 h='$HOME'
    [[ $1 =~ $__LG_RE_PATH ]] || return 1
    v=${BASH_REMATCH[2]}
    v=${v//\"/}
    v=${v//\'/}
    v=${v%"${v##*[![:space:]]}"}
    rest=$v:
    while [ -n "$rest" ]; do
        e=${rest%%:*}
        rest=${rest#*:}
        e=${e/#'${HOME}'/$h}
        e=${e/#'~'/$h}
        e=${e%/}
        case $e in
            '$PATH'|'${PATH}') self=$((self + 1)) ;;
            '$HOME/.local/bin'|'$HOME/.cargo/bin'|'$HOME/.local/opt/tmux/bin'|'$HOME/.fzf/bin')
                owned=$((owned + 1))
                ;;
            *) return 1 ;;
        esac
    done
    [ "$self" -eq 1 ] && [ "$owned" -gt 0 ]
}

# __lg_skip_ok: the names common.bash already passes to `bell_skip add`.
__lg_skip_load() {
    local line w
    local -a words
    [ "${__lg_skip_loaded-}" != 1 ] || return 0
    declare -gA __lg_skip_ok=()
    __lg_skip_loaded=1
    while IFS= read -r line; do
        [[ $line =~ $__LG_RE_BELL_SKIP ]] || continue
        read -ra words <<<"${BASH_REMATCH[3]}"
        for w in "${words[@]}"; do
            case $w in '>'*|[0-9]'>'*|'&>'*|'#'*) break ;; esac
            w=${w//[\"\']/}
            [ -z "$w" ] || __lg_skip_ok[$w]=1
        done
    done 2>/dev/null <"$REPO/.config/bash/common.bash"
}

# True when LINE is a `bell_skip add` of names common.bash already adds.
__lg_skip_covered() {
    local w
    local -a words
    __lg_skip_load
    [[ $1 =~ $__LG_RE_BELL_SKIP ]] || return 1
    read -ra words <<<"${BASH_REMATCH[3]}"
    for w in "${words[@]}"; do
        case $w in '>'*|[0-9]'>'*|'&>'*|'#'*) break ;; esac
        w=${w//[\"\']/}
        [ -z "$w" ] || [ -n "${__lg_skip_ok[$w]-}" ] || return 1
    done
}

# Mark lines FROM..TO (indexes into __lg_lines) as dropped for WHY;
# __lg_filter reports them in line order.
__lg_drop() {
    local k
    for ((k = $1; k <= $2; k++)); do
        __lg_gone[k]=$3
    done
}

# Drop the last kept line when it matches RE: it belongs to the dropped line
# that follows it.
__lg_pop() {
    local last=$((${#__lg_kept[@]} - 1))
    if [ "$last" -lt 0 ] || [[ ! ${__lg_kept[last]} =~ $1 ]]; then
        return 1
    fi
    __lg_drop "${__lg_kept_no[last]}" "${__lg_kept_no[last]}" "$2"
    unset '__lg_kept[last]' '__lg_kept_no[last]'
}

# Called after the lines before line NEXT were dropped for WHY. When NEXT is
# blank or past the end, their paragraph ends there: the comments it still
# keeps explained only the dropped lines, so they go too, and so does one of
# the two blank lines then left around the gap. Installer fences and comments
# __lg_keep reports as KEEP stay.
__lg_drop_notes() {
    local next=$1 why=$2 c
    if [ "$next" -lt ${#__lg_lines[@]} ] && [[ ! ${__lg_lines[next]} =~ $__LG_RE_BLANK ]]; then
        return 0
    fi
    while [ ${#__lg_kept[@]} -gt 0 ]; do
        c=${__lg_kept[-1]}
        if [[ $c =~ $__LG_RE_FENCE || $c =~ $__LG_RE_KEEP ]]; then
            break
        fi
        __lg_pop "$__LG_RE_NOTE" "$why" || break
    done
    if [ ${#__lg_kept[@]} -gt 0 ] && [[ ${__lg_kept[-1]} =~ $__LG_RE_BLANK ]]; then
        unset '__lg_kept[-1]' '__lg_kept_no[-1]'
    fi
}

# True when the include path at index I is the only entry of its [include].
__lg_git_include_only() {
    local j n=${#__lg_lines[@]} last=$((${#__lg_kept[@]} - 1))
    if [ "$last" -lt 0 ] || [[ ! ${__lg_kept[last]} =~ $__LG_RE_INCLUDE ]]; then
        return 1
    fi
    for ((j = $1 + 1; j < n; j++)); do
        [[ ! ${__lg_lines[j]} =~ $__LG_RE_GIT_EMPTY ]] || continue
        [[ ${__lg_lines[j]} =~ $__LG_RE_GIT_SECTION ]]
        return
    done
}

# Keep line I of DISP and report what it may need.
__lg_keep() {
    local kind=$1 disp=$2 i=$3 line=${__lg_lines[$3]} where
    __lg_kept+=("$line")
    __lg_kept_no+=("$i")
    where="$disp:$((i + 1)): $line"
    if [[ $line =~ $__LG_RE_NOTE ]]; then
        : # comments need no fix
    elif [[ $line =~ $__LG_RE_DOCKER_GIT ]]; then
        __lg_item FIX-SUGGESTION "$where  [mount -v \"\$HOME/.config/git:<home>/.config/git:ro\" instead; docker creates a directory where ~/.gitconfig is missing]"
    elif [[ $line =~ $__LG_RE_OLDREF ]]; then
        __lg_item FIX-SUGGESTION "$where  [$(__lg_hint "${BASH_REMATCH[2]}")]"
    elif [[ $line =~ $__LG_RE_OLDREPO ]]; then
        __lg_item FIX-SUGGESTION "$where  [the checkout is now ~/.dotfiles; the ~/dotfiles link goes away with 'dotfiles migrate cleanup']"
    elif [ "$kind" = bash ] && [[ $line =~ NOTI_WEBHOOK= ]]; then
        __lg_item FIX-SUGGESTION "$where  [a secret in ~/.bashrc; common.bash reads it from ~/.config/noti/webhook (chmod 600) instead]"
    elif [ "$kind" = bash ] && [[ $line =~ $__LG_RE_PATH ]] &&
        [[ $line == *.local/bin* || $line == *.local/opt/tmux/bin* ]]; then
        __lg_item FIX-SUGGESTION "$where  [env.bash already puts ~/.local/bin, cargo, fnm and tmux on PATH; this line now runs after common.bash, so ~/.local/bin comes before the bell-bash and noti-bash clones]"
    elif [ "$kind" = tmux ] && [[ $line =~ $__LG_RE_TMUX_PLUGIN ]]; then
        __lg_item FIX-SUGGESTION "$where  [declare local TPM plugins above the managed block]"
    elif [ "$kind" = git ] && [[ $line =~ $__LG_RE_GIT_REL ]]; then
        __lg_item FIX-SUGGESTION "$where  [a relative include path now resolves against ~/.config/git]"
    elif [ "$kind" = wezterm ] && [[ $line == *.wezterm.common.lua* ]]; then
        __lg_item FIX-SUGGESTION "$where  [loads the old common file; load ~/.config/wezterm/common.lua as the template does]"
    fi
    if [[ $line =~ $__LG_RE_KEEP ]]; then
        __lg_item KEEP "$where"
    fi
    if [[ $line =~ $__LG_RE_HIST ]] && [ "${BASH_REMATCH[3]}" -lt 10000 ]; then
        __lg_item WARN "$where  [truncates the history file to ${BASH_REMATCH[3]} lines on every start; use 10000 or more]"
    fi
}

# Filter __lg_lines from index START (a section, shown as DISP) for KIND
# bash|tmux|git|wezterm into __lg_kept. With MODE "report" the file stays as
# it is, so drops are only suggested.
__lg_filter() {
    local kind=$1 disp=$2 start=$3 mode=${4-apply} n=${#__lg_lines[@]} i j k line name end_re why
    __lg_kept=() __lg_kept_no=() __lg_gone=()
    for ((i = start; i < n; i++)); do
        line=${__lg_lines[i]}
        if { [ "$kind" = bash ] || [ "$kind" = tmux ]; } && [[ $line =~ $__LG_RE_BLOCK ]]; then
            name=${BASH_REMATCH[1]}
            if [ "$kind" = bash ] || [ "$name" = bell-bash ]; then
                end_re="^[[:space:]]*# <<< $name"
                for ((j = i + 1; j < n; j++)); do
                    [[ ! ${__lg_lines[j]} =~ $end_re ]] || break
                done
                if [ "$j" -lt "$n" ]; then
                    why="$name block; the common config wires it now"
                    if [ "$kind" = bash ] && [ "$name" != 'modern grep/find' ]; then
                        why="$name block; common.bash wires the clone now (PATH, claude registration); its machine values stay"
                    fi
                    for ((k = i; k <= j; k++)); do
                        if [ "$kind" = bash ] && [[ ${__lg_lines[k]} =~ $__LG_RE_BLOCK_KEEP ]] &&
                            [ "${BASH_REMATCH[2]}" != BELL_BASH_HOME ]; then
                            __lg_keep "$kind" "$disp" "$k"
                        else
                            __lg_drop "$k" "$k" "$why"
                        fi
                    done
                    i=$j
                    __lg_drop_notes "$((i + 1))" "$why"
                    continue
                fi
            fi
        fi
        why='' j=$i
        case $kind in
            bash)
                if __lg_path_owned "$line" || [[ $line =~ $__LG_RE_CARGO_ENV ]]; then
                    why='env.bash sets this up'
                elif [[ $line =~ $__LG_RE_NVM ]]; then
                    why='nvm, replaced by fnm'
                    __lg_pop "$__LG_RE_NVM_NOTE" "$why"
                elif [[ $line =~ $__LG_RE_CLAUDE_ALIAS ]]; then
                    why='shadows the claude() wrapper of common.bash'
                    __lg_pop "$__LG_RE_CLAUDE_NOTE" "$why"
                elif __lg_skip_covered "$line"; then
                    why='common.bash already adds these bell_skip entries'
                    if [[ ${__lg_lines[i + 1]-} =~ $__LG_RE_FI ]] && __lg_pop "$__LG_RE_IF_SKIP" "$why"; then
                        j=$((i + 1))
                    fi
                fi
                ;;
            tmux)
                if [[ $line =~ $__LG_RE_TMUX_COMMON ]]; then
                    why='the managed block loads common.conf'
                fi
                ;;
            git)
                if [[ $line =~ $__LG_RE_GIT_INC ]]; then
                    why='the managed block includes common'
                    if __lg_git_include_only "$i"; then
                        __lg_pop "$__LG_RE_INCLUDE" "$why"
                    fi
                fi
                ;;
        esac
        if [ -z "$why" ]; then
            __lg_keep "$kind" "$disp" "$i"
            continue
        fi
        __lg_drop "$i" "$j" "$why"
        i=$j
        __lg_drop_notes "$((i + 1))" "$why"
    done
    for k in "${!__lg_gone[@]}"; do
        if [ "$mode" = report ]; then
            __lg_item FIX-SUGGESTION "$disp:$((k + 1)): ${__lg_lines[k]}  [remove: ${__lg_gone[k]}]"
        else
            __lg_item REMOVE-CANDIDATE "$disp:$((k + 1)): ${__lg_lines[k]}  [${__lg_gone[k]}]"
        fi
    done
}

__lg_blank() {
    local l
    for l in "$@"; do
        [[ $l =~ $__LG_RE_BLANK ]] || return 1
    done
}

# True when FILE holds LINES, without their leading and trailing blank
# lines, as consecutive lines.
__lg_has_run() {
    local f=$1 i j m
    local -a have=() want=()
    shift
    while [ $# -gt 0 ] && __lg_blank "$1"; do
        shift
    done
    want=("$@")
    while [ ${#want[@]} -gt 0 ] && __lg_blank "${want[-1]}"; do
        unset 'want[-1]'
    done
    m=${#want[@]}
    [ "$m" -gt 0 ] || return 1
    mapfile -t have <"$f" || return 1
    for ((i = 0; i + m <= ${#have[@]}; i++)); do
        for ((j = 0; j < m; j++)); do
            [ "${have[i + j]}" = "${want[j]}" ] || continue 2
        done
        return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Entry files

# ~/.bashrc: with the marker it starts over from the template and gets its
# machine section in the interactive local zone; a repo copy starts over from
# the template; a distro or custom file gets the managed blocks like install.
__lg_entry_bash() {
    local f=$HOME/.bashrc
    __lg_exists "$f" || return 0
    if [ -L "$f" ] || [ ! -f "$f" ]; then
        __err "~/.bashrc is not a regular file; replace it by hand first"
        return 5
    fi
    # A resumed run: the stopped one already wrote the new ~/.bashrc.
    if [ "$__lg_legacy" = 0 ] || [ "$__lg_resume" = 1 ]; then
        return 0
    fi
    __lg_read "$f" || return 1
    if [ "$__lg_mark" -gt 0 ]; then
        __lg_check_above "$f" .bashrc
        __lg_filter bash '~/.bashrc' "$__lg_start"
        if [ ${#__lg_kept[@]} -gt 0 ] && ! __lg_blank "${__lg_kept[@]}"; then
            __lg_sec_bash=("${__lg_kept[@]}")
        fi
    elif ! __lg_is_blob "$f" .bashrc; then
        if [ -f /etc/skel/.bashrc ] && cmp -s -- "$f" /etc/skel/.bashrc; then
            __lg_item MOVE '~/.bashrc (distro copy; replaced by the template)'
        else
            __lg_filter bash '~/.bashrc' 0 report
            __lg_item KEEP '~/.bashrc (no legacy marker; the managed blocks are added around it)'
        fi
        return 0
    fi
    # The machine section may hold secrets: the new file keeps the old mode.
    __lg_bash_mode=$(stat -c %a -- "$f") || return 1
    __lg_mode_bash=migrate
    __lg_fresh+=(bash)
    __lg_item MIGRATE "~/.bashrc -> ~/.bashrc (new template; ${#__lg_sec_bash[@]} machine line(s) in its interactive local zone; the old file moves to the backup dir)"
}

# SRC (~/.tmux.conf or ~/.gitconfig): its machine section, or the whole file
# when it has no marker and is no repo version, goes below the block of the
# XDG entry DST.
__lg_entry_file() {
    local tool=$1 src=$2 dst=$3 rpath=${2##*/}
    __lg_exists "$src" || return 0
    if [ -L "$dst" ] || { __lg_exists "$dst" && [ ! -f "$dst" ]; }; then
        __err "$dst is not a regular file; fix it by hand first"
        return 5
    fi
    __lg_moves+=("$src")
    if [ ! -f "$src" ]; then
        __lg_item MOVE "$(__tilde "$src") (not a regular file)"
        __lg_item WARN "$(__tilde "$src") is a directory or special file (docker creates a directory for a missing mount source)"
        return 0
    fi
    __lg_read "$src" || return 1
    if [ "$__lg_mark" -gt 0 ]; then
        __lg_check_above "$src" "$rpath"
        __lg_filter "$tool" "$(__tilde "$src")" "$__lg_start"
    elif __lg_is_blob "$src" "$rpath"; then
        __lg_kept=()
    else
        __lg_filter "$tool" "$(__tilde "$src")" 0
    fi
    if [ ${#__lg_kept[@]} -eq 0 ] || __lg_blank "${__lg_kept[@]}"; then
        __lg_kept=()
        __lg_item MOVE "$(__tilde "$src") (no machine settings)"
    elif [ -f "$dst" ] && __lg_has_run "$dst" "${__lg_kept[@]}"; then
        # An earlier run wrote the section and stopped before moving SRC.
        __lg_kept=()
        __lg_item MOVE "$(__tilde "$src") (its machine section is already in $(__tilde "$dst"))"
    elif [ -e "$dst" ]; then
        __lg_item MIGRATE-MERGE "$(__tilde "$src") -> $(__tilde "$dst") (${#__lg_kept[@]} line(s) appended below the block; its content stays)"
    else
        __lg_item MIGRATE "$(__tilde "$src") -> $(__tilde "$dst") (${#__lg_kept[@]} line(s) below the block)"
    fi
    if [ "$tool" = tmux ]; then
        __lg_sec_tmux=("${__lg_kept[@]}")
    else
        __lg_sec_git=("${__lg_kept[@]}")
    fi
}

# Replace the two common-loading lines of __lg_lines with the managed block
# (__BODY) into __lg_wez; fails unless each occurs exactly once.
__lg_wez_convert() {
    local i n=${#__lg_lines[@]} t watch=-1 load=-1
    for ((i = 0; i < n; i++)); do
        t=${__lg_lines[i]}
        t=${t#"${t%%[![:space:]]*}"}
        t=${t%"${t##*[![:space:]]}"}
        if [ "$t" = "$__LG_WEZ_WATCH" ]; then
            [ "$watch" -lt 0 ] || return 1
            watch=$i
        elif [ "$t" = "$__LG_WEZ_LOAD" ]; then
            [ "$load" -lt 0 ] || return 1
            load=$i
        fi
    done
    if [ "$watch" -lt 0 ] || [ "$load" -lt 0 ]; then
        return 1
    fi
    __lg_wez=()
    for ((i = 0; i < n; i++)); do
        [ "$i" -ne "$watch" ] || continue
        if [ "$i" -eq "$load" ]; then
            __lg_wez+=('-- >>> dotfiles >>>' "${__BODY[@]}" '-- <<< dotfiles <<<')
        else
            __lg_wez+=("${__lg_lines[i]}")
        fi
    done
}

__lg_entry_wezterm() {
    local src=$HOME/.wezterm.lua dst=$CFG/wezterm/wezterm.lua
    __lg_exists "$src" || return 0
    __template_body "$REPO/lib/templates/wezterm.lua" dotfiles '-- ' || return 1
    __lg_moves+=("$src")
    if [ ! -f "$src" ]; then
        __lg_item MOVE '~/.wezterm.lua (not a regular file)'
        return 0
    fi
    __lg_read "$src" || return 1
    if __lg_exists "$dst"; then
        # What an earlier run that stopped before moving the source wrote.
        if [ -f "$dst" ] && { cmp -s -- "$src" "$dst" ||
            { __lg_wez_convert && cmp -s -- <(__lg_lines_out "${__lg_wez[@]}") "$dst"; }; }; then
            __lg_item MOVE "~/.wezterm.lua (already migrated to $(__tilde "$dst"))"
            return 0
        fi
        # WezTerm reads ~/.wezterm.lua first: that is the config in use.
        __lg_item MOVE "~/.wezterm.lua (the existing $(__tilde "$dst") stays)"
        __lg_item LOCALLY-EDITED "~/.wezterm.lua leaves the active config because $(__tilde "$dst") exists; merge the two by hand from the backup dir"
        __lg_edits=$((__lg_edits + 1))
        return 0
    fi
    if __lg_wez_convert; then
        __lg_mode_wez=managed
        __lg_item MIGRATE "~/.wezterm.lua -> $(__tilde "$dst") (its two common-loading lines become the managed block)"
        __lg_lines=("${__lg_wez[@]}")
    else
        __lg_mode_wez=unmanaged
        __lg_item MIGRATE "~/.wezterm.lua -> $(__tilde "$dst") (NO COMMON LOADER: moved unchanged and recorded as unmanaged)"
    fi
    __lg_filter wezterm "$(__tilde "$dst")" 0
}

__lg_credentials() {
    local src=$HOME/.git-credentials dst=$CFG/git/credentials why=''
    __lg_exists "$src" || return 0
    if [ -L "$src" ] || [ ! -f "$src" ]; then
        why='not a regular file'
    elif __lg_exists "$dst"; then
        why="$(__tilde "$dst") exists too"
    fi
    if [ -n "$why" ]; then
        __lg_item KEEP "~/.git-credentials ($why)"
        __lg_item WARN "~/.git-credentials stays ($why); merge it into $(__tilde "$dst") by hand"
        return 0
    fi
    __lg_cred=1
    __lg_item MIGRATE "~/.git-credentials -> $(__tilde "$dst") (mode kept)"
}

# ---------------------------------------------------------------------------
# Old copies, debris and leftovers

__lg_copies() {
    local p f
    for p in "${__LG_COPIES[@]}"; do
        f=$HOME/$p
        __lg_exists "$f" || continue
        __lg_copy "$f" "$p"
        __lg_moves+=("$f")
    done
    for f in "$HOME"/.tmux/.tmux.theme.*.conf; do
        __lg_exists "$f" || continue
        __lg_copy "$f" ".tmux/${f##*/}"
        __lg_tmux_files+=("$f")
    done
    for p in "${__LG_VIM_COPIES[@]}"; do
        f=$HOME/$p
        __lg_exists "$f" || continue
        __lg_copy "$f" "$p"
        __lg_vim_files+=("$f")
    done
}

# Old copies and links in the ~/.config dirs and the font dir the old
# installer filled: every path that ever existed there in the repo. One in
# the way of a link is marked for install's plan; the others just move.
__lg_config_copies() {
    local rpath f
    while IFS= read -r rpath; do
        f=$HOME/$rpath
        __lg_exists "$f" || continue
        if [ -d "$f" ] && [ ! -L "$f" ]; then
            continue
        fi
        case ${__lg_kind[$f]-} in
            correct|kept) continue ;;
            identical)
                __lg_item MOVE "$(__tilde "$f") (identical copy)"
                continue
                ;;
            conflict) __lg_occ[$f]=1 ;;
            '') __lg_moves+=("$f") ;;
            *) continue ;;
        esac
        __lg_copy "$f" "$rpath"
    done < <(printf '%s\n' "${!__lg_blobs[@]}" | grep -E -- "$__LG_CONFIG_RE" | LC_ALL=C sort)
}

# Old copies of commands the repo once kept in .local/bin (noti, now from the
# noti-bash clone). Login shells put ~/.local/bin ahead of the clones, so a
# stale copy shadows them. ~/.local/bin holds other tools too: only a file
# that matches a repo version moves.
__lg_local_bin() {
    local rpath f
    while IFS= read -r rpath; do
        f=$HOME/$rpath
        __lg_exists "$f" || continue
        [ -z "${__lg_kind[$f]-}" ] || continue
        if [ -f "$f" ] && [ ! -L "$f" ] && __lg_is_blob "$f" "$rpath"; then
            __lg_moves+=("$f")
            __lg_item MOVE "$(__tilde "$f") (old copy of the repo's $rpath; it would shadow the clone's ${f##*/} on PATH)"
        else
            __lg_item WARN "$(__tilde "$f") matches no version of the repo's $rpath, so it stays; it shadows the clone's ${f##*/} on PATH (login shells put ~/.local/bin first)"
        fi
    done < <(printf '%s\n' "${!__lg_blobs[@]}" | grep -E -- '^\.local/bin/' | LC_ALL=C sort)
}

__lg_vim_dir() {
    local d=$HOME/.vim
    __lg_exists "$d" || return 0
    if [ ! -L "$d" ] && __path_in_use "$d"; then
        __lg_moves+=("${__lg_vim_files[@]}")
        __lg_item KEEP '~/.vim (a running process uses it; only the old copies inside move)'
        __lg_item WARN '~/.vim stays until nothing uses it; move it into the backup dir by hand later'
        if [ -e "$d/vimrc" ]; then
            __lg_item WARN '~/.vim/vimrc shadows ~/.config/vim/vimrc while it stays'
        fi
    else
        __lg_moves+=("$d")
        __lg_item MOVE '~/.vim (with its undo, swap, sessions and plugins: vim state is not migrated)'
    fi
}

__lg_tmux_dir() {
    local d=$HOME/.tmux
    __lg_exists "$d" || return 0
    if [ ! -L "$d" ] && [ -d "$d/plugins" ] && __mg_tmux_refs_old; then
        __lg_moves+=("${__lg_tmux_files[@]}")
        __lg_item KEEP "~/.tmux/plugins (a running tmux server uses it; 'dotfiles migrate cleanup' moves it later)"
    elif [ ! -L "$d" ] && [ -d "$d" ] && [ -z "$(ls -A -- "$d")" ]; then
        __lg_tmux_rmdir=1
        __lg_item MOVE '~/.tmux (empty; removed with rmdir)'
    else
        __lg_moves+=("$d")
        __lg_item MOVE '~/.tmux (themes and old plugins)'
    fi
}

__lg_profile() {
    local f=$HOME/.profile skel=/etc/skel/.profile i line
    local -A known=()
    __lg_exists "$f" || return 0
    if [ -L "$f" ] || [ ! -f "$f" ]; then
        __lg_item KEEP '~/.profile (not a regular file)'
        return 0
    fi
    if __lg_is_blob "$f" .profile; then
        __lg_profile_skel=1
        if [ -f "$skel" ]; then
            __lg_item MOVE '~/.profile (repo copy; replaced by /etc/skel/.profile)'
        else
            __lg_item MOVE '~/.profile (repo copy; replaced by a minimal one that loads ~/.bashrc)'
        fi
        return 0
    fi
    if [ -f "$skel" ]; then
        ! cmp -s -- "$f" "$skel" || return 0
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] || known[$line]=1
        done <"$skel"
    fi
    __lg_item KEEP '~/.profile (locally edited)'
    __lg_read "$f" || return 1
    for i in "${!__lg_lines[@]}"; do
        line=${__lg_lines[i]}
        [[ ! $line =~ $__LG_RE_COMMENT ]] || continue
        if [[ $line =~ $__LG_RE_PROFILE_FIX ]] && [ -z "${known[$line]-}" ]; then
            __lg_item FIX-SUGGESTION "~/.profile:$((i + 1)): $line  [env.bash now sets LANG and PATH; the kime variables live in ~/.config/environment.d/kime.conf]"
        fi
    done
}

__lg_debris_add() {
    case ${1##*/} in .claude*) return 0 ;; esac
    __lg_moves+=("$1")
    __lg_item DEBRIS "$(__tilde "$1")"
}

# .bak leftovers: <old top-level name>.bak* in $HOME, and in each ~/.config
# dir that holds a tracked file: <tracked name>.bak*, *.bak and .bak.
__lg_debris() {
    local n p rel dir name hp
    local -A base=() rootbase=() dirs=()
    for n in "${__LG_TOP[@]}"; do
        for p in "$HOME/$n".bak*; do
            ! __lg_exists "$p" || __lg_debris_add "$p"
        done
    done
    for p in "$HOME"/.bashrc.pre-claude-auto.*.bak; do
        ! __lg_exists "$p" || __lg_debris_add "$p"
    done
    hp=$(__mg_home_phys) || return 0
    while IFS= read -r -d '' rel; do
        base[${rel##*/}]=1
        if [ "${rel%/*}" = .config ]; then
            rootbase[${rel##*/}]=1
        else
            dirs[${rel%/*}]=1
        fi
    done < <(__git ls-files -z -- .config 2>/dev/null)
    for p in "$HOME/.config"/*.bak*; do
        name=${p##*/}
        name=${name%%.bak*}
        if __lg_exists "$p" && [ -n "$name" ] && [ -n "${rootbase[$name]-}" ]; then
            __lg_debris_add "$p"
        fi
    done
    for rel in "${!dirs[@]}"; do
        dir=$HOME/$rel
        # Never look through a symlinked dir: it may lead into a repo.
        if [ ! -d "$dir" ] || [ "$(cd -P -- "$dir" 2>/dev/null && pwd -P)" != "$hp/$rel" ]; then
            continue
        fi
        for p in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
            __lg_exists "$p" || continue
            [ -z "${__lg_kind[$p]-}" ] || continue
            name=${p##*/}
            case $name in
                .bak|*.bak) __lg_debris_add "$p" ;;
                *.bak*)
                    name=${name%%.bak*}
                    if [ -n "$name" ] && [ -n "${base[$name]-}" ]; then
                        __lg_debris_add "$p"
                    fi
                    ;;
            esac
        done
    done
}

__lg_keeps() {
    local p
    for p in "$CFG/nvim/lazy-lock.json" "$CFG/nvim/lua/local.lua" "$CFG/nvim/lua/plugins/local.lua" \
        "$CFG/secrets.env" "$CFG/noti/webhook" "$CFG/shell/modern-grep-find.bash" \
        "$HOME/.local/share/nvim/plugged" "$HOME/.local/share/nvim/undo" \
        "$HOME/.local/share/nvim/temp" "$HOME/.local/share/nvim/obsession" "$HOME/.vimrc_adv"; do
        ! __lg_exists "$p" || __lg_item KEEP "$(__tilde "$p")"
    done
    if [ -f "$HOME/.bash_logout" ] && cmp -s -- "$HOME/.bash_logout" /etc/skel/.bash_logout; then
        __lg_item KEEP '~/.bash_logout (distro copy)'
    fi
    # The old bootstrap's Claude wiring; dotfiles never edits ~/.claude.
    for p in bell noti; do
        if [ -L "$HOME/.claude/skills/$p" ]; then
            __lg_item WARN "~/.claude/skills/$p: link from the old bootstrap; the claude() wrapper of common.bash now passes the ~/.local/opt/$p-bash clone, so the skill loads twice; remove the link by hand"
        fi
    done
    if grep -qs bell-send "$HOME/.claude/settings.json"; then
        __lg_item WARN "~/.claude/settings.json: bell-send hooks from the old bootstrap; the claude() wrapper of common.bash now passes bell's claude-settings.json, so they run twice; remove them by hand"
    fi
}

__lg_history_state() {
    local pids
    if __hist_pending "$HOME/.bash_history"; then
        __lg_hist=1
        __lg_item MIGRATE "~/.bash_history -> $(__tilde "$(__hist_file)") ($(wc -l <"$HOME/.bash_history") line(s) appended; the file moves to the backup dir)"
    fi
    __mg_nvim_state_scan
    [ ${#__mg_ns_src[@]} -gt 0 ] || return 0
    pids=$(__mg_nvim_pids | paste -sd ' ' -)
    if [ -n "$pids" ]; then
        __lg_item WARN "nvim runs (pid $pids): copy its undo history and sessions later with 'dotfiles migrate nvim-state'"
    else
        __lg_nvim_state=1
        __lg_item MIGRATE "~/.local/share/nvim/{undo,obsession} -> $(__tilde "$STATE/nvim") (${#__mg_ns_src[@]} file(s) copied, the old dirs stay; undo and sessions of files inside the checkout only partly survive the repo rename)"
    fi
}

# ---------------------------------------------------------------------------
# Plan and entry files

# Mark old copies in the way of a link as legacy (install moves them into the
# backup dir); drop the history row when this run imports it itself.
__lg_mark_plan() {
    local plan=$1 line t
    while IFS= read -r line || [ -n "$line" ]; do
        t=${line#*$'\t'}
        t=${t%%$'\t'*}
        case ${line%%$'\t'*} in
            conflict) [ -z "${__lg_occ[$t]-}" ] || line=legacy$'\t'${line#*$'\t'} ;;
            hist) [ "$__lg_legacy" = 0 ] || continue ;;
        esac
        printf '%s\n' "$line"
    done <"$plan" >"$plan.new" && mv -fT -- "$plan.new" "$plan"
}

# Append LINES to FILE, after a newline when its last line lacks one.
__lg_append() {
    local f=$1 nl=''
    shift
    [ $# -gt 0 ] || return 0
    if [ -s "$f" ] && [ -n "$(tail -c 1 -- "$f")" ]; then
        nl=$'\n'
    fi
    {
        printf '%s' "$nl"
        printf '%s\n' "$@"
    } >>"$f"
}

# Put the machine sections into the entry files __entries_prepare wrote to
# DIR; an entry that was "ok" and gets a section becomes "ensure".
__lg_fill_entries() {
    local dir=$1 id action t f src
    local -a rows=()
    while IFS=$'\t' read -r id action t f; do
        __lg_filled=0
        src=
        case $id in
            bash)
                if [ "$__lg_mode_bash" = migrate ] && [ "$action" = replace ]; then
                    __lg_append "$f" "${__lg_sec_bash[@]}" || return 1
                    if ! bash -n "$f" 2>/dev/null; then
                        __lg_item WARN '~/.bashrc: the migrated file fails bash -n; fix its machine section first'
                        __lg_fatal=1
                    fi
                fi
                ;;
            tmux) src=$HOME/.tmux.conf ;;
            git) src=$HOME/.gitconfig ;;
            wezterm)
                if [ "$action" = create ] && [ -n "$__lg_mode_wez" ]; then
                    src=$HOME/.wezterm.lua
                    if [ "$__lg_mode_wez" = managed ]; then
                        __lg_lines_out "${__lg_wez[@]}" >"$f" || return 1
                    else
                        cat -- "$src" >"$f" || return 1
                        __lg_unmanaged "$dir/blocks.tsv" "$t" || return 1
                    fi
                    __lg_modes+=("$t"$'\t'"$src")
                fi
                src=
                ;;
        esac
        if [ -n "$src" ]; then
            if [ "$id" = tmux ]; then
                __lg_fill_section "$f" "$action" "$src" "${__lg_sec_tmux[@]}" || return 1
            else
                __lg_fill_section "$f" "$action" "$src" "${__lg_sec_git[@]}" || return 1
            fi
            if [ "$__lg_filled" = 1 ]; then
                [ "$action" != ok ] || action=ensure
                [ "$action" != create ] || __lg_modes+=("$t"$'\t'"$src")
            fi
        fi
        rows+=("$id"$'\t'"$action"$'\t'"$t"$'\t'"$f")
    done <"$dir/entries.tsv"
    __lg_lines_out "${rows[@]}" >"$dir/entries.tsv"
}

# Append SRC's section LINES to FILE: right below the template of a new
# entry, after a "migrated from" note in an existing one.
__lg_fill_section() {
    local f=$1 action=$2 src=$3
    shift 3
    [ $# -gt 0 ] || return 0
    case $action in
        create) __lg_append "$f" "$@" || return 1 ;;
        ensure|ok) __lg_append "$f" '' "# migrated from $(__tilde "$src") ($__RUN_TS)" "$@" || return 1 ;;
        *) return 0 ;;
    esac
    __lg_filled=1
}

# Record TARGET as unmanaged in the next blocks.tsv BLOCKS-FILE, so later
# runs never add a block to a migrated wezterm.lua without a loader.
__lg_unmanaged() {
    local file=$1 t b s
    local -a rows=()
    while IFS=$'\t' read -r t b s; do
        [ "$t" != "$2" ] || s=unmanaged
        rows+=("$t"$'\t'"$b"$'\t'"$s")
    done <"$file"
    __lg_lines_out "${rows[@]}" >"$file"
}

# ---------------------------------------------------------------------------
# Preview, consent, apply

__lg_preview() {
    local tmp=$1 k item n
    for k in MOVE LOCALLY-EDITED UNKNOWN DEBRIS MIGRATE MIGRATE-MERGE REMOVE-CANDIDATE \
        FIX-SUGGESTION KEEP WARN; do
        n=0
        for item in "${__lg_items[@]}"; do
            [ "${item%%$'\t'*}" = "$k" ] || continue
            [ "$n" -gt 0 ] || printf '\n== %s\n' "$k"
            n=$((n + 1))
            printf '%s %s\n' "$k" "${item#*$'\t'}"
        done
    done
    printf '\n== LINKS AND ENTRY FILES\n'
    __plan_print "$tmp/plan" "$tmp/entries"
    printf '\n'
}

__lg_consent() {
    local plan=$1
    if [ "$__lg_fatal" = 1 ]; then
        __err "not applying; see the warnings above (nothing changed)"
        return 1
    fi
    if [ ! -t 0 ]; then
        if grep -q $'^conflict\t' "$plan"; then
            if [ -z "$__lg_mode" ]; then
                __err "no terminal to ask about the conflicts; re-run with --replace-all or --keep-all (nothing changed)"
                return 3
            fi
        fi
        if [ "$__lg_edits" -gt 0 ] && [ "$__lg_accept" = 0 ]; then
            __err "$__lg_edits locally edited file(s) would leave the active config; re-run with --accept-dropped-edits (nothing changed)"
            return 3
        fi
        if [ "$__lg_yes" = 0 ]; then
            __err "no terminal to confirm; re-run with --yes (nothing changed)"
            return 3
        fi
    fi
    if grep -q $'^conflict\t' "$plan"; then
        __resolve_conflicts "$plan" "$__lg_mode" || return
    fi
    if [ "$__lg_edits" -gt 0 ] && [ "$__lg_accept" = 0 ] &&
        ! __ask "$__lg_edits locally edited file(s) leave the active config (diffs above; they stay in the backup dir). Continue? [y/N] "; then
        __info "Cancelled; nothing changed."
        return 1
    fi
    [ "$__lg_yes" = 0 ] || return 0
    __ask 'Apply? [y/N] ' && return 0
    __info "Cancelled; nothing changed."
    return 1
}

__lg_verify() {
    local tmp=$1 line t bad=0
    if __legacy_signals >"$tmp/signals"; then
        __err "old-layout files remain:"
        sed 's/^/  /' "$tmp/signals" >&2
        bad=1
    fi
    if __install_plan "$tmp/verify"; then
        while IFS= read -r line; do
            case ${line%%$'\t'*} in
                new|conflict|identical)
                    t=${line#*$'\t'}
                    __err "not linked: ${t%%$'\t'*}"
                    bad=1
                    ;;
            esac
        done <"$tmp/verify"
    else
        bad=1
    fi
    [ "$bad" = 0 ]
}

__lg_apply() {
    local tmp=$1 p src pair
    if [ "$__lg_legacy" = 1 ]; then
        # The detail marks a run __lg_unfinished resumes.
        __journal begin uninstall-legacy legacy || return
    else
        __journal_begin uninstall-legacy || return
    fi
    # Copies of existing entry files that get a migrated section appended.
    if [ ${#__lg_sec_tmux[@]} -gt 0 ] && [ -f "$CFG/tmux/tmux.conf" ]; then
        __backup_copy "$CFG/tmux/tmux.conf" >/dev/null || return
    fi
    if [ ${#__lg_sec_git[@]} -gt 0 ] && [ -f "$CFG/git/config" ]; then
        __backup_copy "$CFG/git/config" >/dev/null || return
    fi
    # Before anything moves, so later appends by old shells start a new file.
    if [ "$__lg_hist" = 1 ]; then
        __hist_import "$HOME/.bash_history" || return
    fi
    # Links first (old copies in the way move into the backup dir), then the
    # entry files: no new shell starts without the common config.
    __install_apply "$tmp/plan" || return
    __entries_commit "$tmp/entries" || return
    if [ "$__lg_mode_bash" = migrate ] && [ -n "$__lg_bash_mode" ]; then
        __journal chmod "$HOME/.bashrc" "$__lg_bash_mode" || return
        chmod "$__lg_bash_mode" -- "$HOME/.bashrc" || return 1
    fi
    for pair in "${__lg_modes[@]}"; do
        __journal chmod "${pair%%$'\t'*}" "${pair#*$'\t'}" || return
        chmod --reference="${pair#*$'\t'}" -- "${pair%%$'\t'*}" || return 1
    done
    for p in "${__lg_moves[@]}"; do
        __lg_exists "$p" || continue
        __backup_move "$p" >/dev/null || return
    done
    if [ "$__lg_profile_skel" = 1 ] && __lg_exists "$HOME/.profile"; then
        __backup_move "$HOME/.profile" >/dev/null || return
        src=/etc/skel/.profile
        [ -f "$src" ] || src=$REPO/lib/templates/profile-portable
        __journal copy "$HOME/.profile" "$src" || return
        cp -- "$src" "$HOME/.profile" || return 1
    fi
    if [ "$__lg_cred" = 1 ]; then
        if __lg_exists "$CFG/git/credentials"; then
            __warn "$(__tilde "$CFG/git/credentials") appeared meanwhile; ~/.git-credentials stays"
        else
            __journal mv "$HOME/.git-credentials" "$CFG/git/credentials" || return
            mv -T -- "$HOME/.git-credentials" "$CFG/git/credentials" || return 1
        fi
    fi
    if [ "$__lg_tmux_rmdir" = 1 ]; then
        __journal rmdir "$HOME/.tmux" || return
        rmdir -- "$HOME/.tmux" || __warn "~/.tmux is not empty any more; it stays"
    fi
    if [ "$__lg_nvim_state" = 1 ]; then
        __mg_nvim_state_copy || return
    fi
    __lg_verify "$tmp" || return 1
    __journal_done || return
    printf 'Done. The old files are in %s.\n' "$(__tilde "$(__backup_dir)")"
    printf "To roll back: 'dotfiles uninstall', then move them back from there.\n"
    printf 'New shells use the new layout; leave running tmux servers until they end and start new work in a new one.\n'
}
