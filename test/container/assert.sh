#!/usr/bin/env bash
# Assertion helpers for the container tests. Source this file.
# Every assertion records a result and continues, so one run surfaces all
# failures. Results are appended to the file named by ASSERT_RESULTS, so
# assertions made in subshells (checks run for another account's HOME) count
# too. assert_summary returns non-zero iff a hard assertion failed; soft
# assertions (WARN) and findings (NOTE) never fail the run.

: "${ASSERT_RESULTS:=/tmp/assert-results.$$}"
export ASSERT_RESULTS

_c_green=''; _c_red=''; _c_yellow=''; _c_reset=''
if [ -t 1 ]; then
    _c_green=$'\033[32m'; _c_red=$'\033[31m'; _c_yellow=$'\033[33m'; _c_reset=$'\033[0m'
fi

__assert_record() {
    printf '%s\t%s\n' "$1" "${2//$'\n'/ }" >>"$ASSERT_RESULTS"
}
_pass()     { __assert_record PASS "$1"; printf '  %sPASS%s  %s\n' "$_c_green" "$_c_reset" "$1"; }
_hardfail() { __assert_record FAIL "$1"; printf '  %sFAIL%s  %s\n' "$_c_red" "$_c_reset" "$1"; }
_softfail() { __assert_record WARN "$1"; printf '  %sWARN%s  %s (soft)\n' "$_c_yellow" "$_c_reset" "$1"; }

# finding TEXT — record an observation that needs a decision, not a failure.
finding() { __assert_record NOTE "$1"; printf '  %sNOTE%s  %s\n' "$_c_yellow" "$_c_reset" "$1"; }

# _result OK SOFT LABEL — pass when OK is 0, else fail hard or soft.
_result() {
    if [ "$1" = 0 ]; then _pass "$3"
    elif [ "$2" = soft ]; then _softfail "$3"
    else _hardfail "$3"; fi
}

# Prints the last lines (ASSERT_SHOW_LINES, default 15) of a captured output
# under a failed assertion.
__assert_show() {
    [ -s "$1" ] || return 0
    tail -n "${2:-${ASSERT_SHOW_LINES:-15}}" "$1" | sed 's/^/        | /'
}

group() { printf '\n=== %s ===\n' "$1"; }

# assert_cmd NAME [soft] — command is resolvable on PATH
assert_cmd() {
    local name=$1 soft=${2:-} path
    if path=$(command -v "$name" 2>/dev/null); then _pass "cmd: $name -> $path"
    else _result 1 "$soft" "cmd: $name not found"; fi
}

# assert_file PATH [soft] — path exists (file, dir, or a link that resolves)
assert_file() {
    local p=$1 soft=${2:-}
    if [ -e "$p" ]; then _pass "exists: $p"
    else _result 1 "$soft" "exists: $p (missing)"; fi
}

# assert_absent PATH [soft] — nothing at PATH, not even a dangling link
assert_absent() {
    local p=$1 soft=${2:-}
    if [ ! -e "$p" ] && [ ! -L "$p" ]; then _pass "absent: $p"
    else _result 1 "$soft" "absent: $p (present)"; fi
}

# assert_symlink LINK [WANT_SUBSTR] [soft] — LINK is a symlink whose resolved
# target contains WANT_SUBSTR (if given) and exists (no dangling links).
assert_symlink() {
    local link=$1 want=${2:-} soft=${3:-} tgt
    if [ -L "$link" ]; then
        tgt=$(readlink -f "$link" 2>/dev/null)
        # `[ -e "$link" ]` follows the link, so it is false for a dangling one.
        if { [ -z "$want" ] || [[ "$tgt" == *"$want"* ]]; } && [ -e "$link" ]; then
            _pass "symlink: $link -> $tgt"
        else
            _result 1 "$soft" "symlink: $link -> $tgt (want *$want* and an existing target)"
        fi
    else
        _result 1 "$soft" "symlink: $link missing"
    fi
}

