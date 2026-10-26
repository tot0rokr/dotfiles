# dotfiles tests

Docker images and scenarios that install the dotfiles into clean accounts and
check the result: the XDG layout, the `dotfiles` CLI, the migration of old
copied installs, and every tool loading its config. Nothing runs on the host
except `run.sh`, which only drives docker, reads git and copies tracked files
into the work dir.

## Run it

```
~/.dotfiles/test/run.sh --work DIR [--tier lite|full] [--scenario LIST] [--target repo|repo-ro|tmux32] [--rebuild]
```

```bash
~/.dotfiles/test/run.sh --work /tmp/dotfiles-test                 # lite tier, every scenario
~/.dotfiles/test/run.sh --work /tmp/dotfiles-test --scenario s1-fresh,s6-cli
~/.dotfiles/test/run.sh --work /tmp/dotfiles-test --tier full     # s1, s2, s5 with every tool
~/.dotfiles/test/run.sh --work /tmp/dotfiles-test --target tmux32 # build one image only
```

- `--work DIR` (required) holds `logs/` (one build log per image, one log per
  scenario) and the temporary build context.
- `--tier lite` installs a subset of the tools (no cargo builds); `--tier full`
  runs the whole `dotfiles bootstrap user` and `bootstrap agents`.
- `--scenario LIST` takes comma-separated names from the scenario table
  below. Without it, lite runs all of them and full runs s1-fresh, s2-legacy
  and s5-live.
- `--target repo|repo-ro|tmux32` builds only that image and runs LIST (none
  by default) on it.
- `--rebuild` builds without the layer cache.
- Exit status 0 means every scenario passed. In a scenario log, `FAIL` lines
  fail the run; `WARN` (soft) lines and `NOTE` findings do not.

`GH_TOKEN`, when set, is passed to the build as the BuildKit secret `gh_token`
only (the bootstrap's GitHub API lookups); no container gets it at run time.
After every build and run, `run.sh` checks that the token appears in no log
and in no file or metadata of the image.

## Images

All tags are `dotfiles-xdg-test:*`, built from `test/Dockerfile` with a
context generated from `git ls-files` (ignored local files never reach the
daemon). New files must be whitelisted in `.gitignore` to be tested at all.

| stage | contents |
|---|---|
| base | ubuntu 24.04 (amd64), test packages, user `tester` (uid 1001) with passwordless sudo, vim built with XDG support |
| tools-lite | `dotfiles bootstrap system` and `bootstrap user --only` a subset; node 20 and zoxide 0.9.9 (the prompt hook order of real hosts) for the fnm and bell tests |
| tools-full | the full `bootstrap user` (cargo cache mounts) and `bootstrap agents` |
| editor | nvim and vim plugins, treesitter parsers and coc extensions (in `~/.config/coc`), from the editor config only; the build fails when one is missing |
| repo (`:lite`, `:full`) | the checkout at `~/.dotfiles` with new files staged, and the git baseline |
| repo-ro (`:ro-lite`) | the same checkout owned by root and read-only |
| tmux32 (`:tmux32`) | the static tmux 3.2 build, the oldest supported tmux |

The tool stages copy only `bin/dotfiles`, `lib/dotfiles/{core,bootstrap}.bash`
and `.config/bash/env.bash`, so other edits reuse the cached tools. They fail
when the bootstrap changes `~/.bashrc` or `~/.profile` or creates `~/.gitconfig`.

## Scenarios

| scenario | what it does |
|---|---|
| s0-static | old-path grep (A11), `bash -n`, `luac -p`, tmux parse checks (A32), env.bash properties (A30) |
| s1-fresh | fresh account: install, bootstrap through the common.bash wrappers, every tool loads (A01-A10, A12-A14, A16, A19-A21, A24 in full); the prompt hooks of non-login shells and bell's auto-trigger in live `bash -i` and `bash -l -i` shells, before and after a re-sourced `~/.bashrc` (A06); in full, claude is installed before the switcher and the fd ignore file hides the tool trees |
| s2-legacy | old layout from `LEGACY_REF` plus machine sections, debris and the old `~/.local/bin/noti`, `uninstall-legacy`, then `install` (A18); five account variants (a is applied under umask 002, c first previews an edited noti copy, e has a host-shaped machine section), and two accounts whose first apply fails part-way and is re-run |
| s3a-xdg-config | only `XDG_CONFIG_HOME` set; drift warning afterwards |
| s3b-xdg-all | all four `XDG_*` set; `bootstrap user --only fnm,pynvim` under them |
| s4-portable | `enter.sh` in checkout, tmux and DIR modes, from an account whose own `dotfiles` is on PATH (A22) |
| s5-live | live migration with running tmux servers, shells and nvims, a process in `~/dotfiles`, a linked worktree and the old `~/.local/bin/noti`; one old server is re-read with the new config before cleanup, which keeps `~/.tmux` for it; the last cleanup runs next to a non-dumpable process and a zombie (A23) |
| s6-cli | CLI semantics on fresh accounts (A15, A17, A25-A28), the resume and safety paths of `dotfiles migrate`, and the refusals of `bootstrap user` and `uninstall-legacy` while its node move is pending (A23, A28) |
| s7-readonly | install from a read-only checkout owned by root (A29) |
| s8-bootstrap | failure paths of `bootstrap user`: tmux replaces under a running server, failed final installs, an fzf clone without its binary, the claude and switcher order; downloads GitHub release files |
| tmux32 | tmux 3.2 loads the config, plugins, theme and status line |

`LEGACY_REF` is the commit before the one that deleted `.bashrc.common` (or
`main` until then); `run.sh` passes it to s2 and s5.

## Layout

```
test/
  run.sh, Dockerfile, README.md
  container/
    entrypoint.sh      prints what is under test, runs the scenario
    assert.sh          assertion helpers (results collected in a file)
    tests.sh           shared helpers and assertion groups (A01-A24)
    scenarios/         one script per scenario
    static/            old-path check: script, patterns, allow-list, self-test
    props/env-bash.sh  env.bash property checks (A30)
    build/             build-time scripts of the tool and editor stages
    fixtures/          fakes (claude, tmux 3.0a, a failing mv), editor probes,
                       wezterm stub, legacy machine sections and debris,
                       expect drivers
```

## Notes

- Old-path references outside legacy and migration code need an entry in
  `container/static/oldpath-allow.txt` (path, exact line, reason).
- Containers are named `dotfiles-xdg-<scenario>-<run id>` and labelled
  `dotfiles-xdg-test=1`; `run.sh` removes exactly the ones it started.
- tmux runs only inside containers; scenarios time out after 15 minutes
  (lite) or 45 minutes (full).
- The full tier hits GitHub release downloads and cargo, and s8-bootstrap
  release downloads; an occasional network flake is not a dotfiles bug.
