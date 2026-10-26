# shellcheck shell=bash
# shellcheck disable=SC2034  # globals read by install, status and legacy
# links.bash - which repo paths install links where, how a target is
# classified, and the state files that describe the result (manifest.tsv,
# kept.list, xdg.env).

# __link_units: fill U_PATH (repo path), U_TARGET (absolute target) and
# U_BASE (the dir below which no parent may be a symlink) from the tracked
# files under .config and .local/share/fonts, plus bin/dotfiles. The bash,
# fzf and readline dirs hold only common files and are linked whole.
__link_units() {
    local p unit rest
    local -A seen=()
    U_PATH=()
    U_TARGET=()
    U_BASE=()
    if ! __git rev-parse --git-dir >/dev/null 2>&1; then
        __err "$REPO is not a git checkout"
        return 1
    fi
    while IFS= read -r -d '' p; do
        case $p in
            *$'\t'*|*$'\n'*)
                __warn "skipping '$p': tab or newline in its name"
                continue
                ;;
            .config/bash/*|.config/fzf/*|.config/readline/*)
                rest=${p#.config/}
                unit=.config/${rest%%/*}
                ;;
            *) unit=$p ;;
        esac
        [ -z "${seen[$unit]-}" ] || continue
        seen[$unit]=1
        if [ ! -e "$REPO/$unit" ] && [ ! -L "$REPO/$unit" ]; then
            __warn "skipping $unit: tracked but missing from the work tree"
            continue
        fi
        case $unit in
            .config/*)
                U_TARGET+=("$CFG/${unit#.config/}")
                U_BASE+=("$CFG")
                ;;
            .local/share/fonts/*)
                U_TARGET+=("$DATA/fonts/${unit#.local/share/fonts/}")
                U_BASE+=("$DATA")
                ;;
            bin/dotfiles)
                U_TARGET+=("$HOME/.local/bin/dotfiles")
                U_BASE+=("$HOME/.local")
                ;;
            *) continue ;;
        esac
        U_PATH+=("$unit")
    done < <(__git ls-files -z -- .config .local/share/fonts bin/dotfiles)
}

# __link_text TARGET REPO-PATH VAR: the relative link text, computed from the
# physical parent of TARGET to the physical repo path. -s keeps a tracked
# repo symlink (nvim's coc-settings.json) as the link source.
__link_text() {
    local pp rel
    __phys_dir "${1%/*}" pp || return
    rel=$(realpath -m -s --relative-to="$pp" -- "$REPO/$2") || return
    printf -v "$3" '%s' "$rel"
}

# __link_classify TARGET TEXT REPO-PATH: set __CLASS to correct (our link),
# new (nothing there), identical (a copy of the repo file or dir) or
# conflict, and __WHAT to a description of what is there.
__link_classify() {
    local t=$1 src=$REPO/$3 cur
    __WHAT=
    if [ -L "$t" ]; then
        cur=$(readlink -- "$t")
        if [ "$cur" = "$2" ] && [ -e "$t" ]; then
            __CLASS=correct
            return
        fi
        __CLASS=conflict
        if [ -e "$t" ]; then
            __WHAT="symlink to $cur"
        else
            __WHAT="dangling symlink to $cur"
        fi
        return
    fi
    if [ ! -e "$t" ]; then
        __CLASS=new
        return
    fi
    if [ -f "$t" ] && [ -f "$src" ] && cmp -s -- "$t" "$src"; then
        __CLASS=identical
        __WHAT="identical copy"
        return
    fi
    if [ -d "$t" ] && [ -d "$src" ] && diff -rq --no-dereference -- "$t" "$src" >/dev/null 2>&1; then
        __CLASS=identical
        __WHAT="identical copy"
        return
    fi
    __CLASS=conflict
    if [ -d "$t" ]; then
        __WHAT=directory
    else
        __WHAT="regular file"
    fi
}

# __parent_check TARGET BASE: refuse (5) when a dir between BASE and TARGET
# is a symlink (e.g. ~/.config/nvim linked to another repo) or not a dir;
# __BAD_PARENT names it.
__parent_check() {
    local d=${1%/*}
    __BAD_PARENT=
    while [ -n "$d" ] && [ "$d" != "$2" ]; do
        if [ -L "$d" ]; then
            __BAD_PARENT=$d
            __err "$d is a symlink (to $(readlink -- "$d")); refusing to link through it"
            return 5
        fi
        if [ -e "$d" ] && [ ! -d "$d" ]; then
            __BAD_PARENT=$d
            __err "$d is not a directory"
            return 5
        fi
        d=${d%/*}
    done
}

# __link_create TARGET TEXT: create the link TARGET (absent, or already moved
# to the backup dir). Never replaces anything: whatever appeared at TARGET
# since the plan was made stays, and the run fails.
__link_create() {
    if ln -sT -- "$2" "$1"; then
        return 0
    fi
    if [ -e "$1" ] || [ -L "$1" ]; then
        __err "$1 appeared while dotfiles was running; re-run"
    else
        __err "cannot link $1"
    fi
    return 1
}

__kept_load() {
    local t
    declare -gA KEPT_SET=()
    [ -f "$KEPT" ] || return 0
    while IFS= read -r t; do
        [ -z "$t" ] || KEPT_SET[$t]=1
    done <"$KEPT"
}

# Manifest rows: target<TAB>link-text<TAB>repo-path.
__manifest_load() {
    local t text p
    declare -gA MAN_TEXT=() MAN_PATH=()
    MAN_TARGETS=()
    [ -f "$MANIFEST" ] || return 0
    while IFS=$'\t' read -r t text p; do
        if [ -z "$t" ] || [ -z "$text" ]; then
            continue
        fi
        MAN_TEXT[$t]=$text
        MAN_PATH[$t]=${p:--}
        MAN_TARGETS+=("$t")
    done <"$MANIFEST"
}

__xdg_content() {
    printf 'XDG_CONFIG_HOME=%s\nXDG_DATA_HOME=%s\nXDG_STATE_HOME=%s\nXDG_CACHE_HOME=%s\nHOME=%s\nREPO=%s\n' \
        "$CFG" "$DATA" "$STATE" "$CACHE" "$HOME" "$REPO"
}

# __xdg_drift [KEY...]: print a line for each value (of KEYs, default all)
# that differs from the one recorded by the last install. A changed
# XDG_STATE_HOME moves the state dir itself, so the default location is
# consulted too.
__xdg_drift() {
    local f=$XDG_FILE line k v cur found=1
    [ -f "$f" ] || f=$HOME/.local/state/dotfiles/xdg.env
    [ -f "$f" ] || return 1
    while IFS= read -r line; do
        k=${line%%=*}
        v=${line#*=}
        if [ $# -gt 0 ] && [[ " $* " != *" $k "* ]]; then
            continue
        fi
        case $k in
            XDG_CONFIG_HOME) cur=$CFG ;;
            XDG_DATA_HOME) cur=$DATA ;;
            XDG_STATE_HOME) cur=$STATE ;;
            XDG_CACHE_HOME) cur=$CACHE ;;
            HOME) cur=$HOME ;;
            REPO) cur=$REPO ;;
            *) continue ;;
        esac
        if [ "$v" != "$cur" ]; then
            printf '%s resolves to %s, but install used %s; set it back or re-run '\''dotfiles install'\''\n' \
                "$k" "$cur" "$v"
            found=0
        fi
    done <"$f"
    return "$found"
}

# __journal_unfinished: print "run-id<TAB>time<TAB>command" for each run in
# the journal that began but never wrote its done line.
__journal_unfinished() {
    local id t action path rest
    local -A began=() cmd=() fin=()
    local -a order=()
    [ -f "$JOURNAL" ] || return 0
    while IFS=$'\t' read -r id t action path rest; do
        [ -n "$id" ] || continue
        case $action in
            begin)
                began[$id]=$t
                cmd[$id]=$path
                order+=("$id")
                ;;
            done) fin[$id]=1 ;;
        esac
    done <"$JOURNAL"
    for id in "${order[@]}"; do
        [ -n "${fin[$id]-}" ] || printf '%s\t%s\t%s\n' "$id" "${began[$id]}" "${cmd[$id]}"
    done
}
