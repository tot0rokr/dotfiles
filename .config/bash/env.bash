# env.bash - environment for every bash, interactive or not (tracked in dotfiles).
# Sourced by the env block at the top of $HOME/.bashrc, ahead of the interactive
# guard, so non-interactive shells such as "ssh host cmd" get it too.
# Builtins only and no output: it runs for every ssh command, and output breaks
# scp/rsync/sftp. Safe to source repeatedly and under "set -u".
# cron and systemd units do not read it.
# A tmux server keeps the environment of the shell that started it, often a
# non-interactive "ssh host tmux attach", and hands it to what it runs without
# a shell (run-shell, new-window CMD), so variables commands need belong here.

# Desktop terminals inherit XDG_SESSION_TYPE and keep the system locale;
# ssh and tty shells get C.UTF-8.
case ${XDG_SESSION_TYPE-} in
    x11|wayland) ;;
    *) export LANG=C.UTF-8 ;;
esac

__dotfiles_c=${XDG_CONFIG_HOME:-$HOME/.config}
__dotfiles_d=${XDG_DATA_HOME:-$HOME/.local/share}
export CARGO_HOME="$__dotfiles_d/cargo"
export RUSTUP_HOME="$__dotfiles_d/rustup"
export FNM_DIR="$__dotfiles_d/fnm"
export npm_config_cache="${XDG_CACHE_HOME:-$HOME/.cache}/npm"
export INPUTRC="$__dotfiles_c/readline/inputrc"
export NOTI_CONFIG="$__dotfiles_c/noti/noti.conf"
export NOTI_PRESET="$__dotfiles_c/noti/noti.preset"
# starship ignores XDG_CONFIG_HOME.
export STARSHIP_CONFIG="$__dotfiles_c/starship.toml"
export LOCAL_BIN_PATH="$HOME/.local/bin"
export LOCAL_OPT_PATH="$HOME/.local/opt"
export LOCAL_SRC_PATH="$HOME/.local/src"
export LOCAL_STATE_PATH="${XDG_STATE_HOME:-$HOME/.local/state}"

# These dirs go first, in this order, and their other copies are dropped, so a
# second source leaves PATH unchanged. Tool clones lead when they exist; fzf's
# shell bindings and Vim plugin expect the clone's binary, not a host fzf. The
# user-local tmux wins over a distro one; the fnm default node comes last
# because interactive shells put fnm's per-shell dir in front of it
# (common.bash). Splitting with parameter expansion needs no subprocess and no
# IFS or globbing change.
__dotfiles_w=
for __dotfiles_e in "$HOME/.local/opt/bell-bash/bin" "$HOME/.local/opt/noti-bash/bin" \
    "$HOME/.lmstudio/bin" "$HOME/.local/opt/fzf/bin"; do
    if [ -d "$__dotfiles_e" ]; then
        __dotfiles_w=$__dotfiles_w$__dotfiles_e:
    fi
done
__dotfiles_w="$__dotfiles_w$HOME/.local/opt/tmux/bin:$HOME/.local/bin:$CARGO_HOME/bin:$FNM_DIR/aliases/default/bin"
__dotfiles_r=${PATH:+$PATH:}
__dotfiles_o=
while [ -n "$__dotfiles_r" ]; do
    __dotfiles_e=${__dotfiles_r%%:*}
    __dotfiles_r=${__dotfiles_r#*:}
    case ":$__dotfiles_w:" in
        *":$__dotfiles_e:"*) ;;
        *) __dotfiles_o=$__dotfiles_o:$__dotfiles_e ;;
    esac
done
export PATH="$__dotfiles_w$__dotfiles_o"
unset __dotfiles_c __dotfiles_d __dotfiles_w __dotfiles_r __dotfiles_e __dotfiles_o
