#!/usr/bin/env bash
# Container entrypoint (runs as tester): prints what is under test, then runs
# its arguments; test/run.sh passes `timeout LIMIT bash SCENARIO`. Without
# arguments it lists the scenarios.
set -o pipefail

if [ $# -eq 0 ]; then
    printf 'usage: docker run IMAGE timeout SECONDS bash /opt/dotfiles-test/scenarios/NAME.sh\n'
    printf 'scenarios:\n'
    ls /opt/dotfiles-test/scenarios
    exit 2
fi

printf '==================================================================\n'
printf ' dotfiles test container, %s\n' "$(date -u +%FT%TZ)"
printf '   tier: %s  user: %s (%s)  bash: %s\n' \
    "$(cat /opt/dotfiles-test/build-checks/tier 2>/dev/null)" "$(id -un)" "$(id -u)" "$BASH_VERSION"
printf '   checkout: %s at %s, new layout staged\n' "$HOME/.dotfiles" \
    "$(git -c safe.directory='*' -C "$HOME/.dotfiles" rev-parse --short HEAD 2>/dev/null)"
printf '   tmux: %s  vim: %s\n' "$("$HOME/.local/opt/tmux/bin/tmux" -V 2>/dev/null)" \
    "$(vim --version 2>/dev/null | head -n 1)"
printf '   LEGACY_REF: %s\n' "${LEGACY_REF:-<unset>}"
printf '   command: %s\n' "$*"
printf '==================================================================\n'

cd "$HOME" || exit 1
exec "$@"
