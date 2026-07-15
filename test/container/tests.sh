#!/usr/bin/env bash
# Runs inside the container as the `tester` user, AFTER entrypoint.sh has run
# install.sh to populate $HOME. Sources .bashrc.common, runs the bootstrap
# functions in order, and asserts the results. No `set -e/-u` on purpose:
# .bashrc.common references may be unset and bootstrap functions may return
# nonzero for individual tools — the assert lib records outcomes and continues.
set -o pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=assert.sh
source "$HERE/assert.sh"

LOGDIR=/tmp/bootstrap-logs
mkdir -p "$LOGDIR"
RUN_USER_TOOLS=${RUN_USER_TOOLS:-0}

# ---------------------------------------------------------------------------
group "install: dotfiles placed + bootstrap functions defined"
# Content-check, not mere existence: ubuntu's /etc/skel seeds a default ~/.bashrc,
# so `[ -e ~/.bashrc ]` would pass even if install.sh placed nothing. The repo's
# .bashrc sources .bashrc.common — the skel default does not.
assert_grep "$HOME/.bashrc" 'bashrc\.common' '~/.bashrc is the repo copy (sources .bashrc.common)'
assert_file "$HOME/.bashrc.common"
# shellcheck disable=SC1090,SC1091
source "$HOME/.bashrc.common" 2>/dev/null || true
assert_func bootstrap_system_tools
assert_func bootstrap_user_tools
assert_func bootstrap_agents

# ---------------------------------------------------------------------------
group "system: bootstrap_system_tools (sudo apt)"
echo "  [running bootstrap_system_tools ... log: $LOGDIR/system.log]"
bootstrap_system_tools >"$LOGDIR/system.log" 2>&1 || {
  echo "  (returned nonzero — tail:)"; tail -n 15 "$LOGDIR/system.log" | sed 's/^/    /'
}
# NOTE: git and curl are image prerequisites (the Dockerfile pre-installs them
# so the clone/bootstrap can run at all), so asserting them proves nothing about
# bootstrap_system_tools — check only packages it UNIQUELY provides.
for c in wget gcc make cscope unzip ruby python3; do assert_cmd "$c"; done
assert_cmd ctags          # provided by universal-ctags
assert_cmd wezterm soft   # apt.fury.io repo can flake; not core

# ---------------------------------------------------------------------------
group "agents: bootstrap_agents (clone + install.py + doctor.sh)"
echo "  [running bootstrap_agents ... log: $LOGDIR/agents.log]"
bootstrap_agents >"$LOGDIR/agents.log" 2>&1 || true
assert_file    "$HOME/agents/scripts/install.py"
assert_symlink "$HOME/.claude"  "/agents/claude"
assert_symlink "$HOME/.agents"  "/agents/universal"
assert_symlink "$HOME/.codex"   "/agents/codex"   soft
assert_symlink "$HOME/.gemini"  "/agents/gemini"  soft
# doctor.sh is the agents repo's own health check — soft (a known codex/config.toml
# issue there must not mask a successful dotfiles bootstrap).
assert_exit0_soft "agents doctor.sh" -- bash "$HOME/agents/scripts/doctor.sh"

# ---------------------------------------------------------------------------
if [ "$RUN_USER_TOOLS" = 1 ]; then
  group "user: bootstrap_user_tools (~/.local, cargo builds — slow)"
  echo "  [running bootstrap_user_tools ... log: $LOGDIR/user.log]"
  bootstrap_user_tools >"$LOGDIR/user.log" 2>&1 || {
    echo "  (returned nonzero — tail:)"; tail -n 15 "$LOGDIR/user.log" | sed 's/^/    /'
  }
  # Make the freshly installed tools resolvable for `command -v`.
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.fzf/bin:$PATH"

  for c in nvim jq lazygit lazydocker delta gdu up fzf starship clangd btop nnn tmux; do assert_cmd "$c"; done
  for c in fd bat rg dust eza hyperfine difft tldr choose zoxide; do assert_cmd "$c"; done
  assert_cmd cargo
  assert_cmd rustc
  assert_file "$HOME/.nvm/nvm.sh"
  if ls "$HOME"/.nvm/versions/node/*/bin/node >/dev/null 2>&1; then
    _pass "cmd: node (nvm-installed)"
  else
    _hardfail "cmd: node (nvm-installed) not found"
  fi
  assert_file "$HOME/.local/opt/bell-bash/bin/bell-send"
  assert_file "$HOME/.local/opt/noti-bash/bin/noti"
else
  group "user: SKIPPED (RUN_USER_TOOLS=0 — smoke tier)"
  echo "  run.sh --full  exercises bootstrap_user_tools (nvim, cargo tools, ...)"
fi

# ---------------------------------------------------------------------------
assert_summary
