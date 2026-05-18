#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}"

EXCLUDE=(.git .gitignore)

is_excluded() {
    local name="$1"
    for e in "${EXCLUDE[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

shopt -s dotglob nullglob
for path in "$SRC"/.*; do
    name="$(basename "$path")"
    [[ "$name" == "." || "$name" == ".." ]] && continue
    is_excluded "$name" && continue

    echo "==> $name"
    cp -rf "$path" "$DEST/"
done
