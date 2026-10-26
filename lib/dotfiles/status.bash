# shellcheck shell=bash
# shellcheck disable=SC2088  # "~/..." in messages is display text
# status.bash - `dotfiles status`: a report that writes nothing (git runs
# with --no-optional-locks so not even the index is refreshed).

__ST_SECTION=
__ST_LINES=0
__ST_PORTABLE=0

# __st SECTION LINE: print LINE under SECTION's heading (printed once).
__st() {
    if [ "$__ST_SECTION" != "$1" ]; then
        printf '%s:\n' "$1"
        __ST_SECTION=$1
    fi
    printf '  %s\n' "$2"
    __ST_LINES=$((__ST_LINES + 1))
}

__status_repo() {
    local line
    if ! __git rev-parse --git-dir >/dev/null 2>&1; then
        __st repo "$REPO is not a git checkout"
        return
    fi
    while IFS= read -r line; do
        __st "repo: uncommitted changes" "$line"
    done < <(__git --no-optional-locks status --porcelain)
    while IFS= read -r -d '' line; do
        __st "repo: untracked files in a whole-dir link (shared by every machine)" "$line"
    done < <(__git ls-files -z -o -- .config/bash .config/fzf .config/readline)
}

__status_links() {
    local i t p text
    local -A unit=() bad=()
    if [ "$__ST_PORTABLE" = 1 ]; then
        printf 'links: none in portable mode; the checkout is the home\n'
        return
    fi
    __link_units || return
    __kept_load
    __manifest_load
    for i in "${!U_PATH[@]}"; do
        t=${U_TARGET[i]}
        p=${U_PATH[i]}
        unit[$t]=1
        if ! __parent_check "$t" "${U_BASE[i]}" 2>/dev/null; then
            if [ -z "${bad[$__BAD_PARENT]-}" ]; then
                bad[$__BAD_PARENT]=1
                __st links "blocked   $(__tilde "$__BAD_PARENT") is a symlink or not a dir; install refuses to link below it"
            fi
            continue
        fi
        __link_text "$t" "$p" text || continue
        __link_classify "$t" "$text" "$p"
        [ "$__CLASS" != correct ] || continue
        [ -z "${KEPT_SET[$t]-}" ] || continue
        case $__CLASS in
            new) __st links "missing   $(__tilde "$t")" ;;
            *) __st links "foreign   $(__tilde "$t") ($__WHAT)" ;;
        esac
    done
    for t in "${MAN_TARGETS[@]}"; do
        [ -z "${unit[$t]-}" ] || continue
        if [ -L "$t" ] && [ ! -e "$t" ] && [ "$(readlink -- "$t")" = "${MAN_TEXT[$t]}" ]; then
            __st links "dangling  $(__tilde "$t") (no longer tracked; 'dotfiles install' prunes it)"
        fi
    done
    while IFS= read -r t; do
        __st "kept (delete a line from $(__tilde "$KEPT") to be asked again)" "$(__tilde "$t")"
    done < <(printf '%s\n' "${!KEPT_SET[@]}" | LC_ALL=C sort | grep -v '^$')
}

