#!/usr/bin/env bash
# env.bash properties (A30, DD §4): no output, no subprocess, idempotent,
# leaves the shell state alone, and builds PATH as specified (PLAN B1) for odd
# inputs. Source after assert.sh and tests.sh, then call check_a30_env_bash.

# The PATH env.bash should produce for INPUT (or "__unset__"): every
# occurrence of the wanted dirs dropped, then those prepended in order; other
# entries keep their order, empty ones included. The wanted dirs are the tool
# clone dirs in FIRST (those HOME has, in env.bash's order), then the four.
__a30_expected_path() {
    local home=$1 input=$2 first=${3-} want rest e out=
    want="${first:+$first:}$home/.local/opt/tmux/bin:$home/.local/bin:$home/.local/share/cargo/bin:$home/.local/share/fnm/aliases/default/bin"
    if [ "$input" = __unset__ ] || [ -z "$input" ]; then
        printf '%s' "$want"
        return
    fi
    rest=$input:
    while [ -n "$rest" ]; do
        e=${rest%%:*}
        rest=${rest#*:}
        case ":$want:" in
            *":$e:"*) ;;
            *) out+=":$e" ;;
        esac
    done
    printf '%s' "$want$out"
}

# __a30_path_case LABEL INPUT [FIRST] — sources env.bash twice from INPUT (a
# PATH value or __unset__) and compares both results with the specification.
__a30_path_case() {
    local label=$1 input=$2 tools=${3-} h=$T_WORK/a30-home out want first second
    out=$(env -i HOME="$h" USER="$T_USER" T_INPUT="$input" /bin/bash --norc --noprofile -c '
        if [ "$T_INPUT" = __unset__ ]; then unset PATH; else PATH=$T_INPUT; fi
        unset T_INPUT
        . "$1"; printf "%s\n" "$PATH"
        . "$1"; printf "%s\n" "$PATH"' a30 "$T_A30_ENV" 2>&1)
    want=$(__a30_expected_path "$h" "$input" "$tools")
    first=${out%%$'\n'*}
    second=${out#*$'\n'}
    assert_eq "A30 PATH from $label" "$want" "$first"
    assert_eq "A30 PATH from $label, sourced again" "$want" "$second"
}

check_a30_env_bash() {
    local env=$1 o=$T_WORK/a30 h=$T_WORK/a30-home f lvl
    T_A30_ENV=$env
    group "A30 env.bash properties"
    mkdir -p "$o" "$h"
    if [ ! -f "$env" ]; then
        _hardfail "A30 $env missing"
        return
    fi

    # env looks bash up in the PATH it sets, hence the absolute path.
    assert_no_output "A30 sourcing twice under set -u keeps PATH and prints nothing" -- \
        env -i HOME="$HOME" USER="$T_USER" PATH=/nonexistent /bin/bash --norc --noprofile -uc \
        '. "$1"; p=$PATH; . "$1"; [ "$p" = "$PATH" ] || { echo "PATH changed: $p -> $PATH"; exit 1; }' a30 "$env"

    # Shell state before and after, in an interactive shell (bind needs one).
    f=$o/state.bash
    printf '%s\n' \
        '__a30_state() { declare -p IFS; printf "flags=%s\n" "$-"; shopt -p; set -o; declare -F; alias; bind -p; trap -p; umask; }' \
        "__a30_state >$o/before 2>&1" \
        ". $env" \
        "__a30_state >$o/after 2>&1" \
        "compgen -v __dotfiles_ >$o/leftover" >"$f"
    env -i HOME="$h" USER="$T_USER" PATH="$BASE_PATH" TERM=xterm-256color \
        timeout 60 script -qec "bash --norc --noprofile -i -c '. $f'" /dev/null </dev/null >/dev/null 2>&1
    if [ -s "$o/before" ]; then
        assert_empty "A30 IFS, \$-, shopt, set -o, functions, aliases, bindings, traps, umask unchanged" \
            "$(diff "$o/before" "$o/after" 2>&1)"
        assert_empty "A30 no __dotfiles_ variables left behind" "$(cat "$o/leftover" 2>/dev/null)"
    else
        _hardfail "A30 the interactive state probe did not run"
    fi

    __a30_path_case "an unset PATH" __unset__
    __a30_path_case "an empty PATH" ''
    __a30_path_case "'::'" '::'
    __a30_path_case "a trailing ':'" '/usr/bin:/bin:'
    __a30_path_case "entries with '*' and spaces" '/opt/a b/bin:/opt/c*d:/usr/bin'
    __a30_path_case "the wanted dirs already present" \
        "/usr/bin:$h/.local/bin:/bin:$h/.local/opt/tmux/bin:$h/.local/bin"

    # Tool clone dirs lead only when they exist; fzf's also moves ahead of
    # a copy fzf.bash appended in a parent shell.
    mkdir -p "$h/.local/opt/bell-bash/bin" "$h/.local/opt/fzf/bin"
    __a30_path_case "the bell and fzf clones present" \
        "/usr/bin:/bin:$h/.local/opt/fzf/bin" \
        "$h/.local/opt/bell-bash/bin:$h/.local/opt/fzf/bin"

    # Nested login shells: the distro ~/.profile prepends ~/.local/bin after
    # ~/.bashrc each time; PATH must stop growing after the second level.
    cp /etc/skel/.profile "$h/.profile"
    printf '. "%s"\ncase $- in *i*) ;; *) return ;; esac\n' "$env" >"$h/.bashrc"
    mkdir -p "$h/.local/bin"
    printf '%s\n' \
        'printf "%s\n" "$PATH" >>"$T_A30_OUT"' \
        '[ "$1" -gt 1 ] && exec bash -l "$0" "$(($1 - 1))"' \
        'exit 0' >"$o/nest.bash"
    rm -f "$o/nest.out"
    env -i HOME="$h" USER="$T_USER" PATH="$BASE_PATH" T_A30_OUT="$o/nest.out" \
        bash -l "$o/nest.bash" 3 >/dev/null 2>&1
    lvl=$(wc -l <"$o/nest.out" 2>/dev/null)
    if [ "${lvl:-0}" = 3 ]; then
        assert_eq "A30 nested bash -l: no PATH growth from level 2 to 3" \
            "$(sed -n 2p "$o/nest.out")" "$(sed -n 3p "$o/nest.out")"
    else
        _hardfail "A30 nested bash -l ran ${lvl:-0} of 3 levels"
    fi

    # No process other than bash itself.
    env -i HOME="$h" USER="$T_USER" PATH="$BASE_PATH" strace -f -qq \
        -e trace=execve,clone,clone3,fork,vfork -o "$o/strace.log" \
        bash --norc --noprofile -c ". $env" >/dev/null 2>&1
    assert_eq "A30 strace: only bash's own execve, no fork or clone" \
        "1 execve" "$(grep -c . "$o/strace.log" 2>/dev/null) $(grep -o 'execve' "$o/strace.log" 2>/dev/null | head -n 1)"
}
