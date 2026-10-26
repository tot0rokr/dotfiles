# shellcheck shell=bash
# shellcheck disable=SC2034  # globals read by install, status and legacy
# blocks.bash - managed blocks in the account-local entry files.
#
# A block is the whole-line marker pair "<prefix>>>> <id> >>>" ...
# "<prefix><<< <id> <<<" (prefix "# ", or "-- " for Lua). Its body comes from
# the same block in lib/templates/<tool>. Only the lines between the markers
# are ever rewritten: every byte outside the blocks is kept (CR included), and
# a rendered file whose outside text differs is never written.

ENTRY_IDS=(bash git tmux wezterm)

__RE_SERVERS='^local[[:space:]]+servers([[:space:]=]|$)'
__RE_RETURN='^return[[:space:]]+config[[:space:]]*$'

# __entry_info ID: set __E_TARGET, __E_TEMPLATE and __E_BLOCKS (one
# "id|prefix|policy" per block; policy says where a missing block goes:
# top, end, or before-return for wezterm). "profile" is portable mode's
# ~/.profile, which has no block.
__entry_info() {
    __E_BLOCKS=()
    case $1 in
        bash)
            __E_TARGET=$HOME/.bashrc
            __E_TEMPLATE=$REPO/lib/templates/bashrc
            __E_BLOCKS=('dotfiles env|# |top' 'dotfiles|# |end')
            ;;
        git)
            __E_TARGET=$CFG/git/config
            __E_TEMPLATE=$REPO/lib/templates/gitconfig
            __E_BLOCKS=('dotfiles|# |top')
            ;;
        tmux)
            __E_TARGET=$CFG/tmux/tmux.conf
            __E_TEMPLATE=$REPO/lib/templates/tmux.conf
            __E_BLOCKS=('dotfiles|# |top')
            ;;
        wezterm)
            __E_TARGET=$CFG/wezterm/wezterm.lua
            __E_TEMPLATE=$REPO/lib/templates/wezterm.lua
            __E_BLOCKS=('dotfiles|-- |before-return')
            ;;
        profile)
            __E_TARGET=$HOME/.profile
            __E_TEMPLATE=$REPO/lib/templates/profile-portable
            ;;
        *)
            __err "unknown entry file '$1'"
            return 1
            ;;
    esac
}

# __read_lines FILE: load FILE into __LINES; __NL_LAST is 0 when the last line
# has no trailing newline. read drops NUL bytes, hence __edit_check.
__read_lines() {
    local line=
    __LINES=()
    __NL_LAST=1
    if [ ! -r "$1" ]; then
        __err "cannot read $1"
        return 1
    fi
    while IFS= read -r line; do
        __LINES+=("$line")
    done <"$1"
    if [ -n "$line" ]; then
        __LINES+=("$line")
        __NL_LAST=0
    fi
}

# __write_lines FILE NL_LAST: write __OUT to FILE; the last line gets a
# newline unless NL_LAST is 0.
__write_lines() {
    local n=${#__OUT[@]}
    {
        if [ "$n" -gt 1 ]; then
            printf '%s\n' "${__OUT[@]:0:n-1}"
        fi
        if [ "$n" -gt 0 ]; then
            if [ "$2" = 0 ]; then
                printf '%s' "${__OUT[n-1]}"
            else
                printf '%s\n' "${__OUT[n-1]}"
            fi
        fi
    } >"$1"
}

# __edit_check FILE: refuse (5) a symlink, a non-regular file, or one with NUL
# bytes; fail when it cannot be read.
__edit_check() {
    if [ -L "$1" ]; then
        __err "$1 is a symlink; dotfiles edits only regular files"
        return 5
    fi
    if [ ! -f "$1" ]; then
        __err "$1 is not a regular file"
        return 5
    fi
    if [ ! -r "$1" ]; then
        __err "cannot read $1"
        return 1
    fi
    if [ "$(tr -d '\000' <"$1" | wc -c)" != "$(wc -c <"$1")" ]; then
        __err "$1 contains NUL bytes; refusing to edit it"
        return 5
    fi
}

# __block_find ID PREFIX FILE: locate block ID in __LINES (a marker may end in
# CR); __BS/__BE are the marker indexes, -1 when absent. Fails on a lone or
# repeated marker; FILE only names the file in the message.
__block_find() {
    local bs="$2>>> $1 >>>" be="$2<<< $1 <<<" i ns=0 ne=0
    __BS=-1
    __BE=-1
    for i in "${!__LINES[@]}"; do
        case ${__LINES[i]} in
            "$bs"|"$bs"$'\r') ns=$((ns + 1)); __BS=$i ;;
            "$be"|"$be"$'\r') ne=$((ne + 1)); __BE=$i ;;
        esac
    done
    if [ "$ns" -eq 0 ] && [ "$ne" -eq 0 ]; then
        return 0
    fi
    if [ "$ns" -eq 1 ] && [ "$ne" -eq 1 ] && [ "$__BS" -lt "$__BE" ]; then
        return 0
    fi
    __err "$3: broken managed block '$1' ($ns start and $ne end markers); fix it by hand"
    return 1
}

