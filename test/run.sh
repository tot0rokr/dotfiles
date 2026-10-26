#!/usr/bin/env bash
# Build the dotfiles test images and run scenarios in Docker.
#   run.sh --work DIR [--tier lite|full] [--scenario LIST] [--target repo|repo-ro|tmux32] [--rebuild]
#   --work DIR       logs and the generated build context go under DIR (required)
#   --tier T         lite (default) or full: every tool, cargo builds, agents
#   --scenario LIST  comma-separated names from test/README.md (default: all of the tier)
#   --target T       build only that image (and run LIST on it)
#   --rebuild        build without the layer cache
# GH_TOKEN, when set, reaches the build only as a BuildKit secret.
# Exit status: 0 when every scenario passed.
set -u -o pipefail

HERE=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
REPO=$(cd -P "$HERE/.." && pwd -P) || exit 1

ALL_SCENARIOS=(s0-static s1-fresh s2-legacy s3a-xdg-config s3b-xdg-all s4-portable s5-live s6-cli s7-readonly
    s8-bootstrap tmux32)
FULL_SCENARIOS=(s1-fresh s2-legacy s5-live)

WORK=
TIER=lite
SCENARIOS=
TARGET=
REBUILD=0
RUNID=$(date +%Y%m%d-%H%M%S)-$$
STARTED=()
CTX=
SCANS=0

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

die() {
    printf 'run.sh: %s\n' "$*" >&2
    exit 1
}

# Removes exactly the containers this run started, and its build context.
cleanup() {
    local name
    for name in "${STARTED[@]}"; do
        docker rm -f "$name" >/dev/null 2>&1
    done
    [ -z "$CTX" ] || rm -rf "$CTX"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

while [ $# -gt 0 ]; do
    case $1 in
        --work) WORK=${2:?--work needs a directory}; shift ;;
        --tier) TIER=${2:?--tier needs lite or full}; shift ;;
        --scenario) SCENARIOS=${2:?--scenario needs a list}; shift ;;
        --target) TARGET=${2:?--target needs repo, repo-ro or tmux32}; shift ;;
        --rebuild) REBUILD=1 ;;
        -h | --help) usage; exit 0 ;;
        *) printf 'run.sh: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
if [ -z "$WORK" ]; then
    usage >&2
    exit 2
fi
case $TIER in lite | full) ;; *) die "--tier must be lite or full" ;; esac
case $TARGET in '' | repo | repo-ro | tmux32) ;; *) die "--target must be repo, repo-ro or tmux32" ;; esac
mkdir -p "$WORK/logs" || die "cannot create $WORK/logs"
WORK=$(cd -P "$WORK" && pwd -P) || exit 1

target_of() {
    case $1 in
        s7-readonly) printf 'repo-ro\n' ;;
        tmux32) printf 'tmux32\n' ;;
        *) printf 'repo\n' ;;
    esac
}

tag_of() {
    case $1 in
        repo) printf 'dotfiles-xdg-test:%s\n' "$TIER" ;;
        repo-ro) printf 'dotfiles-xdg-test:ro-%s\n' "$TIER" ;;
        tmux32) printf 'dotfiles-xdg-test:tmux32\n' ;;
    esac
}

# The legacy layout the migration scenarios install: the commit before the
# one that deleted .bashrc.common, or main until that commit exists.
legacy_ref() {
    local c
    c=$(git -C "$REPO" log -1 --format=%H --diff-filter=D -- .bashrc.common) || return 1
    if [ -n "$c" ]; then
        git -C "$REPO" rev-parse "$c^"
    else
        git -C "$REPO" rev-parse main
    fi
}

