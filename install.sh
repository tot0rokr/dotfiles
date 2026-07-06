#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}"

EXCLUDE=(.git .gitignore)

DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run|-n] [--dest|-d DIR] [DIR] [--help|-h]

Copy this repo's dotfiles into a home directory (default: $HOME).

  -d, --dest DIR  Install into DIR instead of $HOME. May also be given as a
                  bare positional argument. DIR is created if missing. Combine
                  with an `enter` shell to use DIR as an isolated $HOME.
  -n, --dry-run   Show what would change WITHOUT copying anything. For every
                  file that differs, prints a unified diff; '-' lines are the
                  destination's current content that would be overwritten
                  (lost), '+' lines are the incoming repo version. New files
                  are listed too.
  -h, --help      Show this help and exit.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -d|--dest)    shift; DEST="${1:?--dest requires a directory}" ;;
        --dest=*)     DEST="${1#*=}" ;;
        -h|--help)    usage; exit 0 ;;
        -*)           echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
        *)            DEST="$1" ;;
    esac
    shift
done

if [[ -z "$DEST" ]]; then
    echo "error: destination is empty." >&2
    exit 2
fi

# Create the destination on a real run so a fresh home can be populated.
if [[ "$DRY_RUN" -eq 0 && ! -d "$DEST" ]]; then
    mkdir -p "$DEST"
fi
# Normalise to an absolute path when it exists (needed for the SRC==DEST guard).
[[ -d "$DEST" ]] && DEST="$(cd "$DEST" && pwd)"

if [[ "$SRC" == "$DEST" ]]; then
    echo "error: destination equals the repo location ($SRC); source == destination, nothing to copy." >&2
    echo "       pick a different --dest, or clone the repo elsewhere." >&2
    exit 1
fi

is_excluded() {
    local name="$1"
    for e in "${EXCLUDE[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

# Dry-run helper: compare one incoming repo file against its counterpart in DEST.
# disp is the path relative to DEST (e.g. .config/nvim/init.vim).
diff_file() {
    local src="$1" dst="$2" disp="$3"
    if [[ ! -e "$dst" ]]; then
        printf '  new       %s\n' "$disp"
        return
    fi
    if cmp -s "$src" "$dst"; then
        return   # identical: stay quiet
    fi
    printf '  MODIFIED  %s\n' "$disp"
    # old = current file in DEST (what's there now), new = incoming repo version,
    # so '-' lines are lost and '+' lines are incoming.
    diff -u --label "current  $DEST/$disp" --label "incoming $DEST/$disp (from repo)" "$dst" "$src" \
        | sed 's/^/    /' || true
}

# Dry-run helper: walk every file cp would place for one top-level entry.
preview_entry() {
    local path="$1" name="$2" f rel
    if [[ -d "$path" ]]; then
        while IFS= read -r -d '' f; do
            rel="${f#"$path"/}"
            diff_file "$f" "$DEST/$name/$rel" "$name/$rel"
        done < <(find "$path" -type f -print0 | sort -z)
    else
        diff_file "$path" "$DEST/$name" "$name"
    fi
}

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "# dry run: previewing changes to $DEST"
else
    echo "# installing into $DEST"
fi

shopt -s dotglob nullglob
for path in "$SRC"/.*; do
    name="$(basename "$path")"
    [[ "$name" == "." || "$name" == ".." ]] && continue
    is_excluded "$name" && continue

    echo "==> $name"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        preview_entry "$path" "$name"
    else
        cp -rf "$path" "$DEST/"
    fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    echo "(dry run — nothing was copied. Re-run without --dry-run to apply.)"
fi