# __template_body TEMPLATE ID PREFIX: set __BODY to the lines inside block ID.
__template_body() {
    __read_lines "$1" || return
    __block_find "$2" "$3" "$1" || return
    if [ "$__BS" -lt 0 ]; then
        __err "$1 has no '$3>>> $2 >>>' block"
        return 1
    fi
    __BODY=("${__LINES[@]:__BS+1:__BE-__BS-1}")
}

# __block_render IN OUT TEMPLATE ID PREFIX POLICY [NAME]: write IN with block
# ID refreshed from TEMPLATE (or inserted per POLICY) to OUT. Sets
# __BLOCK_STATE to unmanaged, leaving OUT unwritten, when IN has no block ID
# and POLICY is none, or POLICY is before-return and IN has no top-level
# "local servers" before its last top-level "return config", or already loads
# common.lua outside a block. NAME (default IN) names the file in errors.
__block_render() {
    local in=$1 out=$2 id=$4 prefix=$5 policy=$6 nl i l ls=-1 rt=-1
    local bs="$5>>> $4 >>>" be="$5<<< $4 <<<"
    __BLOCK_STATE=managed
    __template_body "$3" "$id" "$prefix" || return
    __read_lines "$in" || return
    nl=$__NL_LAST
    __block_find "$id" "$prefix" "${7:-$in}" || return
    if [ "$__BS" -ge 0 ]; then
        __OUT=("${__LINES[@]:0:__BS+1}" "${__BODY[@]}" "${__LINES[@]:__BE}")
    else
        case $policy in
            top)
                __OUT=("$bs" "${__BODY[@]}" "$be" "${__LINES[@]}")
                ;;
            end)
                __OUT=("${__LINES[@]}" "$bs" "${__BODY[@]}" "$be")
                nl=1
                ;;
            before-return)
                for i in "${!__LINES[@]}"; do
                    l=${__LINES[i]%$'\r'}
                    case $l in
                        *dofile*common.lua*)
                            __BLOCK_STATE=unmanaged
                            return 0
                            ;;
                    esac
                    if [ "$ls" -lt 0 ] && [[ $l =~ $__RE_SERVERS ]]; then
                        ls=$i
                    fi
                    if [[ $l =~ $__RE_RETURN ]]; then
                        rt=$i
                    fi
                done
                if [ "$ls" -lt 0 ] || [ "$rt" -lt "$ls" ]; then
                    __BLOCK_STATE=unmanaged
                    return 0
                fi
                __OUT=("${__LINES[@]:0:rt}" "$bs" "${__BODY[@]}" "$be" "${__LINES[@]:rt}")
                ;;
            none)
                __BLOCK_STATE=unmanaged
                return 0
                ;;
            *)
                __err "unknown block policy '$policy'"
                return 1
                ;;
        esac
    fi
    __write_lines "$out" "$nl"
}

# __outside_same A B SPEC...: fail unless A and B have the same lines outside
# the blocks named by the "id|prefix|..." SPECs.
__outside_same() {
    local a b
    __outside_lines "$1" "${@:3}" || return
    printf -v a '%s\n' "${__OUTSIDE[@]}"
    __outside_lines "$2" "${@:3}" || return
    printf -v b '%s\n' "${__OUTSIDE[@]}"
    if [ "$a" != "$b" ]; then
        __err "the text outside the managed blocks of $1 would change; nothing written"
        return 1
    fi
}

__outside_lines() {
    local f=$1 spec rest l m i hit inside=0
    local -a s=() e=()
    shift
    for spec; do
        rest=${spec#*|}
        s+=("${rest%%|*}>>> ${spec%%|*} >>>")
        e+=("${rest%%|*}<<< ${spec%%|*} <<<")
    done
    __read_lines "$f" || return
    __OUTSIDE=()
    for l in "${__LINES[@]}"; do
        m=${l%$'\r'}
        hit=
        for i in "${!s[@]}"; do
            if [ "$m" = "${s[i]}" ]; then
                hit=start
                break
            fi
            if [ "$m" = "${e[i]}" ]; then
                hit=end
                break
            fi
        done
        case $hit in
            start) inside=1 ;;
            end) inside=0 ;;
            *) [ "$inside" = 1 ] || __OUTSIDE+=("$l") ;;
        esac
    done
}

# __entry_unmanaged TARGET: true when blocks.tsv records TARGET as unmanaged.
__entry_unmanaged() {
    local t b s
    [ -f "$BLOCKS" ] || return 1
    while IFS=$'\t' read -r t b s; do
        if [ "$t" = "$1" ] && [ "$s" = unmanaged ]; then
            return 0
        fi
    done <"$BLOCKS"
    return 1
}