# assert_rel_link LINK [WANT] — LINK is a symlink with a relative link text
# (raw readlink, which readlink -f would hide) that resolves; with WANT, it
# resolves to the same file as WANT.
assert_rel_link() {
    local link=$1 want=${2:-} text
    if [ ! -L "$link" ]; then _hardfail "relative link: $link is not a symlink"; return; fi
    text=$(readlink "$link")
    case $text in
        /*) _hardfail "relative link: $link -> $text is absolute"; return ;;
    esac
    if [ ! -e "$link" ]; then _hardfail "relative link: $link -> $text dangles"; return; fi
    if [ -n "$want" ] && [ "$(readlink -f "$link")" != "$(readlink -f "$want")" ]; then
        _hardfail "relative link: $link -> $text does not resolve to $want"
        return
    fi
    _pass "relative link: $link -> $text"
}

# assert_grep FILE PATTERN [label] — FILE is a regular file matching PATTERN (grep -E)
assert_grep() {
    local file=$1 pat=$2 label=${3:-$1 matches /$2/}
    if [ -f "$file" ] && grep -Eq -- "$pat" "$file"; then _pass "grep: $label"
    else _hardfail "grep: $label"; fi
}

# assert_no_grep FILE PATTERN [label] — FILE is a regular file without PATTERN
assert_no_grep() {
    local file=$1 pat=$2 label=${3:-$1 has no /$2/}
    if [ -f "$file" ] && ! grep -Eq -- "$pat" "$file"; then _pass "no grep: $label"
    else
        _hardfail "no grep: $label"
        [ -f "$file" ] && grep -En -- "$pat" "$file" | head -n 5 | sed 's/^/        | /'
    fi
}

# assert_line FILE LINE [label] — FILE has LINE as a whole line (fixed string)
assert_line() {
    local file=$1 line=$2 label=${3:-"$1 has line '$2'"}
    if [ -f "$file" ] && grep -qxF -- "$line" "$file"; then _pass "line: $label"
    else _hardfail "line: $label"; fi
}

# assert_func NAME — a bash function by that name is defined in this shell
assert_func() {
    if declare -F "$1" >/dev/null 2>&1; then _pass "func: $1 defined"
    else _hardfail "func: $1 not defined"; fi
}

# assert_eq LABEL WANT GOT
assert_eq() {
    if [ "$2" = "$3" ]; then _pass "$1"
    else _hardfail "$1 (want '$2', got '$3')"; fi
}

# assert_match LABEL ERE STRING
assert_match() {
    if [[ $3 =~ $2 ]]; then _pass "$1"
    else _hardfail "$1 ('$3' does not match /$2/)"; fi
}

# assert_prefix LABEL PREFIX STRING — STRING starts with PREFIX
assert_prefix() {
    if [ -n "$3" ] && [ "${3#"$2"}" != "$3" ]; then _pass "$1"
    else _hardfail "$1 (want prefix '$2', got '$3')"; fi
}

# assert_empty LABEL TEXT — TEXT is empty (shows it otherwise)
assert_empty() {
    if [ -z "$2" ]; then _pass "$1"
    else
        _hardfail "$1"
        printf '%s\n' "$2" | head -n 15 | sed 's/^/        | /'
    fi
}

__assert_out=/tmp/assert-out.$$

# assert_exit0[_soft] LABEL -- CMD... — run CMD, check exit 0
_run_exit0() {
    local kind=$1 label=$2 rc
    shift 2; [ "${1:-}" = -- ] && shift
    "$@" >"$__assert_out" 2>&1
    rc=$?
    if [ "$rc" = 0 ]; then _pass "exit0: $label"
    else _result 1 "$kind" "exit0: $label (exit $rc)"; __assert_show "$__assert_out"; fi
}
assert_exit0()      { _run_exit0 hard "$@"; }
assert_exit0_soft() { _run_exit0 soft "$@"; }

# assert_exit CODE LABEL -- CMD... — run CMD, check its exit status
assert_exit() {
    local want=$1 label=$2 rc
    shift 2; [ "${1:-}" = -- ] && shift
    "$@" >"$__assert_out" 2>&1
    rc=$?
    if [ "$rc" = "$want" ]; then _pass "exit $want: $label"
    else _hardfail "exit $want: $label (got $rc)"; __assert_show "$__assert_out"; fi
}

# assert_no_output LABEL -- CMD... — CMD writes nothing to stdout or stderr
assert_no_output() {
    local label=$1
    shift; [ "${1:-}" = -- ] && shift
    "$@" >"$__assert_out" 2>&1
    if [ ! -s "$__assert_out" ]; then _pass "no output: $label"
    else
        _hardfail "no output: $label ($(wc -c <"$__assert_out") bytes)"
        __assert_show "$__assert_out"
    fi
}

# assert_output_eq LABEL WANT -- CMD... — CMD's stdout equals WANT
assert_output_eq() {
    local label=$1 want=$2 got
    shift 2; [ "${1:-}" = -- ] && shift
    got=$("$@" 2>"$__assert_out")
    if [ "$got" = "$want" ]; then _pass "output: $label"
    else
        _hardfail "output: $label (want '$want', got '$got')"
        __assert_show "$__assert_out"
    fi
}

assert_summary() {
    local pass fail soft note
    pass=$(grep -c '^PASS' "$ASSERT_RESULTS" 2>/dev/null)
    fail=$(grep -c '^FAIL' "$ASSERT_RESULTS" 2>/dev/null)
    soft=$(grep -c '^WARN' "$ASSERT_RESULTS" 2>/dev/null)
    note=$(grep -c '^NOTE' "$ASSERT_RESULTS" 2>/dev/null)
    printf '\n----------------------------------------\n'
    printf 'PASS=%d  FAIL=%d  WARN(soft)=%d  NOTE=%d\n' "${pass:-0}" "${fail:-0}" "${soft:-0}" "${note:-0}"
    if [ "${note:-0}" -gt 0 ]; then
        printf 'FINDINGS:\n'
        sed -n 's/^NOTE\t/  - /p' "$ASSERT_RESULTS"
    fi
    if [ "${fail:-0}" -gt 0 ]; then
        printf '%sFAILED HARD ASSERTIONS:%s\n' "$_c_red" "$_c_reset"
        sed -n 's/^FAIL\t/  - /p' "$ASSERT_RESULTS"
        return 1
    fi
    printf '%sALL HARD ASSERTIONS PASSED%s\n' "$_c_green" "$_c_reset"
    return 0
}
