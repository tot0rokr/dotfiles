# shellcheck shell=bash
# install.bash - `dotfiles install`, the plan/apply API it shares with
# uninstall-legacy, and the internal `_portable-entries` of enter.sh.
#
# Plan file (__install_plan): TSV rows "STATE TARGET ...", no empty fields.
#   correct|new|identical|conflict|kept  TARGET LINK-TEXT REPO-PATH
#          a link target: already our link, nothing there, an identical copy
#          (moved to the backup dir, then linked), something else, or kept
#          earlier. A caller turns conflict into replace or keep, and may use
#          legacy (= replace) for an occupant it knows is an old copy.
#          __install_apply refuses a plan with a conflict left.
#   prune|carry  TARGET LINK-TEXT REPO-PATH
#          a manifest link whose repo path is no longer tracked: prune removes
#          it (it dangles), carry keeps it in the manifest (it still resolves)
#   dir    PATH MODE|-          created before any link
#   cred   PATH -               empty git credentials file, mode 600
#   hist   OLD-HISTORY-FILE -   imported with __hist_import (history.bash)
# A caller may drop rows it handles itself. __install_plan has no legacy gate;
# callers apply it.
#
# Entry dir (__entries_prepare DIR): DIR/entries.tsv has
# "ID ACTION TARGET FILE" rows; FILE holds the new content. ACTION: create,
# skel (stock /etc/skel/.bashrc; backed up, then replaced), replace (asked for
# as fresh; the old file is backed up), ensure (blocks refreshed), ok
# (nothing to change), unmanaged (no anchor for the block, or a block missing
# from a file blocks.tsv records unmanaged; left alone). Rows
# that start from the existing file (ensure, ok, unmanaged) also leave a copy
# of it in FILE.orig; __entries_commit writes an ensure row only while the
# target still equals FILE.orig, and skips ok and unmanaged rows.
# DIR/blocks.tsv ("TARGET BLOCK-ID managed|unmanaged") is the next blocks.tsv.
# Between __entries_prepare and __entries_commit a caller may:
#   - append to FILE of a create, replace, ensure or ok row, and must then
#     rewrite an ok row to ensure;
#   - replace FILE of a create row whole, and set that target's rows in
#     DIR/blocks.tsv to unmanaged when the new FILE has no block.
#
# uninstall-legacy uses: __install_plan PLAN, __resolve_conflicts PLAN MODE,
# __plan_print PLAN [ENTRYDIR], __install_apply PLAN, __entries_prepare DIR
# [FRESH-ID...], __entries_commit DIR.

__install_usage() {
    cat <<'EOF'
Usage: dotfiles install [--yes] [--replace-all | --keep-all] [--dry-run]

Link the repo's config into ~/.config (fonts into ~/.local/share/fonts, this
CLI into ~/.local/bin), create the account-local entry files when they are
missing (~/.bashrc, ~/.config/git/config, ~/.config/tmux/tmux.conf,
~/.config/wezterm/wezterm.lua) and keep their managed blocks current.

An existing file that differs from the repo is a conflict: replace it (it is
moved to the backup dir, then linked), keep it (recorded, not asked again),
or show a diff. Nothing is written before the final confirmation.

  -y, --yes          apply without the final confirmation
      --replace-all  replace every conflict (implies --yes)
      --keep-all     keep every conflict (implies --yes)
  -n, --dry-run      print the plan and exit
EOF
}