# __entry_render IN OUT: render every block of the entry last named by
# __entry_info into OUT (see __block_render for __BLOCK_STATE). A target
# recorded unmanaged gets no block inserted, only its existing ones refreshed:
# the record may come from uninstall-legacy moving a monolithic wezterm.lua
# whose anchors would otherwise take the block.
__entry_render() {
    local in=$1 out=$2 cur=$1 spec rest policy n=0 noinsert=0
    if __entry_unmanaged "$__E_TARGET"; then
        noinsert=1
    fi
    for spec in "${__E_BLOCKS[@]}"; do
        n=$((n + 1))
        rest=${spec#*|}
        policy=${rest#*|}
        [ "$noinsert" = 0 ] || policy=none
        __block_render "$cur" "$out.$n" "$__E_TEMPLATE" "${spec%%|*}" "${rest%%|*}" "$policy" "$in" || return
        if [ "$__BLOCK_STATE" = unmanaged ]; then
            rm -f -- "$out".[0-9]*
            return 0
        fi
        cur=$out.$n
    done
    if [ "$n" -eq 0 ]; then
        cp -- "$in" "$out" || return
    else
        mv -f -- "$cur" "$out" || return
        rm -f -- "$out".[0-9]*
    fi
    __outside_same "$in" "$out" "${__E_BLOCKS[@]}"
}

# __new_file_mode: the mode a plain new file gets under the current umask.
__new_file_mode() {
    local m
    m=$(umask)
    printf '%o\n' $((0666 & ~m))
}

# __replace_file TARGET NEW: give NEW TARGET's mode and rename it over TARGET
# unless they are equal (then NEW is removed). __CHANGED says which.
__replace_file() {
    __CHANGED=0
    if ! chmod --reference="$1" -- "$2"; then
        rm -f -- "$2"
        return 1
    fi
    if cmp -s -- "$2" "$1"; then
        rm -f -- "$2"
        return 0
    fi
    if ! mv -f -- "$2" "$1"; then
        rm -f -- "$2"
        __err "cannot replace $1"
        return 1
    fi
    __CHANGED=1
}

# __block_ensure TARGET TEMPLATE ID PREFIX POLICY: refresh or insert one block
# in place (temp file in the same dir, then rename).
__block_ensure() {
    local t=$1 tmp rc
    __edit_check "$t" || return
    tmp=$(mktemp "${t%/*}/.${t##*/}.dotfiles.XXXXXX") || return
    __block_render "$t" "$tmp" "$2" "$3" "$4" "$5" || {
        rc=$?
        rm -f -- "$tmp"
        return "$rc"
    }
    if [ "$__BLOCK_STATE" = unmanaged ]; then
        rm -f -- "$tmp"
        return 0
    fi
    if ! __outside_same "$t" "$tmp" "$3|$4|$5"; then
        rm -f -- "$tmp"
        return 1
    fi
    __replace_file "$t" "$tmp"
}

# __entry_ensure ID: refresh or insert every block of entry ID in place.
__entry_ensure() {
    local t tmp rc
    __entry_info "$1" || return
    t=$__E_TARGET
    __edit_check "$t" || return
    tmp=$(mktemp "${t%/*}/.${t##*/}.dotfiles.XXXXXX") || return
    __entry_render "$t" "$tmp" || {
        rc=$?
        rm -f -- "$tmp" "$tmp".[0-9]*
        return "$rc"
    }
    if [ "$__BLOCK_STATE" = unmanaged ]; then
        rm -f -- "$tmp"
        __warn "$(__tilde "$t"): no place for the managed block; left as is"
        return 0
    fi
    __replace_file "$t" "$tmp"
}

# __entry_create TARGET TEMPLATE: create TARGET from TEMPLATE only when
# nothing is there (temp file in the same dir, then rename).
__entry_create() {
    local t=$1 tmp
    if [ -e "$t" ] || [ -L "$t" ]; then
        return 0
    fi
    tmp=$(mktemp "${t%/*}/.${t##*/}.dotfiles.XXXXXX") || return
    if ! cat -- "$2" >"$tmp" || ! chmod "$(__new_file_mode)" -- "$tmp" \
        || ! mv -f -- "$tmp" "$t"; then
        rm -f -- "$tmp"
        __err "cannot create $t"
        return 1
    fi
}

# __block_remove TARGET ID PREFIX: delete block ID (markers included) in place.
__block_remove() {
    local t=$1 tmp nl
    __edit_check "$t" || return
    __read_lines "$t" || return
    __block_find "$2" "$3" "$t" || return
    [ "$__BS" -ge 0 ] || return 0
    nl=$__NL_LAST
    if [ "$__BE" -eq $((${#__LINES[@]} - 1)) ]; then
        nl=1
    fi
    __OUT=("${__LINES[@]:0:__BS}" "${__LINES[@]:__BE+1}")
    tmp=$(mktemp "${t%/*}/.${t##*/}.dotfiles.XXXXXX") || return
    if ! __write_lines "$tmp" "$nl" || ! __outside_same "$t" "$tmp" "$2|$3"; then
        rm -f -- "$tmp"
        return 1
    fi
    __replace_file "$t" "$tmp"
}