# The build context: the tracked and the non-ignored untracked files that
# exist (links kept as links), plus a copy of .git.
make_context() {
    local f n=0
    [ -d "$REPO/.git" ] || die "$REPO/.git is not a directory (use a clone, not a worktree)"
    CTX=$WORK/ctx-$RUNID
    mkdir -p "$CTX" || die "cannot create $CTX"
    while IFS= read -r -d '' f; do
        [ -e "$REPO/$f" ] || [ -L "$REPO/$f" ] || continue
        case $f in */*) mkdir -p "$CTX/${f%/*}" || die "cannot create $CTX/${f%/*}" ;; esac
        cp -P --preserve=mode "$REPO/$f" "$CTX/$f" || die "cannot copy $f"
        n=$((n + 1))
    done < <(git -C "$REPO" ls-files -z --cached --others --exclude-standard)
    cp -a "$REPO/.git" "$CTX/.git" || die "cannot copy $REPO/.git"
    printf 'build context: %s (%d files + .git)\n' "$CTX" "$n"
}

# The token never goes on a command line: grep reads it from a pipe.
token_guard_files() {
    local hits
    [ -n "${GH_TOKEN:-}" ] || return 0
    hits=$(printf '%s\n' "$GH_TOKEN" | grep -rlF -f - "$WORK/logs" "$WORK/out" 2>/dev/null)
    [ -z "$hits" ] || die "GH_TOKEN found in: $hits"
}

# Scans an image's files (docker export of a created, never started
# container) and its metadata for the token.
token_guard_image() {
    local tag=$1 name n
    [ -n "${GH_TOKEN:-}" ] || return 0
    SCANS=$((SCANS + 1))
    name=dotfiles-xdg-tokenscan-$RUNID-$SCANS
    STARTED+=("$name")
    docker create --name "$name" --label dotfiles-xdg-test=1 "$tag" >/dev/null || die "cannot create $name"
    n=$(docker export "$name" | grep -caF -f <(printf '%s\n' "$GH_TOKEN"))
    docker rm -f "$name" >/dev/null 2>&1
    [ "${n:-0}" = 0 ] || die "GH_TOKEN found in the files of image $tag"
    n=$({ docker image inspect "$tag"; docker history --no-trunc "$tag"; } | grep -cF -f <(printf '%s\n' "$GH_TOKEN"))
    [ "${n:-0}" = 0 ] || die "GH_TOKEN found in the metadata of image $tag"
}

build() {
    local target=$1 tag log args
    tag=$(tag_of "$target")
    log=$WORK/logs/build-${tag#*:}-$RUNID.log
    args=(build -f "$REPO/test/Dockerfile" --progress=plain --build-arg "TIER=$TIER"
        --target "$target" --label dotfiles-xdg-test=1 -t "$tag")
    [ -z "${GH_TOKEN:-}" ] || args+=(--secret "id=gh_token,env=GH_TOKEN")
    [ "$REBUILD" = 0 ] || args+=(--no-cache)
    printf '[build] %s -> %s, log %s\n' "$target" "$tag" "$log"
    if ! docker "${args[@]}" "$CTX" >"$log" 2>&1; then
        tail -n 30 "$log" >&2
        token_guard_files
        return 1
    fi
    token_guard_files
    token_guard_image "$tag"
}

run_scenario() {
    local s=$1 image=$2 name log limit rc args
    name=dotfiles-xdg-$s-$RUNID
    log=$WORK/logs/run-$s-$RUNID.log
    limit=900
    [ "$TIER" = lite ] || limit=2700
    args=(run --rm --init --name "$name" --label dotfiles-xdg-test=1)
    case $s in
        s2-legacy | s5-live) args+=(-e "LEGACY_REF=$LEGACY_REF") ;;
    esac
    STARTED+=("$name")
    printf '[run] %s on %s, log %s\n' "$s" "$image" "$log"
    timeout $((limit + 120)) docker "${args[@]}" "$image" \
        timeout --kill-after=30 "$limit" bash "/opt/dotfiles-test/scenarios/$s.sh" >"$log" 2>&1
    rc=$?
    # Gone already through --rm, unless the client was killed.
    docker rm -f "$name" >/dev/null 2>&1
    token_guard_files
    tail -n 3 "$log" | sed 's/^/      /'
    return "$rc"
}

if [ -n "$SCENARIOS" ]; then
    IFS=, read -r -a list <<<"$SCENARIOS"
elif [ -n "$TARGET" ]; then
    list=()
elif [ "$TIER" = full ]; then
    list=("${FULL_SCENARIOS[@]}")
else
    list=("${ALL_SCENARIOS[@]}")
fi
for s in "${list[@]}"; do
    case " ${ALL_SCENARIOS[*]} " in
        *" $s "*) ;;
        *) die "unknown scenario: $s (known: ${ALL_SCENARIOS[*]})" ;;
    esac
done

targets=()
if [ -n "$TARGET" ]; then
    targets=("$TARGET")
else
    for s in "${list[@]}"; do
        t=$(target_of "$s")
        case " ${targets[*]} " in *" $t "*) ;; *) targets+=("$t") ;; esac
    done
fi

LEGACY_REF=$(legacy_ref) || die "cannot resolve the legacy ref"
printf 'run %s: tier %s, legacy ref %s\n' "$RUNID" "$TIER" "$LEGACY_REF"
make_context
for t in "${targets[@]}"; do
    build "$t" || die "build of $t failed"
done

failed=()
for s in "${list[@]}"; do
    run_scenario "$s" "$(tag_of "${TARGET:-$(target_of "$s")}")" || failed+=("$s")
done
if [ "${#list[@]}" -gt 0 ]; then
    printf '\n%d of %d scenarios passed' $((${#list[@]} - ${#failed[@]})) "${#list[@]}"
    if [ "${#failed[@]}" -gt 0 ]; then
        printf '; failed: %s\n' "${failed[*]}"
        exit 1
    fi
    printf '\n'
fi