# __install_plan PLANFILE: classify every link target and list the dirs,
# credentials file and history import install needs. Read-only. Refuses (5)
# a symlinked or non-directory parent of a target, and a target inside the
# checkout.
__install_plan() {
    local out=$1 i t p text d mode pp
    local -A unit=() dirseen=()
    local -a dirs=()
    __gate_targets || return
    __link_units || return
    __kept_load
    __manifest_load
    : >"$out" || return
    dirs=("$CFG")
    for i in "${!U_PATH[@]}"; do
        t=${U_TARGET[i]}
        p=${U_PATH[i]}
        unit[$t]=1
        __parent_check "$t" "${U_BASE[i]}" || return
        __link_text "$t" "$p" text || return
        __phys_dir "${t%/*}" pp || return
        if [ "$pp/${t##*/}" = "$REPO/$p" ]; then
            __err "$t is the repo's own $p; refusing to link it to itself"
            return 5
        fi
        __link_classify "$t" "$text" "$p"
        if [ "$__CLASS" != correct ] && [ -n "${KEPT_SET[$t]-}" ]; then
            __CLASS=kept
        fi
        printf '%s\t%s\t%s\t%s\n' "$__CLASS" "$t" "$text" "$p" >>"$out"
        dirs+=("${t%/*}")
    done
    for t in "${MAN_TARGETS[@]}"; do
        [ -z "${unit[$t]-}" ] || continue
        if [ ! -L "$t" ] || [ "$(readlink -- "$t")" != "${MAN_TEXT[$t]}" ]; then
            continue
        fi
        if [ -e "$t" ]; then
            d=carry
        else
            d=prune
        fi
        printf '%s\t%s\t%s\t%s\n' "$d" "$t" "${MAN_TEXT[$t]}" "${MAN_PATH[$t]}" >>"$out"
    done
    dirs+=("$CFG/git" "$CFG/tmux" "$CFG/wezterm" "$DATA/fonts" "$HOME/.local/bin"
        "$STATE_DIR" "$STATE/bash")
    for d in "${dirs[@]}"; do
        [ -z "${dirseen[$d]-}" ] || continue
        dirseen[$d]=1
        [ ! -d "$d" ] || continue
        if [ -e "$d" ] || [ -L "$d" ]; then
            __err "$d is in the way: it should be a directory"
            return 5
        fi
        case $d in
            "$CFG/noti"|"$STATE_DIR") mode=700 ;;
            *) mode=- ;;
        esac
        printf 'dir\t%s\t%s\n' "$d" "$mode" >>"$out"
    done
    if [ ! -e "$HOME/.git-credentials" ] && [ ! -L "$HOME/.git-credentials" ] \
        && [ ! -e "$CFG/git/credentials" ] && [ ! -L "$CFG/git/credentials" ]; then
        printf 'cred\t%s\t-\n' "$CFG/git/credentials" >>"$out"
    fi
    if [ -f "$HOME/.bash_history" ] && [ ! -e "$STATE/bash/history" ]; then
        printf 'hist\t%s\t-\n' "$HOME/.bash_history" >>"$out"
    fi
}

# __entries_prepare DIR [FRESH-ID...]: compute the new content of every entry
# file into DIR without touching the files. FRESH-IDs start from the template
# whatever is there. Refuses (5) a symlinked entry, (4) an old-layout ~/.bashrc.
__entries_prepare() {
    local dir=$1 id t f action state spec bid
    local -A fresh=() mine=()
    shift
    for id; do
        fresh[$id]=1
    done
    mkdir -p -- "$dir" || return
    : >"$dir/entries.tsv" || return
    : >"$dir/blocks.tsv" || return
    for id in "${ENTRY_IDS[@]}"; do
        __entry_info "$id" || return
        t=$__E_TARGET
        f=$dir/$id
        state=managed
        if [ -L "$t" ]; then
            __err "$t is a symlink; dotfiles edits only regular files there"
            return 5
        elif [ -n "${fresh[$id]-}" ] || [ ! -e "$t" ]; then
            cp -- "$__E_TEMPLATE" "$f" || return
            if [ -e "$t" ]; then
                action=replace
            else
                action=create
            fi
        elif [ "$id" = bash ] && [ -f /etc/skel/.bashrc ] && cmp -s -- /etc/skel/.bashrc "$t"; then
            cp -- "$__E_TEMPLATE" "$f" || return
            action=skel
        elif [ "$id" = bash ] && grep -qs -- "$LEGACY_MARKER_RE" "$t"; then
            __err "$t is from the old layout; run 'dotfiles uninstall-legacy'"
            return 4
        else
            __edit_check "$t" || return
            cp -p -- "$t" "$f.orig" || return
            __entry_render "$t" "$f" || return
            if [ "$__BLOCK_STATE" = unmanaged ]; then
                action=unmanaged
                state=unmanaged
            elif cmp -s -- "$f" "$t"; then
                action=ok
            else
                action=ensure
            fi
        fi
        printf '%s\t%s\t%s\t%s\n' "$id" "$action" "$t" "$f" >>"$dir/entries.tsv"
        mine[$t]=1
        for spec in "${__E_BLOCKS[@]}"; do
            printf '%s\t%s\t%s\n' "$t" "${spec%%|*}" "$state" >>"$dir/blocks.tsv"
        done
    done
    # Rows for entry files under an earlier XDG_CONFIG_HOME stay known to uninstall.
    if [ -f "$BLOCKS" ]; then
        while IFS=$'\t' read -r t bid state; do
            if [ -z "$t" ] || [ -n "${mine[$t]-}" ] || [ ! -f "$t" ]; then
                continue
            fi
            printf '%s\t%s\t%s\n' "$t" "$bid" "$state" >>"$dir/blocks.tsv"
        done <"$BLOCKS"
    fi
}

