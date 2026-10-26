#!/usr/bin/env bash
# s7-readonly: the checkout is owned by root and read-only (image
# dotfiles-xdg-test:ro-<tier>, A29). install must work through
# safe.directory and leave the checkout exactly as it was.
set -o pipefail
# shellcheck source=test/container/assert.sh
. /opt/dotfiles-test/assert.sh
# shellcheck source=test/container/tests.sh
. /opt/dotfiles-test/tests.sh
t_init s7-readonly

group "A29 read-only checkout owned by another user"
assert_eq "the checkout is owned by root" root "$(stat -c %U "$T_REPO")"
if [ -w "$T_REPO" ] || [ -w "$T_REPO/.git" ]; then _hardfail "the checkout is writable"
else _pass "the checkout is read-only"; fi
m=$(t_marker)
ASSERT_SHOW_LINES=40 assert_exit0 "A29 install.sh --yes" -- t_env "$T_REPO/install.sh" --yes
check_layout
assert_empty "A29 nothing in the checkout changed" "$(find "$T_REPO" -newer "$m" -print)"
assert_empty "A29 git status equals the image baseline" \
    "$(diff "$T_DIR/baseline/status.txt" <(t_git -C "$T_REPO" status --porcelain 2>&1))"
check_a02_noninteractive
check_a16_silence

assert_summary
