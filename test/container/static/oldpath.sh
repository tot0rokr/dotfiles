#!/usr/bin/env bash
# Old-path check (A11): references to the pre-XDG home layout in the tracked
# files of a checkout. The patterns (grep -E) are in oldpath-patterns.txt.
#
#   oldpath.sh REPO               report every hit not allowed, exit 1 if any
#   oldpath.sh --selftest FILE    "+ " lines of FILE must match, "- " must not
#
# Allowed: lines listed in oldpath-allow.txt (path<TAB>exact line<TAB>reason)
# and the exempt files below. Run it on a checkout whose new files are staged
# (`git ls-files` must list them).
set -o pipefail
# Byte semantics, so the hits do not depend on the caller's locale: in a UTF-8
# locale a Hangul letter right after "nvm" is a word character and hides it.
export LC_ALL=C

HERE=$(cd -P "${BASH_SOURCE[0]%/*}" && pwd -P) || exit 2
PATTERNS=$HERE/oldpath-patterns.txt
ALLOW=$HERE/oldpath-allow.txt

die() {
    printf 'oldpath.sh: %s\n' "$*" >&2
    exit 2
}

# Legacy and migration code must name the old paths; the test tree holds the
# fixtures; the vendored git scripts are upstream's.
exempt() {
    case $1 in
        lib/dotfiles/legacy.bash | lib/dotfiles/migrate.bash | lib/dotfiles/history.bash) return 0 ;;
        test/*) return 0 ;;
        .config/bash/git-prompt.sh | .config/bash/git-completion.bash) return 0 ;;
        .local/share/fonts/*) return 0 ;;
    esac
    return 1
}

selftest() {
    local line text bad=0
    while IFS= read -r line; do
        case $line in
            '+ '*) text=${line#+ }
                grep -qE -f "$PATTERNS" <<<"$text" || { printf 'not reported: %s\n' "$text"; bad=1; } ;;
            '- '*) text=${line#- }
                ! grep -qE -f "$PATTERNS" <<<"$text" || { printf 'reported: %s\n' "$text"; bad=1; } ;;
        esac
    done <"$1"
    return "$bad"
}

scan() {
    local repo=$1 row path rest reason line f hit n text bad=0
    local -A allowed=() used=()
    while IFS= read -r row; do
        case $row in '' | '#'*) continue ;; esac
        path=${row%%$'\t'*}
        rest=${row#*$'\t'}
        reason=${rest##*$'\t'}
        line=${rest%$'\t'*}
        if [ "$path" = "$row" ] || [ "$line" = "$rest" ] || [ -z "$reason" ]; then
            die "malformed allow-list entry (want path<TAB>line<TAB>reason): $row"
        fi
        allowed["$path"$'\t'"$line"]=1
    done <"$ALLOW"

    while IFS= read -r -d '' f; do
        exempt "$f" && continue
        [ -f "$repo/$f" ] || continue
        while IFS= read -r hit; do
            n=${hit%%:*}
            text=${hit#*:}
            if [ -n "${allowed["$f"$'\t'"$text"]:-}" ]; then
                used["$f"$'\t'"$text"]=1
                continue
            fi
            printf '%s:%s: %s\n' "$f" "$n" "$text"
            bad=1
        done < <(grep -nIE -f "$PATTERNS" -- "$repo/$f")
    done < <(git -c safe.directory='*' -C "$repo" ls-files -z)

    for row in "${!allowed[@]}"; do
        [ -n "${used["$row"]:-}" ] || printf 'warning: stale allow-list entry: %s\n' "${row/$'\t'/: }" >&2
    done
    return "$bad"
}

[ -r "$PATTERNS" ] || die "missing $PATTERNS"
case ${1:-} in
    --selftest) [ -r "${2:-}" ] || die "usage: oldpath.sh --selftest FILE"; selftest "$2" ;;
    '' | -*) die "usage: oldpath.sh REPO | --selftest FILE" ;;
    *) [ -r "$ALLOW" ] || die "missing $ALLOW"; scan "$1" ;;
esac
