#!/usr/bin/env bash
# Minimal assertion helpers for the bootstrap test. Source this file.
# Every assertion records a result and CONTINUES (so one run surfaces all
# failures). Call assert_summary at the end — it returns non-zero iff any
# HARD assertion failed. Soft assertions (WARN) never fail the suite.

_ASSERT_PASS=0
_ASSERT_FAIL=0
_ASSERT_SOFT=0
_ASSERT_FAILED_NAMES=()

_c_green=''; _c_red=''; _c_yellow=''; _c_reset=''
if [ -t 1 ]; then _c_green=$'\033[32m'; _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_reset=$'\033[0m'; fi

_pass()     { _ASSERT_PASS=$((_ASSERT_PASS + 1)); printf '  %sPASS%s  %s\n' "$_c_green" "$_c_reset" "$1"; }
_hardfail() { _ASSERT_FAIL=$((_ASSERT_FAIL + 1)); _ASSERT_FAILED_NAMES+=("$1"); printf '  %sFAIL%s  %s\n' "$_c_red" "$_c_reset" "$1"; }
_softfail() { _ASSERT_SOFT=$((_ASSERT_SOFT + 1)); printf '  %sWARN%s  %s (soft)\n' "$_c_yellow" "$_c_reset" "$1"; }

group() { printf '\n=== %s ===\n' "$1"; }

# assert_cmd NAME [soft]  — command is resolvable on PATH
assert_cmd() {
  local name="$1" soft="${2:-}" path
  if path=$(command -v "$name" 2>/dev/null); then _pass "cmd: $name -> $path"
  elif [ "$soft" = soft ]; then _softfail "cmd: $name not found"
  else _hardfail "cmd: $name not found"; fi
}

# assert_file PATH [soft]  — path exists (file/dir/symlink)
assert_file() {
  local p="$1" soft="${2:-}"
  if [ -e "$p" ]; then _pass "file: $p"
  elif [ "$soft" = soft ]; then _softfail "file: $p missing"
  else _hardfail "file: $p missing"; fi
}

# assert_symlink LINK [WANT_SUBSTR] [soft]  — LINK is a symlink whose resolved
# target contains WANT_SUBSTR (if given) AND actually exists (no dangling links).
assert_symlink() {
  local link="$1" want="${2:-}" soft="${3:-}" tgt
  if [ -L "$link" ]; then
    tgt=$(readlink -f "$link" 2>/dev/null || true)
    # `[ -e "$link" ]` follows the link, so it is false for a dangling symlink.
    if { [ -z "$want" ] || [[ "$tgt" == *"$want"* ]]; } && [ -e "$link" ]; then _pass "symlink: $link -> $tgt"
    elif [ "$soft" = soft ]; then _softfail "symlink: $link -> $tgt (want *$want* + existing target)"
    else _hardfail "symlink: $link -> $tgt (want *$want* + existing target)"; fi
  elif [ "$soft" = soft ]; then _softfail "symlink: $link missing"
  else _hardfail "symlink: $link missing"; fi
}

# assert_grep FILE PATTERN [label]  — FILE is a regular file containing PATTERN
# (grep -E). Use instead of assert_file when mere existence is not proof (e.g. a
# skel-seeded default could satisfy existence).
assert_grep() {
  local file="$1" pat="$2" label="${3:-$file matches /$2/}"
  if [ -f "$file" ] && grep -Eq "$pat" "$file"; then _pass "grep: $label"
  else _hardfail "grep: $label"; fi
}

# assert_func NAME  — a bash function by that name is defined in this shell
assert_func() {
  if declare -F "$1" >/dev/null 2>&1; then _pass "func: $1 defined"
  else _hardfail "func: $1 not defined"; fi
}

# assert_exit0[_soft] LABEL -- CMD...  — run CMD, check exit 0
_run_exit0() {
  local kind="$1" label="$2"; shift 2; [ "${1:-}" = -- ] && shift
  if "$@" >/dev/null 2>&1; then _pass "exit0: $label"
  elif [ "$kind" = soft ]; then _softfail "exit0: $label (nonzero)"
  else _hardfail "exit0: $label (nonzero)"; fi
}
assert_exit0()      { _run_exit0 hard "$@"; }
assert_exit0_soft() { _run_exit0 soft "$@"; }

assert_summary() {
  printf '\n────────────────────────────────────────\n'
  printf 'PASS=%d  FAIL=%d  WARN(soft)=%d\n' "$_ASSERT_PASS" "$_ASSERT_FAIL" "$_ASSERT_SOFT"
  if [ "$_ASSERT_FAIL" -gt 0 ]; then
    printf '%sFAILED HARD ASSERTIONS:%s\n' "$_c_red" "$_c_reset"
    printf '  - %s\n' "${_ASSERT_FAILED_NAMES[@]}"
    return 1
  fi
  printf '%sALL HARD ASSERTIONS PASSED%s\n' "$_c_green" "$_c_reset"
  return 0
}
