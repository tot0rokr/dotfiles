#!/usr/bin/env bash
# Build-time tool layers (test/Dockerfile stages tools-lite and tools-full).
# Runs `dotfiles bootstrap` from the four files copied to /opt/dotfiles-bootstrap
# and fails when it changes ~/.bashrc or ~/.profile or creates ~/.gitconfig
# (A19). The hashes and the tier go to /opt/dotfiles-test/build-checks.
#
#   tools.sh lite     bootstrap system + `bootstrap user --only` LITE_TOOLS
#   tools.sh extras   test-only tools: node 20 (A12) and zoxide (no cargo here)
#   tools.sh full     the full `bootstrap user` and `bootstrap agents`
set -o pipefail

DOT=/opt/dotfiles-bootstrap/bin/dotfiles
CHECKS=/opt/dotfiles-test/build-checks
# gh: nvim's octo.nvim setup fails at every start without it (A04 wants silence).
LITE_TOOLS=neovim,tmux,fnm,fzf,fzf-tab-completion,jq,gh,starship,pynvim,vim-plug,btop,bell,noti
# Since 0.9.9 zoxide appends its prompt hook (0.9.8 prepended it), as on real
# hosts; A06 checks bell's timing with a hook after starship's.
ZOXIDE_VERSION=0.9.9

die() {
    printf 'tools.sh: %s\n' "$*" >&2
    exit 1
}

rc_hash() { sha256sum "$HOME/.bashrc" "$HOME/.profile"; }

step=${1:-}
case $step in
    lite | full) ;;
    extras)
        # shellcheck source=.config/bash/env.bash
        . /opt/dotfiles-bootstrap/.config/bash/env.bash
        fnm install 20 || die "fnm install 20 failed"
        curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v$ZOXIDE_VERSION/zoxide-$ZOXIDE_VERSION-x86_64-unknown-linux-musl.tar.gz" |
            tar -xz -C "$HOME/.local/bin" zoxide || die "zoxide download failed"
        exit 0
        ;;
    *) die "usage: tools.sh lite|extras|full" ;;
esac

rc_hash >"$CHECKS/rc-$step.before" || die "cannot hash ~/.bashrc and ~/.profile"

case $step in
    lite)
        if ! "$DOT" bootstrap system; then
            # The WezTerm apt repository flakes; what the tests need is checked below.
            printf 'tools.sh: bootstrap system failed; checking the packages the tests need\n' >&2
        fi
        for c in git curl wget gcc make python3 unzip; do
            command -v "$c" >/dev/null || die "bootstrap system did not provide $c"
        done
        python3 -c 'import ensurepip, venv' || die "bootstrap system did not provide python3-venv"
        "$DOT" bootstrap user --only "$LITE_TOOLS" || die "bootstrap user --only $LITE_TOOLS failed"
        printf '%s\n' "$LITE_TOOLS" >"$CHECKS/lite-tools"
        ;;
    full)
        # The lite tier's release binary would make cargo skip zoxide (A24).
        rm -f "$HOME/.local/bin/zoxide"
        # Failures here are reported by A24 at run time rather than stopping the
        # build: one flaky download must not block every full-tier scenario.
        "$DOT" bootstrap user
        printf '%s\n' "$?" >"$CHECKS/bootstrap-user-full.rc"
        "$DOT" bootstrap agents
        printf '%s\n' "$?" >"$CHECKS/bootstrap-agents.rc"
        ;;
esac

rc_hash >"$CHECKS/rc-$step.after" || die "cannot hash ~/.bashrc and ~/.profile"
cmp -s "$CHECKS/rc-$step.before" "$CHECKS/rc-$step.after" ||
    die "bootstrap changed ~/.bashrc or ~/.profile: $(diff "$CHECKS/rc-$step.before" "$CHECKS/rc-$step.after")"
[ ! -e "$HOME/.gitconfig" ] || die "bootstrap created ~/.gitconfig"
printf '%s\n' "$step" >"$CHECKS/tier"