__status_entries() {
    local id t spec rest
    for id in "${ENTRY_IDS[@]}"; do
        if [ "$__ST_PORTABLE" = 1 ] && [ "$id" = wezterm ]; then
            continue
        fi
        __entry_info "$id" || continue
        t=$__E_TARGET
        if [ -L "$t" ]; then
            __st entries "$(__tilde "$t"): a symlink; dotfiles will not edit it"
            continue
        fi
        if [ ! -e "$t" ]; then
            __st entries "$(__tilde "$t"): missing ('dotfiles install' creates it)"
            continue
        fi
        __read_lines "$t" 2>/dev/null || {
            __st entries "$(__tilde "$t"): unreadable"
            continue
        }
        for spec in "${__E_BLOCKS[@]}"; do
            rest=${spec#*|}
            if ! __block_find "${spec%%|*}" "${rest%%|*}" "$t" 2>/dev/null; then
                __st entries "$(__tilde "$t"): broken managed block '${spec%%|*}'; fix it by hand"
            elif [ "$__BS" -lt 0 ] && __entry_unmanaged "$t"; then
                __st entries "$(__tilde "$t"): recorded unmanaged; 'dotfiles install' adds no managed block to it (it keeps one current once you add the marker lines by hand)"
            elif [ "$__BS" -lt 0 ] && [ "$id" = wezterm ]; then
                __st entries "$(__tilde "$t"): no managed block (no anchor for it, or it loads common.lua itself)"
            elif [ "$__BS" -lt 0 ]; then
                __st entries "$(__tilde "$t"): managed block '${spec%%|*}' missing ('dotfiles install' adds it)"
            fi
        done
    done
}

__status_journal() {
    local id when cmd
    while IFS=$'\t' read -r id when cmd; do
        __st "interrupted runs (see $(__tilde "$JOURNAL"))" "$id started $when: $cmd"
    done < <(__journal_unfinished)
}

__status_env() {
    local line
    while IFS= read -r line; do
        __st environment "$line"
    done < <(__xdg_check; __xdg_drift; __tmux_check)
}

__status_leftovers() {
    local f kind path reason line home_p
    for f in bell noti; do
        if [ -L "$HOME/.claude/skills/$f" ]; then
            __st leftovers "~/.claude/skills/$f: link from the old bootstrap; the claude() wrapper already loads this skill; remove the link by hand"
        fi
    done
    if grep -qs 'bell-send' "$HOME/.claude/settings.json"; then
        __st leftovers "~/.claude/settings.json: bell-send hooks from the old bootstrap; bell's claude-settings.json provides them now; remove them by hand"
    fi
    while IFS=: read -r line _; do
        __st leftovers "~/.bashrc:$line: alias claude= hides the claude() wrapper of common.bash"
    done < <(grep -nE '^[[:space:]]*alias[[:space:]]+claude=' "$HOME/.bashrc" 2>/dev/null)
    while IFS=$'\t' read -r kind path reason; do
        case $kind in
            legacy|prexdg) __st leftovers "$(__tilde "$path"): $reason; run 'dotfiles uninstall-legacy'" ;;
            *) __st leftovers "$(__tilde "$path"): $reason (your file; left alone)" ;;
        esac
    done < <(__legacy_signals --all)
    if [ -e "$HOME/.bash_history" ]; then
        if [ -e "$STATE/bash/history" ]; then
            __st leftovers "~/.bash_history: written by shells started before the move; 'dotfiles migrate history' merges it"
        else
            __st leftovers "~/.bash_history: 'dotfiles install' imports it into $(__tilde "$STATE/bash/history")"
        fi
    fi
    for f in .cargo .rustup .fzf .fzf-tab-completion .bell-bash .noti-bash; do
        if [ -L "$HOME/$f" ]; then
            __st leftovers "~/$f: compat link for shells started before the move; 'dotfiles migrate cleanup' removes it once they are gone"
        elif [ -d "$HOME/$f" ]; then
            __st leftovers "~/$f: old tool location; run 'dotfiles migrate tools'"
        fi
    done
    home_p=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || home_p=$HOME
    if [ -L "$HOME/dotfiles" ]; then
        __st leftovers "~/dotfiles: compat link to the moved checkout; 'dotfiles migrate cleanup' removes it once nothing uses it"
    elif [ "$REPO" = "$home_p/dotfiles" ]; then
        __st leftovers "~/dotfiles: the checkout is at the legacy path; run 'dotfiles migrate repo'"
    fi
    if [ -e "$HOME/.npm" ]; then
        __st leftovers "~/.npm: old npm cache (npm now uses $(__tilde "$CACHE/npm")); delete it when you like"
    fi
    if [ -e "$HOME/.tmux" ]; then
        __st leftovers "~/.tmux: old TPM plugin dir; 'dotfiles migrate cleanup' moves it once no tmux server uses it"
    fi
    if [ -e "$HOME/.nvm" ]; then
        __st leftovers "~/.nvm: old node install; 'dotfiles migrate cleanup' moves it once nothing runs from it"
    fi
}

# fnm keeps its per-shell dirs under $XDG_RUNTIME_DIR, which logout empties;
# without XDG_RUNTIME_DIR it falls back to the state dir, where they pile up.
__status_fnm() {
    local d=$STATE/fnm_multishells e n=0
    [ -d "$d" ] || return 0
    for e in "$d"/*; do
        if [ -e "$e" ] || [ -L "$e" ]; then
            n=$((n + 1))
        fi
    done
    __st fnm "$n per-shell dirs under $(__tilde "$d") (used when XDG_RUNTIME_DIR is unset; dotfiles never deletes them)"
}

__cmd_status() {
    case ${1-} in
        '') ;;
        -h|--help)
            printf 'Usage: dotfiles status\n\nReport links, entry files, kept files and leftovers. Writes nothing.\n'
            return 0
            ;;
        *)
            __err "status: unknown option '$1'"
            return 2
            ;;
    esac
    local cfg_p
    __phys_dir "$CFG" cfg_p || cfg_p=
    if [ "$cfg_p" = "$REPO/.config" ]; then
        __ST_PORTABLE=1
    fi
    printf 'repo: %s\n' "$REPO"
    __status_repo
    __status_links
    __status_entries
    __status_journal
    __status_env
    __status_leftovers
    __status_fnm
    if [ "$__ST_LINES" -eq 0 ]; then
        printf 'Everything is in place.\n'
    fi
    return 0
}