# __entries_commit DIR: put the prepared entry files in place (temp file in
# the target's dir, then rename) and record blocks.tsv. A file that is
# replaced or refreshed keeps its mode; the old one of a skel or replace row
# moves to the backup dir only once the new one is ready. An ensured file
# that changed since __entries_prepare is not overwritten.
__entries_commit() {
    local dir=$1 id action t f tmp mode
    while IFS=$'\t' read -r -u 3 id action t f; do
        case $action in
            create|skel|replace|ensure) ;;
            *) continue ;;
        esac
        if [ -L "$t" ]; then
            __err "$t is now a symlink; not touching it"
            return 5
        fi
        if [ "$action" = create ] && [ -e "$t" ]; then
            __err "$t appeared while dotfiles was running; re-run"
            return 1
        fi
        if [ "$action" = ensure ] && ! cmp -s -- "$f.orig" "$t"; then
            __err "$t changed while dotfiles was running; re-run"
            return 1
        fi
        __journal "entry-$action" "$t" || return
        mkdir -p -- "${t%/*}" || return
        tmp=$(mktemp "${t%/*}/.${t##*/}.dotfiles.XXXXXX") || return
        if [ -f "$t" ]; then
            mode=--reference=$t
        else
            mode=$(__new_file_mode)
        fi
        if ! cat -- "$f" >"$tmp" || ! chmod "$mode" -- "$tmp"; then
            rm -f -- "$tmp"
            __err "cannot write $t"
            return 1
        fi
        if [ "$action" = skel ] || [ "$action" = replace ]; then
            if [ -e "$t" ] && ! __backup_move "$t" >/dev/null; then
                rm -f -- "$tmp"
                return 1
            fi
        fi
        if ! mv -f -- "$tmp" "$t"; then
            rm -f -- "$tmp"
            __err "cannot write $t"
            return 1
        fi
    done 3<"$dir/entries.tsv"
    if __file_differs "$dir/blocks.tsv" "$BLOCKS"; then
        __journal state "$BLOCKS" || return
        __state_write "$BLOCKS" "$dir/blocks.tsv" || return
    fi
}

# __file_differs NEW CUR: true when NEW differs from CUR; a missing CUR equals
# an empty NEW.
__file_differs() {
    if [ ! -e "$2" ]; then
        [ -s "$1" ]
        return
    fi
    ! cmp -s -- "$1" "$2"
}

# __state_render PLANFILE DIR: the manifest.tsv, kept.list and xdg.env that
# applying PLANFILE results in.
__state_render() {
    local plan=$1 dir=$2 state t text p
    local -A ours=() keep=()
    mkdir -p -- "$dir" || return
    : >"$dir/manifest.tsv" || return
    __kept_load
    for t in "${!KEPT_SET[@]}"; do
        keep[$t]=1
    done
    while IFS=$'\t' read -r -u 3 state t text p; do
        case $state in
            correct|new|identical|replace|legacy|carry)
                printf '%s\t%s\t%s\n' "$t" "$text" "$p" >>"$dir/manifest.tsv"
                ours[$t]=1
                ;;
            keep) keep[$t]=1 ;;
        esac
    done 3<"$plan"
    for t in "${!keep[@]}"; do
        [ -n "${ours[$t]-}" ] || printf '%s\n' "$t"
    done | LC_ALL=C sort >"$dir/kept.list" || return
    __xdg_content >"$dir/xdg.env"
}

# __state_differs DIR: true when a file rendered into DIR differs from state.
__state_differs() {
    __file_differs "$1/manifest.tsv" "$MANIFEST" \
        || __file_differs "$1/kept.list" "$KEPT" \
        || __file_differs "$1/xdg.env" "$XDG_FILE"
}

