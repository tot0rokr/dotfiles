# shellcheck shell=bash
# update.bash - `dotfiles update`: fetch, review, fast-forward, relink.

__update_usage() {
    cat <<'EOF'
Usage: dotfiles update [--yes] [--replace-all | --keep-all]

Fetch the upstream of the checkout's branch, show the incoming commits and
diffstat, check the incoming shell files with bash -n, fast-forward after
confirmation, then run `dotfiles install` (new files are linked, links to
removed files are pruned). In portable mode only fetch and merge run.

  -y, --yes          merge and apply without asking
      --replace-all  passed to install (implies --yes)
      --keep-all     passed to install (implies --yes)
EOF
}

__cmd_update() {
    local yes=0 bad=0 portable=0 home_p branch remote merge n f
    local -a pass=() blocked=()
    local -A incoming=()
    while [ $# -gt 0 ]; do
        case $1 in
            -y|--yes)
                yes=1
                pass+=(--yes)
                ;;
            --replace-all|--keep-all)
                yes=1
                pass+=("$1")
                ;;
            -h|--help)
                __update_usage
                return 0
                ;;
            *)
                __err "update: unknown option '$1'"
                __update_usage >&2
                return 2
                ;;
        esac
        shift
    done
    home_p=$(cd -P -- "$HOME" 2>/dev/null && pwd -P) || home_p=$HOME
    if [ -n "${DOTFILES_PORTABLE:-}" ] || [ "$home_p" = "$REPO" ]; then
        portable=1
    fi

    branch=$(__git symbolic-ref -q --short HEAD) || {
        __err "$REPO is not on a branch"
        return 1
    }
    if ! remote=$(__git config "branch.$branch.remote") \
        || ! merge=$(__git config "branch.$branch.merge"); then
        __err "branch $branch has no upstream; set one with git branch --set-upstream-to"
        return 1
    fi
    __info "Fetching $merge from $remote ..."
    __git fetch -q "$remote" "$merge" || {
        __err "git fetch failed"
        return 1
    }
    n=$(__git rev-list --count HEAD..FETCH_HEAD) || return 1
    if [ "$n" -eq 0 ]; then
        __info "Already up to date."
    else
        if ! __git merge-base --is-ancestor HEAD FETCH_HEAD; then
            __err "HEAD has commits that $remote lacks, so it cannot fast-forward (nothing changed)"
            return 1
        fi
        printf 'Incoming commits (%d):\n' "$n"
        __git --no-pager log --oneline --no-decorate HEAD..FETCH_HEAD
        __git --no-pager diff --stat HEAD FETCH_HEAD
        while IFS= read -r -d '' f; do
            incoming[$f]=1
            case $f in
                *.bash|*.sh|bin/dotfiles) ;;
                *) continue ;;
            esac
            __git cat-file -e "FETCH_HEAD:$f" 2>/dev/null || continue
            if ! __git show "FETCH_HEAD:$f" | bash -n; then
                __err "incoming $f has a syntax error"
                bad=1
            fi
        done < <(__git diff -z --name-only HEAD FETCH_HEAD)
        if [ "$bad" = 1 ]; then
            __err "update stopped before merging; nothing changed"
            return 1
        fi
        while IFS= read -r -d '' f; do
            [ -z "${incoming[$f]-}" ] || blocked+=("$f")
        done < <(__git diff -z --name-only HEAD)
        if [ ${#blocked[@]} -gt 0 ]; then
            __err "local changes to files the update touches; commit, stash or revert them first (nothing changed):"
            printf '  %s\n' "${blocked[@]}" >&2
            return 1
        fi
        if [ "$yes" = 0 ]; then
            if [ ! -t 0 ]; then
                __err "no terminal to confirm; re-run with --yes (nothing merged)"
                return 3
            fi
            if ! __ask "Fast-forward to these $n commits? [y/N] "; then
                __info "Cancelled; nothing merged."
                return 1
            fi
        fi
        __git merge -q --ff-only FETCH_HEAD || {
            __err "git merge --ff-only failed"
            return 1
        }
    fi
    if [ "$portable" = 1 ]; then
        __portable_link_hint "$home_p" install
        return 0
    fi
    # The merge may have changed this CLI, so relink with the new code.
    exec "$REPO/bin/dotfiles" install "${pass[@]}"
}
