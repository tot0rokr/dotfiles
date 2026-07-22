#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HOME}"

EXCLUDE=(.git .gitignore)

# Entry-point files carry a per-host "Machine-specific settings below" section
# the user edits and does NOT commit. On update we refresh only the part ABOVE
# that marker (template + `source ~/.*.common`) and keep everything below it
# (their settings + secrets) byte-for-byte. Every other dotfile is copied as-is.
ENTRYPOINTS=(.bashrc .tmux.conf)
MARKER_RE='^# Machine-specific settings below'

# Whole-file machine-specific entry points: the ENTIRE file is the user's
# per-host config (no template/marker split — e.g. .wezterm.lua's SSH server
# registry). Place it on first install, but never overwrite an existing one.
KEEP_IF_EXISTS=(.wezterm.lua)

DRY_RUN=0
TS="$(date +%Y%m%d-%H%M%S)"

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run|-n] [--dest|-d DIR] [--exclude|-x NAME]... [DIR] [--help|-h]

Copy this repo's dotfiles into a home directory (default: $HOME).

Machine-specific files are protected from being clobbered on update:
  * .bashrc, .tmux.conf — their "# Machine-specific settings below" marker
    splits a shared template (above, refreshed from the repo) from your per-host
    settings (below, preserved as-is). A changed file is backed up to
    <file>.bak.<ts> before the template part is refreshed.
  * .wezterm.lua — the whole file is your per-host SSH registry, so it is placed
    only on first install and never overwritten (KEEP).
Every other dotfile is copied over (use --dry-run to preview).

  -d, --dest DIR  Install into DIR instead of $HOME. May also be given as a
                  bare positional argument. DIR is created if missing. Combine
                  with an `enter` shell to use DIR as an isolated $HOME.
  -n, --dry-run   Show what would change WITHOUT copying anything. For every
                  file that differs, prints a unified diff; '-' lines are the
                  destination's current content that would be overwritten
                  (lost), '+' lines are the incoming repo version. New files
                  are listed too.
  -x, --exclude NAME
                  Skip the top-level entry NAME for this run (repeatable), on
                  top of the always-excluded .git/.gitignore. NAME matches a
                  top-level file or directory by exact name, e.g.
                  `install.sh -x .vimrc -x .gitconfig`. For a one-off install
                  that leaves those two untouched. To protect a file on EVERY
                  run instead, add it to KEEP_IF_EXISTS in this script.
  -h, --help      Show this help and exit.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -d|--dest)    shift; DEST="${1:?--dest requires a directory}" ;;
        --dest=*)     DEST="${1#*=}" ;;
        -x|--exclude) shift; EXCLUDE+=("${1:?--exclude requires a name}") ;;
        --exclude=*)  EXCLUDE+=("${1#*=}") ;;
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

is_entrypoint() {
    local name="$1"
    for e in "${ENTRYPOINTS[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

is_keep_if_exists() {
    local name="$1"
    for e in "${KEEP_IF_EXISTS[@]}"; do
        [[ "$name" == "$e" ]] && return 0
    done
    return 1
}

# Echo the content install would write for entry-point SRC given current DST.
# Return codes: 0 = merge (repo part above the marker + DST part below it),
# 2 = first install (echo whole SRC), 3 = DST exists but has no marker (caller
# must leave it untouched — we won't clobber an unrecognized file).
compute_entrypoint() {
    local src="$1" dst="$2"
    [[ -e "$dst" ]]                 || { cat "$src"; return 2; }
    grep -qE "$MARKER_RE" "$src"    || { cat "$src"; return 2; }
    grep -qE "$MARKER_RE" "$dst"    || return 3
    sed "/$MARKER_RE/q"   "$src"    # repo lines through the marker (inclusive)
    sed "1,/$MARKER_RE/d" "$dst"    # DST lines after its marker (user's section)
}

backup_file() {
    cp -p "$1" "$1.bak.$TS"
    echo "  backed up $1 -> $1.bak.$TS"
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

# Real-run install for an entry-point file (marker-preserving).
install_entrypoint() {
    local src="$1" dst="$2" name="$3" content rc
    content="$(compute_entrypoint "$src" "$dst")" && rc=0 || rc=$?
    case $rc in
        2) cp -f "$src" "$dst"; echo "  placed $name (first install)" ;;
        3) echo "  SKIP $name — no machine-specific marker in $dst; left untouched (reconcile by hand)" ;;
        0) if printf '%s\n' "$content" | cmp -s - "$dst"; then
               echo "  $name already up to date"
           else
               backup_file "$dst"
               printf '%s\n' "$content" > "$dst"
               echo "  updated $name (template/common refreshed; your machine-specific section preserved)"
           fi ;;
    esac
}

# Dry-run preview for an entry-point file — mirrors install_entrypoint exactly.
preview_entrypoint() {
    local src="$1" dst="$2" name="$3" content rc
    content="$(compute_entrypoint "$src" "$dst")" && rc=0 || rc=$?
    case $rc in
        2) printf '  new       %s (first install)\n' "$name" ;;
        3) printf '  SKIP      %s (no marker in current file; would be left untouched)\n' "$name" ;;
        0) if printf '%s\n' "$content" | cmp -s - "$dst"; then
               : # identical: stay quiet
           else
               printf '  MERGE     %s (refresh above marker; your section below is preserved)\n' "$name"
               diff -u --label "current  $dst" --label "after install $dst (merged)" \
                   "$dst" <(printf '%s\n' "$content") | sed 's/^/    /' || true
           fi ;;
    esac
}

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "# dry run: previewing changes to $DEST"
else
    echo "# installing into $DEST"
fi
# EXCLUDE's first two entries are the always-on .git/.gitignore; anything past
# them came from --exclude, so surface it to confirm what this run skips.
if [[ ${#EXCLUDE[@]} -gt 2 ]]; then
    echo "# excluding (this run): ${EXCLUDE[*]:2}"
fi

shopt -s dotglob nullglob
for path in "$SRC"/.*; do
    name="$(basename "$path")"
    [[ "$name" == "." || "$name" == ".." ]] && continue
    is_excluded "$name" && continue

    echo "==> $name"
    if is_entrypoint "$name"; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            preview_entrypoint "$path" "$DEST/$name" "$name"
        else
            install_entrypoint "$path" "$DEST/$name" "$name"
        fi
    elif is_keep_if_exists "$name"; then
        if [[ -e "$DEST/$name" ]]; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                printf '  KEEP      %s (machine-specific; would be left untouched)\n' "$name"
            else
                echo "  KEEP $name (machine-specific; left untouched)"
            fi
        elif [[ "$DRY_RUN" -eq 1 ]]; then
            printf '  new       %s (first install)\n' "$name"
        else
            cp -f "$path" "$DEST/$name"
            echo "  placed $name (first install)"
        fi
    elif [[ "$DRY_RUN" -eq 1 ]]; then
        preview_entry "$path" "$name"
    else
        cp -rf "$path" "$DEST/"
    fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo
    echo "(dry run — nothing was copied. Re-run without --dry-run to apply.)"
fi