__state_commit() {
    local src dst
    for src in manifest.tsv kept.list xdg.env; do
        case $src in
            manifest.tsv) dst=$MANIFEST ;;
            kept.list) dst=$KEPT ;;
            xdg.env) dst=$XDG_FILE ;;
        esac
        __file_differs "$1/$src" "$dst" || continue
        __journal state "$dst" || return
        __state_write "$dst" "$1/$src" || return
    done
}

# __install_apply PLANFILE: carry out a resolved plan: dirs, backups and
# links, prunes, the credentials file, the history import, then manifest.tsv,
# kept.list and xdg.env, then fc-cache when fonts changed. Every write is
# journaled first; the caller brackets it with __journal_begin/__journal_done.
__install_apply() {
    local plan=$1 state t text p fonts=0
    if grep -q $'^conflict\t' "$plan"; then
        __err "the plan still has unresolved conflicts"
        return 1
    fi
    __tmpdir || return
    while IFS=$'\t' read -r -u 3 state t text p; do
        [ "$state" = dir ] || continue
        __journal mkdir "$t" "$text" || return
        if ! mkdir -p -- "$t"; then
            __err "cannot create $t"
            return 1
        fi
        if [ "$text" = 700 ]; then
            chmod 700 -- "$t" || return
        fi
    done 3<"$plan"
    while IFS=$'\t' read -r -u 3 state t text p; do
        case $state in
            new) ;;
            identical|replace|legacy) __backup_move "$t" >/dev/null || return ;;
            prune)
                if [ ! -L "$t" ] || [ -e "$t" ] || [ "$(readlink -- "$t")" != "$text" ]; then
                    __warn "$t changed while dotfiles was running; not pruning it"
                    continue
                fi
                __journal unlink "$t" "$text" || return
                if ! rm -f -- "$t"; then
                    __err "cannot remove $t"
                    return 1
                fi
                case $t in
                    "$DATA"/fonts/*) fonts=1 ;;
                esac
                continue
                ;;
            *) continue ;;
        esac
        __journal link "$t" "$text" || return
        __link_create "$t" "$text" || return
        case $t in
            "$DATA"/fonts/*) fonts=1 ;;
        esac
    done 3<"$plan"
    while IFS=$'\t' read -r -u 3 state t text p; do
        case $state in
            cred)
                __journal cred "$t" || return
                if ! (umask 077 && set -C && : >"$t"); then
                    __err "cannot create $t"
                    return 1
                fi
                ;;
            hist)
                if ! declare -F __hist_import >/dev/null; then
                    __err "history.bash is not loaded; cannot import $t"
                    return 1
                fi
                __hist_import "$t" || return
                ;;
        esac
    done 3<"$plan"
    __state_render "$plan" "$__TMP/state-apply" || return
    __state_commit "$__TMP/state-apply" || return
    if [ "$fonts" = 1 ] && command -v fc-cache >/dev/null 2>&1; then
        __journal fc-cache "$DATA/fonts" || return
        fc-cache "$DATA/fonts" >/dev/null 2>&1 || __warn "fc-cache failed; run it by hand"
    fi
}

# __install_has_writes PLANFILE ENTRYDIR STATEDIR: true when applying would
# change anything.
__install_has_writes() {
    local state id rest
    while IFS=$'\t' read -r -u 3 state rest; do
        case $state in
            correct|kept|carry) ;;
            *) return 0 ;;
        esac
    done 3<"$1"
    while IFS=$'\t' read -r -u 3 id state rest; do
        case $state in
            create|skel|replace|ensure) return 0 ;;
        esac
    done 3<"$2/entries.tsv"
    __state_differs "$3" || __file_differs "$2/blocks.tsv" "$BLOCKS"
}

__plan_line() {
    printf '  %-9s %s%s\n' "$1" "${2/#"$HOME"\//"~/"}" "${3:+ $3}"
}

# __plan_print PLANFILE [ENTRYDIR [conflicts]]: the plan as text.
__plan_print() {
    local state t text p ok=0 id action f
    while IFS=$'\t' read -r -u 3 state t text p; do
        if [ "${3-}" = conflicts ] && [ "$state" != conflict ]; then
            continue
        fi
        case $state in
            correct) ok=$((ok + 1)) ;;
            new) __plan_line link "$t" "-> $text" ;;
            identical) __plan_line replace "$t" "(identical copy, moved to the backup dir)" ;;
            replace) __plan_line replace "$t" "(moved to the backup dir, then linked)" ;;
            legacy) __plan_line replace "$t" "(old copy, moved to the backup dir)" ;;
            keep) __plan_line keep "$t" "(recorded; not asked again)" ;;
            kept) __plan_line kept "$t" "(kept earlier)" ;;
            conflict) __plan_line conflict "$t" "(differs from the repo's $p)" ;;
            prune) __plan_line prune "$t" "(dangling link to a file no longer tracked)" ;;
            dir) __plan_line mkdir "$t" ;;
            cred) __plan_line create "$t" "(empty, mode 600; git's credential store writes here)" ;;
            hist) __plan_line import "$t" "-> $(__tilde "$STATE/bash/history")" ;;
        esac
    done 3<"$1"
    if [ -n "${2-}" ] && [ "${3-}" != conflicts ]; then
        while IFS=$'\t' read -r -u 3 id action t f; do
            case $action in
                create) __plan_line create "$t" ;;
                skel) __plan_line replace "$t" "(stock /etc/skel copy, moved to the backup dir)" ;;
                replace) __plan_line replace "$t" "(moved to the backup dir)" ;;
                ensure) __plan_line update "$t" "(managed blocks)" ;;
                unmanaged) __plan_line skip "$t" "(unmanaged; no managed block added)" ;;
            esac
        done 3<"$2/entries.tsv"
    fi
    if [ "$ok" -gt 0 ]; then
        printf '  %d links already in place\n' "$ok"
    fi
}

__show_diff() {
    if [ -d "$1" ] && [ ! -L "$1" ]; then
        diff -r -- "$1" "$REPO/$2"
    else
        diff -u -- "$1" "$REPO/$2"
    fi
}

# __resolve_conflicts PLANFILE MODE: turn every conflict row into replace or
# keep, from MODE (replace|keep) or by asking. Fails when cancelled.
__resolve_conflicts() {
    local plan=$1 mode=$2 i state t text p ans
    local -a rows=()
    mapfile -t rows <"$plan"
    for i in "${!rows[@]}"; do
        IFS=$'\t' read -r state t text p <<<"${rows[i]}"
        [ "$state" = conflict ] || continue
        if [ -n "$mode" ]; then
            state=$mode
        else
            __link_classify "$t" "$text" "$p"
            while :; do
                __info ""
                __info "$(__tilde "$t"): $__WHAT, differs from the repo's $p"
                __info "  r replace (back up, then link), k keep, d diff, R replace all remaining, K keep all remaining, c cancel"
                __ask "  [r/k/d/R/K/c] " ans || ans=c
                case $ans in
                    r) state=replace; break ;;
                    k) state=keep; break ;;
                    R) mode=replace; state=replace; break ;;
                    K) mode=keep; state=keep; break ;;
                    d) __show_diff "$t" "$p" ;;
                    c|q)
                        __info "Cancelled; nothing changed."
                        return 1
                        ;;
                esac
            done
        fi
        printf -v "rows[$i]" '%s\t%s\t%s\t%s' "$state" "$t" "$text" "$p"
    done
    printf '%s\n' "${rows[@]}" >"$plan"
}

# __hist_size_warnings FILE: a line per HISTSIZE/HISTFILESIZE below 10000.
__hist_size_warnings() {
    local n=0 l re='^[[:space:]]*(export[[:space:]]+)?(HISTSIZE|HISTFILESIZE)=["'\'']?([0-9]+)'
    __read_lines "$1" 2>/dev/null || return 0
    for l in "${__LINES[@]}"; do
        n=$((n + 1))
        if [[ $l =~ $re ]] && [ "${BASH_REMATCH[3]}" -lt 10000 ]; then
            # shellcheck disable=SC2088  # display text
            printf '~/.bashrc:%d: %s=%s truncates whichever history file is current at that point; use 10000 or more\n' \
                "$n" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        fi
    done
}

# __install_warnings ENTRYDIR: the warnings install prints before and after.
__install_warnings() {
    local kind path reason id action t f
    __tmux_check
    __xdg_check
    __xdg_drift
    while IFS=$'\t' read -r kind path reason; do
        if [ "$kind" = shadow ]; then
            printf '%s: %s\n' "$(__tilde "$path")" "$reason"
        fi
    done < <(__legacy_signals --all)
    __hist_size_warnings "$1/bash"
    while IFS=$'\t' read -r id action t f; do
        [ "$action" = unmanaged ] || continue
        if __entry_unmanaged "$t"; then
            printf '%s: recorded unmanaged, so no managed block is added; to have one kept current, add the lines "-- >>> dotfiles >>>" and "-- <<< dotfiles <<<" above its last "return config"\n' \
                "$(__tilde "$t")"
        else
            printf '%s: no managed block added (it needs a top-level "local servers" before the last top-level "return config", and no other common.lua loader); left as is and recorded unmanaged\n' \
                "$(__tilde "$t")"
        fi
    done <"$1/entries.tsv"
}

__cmd_install() {
    local yes=0 dry=0 mode='' w kind path reason
    local -a warnings=()
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes) yes=1 ;;
            --replace-all) mode=replace ;;
            --keep-all) mode=keep ;;
            -n|--dry-run) dry=1 ;;
            -h|--help)
                __install_usage
                return 0
                ;;
            *)
                __err "install: unknown option '$1'"
                __install_usage >&2
                return 2
                ;;
        esac
        shift
    done
    [ -z "$mode" ] || yes=1

    __gate_portable || return
    __gate_repo_path || return
    __tmpdir || return
    if __legacy_signals >"$__TMP/legacy"; then
        __err "the old dotfiles layout, or a file that shadows the XDG config, is present:"
        while IFS=$'\t' read -r kind path reason; do
            __info "  $(__tilde "$path"): $reason ($kind)"
        done <"$__TMP/legacy"
        __info "Run 'dotfiles uninstall-legacy' first: it previews, then migrates them."
        return 4
    fi
    __install_plan "$__TMP/plan" || return
    __entries_prepare "$__TMP/entries" || return
    mapfile -t warnings < <(__install_warnings "$__TMP/entries")
    for w in "${warnings[@]}"; do
        __warn "$w"
    done

    if [ "$dry" = 1 ]; then
        printf 'Plan (dry run; nothing changed):\n'
        __plan_print "$__TMP/plan" "$__TMP/entries"
        return 0
    fi
    __state_render "$__TMP/plan" "$__TMP/state" || return
    if ! __install_has_writes "$__TMP/plan" "$__TMP/entries" "$__TMP/state"; then
        printf 'Nothing to do; everything is in place.\n'
        return 0
    fi
    if grep -q $'^conflict\t' "$__TMP/plan"; then
        if [ -z "$mode" ] && [ ! -t 0 ]; then
            printf 'Conflicts (existing files that differ from the repo):\n'
            __plan_print "$__TMP/plan" "" conflicts
            __err "no terminal to ask about them; re-run with --replace-all or --keep-all (nothing changed)"
            return 3
        fi
        __resolve_conflicts "$__TMP/plan" "$mode" || return
    fi
    printf 'Plan:\n'
    __plan_print "$__TMP/plan" "$__TMP/entries"
    if [ "$yes" = 0 ]; then
        if [ ! -t 0 ]; then
            __err "no terminal to confirm; re-run with --yes (nothing changed)"
            return 3
        fi
        if ! __ask 'Apply? [y/N] '; then
            __info "Cancelled; nothing changed."
            return 1
        fi
    fi
    __journal_begin install || return
    __install_apply "$__TMP/plan" || return
    __entries_commit "$__TMP/entries" || return
    for w in "${warnings[@]}"; do
        __warn "$w"
    done
    __journal_done || return
    printf 'Done.\n'
}

# _portable-entries: create the entry files of a portable checkout when they
# are missing and refresh their blocks. Only for HOME = this checkout.
__cmd_portable_entries() {
    local id home_p
    home_p=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || home_p=
    if [ -z "${DOTFILES_PORTABLE:-}" ] || [ "$home_p" != "$REPO" ]; then
        __err "_portable-entries is internal to enter.sh (HOME must be this checkout)"
        return 5
    fi
    for id in bash profile git tmux; do
        __entry_info "$id" || return
        if [ ! -e "$__E_TARGET" ] && [ ! -L "$__E_TARGET" ]; then
            mkdir -p -- "${__E_TARGET%/*}" || return
            __entry_create "$__E_TARGET" "$__E_TEMPLATE" || return
        elif [ ${#__E_BLOCKS[@]} -gt 0 ]; then
            __entry_ensure "$id" || return
        fi
    done
}
