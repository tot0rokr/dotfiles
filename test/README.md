# dotfiles bootstrap test

Spins up a clean Ubuntu container, obtains the dotfiles, runs `install.sh` +
the bootstrap functions, and asserts the result. Repeatable, self-contained,
no host pollution — so bootstrap regressions get caught without manual testing.

## Run it

```bash
test/run.sh            # smoke tier (fast, ~3-5 min): install + system + agents
test/run.sh --full     # full tier (slow, ~15-40 min): + bootstrap_user_tools
test/run.sh --local    # test THIS working tree instead of cloning main
test/run.sh --ref BR   # clone a specific branch/tag
```

Exit code is 0 iff every **hard** assertion passed. `WARN (soft)` lines never
fail the run — they flag things that are allowed to be flaky or are another
repo's concern (e.g. the WezTerm apt repo, the agents repo's own `doctor.sh`).

## What it checks

| Group | After | Asserts (hard) |
|-------|-------|----------------|
| install | `install.sh --dest $HOME` | `~/.bashrc[.common]` present; bootstrap funcs defined |
| system | `bootstrap_system_tools` | `git curl wget gcc make ctags cscope unzip ruby python3` |
| agents | `bootstrap_agents` | `~/.claude` & `~/.agents` symlinks into `~/agents`; `install.py` OK |
| user (full only) | `bootstrap_user_tools` | `nvim jq lazygit … fzf`, cargo tools (`fd bat rg …`), `cargo/rustc`, nvm node, bell/noti |

Soft checks: `wezterm`, `~/.codex`/`~/.gemini` symlinks, agents `doctor.sh`.

## Layout

```
test/
  run.sh                 host entry point (build + run; sets tier / source)
  Dockerfile             ubuntu:24.04 amd64, non-root `tester` + passwordless sudo
  docker-compose.yml     the `test` service (env-driven)
  container/
    entrypoint.sh        obtain dotfiles → install.sh → tests.sh
    tests.sh             runs the bootstraps, groups the assertions
    assert.sh            tiny assertion helpers (collect-all, exit 1 on hard fail)
```

## Notes

- amd64 is pinned (clangd + static nnn are x86_64-only in the bootstrap).
- The full tier compiles ~10 Rust tools from source and hits the unauthenticated
  GitHub API a handful of times (60 req/hr/IP) — an occasional rate-limit flake
  on repeated full runs is expected, not a bootstrap bug.
- `--local` bind-mounts the repo read-only; `install.sh` only reads from it.
