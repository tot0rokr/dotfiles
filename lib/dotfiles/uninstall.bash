# shellcheck shell=bash
# uninstall.bash - `dotfiles uninstall`: remove the managed blocks, then the
# links install made. Nothing else is touched or restored.

__uninstall_usage() {
    cat <<'EOF'
Usage: dotfiles uninstall

Remove the managed blocks from the entry files (~/.bashrc and the git, tmux
and wezterm entries keep everything else), then remove the links install made
that still point into the repo. Backups are never restored automatically; the
commands to do it are printed at the end. Refuses (exit 5) when HOME or
XDG_STATE_HOME differs from the value install used.
EOF
}

# __uninstall_add_block FILE ID PREFIX: queue block ID of FILE when present.
__uninstall_add_block() {
    local key="$1|$2"
    [ -z "${__UN_SEEN[$key]-}" ] || return 0
    __UN_SEEN[$key]=1
    if [ -L "$1" ] || [ ! -f "$1" ]; then
        return 0
    fi
    __read_lines "$1" || return
    __block_find "$2" "$3" "$1" || return
    [ "$__BS" -ge 0 ] || return 0
    __UN_BFILE+=("$1")
    __UN_BID+=("$2")
    __UN_BPREFIX+=("$3")
}

# __uninstall_add_link TARGET TEXT: queue TARGET when it is still that link.
__uninstall_add_link() {
    [ -z "${__UN_SEEN[$1]-}" ] || return 0
    __UN_SEEN[$1]=1
    if [ -L "$1" ] && [ "$(readlink -- "$1")" = "$2" ]; then
        __UN_LINK+=("$1")
        __UN_TEXT+=("$2")
    fi
}

# Links created by a run that died before it wrote the manifest.
__journal_unfinished_links() {
    local id t action path detail
    local -A open=()
    [ -f "$JOURNAL" ] || return 0
    while IFS=$'\t' read -r id t; do
        open[$id]=1
    done < <(__journal_unfinished)
    while IFS=$'\t' read -r id t action path detail; do
        if [ -n "$id" ] && [ -n "${open[$id]-}" ] && [ "$action" = link ]; then
            printf '%s\t%s\n' "$path" "$detail"
        fi
    done <"$JOURNAL"
}

# Restore commands for what the journal says was moved or copied into a
# backup dir and is still there.
__uninstall_restore_hints() {
    local id t action path detail n=0
    [ -f "$JOURNAL" ] || return 0
    while IFS=$'\t' read -r id t action path detail; do
        case $action in
            backup-move|backup-copy) ;;
            *) continue ;;
        esac
        if [ ! -e "$detail" ] && [ ! -L "$detail" ]; then
            continue
        fi
        if [ "$n" -eq 0 ]; then
            printf '\nNothing was restored. Saved files (move whatever is now at the destination aside first):\n'
        fi
        n=$((n + 1))
        if [ "$action" = backup-move ]; then
            printf '  mv -T %q %q\n' "$detail" "$path"
        else
            printf '  cp -aT %q %q\n' "$detail" "$path"
        fi
    done <"$JOURNAL"
}

__cmd_uninstall() {
    local id spec rest t text f bid state prefix i line
    local -a drift=()
    declare -gA __UN_SEEN=()
    __UN_BFILE=()
    __UN_BID=()
    __UN_BPREFIX=()
    __UN_LINK=()
    __UN_TEXT=()
    if [ $# -gt 0 ]; then
        case $1 in
            -h|--help)
                __uninstall_usage
                return 0
                ;;
        esac
        __err "uninstall: unknown argument '$1'"
        __uninstall_usage >&2
        return 2
    fi
    __gate_portable || return
    # The manifest and blocks.tsv live in the state dir install used; with
    # another one only the blocks would go and the links would stay.
    mapfile -t drift < <(__xdg_drift XDG_STATE_HOME HOME)
    if [ ${#drift[@]} -gt 0 ]; then
        for line in "${drift[@]}"; do
            __err "$line"
        done
        __err "uninstall needs the state dir install used; set the value back (nothing changed)"
        return 5
    fi

    for id in "${ENTRY_IDS[@]}"; do
        __entry_info "$id" || return
        for spec in "${__E_BLOCKS[@]}"; do
            rest=${spec#*|}
            __uninstall_add_block "$__E_TARGET" "${spec%%|*}" "${rest%%|*}" || return
        done
    done
    if [ -f "$BLOCKS" ]; then
        while IFS=$'\t' read -r f bid state; do
            if [ -z "$f" ] || [ "$state" != managed ]; then
                continue
            fi
            case $f in
                *.lua) prefix='-- ' ;;
                *) prefix='# ' ;;
            esac
            __uninstall_add_block "$f" "$bid" "$prefix" || return
        done <"$BLOCKS"
    fi
    __manifest_load
    for t in "${MAN_TARGETS[@]}"; do
        __uninstall_add_link "$t" "${MAN_TEXT[$t]}"
    done
    while IFS=$'\t' read -r t text; do
        __uninstall_add_link "$t" "$text"
    done < <(__journal_unfinished_links)

    if [ ${#__UN_BFILE[@]} -eq 0 ] && [ ${#__UN_LINK[@]} -eq 0 ]; then
        printf 'Nothing to remove.\n'
        return 0
    fi
    printf 'Removing:\n'
    for i in "${!__UN_BFILE[@]}"; do
        printf '  block     %s (%s)\n' "$(__tilde "${__UN_BFILE[i]}")" "${__UN_BID[i]}"
    done
    for i in "${!__UN_LINK[@]}"; do
        printf '  link      %s -> %s\n' "$(__tilde "${__UN_LINK[i]}")" "${__UN_TEXT[i]}"
    done

    __tmpdir || return
    __journal_begin uninstall || return
    for i in "${!__UN_BFILE[@]}"; do
        __journal block-remove "${__UN_BFILE[i]}" "${__UN_BID[i]}" || return
        __block_remove "${__UN_BFILE[i]}" "${__UN_BID[i]}" "${__UN_BPREFIX[i]}" || return
    done
    for i in "${!__UN_LINK[@]}"; do
        __journal unlink "${__UN_LINK[i]}" "${__UN_TEXT[i]}" || return
        if ! rm -f -- "${__UN_LINK[i]}"; then
            __err "cannot remove ${__UN_LINK[i]}"
            return 1
        fi
    done
    : >"$__TMP/empty" || return
    for f in "$MANIFEST" "$BLOCKS"; do
        if [ -s "$f" ]; then
            __journal state "$f" || return
            __state_write "$f" "$__TMP/empty" || return
        fi
    done
    __journal_done || return
    printf 'Done.\n'
    __uninstall_restore_hints
}
