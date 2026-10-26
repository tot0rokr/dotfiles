# shellcheck shell=bash
# history.bash - merge an old bash history file into the XDG HISTFILE.
#
# Used by install, uninstall-legacy and `migrate history`. The old file is
# renamed into the backup dir before its lines are appended, so shells that
# still write to the old path start a fresh file there, which a later run
# merges. The dev:inode:size of every merged file goes to history.merged, so
# no file is merged twice.

__hist_file() {
    printf '%s\n' "$STATE/bash/history"
}

__hist_id() {
    stat -c '%d:%i:%s' -- "$1"
}

# __hist_pending FILE: true when FILE is a regular file not merged yet.
__hist_pending() {
    local id
    if [ ! -f "$1" ] || [ -L "$1" ]; then
        return 1
    fi
    id=$(__hist_id "$1") || return 1
    ! grep -qxF -- "$id" "$STATE_DIR/history.merged" 2>/dev/null
}

# Append SRC to DST under umask 077; a missing DST becomes a plain copy.
__hist_append() {
    (
        umask 077
        # A last line without a newline would glue onto the first appended one.
        if [ -s "$2" ] && [ -n "$(tail -c 1 -- "$2")" ]; then
            printf '\n' >>"$2" || exit 1
        fi
        cat -- "$1" >>"$2"
    )
}

# __hist_import OLD: rename OLD into the backup dir, append it to the
# HISTFILE and record it. No-op when OLD is absent or already merged.
__hist_import() {
    local old=$1 hist id dest fd rc=0
    __hist_pending "$old" || return 0
    hist=$(__hist_file)
    __state_dir_ensure || return
    if [ ! -d "${hist%/*}" ]; then
        __journal mkdir "${hist%/*}" || return
        (umask 077 && mkdir -p -- "${hist%/*}") || return 1
    fi
    exec {fd}>>"$STATE_DIR/history.lock" || return 1
    if ! flock -w 60 "$fd"; then
        exec {fd}>&-
        __err "cannot lock $STATE_DIR/history.lock"
        return 1
    fi
    # Another host sharing this home may have merged it while we waited.
    if __hist_pending "$old"; then
        if ! id=$(__hist_id "$old") || ! __journal hist-import "$old" "$hist" ||
            ! dest=$(__backup_move "$old"); then
            rc=1
        elif ! __hist_append "$dest" "$hist"; then
            __err "cannot append $dest to $hist"
            rc=1
        elif ! (umask 077 && printf '%s\n' "$id" >>"$STATE_DIR/history.merged"); then
            rc=1
        fi
    fi
    exec {fd}>&-
    return "$rc"
}
