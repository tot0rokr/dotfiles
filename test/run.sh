#!/usr/bin/env bash
# Build and run the dotfiles bootstrap test in Docker. Exits with the test's
# status (0 = all hard assertions passed).
#
#   ./run.sh                # smoke tier, clones published main
#   ./run.sh --full         # full tier (runs bootstrap_user_tools; slow, ~15-40m)
#   ./run.sh --local        # test THIS working tree (bind-mounted) instead of cloning
#   ./run.sh --ref v1.2      # clone a specific branch/tag (remote mode)
#   ./run.sh --local --full  # full tier against the working tree
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$HERE/.." && pwd)

TIER=smoke
SOURCE=remote
REF=main

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --full)    TIER=full ;;
    --smoke)   TIER=smoke ;;
    --local)   SOURCE=local ;;
    --ref)     REF="${2:?--ref needs a value}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

run_user=0; [ "$TIER" = full ] && run_user=1

cd "$HERE"
echo "[build image]"
docker compose build

args=(--rm
  -e "RUN_USER_TOOLS=$run_user"
  -e "DOTFILES_SOURCE=$SOURCE"
  -e "DOTFILES_REF=$REF")
[ "$SOURCE" = local ] && args+=(-v "$REPO_ROOT:/mnt/dotfiles:ro")

echo "[run: tier=$TIER source=$SOURCE ref=$REF]"
exec docker compose run "${args[@]}" test
