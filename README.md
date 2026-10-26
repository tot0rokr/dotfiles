# Integrated Bash Environment

Linux(Ubuntu/Debian)용 bash, tmux, git, vim/nvim, wezterm 설정과 도구 설치 스크립트. repo는 `~/.dotfiles`에 두고 설정은 XDG 경로에 상대 심링크로 연결한다. `$HOME` 최상위에는 repo 파일을 두지 않고, 설치는 기존 파일을 덮어쓰거나 합치거나 `.bak` 파일을 흩뿌리지 않는다.

이 문서의 `~/.config`, `~/.local/share`, `~/.local/state`, `~/.cache`는 각각 `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`이 설정돼 있으면 그 값을 뜻한다.

## 설치

### 홈에 적용

```bash
git clone https://github.com/tot0rokr/dotfiles ~/.dotfiles
~/.dotfiles/install.sh   # = ~/.dotfiles/bin/dotfiles install
exec bash
```

- install은 먼저 전체 계획을 계산한다: 새 링크, 이미 맞는 링크, 충돌, 만들 로컬 진입 파일과 관리 블록, 만들 디렉터리.
- 충돌마다 묻는다: `r` replace(백업 후 링크), `k` keep(링크하지 않고 기록), `d` diff 보기, `R` 남은 것 모두 replace, `K` 남은 것 모두 keep, `c` 취소.
- 답이 다 모이면 요약을 보여 주고 최종 확인을 받아 한 번에 적용한다. 중간에 취소하면 아무것도 바뀌지 않는다.
- keep으로 답한 파일은 다시 묻지 않고 `dotfiles status`에 표시된다.
- TTY가 없으면(파이프, Docker) 바꿀 것이 있을 때 계획만 출력하고 exit 3으로 끝난다. 충돌이 있으면 `--replace-all` 또는 `--keep-all`, 충돌 없이 쓸 것만 있으면 `--yes`로 진행한다. `--dry-run`은 계획만 보여 준다.
- 백업은 `~/.local/state/dotfiles/backup/<시각>/` 한 곳에만 생긴다.
- 설치 후에는 `~/.local/bin/dotfiles`(상대 링크)로 `dotfiles` 명령을 쓴다.
- 새 계정은 이어서 `dotfiles bootstrap user`로 도구를 설치한다. 그 전에는 fzf clone이 없어 셸이 시작할 때 오류가 난다([한계](#한계) 참고).
- 폰트 링크가 바뀌면 `fc-cache`를 실행한다. PATH의 tmux가 3.2 미만이면 경고한다.
- 링크 대상의 부모가 다른 곳을 가리키는 심링크면(예: `~/.config/nvim` → 다른 repo) 아무것도 하지 않고 멈춘다.
- `~/.config`, `~/.local/share`, `~/.local/bin`이 `XDG_*` 값이나 심링크를 통해 repo 안을 가리키면 거부한다(exit 5). 추적 파일이 자기 자신을 가리키는 링크로 바뀌기 때문이다.
- 옛 복사 방식 설치가 남아 있거나 `~/.gitconfig`, `~/.tmux.conf`가 있으면 거부하고 `dotfiles uninstall-legacy`를 안내한다. [옛 레이아웃에서 옮기기](#옛-레이아웃에서-옮기기) 참고.

### 휴대용 HOME (enter.sh)

공유 계정이나 임시 서버처럼 계정 설정을 건드리지 않을 때 쓴다. 아무것도 링크하지 않고 `$HOME`과 `XDG_*`만 이 체크아웃으로 돌린다. 되돌리기는 `rm -rf ~/.myhome` 하나다.

```bash
git clone https://github.com/tot0rokr/dotfiles ~/.myhome
~/.myhome/enter.sh                 # 인터랙티브 진입 (exit로 원래 셸 복귀)
~/.myhome/enter.sh tmux            # tmux로 바로 (전용 소켓)
ssh host -t '~/.myhome/enter.sh'   # SSH 접속 즉시 내 환경
~/.myhome/enter.sh ~/box           # ~/box를 HOME으로 쓰는 하위 셸
```

- 진입할 때 체크아웃 안에 로컬 진입 파일이 없으면 만든다: `.bashrc`, `.profile`(tmux pane은 로그인 셸), `.config/git/config`, `.config/tmux/tmux.conf`. 모두 `.gitignore`가 무시한다.
- 도구, 캐시, 플러그인, 상태 파일도 체크아웃 안(`.local`, `.cache`)에 생기고 `.gitignore`가 무시한다.
- `tmux` 모드는 전용 소켓(`portable-<디렉터리 이름>`)과 `.config/tmux/tmux.conf`를 쓴다. 체크아웃에 `.local/opt/tmux/bin/tmux`가 있으면 그것을 쓰고, tmux가 3.2 미만이면 경고한다.
- `DIR` 모드는 DIR에 설치 기록(`DIR/.local/state/dotfiles/manifest.tsv`)이 없으면 묻고, `HOME=DIR`로 인터랙티브 `dotfiles install`을 실행한다. 충돌 질문과 옛 레이아웃 거부가 그대로 적용된다.
- 휴대용 모드에서 `install`, `uninstall`, `uninstall-legacy`, `migrate`는 거부한다. `update`는 fetch와 merge만 하고, `bootstrap`은 휴대용 HOME 안에 설치하고(`bootstrap_user_tools` 또는 `~/.myhome/bin/dotfiles bootstrap user`), `status`는 그대로 동작한다.
- 체크아웃에 진입하면(`enter.sh`, `enter.sh tmux`) 체크아웃의 `bin/`이 PATH 맨 앞에 오므로 `dotfiles`는 그 체크아웃의 CLI다.
- `DIR` 모드(예: `enter.sh ~`)에서 `update`와 거부한 명령은 안내를 출력한다. DIR의 링크를 갱신하려면 그 셸에서 `env -u DOTFILES_PORTABLE dotfiles install`을 실행한다. `enter.sh ~`처럼 DIR이 원래 HOME이면 진입 밖에서 실행해도 된다.
- `$USER`, `whoami`, `id`, `~다른유저` 확장, `sudo`(HOME 리셋)는 여전히 실제 계정을 가리킨다. HOME은 홈을 찾는 위치만 바꾸며 chroot가 아니다. repo의 `.git/config`처럼 더 구체적인 설정은 전역 git 설정보다 우선한다.
- 옛 휴대용 체크아웃(추적되던 `.bashrc`, `.gitconfig`, `.tmux.conf`를 쓰던 것)은 enter.sh가 경고만 한다. 그 파일을 고쳐 썼다면 `git pull`이 거부하므로, 고친 내용을 따로 보관하고 되돌린 뒤 pull하고, 다시 진입해 새 진입 파일의 로컬 구역으로 옮긴다.

### 도구 설치 (bootstrap)

```bash
dotfiles bootstrap system   # sudo apt: build-essential, git, python3, ctags, wezterm 등 (root 필요)
dotfiles bootstrap user     # 사용자 도구: nvim, fnm, fzf, rg, bat, eza, starship, lazygit, gh, tmux, bell, noti, claude CLI 등 (root 불필요, cargo 빌드로 느림)
dotfiles bootstrap agents   # ~/agents: Claude/Codex/OpenCode/Gemini 하네스, 없으면 claude CLI
```

- 예전 함수 `bootstrap_system_tools`, `bootstrap_user_tools`, `bootstrap_agents`도 `common.bash`에 한 줄 wrapper로 남아 `dotfiles bootstrap system|user|agents`를 인자와 함께 실행한다. `common.bash`가 들어 있는 repo의 `bin/dotfiles`(휴대용 체크아웃이면 그 체크아웃의 것)를 부르고, 그것이 없으면 PATH의 `dotfiles`를 부른다.
- bootstrap의 설치기는 `~/.bashrc`, `~/.profile` 같은 rc 파일을 고치지 않는다. 도구 경로와 PATH는 `env.bash`가 정한다.
- bell과 noti는 clone만 하므로 `~/.claude`에 쓰지 않는다. `~/.claude`에 쓰는 것은 다른 프로젝트의 설치기다.
  - claude-account-switcher 설치기는 statusLine이 아직 자기 sensor(`claude-auto-statusline`)를 거치지 않으면 `~/.claude/settings.json`을 고친다. 원본은 같은 디렉터리의 `settings.json.pre-claude-auto.<시각>.bak`으로 남는다.
  - Claude Code CLI 설치기는 `~/.claude/downloads`에 내려받고, 이어서 실행하는 `claude install`이 `~/.claude/backups`와 `~/.claude/sessions`를 만든다.
  - `bootstrap agents`가 실행하는 agents 하네스 설치기는 `~/.claude` 같은 설정 디렉터리를 `~/agents`로의 링크로 바꾼다.
- `GH_TOKEN` 또는 `GITHUB_TOKEN`이 있으면 GitHub API의 릴리스 조회에만 쓴다(없으면 시간당 60회 제한). GitHub가 토큰을 거부하면(HTTP 401, 예: 만료된 토큰이나 다른 호스트용 토큰) 알림을 출력하고 토큰 없이 다시 조회한다. bootstrap은 시작할 때 두 변수를 환경에서 지우므로 어떤 설치기도 토큰을 보지 못한다.
- `bootstrap user`는 Claude Code CLI(`claude`)가 없으면 설치한다. `nvm`은 더 이상 설치하지 않는다([node (fnm)](#node-fnm) 참고).
- 옛 bootstrap이 만든 `~/.local/bin/{nvim,tmux,btop}` 절대 링크가 `~/.local/opt`의 같은 설치를 가리키면 상대 링크로 바꾼다.
- 옛 레이아웃이 남아 있거나(exit 4) `dotfiles migrate tools`가 아직 필요하면(exit 5) `bootstrap user`는 거부한다.
- `bootstrap user --only NAME[,NAME...] [--force]`는 일부 도구만 (다시) 설치하는 내부·테스트용 옵션이다. 적은 순서와 상관없이 아래 이름 순서대로 실행한다.
  - 이름: `neovim fnm vim-plug rustup cargo-tools tldr starship jq lazygit gh gh-dash lazydocker delta gdu up fzf fzf-tab-completion pynvim clangd btop nnn tmux bell noti claude switcher`.
  - `--force`는 `neovim`(최신 릴리스로 다시 설치)과 `tmux`(고정한 버전으로 다시 설치)에만 적용된다.
  - static tmux 버전은 환경변수 `TMUX_STATIC_TAG`(x86_64, 기본 `v3.7b`)와 `TMUX_STATIC_TAG_ARM64`(arm64, 기본 `v3.6b`)로 정한다. 예: `TMUX_STATIC_TAG=v3.2 dotfiles bootstrap user --only tmux --force`.

| 도구                                     | 위치                                                                                   |
| ---------------------------------------- | -------------------------------------------------------------------------------------- |
| nvim, tmux, btop, lazygit, gh, delta 등  | `~/.local/opt`, `~/.local/bin`                                                         |
| rustup, cargo                            | `~/.local/share/rustup`, `~/.local/share/cargo` (`--no-modify-path`)                   |
| cargo 도구 (rg, fd, bat, eza, zoxide 등) | `~/.local/share/cargo/bin`                                                             |
| node                                     | fnm: 바이너리 `~/.local/opt/fnm`, 링크 `~/.local/bin/fnm`, 데이터 `~/.local/share/fnm` |
| npm cache                                | `~/.cache/npm`                                                                         |
| fzf, fzf-tab-completion                  | `~/.local/opt/`                                                                        |
| pynvim                                   | `~/.local/share/nvim/venv`                                                             |
| vim-plug, vim 플러그인                   | `~/.local/share/vim/`                                                                  |
| TPM, tmux 플러그인                       | `~/.local/share/tmux/plugins` (tmux 첫 실행 때 받는다)                                 |
| bell-bash, noti-bash                     | `~/.local/opt/` (clone과 pull만)                                                       |

### 업데이트

```bash
dotfiles update
```

- `git fetch` → 들어올 커밋과 diffstat 표시 → 바뀐 셸 파일에 `bash -n`(실패하면 merge 전에 멈춤) → 확인 → `git merge --ff-only` → 다시 링크.
- 다시 링크할 때 새 파일은 링크하고, repo에서 지워진 파일의 끊어진 링크는 정리한다. 충돌은 install과 같은 규칙을 따른다.
- 로컬 수정이 merge를 막으면 그 파일 목록을 보여 주고 멈춘다.
- TTY가 없으면 `--yes`가 필요하다. 다시 링크할 때의 충돌은 `--replace-all` 또는 `--keep-all`로 정한다(둘 다 `--yes`를 포함한다).
- 휴대용 모드에서는 fetch와 merge만 하고 다시 링크하지 않는다. `DIR` 모드에서는 링크를 갱신하는 명령(`env -u DOTFILES_PORTABLE dotfiles install`)을 안내한다.

## dotfiles 명령

| 명령               | 옵션                                                                                                | 하는 일                                      |
| ------------------ | --------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `install`          | `--yes`, `--replace-all` 또는 `--keep-all`, `--dry-run`                                             | 링크, 로컬 진입 파일, 상태 디렉터리를 만든다 |
| `update`           | `--yes`, `--replace-all` 또는 `--keep-all`                                                          | fetch, 검토, ff-only merge, 다시 링크        |
| `status`           | —                                                                                                   | 상태 점검 (읽기 전용)                        |
| `uninstall`        | —                                                                                                   | 관리 블록과 manifest 링크만 지운다           |
| `uninstall-legacy` | `--dry-run`, `--yes`, `--accept-dropped-edits`, `--replace-all` 또는 `--keep-all`                   | 옛 복사 방식 정리와 이전                     |
| `bootstrap system` | —                                                                                                   | apt 패키지 (sudo)                            |
| `bootstrap user`   | `--only NAME[,NAME...]`, `--force`                                                                  | 사용자 도구 (root 불필요)                    |
| `bootstrap agents` | —                                                                                                   | agents 하네스와 claude CLI                   |
| `migrate STEP`     | `--yes`, `--dry-run` (`all`은 `--accept-dropped-edits`, `--replace-all` 또는 `--keep-all`도 받는다) | 실행 중인 옛 계정 이전                       |

- `dotfiles --help`는 명령 목록을, `dotfiles <명령> --help`는 그 명령의 옵션을 보여 준다.
- `install`, `update`, `uninstall-legacy`, `migrate`는 TTY가 없을 때 `--yes`(충돌이 있으면 `--replace-all` 또는 `--keep-all`)가 없으면 아무것도 바꾸지 않고 exit 3으로 끝난다. `uninstall`은 묻지 않는다.
- `migrate`의 STEP은 `repo`, `tools`, `nvim-save`, `nvim-state`, `nvim-restore`, `history`, `cleanup`, `all`이다. [실행 중인 계정 옮기기](#실행-중인-계정-옮기기) 참고.

### status와 uninstall

`dotfiles status`는 아무것도 쓰지 않고 다음을 보고한다.

- repo의 수정된 파일, 디렉터리째 링크한 `~/.config/{bash,fzf,readline}` 안의 추적되지 않는 파일
- 빠졌거나 끊어졌거나 다른 곳을 가리키는 링크, keep한 파일, 끝나지 않은 실행
- install 때와 달라진 `XDG_*` 값, 상대 경로인 `XDG_*`, tmux 버전
- 옛 bootstrap이 남긴 `~/.claude/skills/{bell,noti}` 링크와 `~/.claude/settings.json`의 bell hook, `~/.bashrc`의 `alias claude=` (경고만 하고 지우지 않는다)
- 옛 레이아웃 잔재, `~/.vimrc`, `~/.wezterm.lua` 같은 shadow 파일, 다시 생긴 `~/.bash_history`(`dotfiles migrate history` 안내)
- 남아 있는 `~/.npm`, `~/.tmux`, `~/.nvm`과 호환 링크
- `~/.local/state/fnm_multishells` 아래 fnm 셸별 디렉터리 개수
- 옛 위치 `~/dotfiles`에 있는 repo(`dotfiles migrate repo` 안내)와 아직 옮기지 않은 도구 디렉터리(`dotfiles migrate tools` 안내)
- 진입 파일: 없거나 심링크인 것, 관리 블록이 빠졌거나 깨진 것, 관리 블록 없이 남긴(`unmanaged`) wezterm 진입 파일

`dotfiles uninstall`은 옵션이 없고 묻지 않는다. `HOME`이나 `XDG_STATE_HOME`이 install 때와 다르면 아무것도 바꾸지 않고 거부한다(exit 5). manifest가 install이 쓴 상태 디렉터리에 있기 때문이다. 지울 관리 블록과 링크를 출력한 뒤 관리 블록을 먼저 지우고, manifest에 있으면서 아직 repo를 가리키는 링크를 지운다. 그 밖의 파일은 건드리지 않고 자동으로 복원하지도 않는다. 끝나면 백업에 남아 있는 파일을 되돌리는 명령(예: install이 백업한 배포판 `~/.bashrc`)을 출력한다.

### 종료 코드

| 코드 | 뜻                                                             |
| ---- | -------------------------------------------------------------- |
| 0    | 성공                                                           |
| 1    | 오류                                                           |
| 2    | 잘못된 사용법                                                  |
| 3    | 결정이나 동의가 필요한데 TTY가 없다. 아무것도 바꾸지 않았다    |
| 4    | 옛 레이아웃이나 `~/.gitconfig`, `~/.tmux.conf`가 있어 거부했다 |
| 5    | 안전 조건으로 거부했다 (아래 참고)                             |

종료 코드 5의 경우: 휴대용 모드, 링크 대상의 부모나 진입 파일이 심링크, `~/.config`, `~/.local/share`, `~/.local/bin`이 `XDG_*` 값이나 심링크로 repo 안을 가리킴, `uninstall`에서 `HOME`이나 `XDG_STATE_HOME`이 install 때와 다름, repo가 옛 위치 `~/dotfiles`에 있음, 도구 이전이 아직 필요함(`dotfiles migrate tools`), 옮길 대상이 이미 있음, 프로세스가 사용 중인 경로.

### 상태 파일

`~/.local/state/dotfiles/`(mode 700)에 둔다.

| 파일                        | 내용                                                                                |
| --------------------------- | ----------------------------------------------------------------------------------- |
| `manifest.tsv`              | install이 만든 링크. `update`와 `uninstall`은 이 목록만 다룬다                      |
| `journal.tsv`               | 각 동작 직전에 남기는 기록. 끝나지 않은 실행은 `status`가 보고한다                  |
| `kept.list`                 | keep으로 답한 대상                                                                  |
| `blocks.tsv`                | 관리 블록을 가진 파일과 `unmanaged`로 남긴 파일                                     |
| `xdg.env`                   | install 때 쓴 `XDG_*`, `HOME`, `REPO` 값                                            |
| `backup/<YYYYmmdd-HHMMSS>/` | 유일한 백업 위치. `$HOME` 기준 상대 경로로 보관한다                                 |
| `history.merged`            | 이미 합친 옛 history 파일                                                           |
| `hosts`                     | `migrate`를 실행한 호스트                                                           |
| `migrate/`                  | `nvim-save`가 쓴 세션 파일과 `nvim.tsv`, `migrate tools` node 단계의 `node.pending` |

## 구조

### 공통과 로컬

- 공통(common): repo가 관리하고 모든 머신이 공유한다. 심링크로 배치되며 머신에서 도구나 손으로 고치지 않는다. `$HOME`에서 고치면 repo가 바뀌고 `git -C ~/.dotfiles status`에 보인다.
- 로컬(account-local): 추적하지 않는 계정·머신 고유 파일. 도구는 여기에 쓴다.
- 로컬 진입 파일이 공통을 불러온다. 진입 파일은 없을 때만 만들고, 그 안에서는 `>>> dotfiles >>>`와 `<<< dotfiles <<<` 사이의 관리 블록만 갱신한다. 블록 밖은 건드리지 않는다.
- 설정 파일은 자기 위치를 기준으로 서로를 불러온다(bash `BASH_SOURCE`, tmux `#{d:current_file}`, git 상대 include, nvim `stdpath()`, wezterm `wezterm.config_dir`). 그래서 `XDG_CONFIG_HOME` 값과 상관없이 동작한다.

### repo 레이아웃

```text
~/.dotfiles/
├── install.sh            bin/dotfiles install 래퍼
├── enter.sh              휴대용 HOME 진입
├── bin/dotfiles          CLI (~/.local/bin/dotfiles로 링크)
├── lib/dotfiles/         CLI 모듈
├── lib/templates/        로컬 진입 파일 템플릿
├── test/                 Docker 테스트
├── .config/              ~/.config/ 아래로 링크
└── .local/share/fonts/   ~/.local/share/fonts/ 아래로 링크
```

- 링크 대상은 `git ls-files`로 고른 추적 파일뿐이다: `.config/**`, `.local/share/fonts/**`, `bin/dotfiles`. `README.md`, `install.sh`, `enter.sh`, `lib/`, `test/`는 링크하지 않는다.
- 링크는 모두 상대 경로다. 디렉터리째 링크는 공통 파일만 담는 `~/.config/bash/`, `~/.config/fzf/`, `~/.config/readline/`뿐이고, 나머지는 파일 단위로 링크한다(부모는 실제 디렉터리).
- `.gitignore`는 `*`로 전부 무시하고 추적할 파일만 `!` 줄로 연다. 새 파일은 `.gitignore`에 줄을 더하고 `git add`해야 링크된다.

### 나뉜 도구

| 도구    | 로컬 진입 파일                                  | 공통 (repo 링크)                                        |
| ------- | ----------------------------------------------- | ------------------------------------------------------- |
| bash    | `~/.bashrc`                                     | `~/.config/bash/` (디렉터리 링크)                       |
| git     | `~/.config/git/config`                          | `~/.config/git/common`                                  |
| tmux    | `~/.config/tmux/tmux.conf`                      | `~/.config/tmux/common.conf`, `~/.config/tmux/themes/*` |
| wezterm | `~/.config/wezterm/wezterm.lua` (SSH 서버 목록) | `~/.config/wezterm/common.lua`                          |

### 공통만 있는 도구

| 도구                                                     | 위치                                  | 비고                         |
| -------------------------------------------------------- | ------------------------------------- | ---------------------------- |
| fzf                                                      | `~/.config/fzf/` (디렉터리 링크)      | `fzf.bash`, `fzf-git.sh`     |
| readline                                                 | `~/.config/readline/` (디렉터리 링크) | `INPUTRC`                    |
| vim                                                      | `~/.config/vim/`                      | nvim도 여기 파일을 읽는다    |
| noti                                                     | `~/.config/noti/`                     | `NOTI_CONFIG`, `NOTI_PRESET` |
| nvim, btop, lazygit, gh-dash, kime, kanata, fd, starship | `~/.config/` 아래 기존 위치           | nvim은 로컬 hook을 지원한다  |
| kime 입력기 환경변수                                     | `~/.config/environment.d/kime.conf`   | 데스크톱 세션 전용           |
| 폰트                                                     | `~/.local/share/fonts/`               | D2Coding Ligature Nerd Font  |

`~/.profile`은 배포판 기본 파일을 그대로 쓴다. 예전 `.profile`에 넣던 PATH와 `LANG`은 `env.bash`로, kime 변수는 `environment.d/kime.conf`로 옮겼다. `~/.bash_logout`은 `/etc/skel`과 같아서 repo에서 뺐다.

### 로컬 진입 파일

`~/.bashrc`:

```bash
# >>> dotfiles env >>>
. "${XDG_CONFIG_HOME:-$HOME/.config}/bash/env.bash"
# <<< dotfiles env <<<
# [local] environment variables also needed by non-interactive shells
# >>> dotfiles >>>
case $- in *i*) ;; *) return ;; esac
. "${XDG_CONFIG_HOME:-$HOME/.config}/bash/common.bash"
# <<< dotfiles <<<
# [local] interactive settings, overrides of common
```

- 없으면 템플릿(`lib/templates/bashrc`)으로 만든다.
- `/etc/skel/.bashrc`와 같으면 백업하고 바꾼다. 배포판 파일의 `HISTFILESIZE=2000`이 우리 값보다 먼저 실행돼 history 파일을 2000줄로 잘라 버리기 때문이다.
- 옛 레이아웃이면 `uninstall-legacy`가 변환한다.
- 그 밖의 파일이면 env 블록을 맨 위에, 메인 블록을 맨 끝에 넣고, 작은 `HISTSIZE`나 `HISTFILESIZE` 대입이 있으면 경고한다.

`~/.config/git/config`:

```gitconfig
# >>> dotfiles >>>
[include]
    path = common
# <<< dotfiles <<<
# [local] [user], [safe], credential — `git config --global` writes here too
```

`~/.config/tmux/tmux.conf`:

```tmux
# [local] extra TPM plugins go here (must be declared before common's TPM run)
# >>> dotfiles >>>
source-file -F "#{d:current_file}/common.conf"
# <<< dotfiles <<<
# [local] overrides of common
```

`~/.config/wezterm/wezterm.lua`는 `local servers = {...}` 목록 뒤, `return config` 앞에 관리 블록(`-- >>> dotfiles >>>`)을 둔다. 블록은 `common.lua`를 리로드 감시 목록에 넣고 `dofile(wezterm.config_dir .. "/common.lua").apply(config, servers)`를 부른다. 블록 아래가 로컬 덮어쓰기 구역이다.

### 계정 로컬 파일

진입 파일 말고도 다음 파일은 계정마다 따로 두고 repo에 커밋하지 않는다(`.gitignore`가 막는다).

| 파일                                   | 용도                                                                      |
| -------------------------------------- | ------------------------------------------------------------------------- |
| `~/.config/secrets.env`                | 셸 시크릿 (토큰, API 키). chmod 600. 대화형 셸에서 `common.bash`가 읽는다 |
| `~/.config/noti/webhook`               | noti webhook URL. chmod 600. 첫 줄이 `NOTI_WEBHOOK`이 된다                |
| `~/.config/git/credentials`            | git `credential.helper = store`의 저장소                                  |
| `~/.config/nvim/lua/local.lua`         | nvim 로컬 설정 hook                                                       |
| `~/.config/nvim/lua/plugins/local.lua` | lazy.nvim 로컬 플러그인 spec                                              |
| `~/.config/nvim/lazy-lock.json`        | lazy.nvim lock 파일                                                       |

## 도구별 설정

### bash

```text
~/.profile (배포판 기본, 로그인 셸)
└── ~/.bashrc
    ├── dotfiles env 블록 → ~/.config/bash/env.bash     모든 bash
    ├── [local] 환경변수 구역                           모든 bash
    ├── dotfiles 블록: 비대화형 셸은 여기서 return
    │   └── ~/.config/bash/common.bash                 대화형 셸
    │       └── aliases.bash, git-prompt.sh, git-completion.bash, ../fzf/fzf.bash
    └── [local] 대화형 구역
```

`env.bash`는 비대화형 셸과 `ssh host cmd`를 포함한 모든 bash가 읽는다.

- 내용: `LANG`, PATH(`~/.local/opt/tmux/bin`, `~/.local/bin`, `$CARGO_HOME/bin`, `$FNM_DIR/aliases/default/bin`을 앞에 두고 중복 제거), `CARGO_HOME`, `RUSTUP_HOME`, `FNM_DIR`, `npm_config_cache`, `NOTI_CONFIG`, `NOTI_PRESET`, `INPUTRC`, `STARSHIP_CONFIG`.
- 출력하지 않는다. 출력이 있으면 scp, rsync, sftp가 깨진다.
- 서브프로세스를 띄우지 않는다. 모든 ssh 명령마다 실행되기 때문이다.
- 여러 번 읽어도 결과가 같고, alias, 함수, 프롬프트, 키 바인딩을 정의하지 않는다.
- `~/.bashrc`의 로컬 환경변수 구역도 같은 규칙을 지킨다.
- `LANG`은 그래픽 세션(`XDG_SESSION_TYPE`이 `x11` 또는 `wayland`) 밖에서만 `C.UTF-8`로 정한다. 데스크톱 세션 안의 터미널은 시스템 로캘을 유지하고, SSH와 tty 셸은 `C.UTF-8`을 쓴다.

`common.bash`는 대화형 셸 설정이다.

- history: `HISTFILE=~/.local/state/bash/history`(디렉터리가 없으면 만든다), `HISTFILESIZE=100000`. install은 새 history 파일이 없을 때 `~/.bash_history`를 가져온다.
- 프롬프트, completion(bash-completion은 한 번만 로드), fzf, zoxide, starship, fnm 자동 전환, bell과 noti 연결, `claude()` wrapper, SSH 접속의 `DISPLAY`, `secrets.env`.

`XDG_*` 값을 바꾸려면 `~/.bashrc`가 실행되기 전(로그인 환경)에 정한다. `~/.bashrc`의 블록이 그 값으로 `env.bash`와 `common.bash`를 찾는다.

- install은 쓴 값을 `xdg.env`에 기록하고, 이후 값이 달라지면 install과 status가 경고한다.
- 상대 경로인 `XDG_*`도 경고한다. `dotfiles` 명령은 그 값을 실행한 디렉터리 기준으로 풀어 절대 경로로 기록하므로, 다른 디렉터리에서 실행하면 값이 달라진 것으로 보고된다.

### git

- 머신 고유 설정(`[user]`, `[safe] directory`, 호스트별 `[credential]` helper)은 `~/.config/git/config`의 블록 아래에 둔다. `git config --global`과 `gh auth setup-git`도 이 파일에 쓴다.
- `~/.gitconfig`가 있으면 git은 그 파일에 쓰고 그 값이 XDG 파일보다 우선한다. 그래서 `~/.gitconfig`가 있으면 install이 거부하고, `uninstall-legacy`가 내용을 옮긴다.
- 공통의 `credential.helper = store`는 `~/.config/git/credentials`에 저장한다. install은 이 파일과 `~/.git-credentials`가 둘 다 없으면 빈 파일(mode 600)을 만들고, `uninstall-legacy`는 기존 `~/.git-credentials`를 이 위치로 옮긴다.
- 컨테이너에 git 신원을 넘길 때는 디렉터리를 마운트한다: `-v "$HOME/.config/git:/home/<user>/.config/git:ro"`. 없는 `~/.gitconfig`를 마운트하면 docker가 그 자리에 디렉터리를 만든다.

### tmux

- tmux 3.2 이상이 필요하다(`source-file -F`, `#{d:current_file}`). 3.0a는 XDG 설정을 아예 읽지 않는다. install과 status가 낮은 버전을 경고하고, `dotfiles bootstrap user`가 static tmux를 `~/.local/opt/tmux`에 설치한다. `env.bash`가 그 디렉터리를 PATH 맨 앞에 둔다.
- tmux는 `~/.tmux.conf`와 XDG 파일을 둘 다 읽으므로 `~/.tmux.conf`가 남아 있으면 install이 거부한다.
- 플러그인을 더하려면 `~/.config/tmux/tmux.conf`의 관리 블록 위에 `set -g @plugin 'owner/repo'`를 적는다(템플릿의 첫 줄이 그 자리를 가리킨다). TPM과 플러그인은 `~/.local/share/tmux/plugins`(`TMUX_PLUGIN_MANAGER_PATH`)에 받는다.
- `common.conf`는 자기 플러그인을 `@tpm_plugins`에 적는다. TPM은 `source-file -F`로 읽은 파일 안의 `@plugin` 줄을 보지 못하기 때문이다.
- 로컬 진입 파일에서는 `@tpm_plugins`에 값을 넣지 않는다. 블록 위에서 넣은 값은 `common.conf`의 `set -g`가 덮어쓰고, 블록 아래의 `set -ga`는 TPM이 실행된 뒤에 돌아 소용없다.
- 테마는 `~/.config/tmux/themes/`에 있고 `common.conf`가 상대 경로로 읽는다. bell 연결도 `common.conf`에 있다.
- 새 설정으로 띄운 tmux 서버는 `prefix R`이나 `tmux source ~/.config/tmux/tmux.conf`로 설정을 다시 읽는다. 옛 레이아웃에서 띄운 서버는 다시 읽히지 말고 끝날 때까지 그대로 둔다([실행 중인 계정 옮기기](#실행-중인-계정-옮기기) 참고).

### vim과 nvim

- vim은 9.1.0327 이상만 `~/.config/vim/vimrc`를 읽는다. 그보다 오래된 vim(Ubuntu 24.04 기본 9.1.0016 포함)은 설정 없는 plain vim으로 뜬다.
- `~/.vimrc`나 `~/.vim/vimrc`가 있으면 vim이 그쪽을 먼저 읽는다. install과 status가 경고한다.
- vim 플러그인과 vim-plug는 `~/.local/share/vim/`, undo, swap, backup, session, viminfo는 `~/.local/state/vim/`에 둔다.
- nvim의 undo, swap, backup, session은 `stdpath("state")`(`~/.local/state/nvim/`)에 둔다. nvim도 `~/.config/vim/`의 `common.vim`, `plugins.vim`, `coc-settings.json`을 읽는다.
- nvim 로컬 hook은 둘 다 추적하지 않는 파일이다.
  - `~/.config/nvim/lua/plugins/local.lua`: lazy.nvim이 `lua/plugins/`의 모든 파일을 import하므로 여기 적은 spec이 그대로 로드된다.
  - `~/.config/nvim/lua/local.lua`: `init.vim` 마지막에 실행된다. 오류는 숨기지 않고 보여 준다.

### node (fnm)

- nvm 대신 fnm을 쓴다. `bootstrap user`는 nvm을 설치하지 않고, fnm 기본 버전이 없을 때만 LTS를 설치해 기본으로 정한다. 이미 있는 기본 버전은 그대로 둔다.
- 대화형 셸은 `.node-version`, `.nvmrc`, `package.json`이 있는 디렉터리로 옮기면 그 버전으로 바꾼다. 프롬프트 hook이 디렉터리가 바뀐 것을 보고 전환하므로 `cd`, zoxide `z`, `pushd`/`popd` 모두 같다.
- 전환은 다음 프롬프트 전에 일어난다. `cd dir && node ...`처럼 한 줄에 이어 쓴 명령은 아직 이전 버전으로 실행된다.
- 비대화형 셸은 기본 버전(`~/.local/share/fnm/aliases/default/bin`)만 PATH에 둔다.
- 셸마다 생기는 디렉터리(`fnm_multishells`)는 `XDG_RUNTIME_DIR`이 있으면 그 아래에 생긴다. 이곳은 호스트 로컬 tmpfs라 로그아웃이나 재부팅 때 비워진다.
- `XDG_RUNTIME_DIR`이 없으면 `~/.local/state/fnm_multishells`에 쌓인다. 아무것도 이 디렉터리를 지우지 않고, `dotfiles status`가 개수를 보고한다.
- 셸별 bin이 기본 버전보다 PATH 앞에 있다. 오래 떠 있는 tmux 셸에서 runtime 디렉터리가 사라져도 `node`는 기본 버전으로 찾아진다.

### bell, noti, claude

- `bootstrap user`는 `~/.local/opt/bell-bash`와 `~/.local/opt/noti-bash`를 clone하거나 pull만 한다. 각자의 설치기는 실행하지 않는다.
- 셸: `common.bash`가 clone을 찾아 PATH, `source bell`, 기본값(`BELL_BASH_BACKENDS='bel,notify-send'`)을 설정한다. 머신별 값은 `~/.bashrc`의 대화형 구역에서 덮어쓴다.
  - bell은 다른 프롬프트 hook(starship, zoxide, fnm)을 모두 건 뒤 맨 마지막에 읽는다.
  - 프롬프트 hook은 셸마다 한 번만 걸므로, 대화형 구역을 고친 뒤 `. ~/.bashrc`로 다시 읽어도 hook이 겹치지 않는다.
- noti 설정: `env.bash`가 `NOTI_CONFIG`, `NOTI_PRESET`을 `~/.config/noti/noti.conf`, `~/.config/noti/noti.preset`으로 정한다. noti는 이 변수가 가리키는 파일을 현재 디렉터리의 `.noti.conf`, `.noti.preset`보다 먼저 읽으므로, 프로젝트 디렉터리에 둔 이 파일은 더 이상 쓰이지 않는다. 다른 파일을 쓰려면 `~/.bashrc`의 로컬 환경변수 구역에서 두 변수를 다시 정한다.
- tmux: `common.conf`가 bell 옵션을 설정한다.
- Claude: `common.bash`가 clone을 `CLAUDE_PLUGIN_DIRS`(플러그인과 스킬)와 `CLAUDE_SETTINGS_FILES`(bell의 `claude-settings.json`, Stop/Notification hook)에 등록한다. `claude()` wrapper가 이 배열을 `--plugin-dir`, `--settings` 인자로 바꿔 `claude-auto`(있으면) 또는 `command claude`를 실행한다.
- 로컬 wrapper(예: claude-bsp)가 필요하면 `~/.bashrc` 대화형 구역에서 `claude()`를 다시 정의한다. 나중에 정의한 함수가 이 wrapper를 대신하므로, 두 배열을 인자로 넘겨야 bell과 noti가 유지된다.
- `alias claude=...`는 넣지 않는다. alias가 함수보다 먼저 확장돼 wrapper를 건너뛰고 plugin 인자가 빠진다. claude-account-switcher가 `alias claude=claude-auto`를 권해도 넣지 않는다. `dotfiles status`가 이런 alias를 경고한다.
- bell과 noti 연결은 `~/.claude`에 쓰지 않는다. 옛 bootstrap이 만든 `~/.claude/skills/{bell,noti}` 링크는 스킬을 중복시키므로 `dotfiles status`가 경고한다. 직접 지운다.

### btop

- `save_config_on_exit = false`라서 btop UI에서 바꾼 설정은 저장되지 않는다. `btop.conf`는 repo로의 링크다.
- 설정을 남기려면 `~/.config/btop/btop.conf`(= repo 파일)를 직접 고친다.
- 또는 UI에서 이 옵션을 켜고 원하는 설정을 바꾼 뒤 종료하고, `git -C ~/.dotfiles diff`에서 원하는 변경만 남기고 `save_config_on_exit` 줄은 되돌린다.

## 옛 레이아웃에서 옮기기

옛 레이아웃은 dotfiles를 `$HOME`에 복사하고 `# Machine-specific settings below` 마커 아래에 머신 설정을 적던 방식이다(`~/.bashrc.common`, `~/.gitconfig.common`, `~/.tmux.common.conf`, `~/.wezterm.common.lua` 등). install은 이런 계정에서 거부하고 `uninstall-legacy`를 안내한다.

### uninstall-legacy

```bash
~/.dotfiles/bin/dotfiles uninstall-legacy --dry-run   # 미리보기만
~/.dotfiles/bin/dotfiles uninstall-legacy             # 미리보기 → 확인 → 적용
```

| 옵션                              | 뜻                                                                                                                |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `--dry-run`                       | 미리보기만 하고 끝낸다                                                                                            |
| `--yes`                           | 최종 확인 없이 적용한다                                                                                           |
| `--accept-dropped-edits`          | 고쳐 쓴 옛 사본(`LOCALLY-EDITED`, `UNKNOWN`)이 활성 설정에서 빠지는 것을 묻지 않고 허락한다. 원본은 백업에 남는다 |
| `--replace-all` 또는 `--keep-all` | 옛 레이아웃과 무관한 링크 충돌을 모두 replace(백업 후 링크)하거나 모두 keep한다                                   |

- 미리보기는 항목을 종류별로 보여 준다: `MOVE`, `DEBRIS`, `MIGRATE`, `MIGRATE-MERGE`, `REMOVE-CANDIDATE`, `FIX-SUGGESTION`, `KEEP`, `WARN`, `LOCALLY-EDITED`, `UNKNOWN`(diff 포함).
- 옛 파일과 `.bak` 잔재(`$HOME`과 `~/.config` 도구 디렉터리 안)는 백업 디렉터리로 옮긴다. 지우는 것은 없다.
- `~/.local/bin/noti`가 repo가 예전에 배포한 사본이면 백업 디렉터리로 옮긴다. 로그인 셸에서 noti-bash clone의 `noti`를 가리기 때문이다. 고쳐 쓴 사본은 그대로 두고 `WARN`으로 알린다.
- 머신 구역은 새 진입 파일로 옮긴다.
  - `~/.bashrc` 마커 아래 → 새 `~/.bashrc`의 대화형 구역. 머신 구역에 시크릿이 있을 수 있으므로 새 `~/.bashrc`는 옛 파일의 권한(예: 600)을 유지한다.
  - `~/.tmux.conf` 마커 아래 → `~/.config/tmux/tmux.conf` 블록 아래
  - `~/.gitconfig` 마커 아래 → `~/.config/git/config` 블록 아래
  - `~/.wezterm.lua` → `~/.config/wezterm/wezterm.lua`. 공통을 불러오던 두 줄만 관리 블록으로 바꾼다. 그 두 줄이 없는 파일은 그대로 옮기고 `unmanaged`로 기록한다.
    - install은 `unmanaged`로 기록된 파일에 관리 블록을 넣지 않는다. 블록을 최신으로 유지하려면 마지막 `return config` 위에 `-- >>> dotfiles >>>`와 `-- <<< dotfiles <<<` 두 줄을 손으로 넣는다. 그러면 install이 블록을 채우고 파일을 관리 대상으로 기록한다. install 경고와 `dotfiles status`가 이 방법을 안내한다.
- 옮길 곳에 파일이 이미 있으면(`MIGRATE-MERGE`) 내용을 유지하고 블록 아래에 옮긴 구역을 덧붙인다. 원래 파일은 먼저 백업한다.
- `~/.bash_history`는 새 `HISTFILE`에 덧붙이고, `~/.git-credentials`는 `~/.config/git/credentials`로 옮긴다(권한 유지).
- `~/.profile`이 옛 repo 사본과 같으면 `/etc/skel/.profile`로 바꾸고, 고쳐 썼으면 그대로 두고 수정 제안을 보여 준다.
- `REMOVE-CANDIDATE`는 옮긴 텍스트에서 빠지고 원본은 백업에 남는다: bell과 noti 설치기 블록, 중복된 `bell_skip`, `env.bash`와 겹치는 PATH 줄, nvm 줄, `alias claude=...`, `source-file ~/.tmux.common.conf`, `~/.gitconfig.common` include 등.
  - 빠지는 줄만 설명하던 주석도 함께 빠진다. 빠지는 줄 뒤에 빈 줄이 오거나 파일이 끝나서 그 문단이 끝나면, 그 문단에서 남는 주석 아닌 마지막 줄 뒤의 주석이 빠진다. 빠진 자리에 겹친 빈 줄은 하나로 줄인다.
  - 다른 설치기 블록의 `# >>>`/`# <<<` 줄과 `KEEP`으로 보고하는 주석은 남는다.
- `FIX-SUGGESTION`은 텍스트를 유지하고 고칠 곳만 알려 준다: docker `-v "$HOME/.gitconfig:..."` → `-v "$HOME/.config/git:<home>/.config/git:ro"`, `~/.bell-bash`, `~/.noti-bash`, `~/.fzf`, `~/.cargo`, `~/.nvm`, `~/.vim` 경로 참조 등.
- `KEEP`은 그대로 옮긴다: `BELL_BASH_*` 같은 머신 값, claude-bsp wrapper, Xilinx, petalinux, minicom 설정, bun 등.
  - bell과 noti 설치기 블록 안에 적힌 `BELL_BASH_*` 값과 `NOTI_WEBHOOK`은 블록이 `REMOVE-CANDIDATE`여도 대화형 구역에 남는다. 블록의 `BELL_BASH_HOME`, PATH, source 줄, claude 등록 줄은 빠진다.
  - 남은 `NOTI_WEBHOOK`에는 `~/.config/noti/webhook`(chmod 600)으로 옮기라는 `FIX-SUGGESTION`이 붙는다.
- `~/.vim`의 나머지는 백업으로 옮긴다. vim의 undo와 세션은 이전하지 않는다(nvim 것만 이전).
- TTY가 없는데 필요한 옵션(`--yes`, 고쳐 쓴 사본이 있으면 `--accept-dropped-edits`, 링크 충돌이 있으면 `--replace-all` 또는 `--keep-all`)이 빠지면 미리보기만 출력하고 아무것도 바꾸지 않은 채 exit 3으로 끝난다.
- 다음 경우에는 거부한다(exit 5).
  - repo가 옛 위치 `~/dotfiles`에 있을 때. 먼저 `migrate repo`를 실행한다.
  - `~/.cargo`, `~/.rustup`, `~/.fzf`, `~/.fzf-tab-completion`, `~/.bell-bash`, `~/.noti-bash`가 실제 디렉터리로 남아 있거나, `~/.nvm`이 있는데 fnm 기본 버전이 아직 없거나, `migrate tools`의 node 단계가 끝나지 않았을 때(`node.pending`). 먼저 `migrate tools`를 실행한다.
- 끝나면 백업 디렉터리와 되돌리는 방법(`dotfiles uninstall` 후 백업에서 다시 옮기기)을 출력한다.
- 적용이 중간에 멈추면(Ctrl-C, NFS 오류) `uninstall-legacy`를 다시 실행해 마저 끝낸다. 머신 구역을 두 번 덧붙이지 않는다. 끝까지 마친 뒤의 두 번째 실행은 아무것도 바꾸지 않는다.

### 실행 중인 계정 옮기기

tmux 서버와 세션, Claude와 codex 세션을 죽이지 않고 옮기는 순서다. 각 단계는 미리보기 → 확인 → 적용으로 진행하고(TTY가 없으면 `--yes`, `--dry-run`은 미리보기만), 실행한 호스트를 `~/.local/state/dotfiles/hosts`에 기록한다.

```bash
git -C ~/dotfiles pull                          # 1. 새 코드를 옛 체크아웃에 받는다
~/dotfiles/bin/dotfiles migrate repo            # 2. ~/dotfiles → ~/.dotfiles, ~/dotfiles 호환 링크
~/.dotfiles/bin/dotfiles migrate tools          # 3. 도구 이동과 호환 링크, fnm
~/.dotfiles/bin/dotfiles migrate nvim-save      # 4. tmux pane의 nvim 세션을 저장하고 종료
~/.dotfiles/bin/dotfiles migrate nvim-state     # 5. nvim undo와 세션 복사
~/.dotfiles/bin/dotfiles uninstall-legacy       # 6. 옛 파일 정리, 링크, 진입 파일
~/.dotfiles/bin/dotfiles install                #    확인 (바뀌는 것 없음)
~/.dotfiles/bin/dotfiles migrate nvim-restore   # 7. 저장한 nvim을 원래 pane에서 다시 연다
dotfiles bootstrap user                         # 8. 선택: 도구 갱신 (fnm 기본 버전 유지)
dotfiles migrate cleanup                        # 9. 한참 뒤: 옛 셸, tmux 서버, nvim이 모두 끝난 뒤
```

- repo가 이미 `~/.dotfiles`에 있으면 1단계는 `git -C ~/.dotfiles pull`로 하고 2단계는 건너뛴다.
- `repo`를 뺀 모든 단계는 repo가 아직 `~/dotfiles`에 있으면 거부한다(exit 5).
- `migrate all`은 `tools`, `nvim-save`, `nvim-state`, `uninstall-legacy`, `install`, `nvim-restore`(3~7단계)를 차례로 실행하고, 한 단계가 실패하면 멈춘다(`--dry-run`이면 나머지 단계도 미리 보여 준다).
  - 2단계가 끝나 있어야 하고(repo가 `~/.dotfiles`에 있어야 한다, 아니면 exit 5) `cleanup`은 포함하지 않는다.
  - `--yes`와 `--dry-run`은 모든 단계에, `--accept-dropped-edits`는 `uninstall-legacy`에, `--replace-all`과 `--keep-all`은 `uninstall-legacy`와 `install`에 넘긴다.
- `repo`: `~/dotfiles`를 `~/.dotfiles`로 옮기고 `~/dotfiles` → `.dotfiles` 링크를 남긴다. 둘 다 디렉터리면 거부한다.
  - `.git` 파일이 `~/dotfiles/.git/worktrees/<id>`를 가리키는 linked worktree는 `~/.dotfiles`를 가리키도록 고친다(미리보기의 `WORKTREE`). 그래서 `cleanup`이 `~/dotfiles` 링크를 지운 뒤에도 동작한다.
  - 이름을 바꾼 뒤 `~/dotfiles` 링크를 만들기 전에 실행이 멈췄으면, `repo`를 다시 실행할 때 빠진 링크만 만든다.
- `tools`: `~/.cargo`, `~/.rustup`을 `~/.local/share/{cargo,rustup}`로, `~/.fzf`, `~/.fzf-tab-completion`, `~/.bell-bash`, `~/.noti-bash`를 `~/.local/opt/`로 옮기고 옛 자리에 상대 호환 링크를 남긴다.
  - 옮길 곳이 이미 있거나, 파일 시스템이 다르거나, 그 안의 프로그램이 실행 중이면 그 항목만 거부한다.
  - 도구 디렉터리를 옮긴 뒤 호환 링크를 만들기 전에 실행이 멈췄으면, 다시 실행할 때 빠진 링크만 만든다.
  - `~/.nvm`이 있고 fnm 기본 버전이 없으면 fnm을 설치하고, `~/.nvm`에서 쓰던 node 버전을 기본으로 정하고, 그 버전의 전역 npm 패키지를 다시 설치한다.
  - 쓸 수 있는 nvm 기본 버전을 찾지 못해도 fnm을 설치하고 현재 LTS node를 fnm 기본으로 정한다. 전역 npm 패키지는 다시 설치하지 않는다.
  - node 단계는 이어서 할 수 있다. 이 단계가 쓰던 node 버전을 fnm에 설치하고, 기본으로 정하고, 전역 npm 패키지를 다시 설치하기 전에 멈추면 `~/.local/state/dotfiles/migrate/node.pending`이 남는다(fnm이나 그 버전의 설치 실패, `fnm default` 실패, `npm install -g` 실패, Ctrl-C).
  - `migrate tools`를 다시 실행하면 그 단계를 마저 끝내고 `node.pending`을 지운다. npm이 실패하면 직접 실행할 `npm install -g` 명령도 출력하지만, 그 명령으로 설치했어도 `migrate tools`를 다시 실행해야 파일이 지워진다.
  - `node.pending`이 남아 있는 동안 `bootstrap user`와 `uninstall-legacy`는 그 파일과 node 버전을 알려 주고 거부한다(exit 5).
  - nvm 버전으로 바꾸는 것은 이 단계가 정한 LTS 기본 버전뿐이다. 그 사이에 사용자가 정한 fnm 기본 버전은 그대로 두고 경고한다.
  - `~/.tmux/plugins`와 `~/.nvm`은 건드리지 않는다. 실행 중인 tmux 서버와 codex가 쓰고 있기 때문이다.
- `nvim-save`: 모든 tmux 서버의 pane에서 셸이 직접 띄운 nvim마다 세션 파일(`:mksession`)을 쓰고 정상 종료(`:qa`)시킨다. 수정된 버퍼, `:terminal` 버퍼, 실행 중인 job이 있는 nvim은 건너뛰고 보고한다. 세션 파일과 pane 기록(`nvim.tsv`)은 `~/.local/state/dotfiles/migrate/`에 둔다.
- `nvim-state`: `~/.local/share/nvim/{undo,obsession}`을 `~/.local/state/nvim/`으로 복사한다(`cp -n`). 옛 디렉터리는 그대로 둔다.
- `nvim-restore`: `nvim.tsv`에 기록한 pane에 `nvim -S <session>`을 보낸다. 건너뛴 pane에는 실행할 명령을 출력한다.
  - pane이 nvim을 저장할 때의 그 셸을 아직 실행하고 있고, 그 셸이 터미널을 쥐고 있을 때만 보낸다. 그 셸이 띄운 프로그램(예: bash 스크립트)이 foreground에 있거나 pane이 copy mode면 건너뛴다.
  - 세션이 여는 파일이 더 이상 없으면(예: `uninstall-legacy`가 백업으로 옮긴 옛 파일) 경고한다. nvim은 그 파일을 빈 버퍼로 보여 주고, 그 버퍼를 저장하면 옛 파일이 다시 생긴다.
  - `nvim-save`와 `nvim-restore`의 출력과 확인 질문은 pane을 `default:%3`처럼 tmux 서버 소켓 이름과 pane id로 가리킨다(pane id는 서버마다 `%0`부터 다시 시작한다).
- `history`: 옮긴 뒤 옛 셸이 다시 만든 `~/.bash_history`의 새 줄을 합친다.
- `cleanup`: 아무것도 죽이지 않고, 남긴 것과 이유를 출력한다.
  - 옛 셸은 6단계가 `~/.bashrc`를 바꾸기 전에 시작한, 터미널이 있는 셸이다. `cleanup`을 실행한 셸도 옛 셸이면 남은 것으로 센다. 그러니 `cleanup`은 이전이 끝난 뒤 새로 시작한 로그인 세션에서 실행한다.
  - 도구 호환 링크는 어떤 프로세스도 쓰지 않고 옛 셸도 남지 않았을 때만 지운다. rc 파일이 만든 PATH는 `/proc`에 보이지 않기 때문이다.
  - `~/.rustup`은 `~/.cargo`가 남는 동안 남는다.
  - `~/dotfiles`는 PWD가 `~/dotfiles` 아래인 프로세스나 이름을 바꾸기 전에 체크아웃 안에서 시작한 프로세스(예: `~/dotfiles`에서 시작한 Claude Code나 codex 세션)가 있는 동안 남는다. 지우기 전에 linked worktree를 고친다.
  - `~/.tmux`는 떠 있는 tmux 서버가 `~/.tmux/plugins`를 더 쓰지 않을 때 백업 디렉터리로 옮긴다.
  - `~/.nvm`은 그 안의 node를 실행하거나 PATH에 둔 프로세스가 없고 옛 셸도 남지 않았을 때 백업 디렉터리로 옮긴다.
  - 이어서 `history`와 `nvim-state`를 다시 실행한다.
- 옛 셸은 시작할 때의 PATH를 그대로 쓰므로 호환 링크를 통해 계속 동작한다. 새 셸은 새 레이아웃을 쓴다.
- 떠 있던 tmux 서버는 다시 읽히지 말고 끝날 때까지 그대로 두고, 새 작업은 새 tmux 서버에서 시작한다. 옛 서버가 모두 끝나야 `cleanup`이 `~/.tmux`를 옮긴다.
  - 옛 서버에서도 플러그인 바인딩과 상태 줄은 그대로 동작하고, 새 창은 새 레이아웃의 셸로 뜬다.
  - 6단계 뒤에는 옛 설정의 `prefix R`이 백업으로 옮겨진 `~/.tmux.conf`를 읽으므로 "Sourced" 메시지만 띄우고 아무것도 다시 읽지 않는다.
- 옛 서버에 `tmux source ~/.config/tmux/tmux.conf`를 실행하는 것은 선택이고, 정리를 앞당기지 않는다.
  - 세션과 pane은 그대로이고 플러그인 바인딩은 새 경로로 바뀐다. TPM이 플러그인을 `~/.local/share/tmux/plugins`로 받는 몇 초 동안 명령을 친 셸이 기다리고, 다른 pane은 멈추지 않는다.
  - 옛 설정이 건 것은 남는다: tmux-cuecard의 `window-unlinked` hook이 옛 경로와 새 경로로 두 번 걸리고, 옛 `prefix R`, `prefix a` 바인딩과 `@plugin` 옵션도 그대로다.
  - 남은 hook이 `~/.tmux/plugins`를 가리키므로 `cleanup`은 다시 읽힌 서버도 끝날 때까지 `~/.tmux`를 남긴다.
- NFS 홈을 여러 호스트가 공유하면 각 단계는 실행한 호스트의 프로세스와 tmux 서버만 본다. `nvim-save`와 `nvim-restore`는 호스트마다 실행하고, `cleanup`은 모든 호스트의 옛 셸, tmux 서버, nvim이 끝난 뒤 실행한다. `cleanup`은 확인할 때 `hosts`에 기록된 호스트를 보여 준다. `migrate`를 한 번도 실행하지 않은 호스트는 기록에 없다.

## 테스트 (Docker)

```bash
~/.dotfiles/test/run.sh --work DIR [--tier lite|full] [--scenario LIST] [--target repo|repo-ro|tmux32] [--rebuild]
```

- `--work DIR`는 필수다. 빌드 컨텍스트와 로그가 여기에 생긴다. 컨텍스트는 `git ls-files` 기준으로 만든 복사본이라 무시된 로컬 파일(시크릿, 진입 파일)은 docker로 가지 않는다.
- `--tier`: `lite`는 일부 도구만 bootstrap한 이미지, `full`은 `bootstrap user` 전체(cargo 빌드, 느림)와 `bootstrap agents`.
- `--scenario LIST`: 실행할 시나리오. 시나리오 목록과 검사 항목은 `test/README.md`에 있다.
- `--target`: 이미지 단계. `repo-ro`는 root 소유 읽기 전용 repo, `tmux32`는 tmux 3.2 하한 검사용이다.
- `--rebuild`: 레이어 캐시 없이 이미지를 다시 빌드한다.
- 이미지는 `dotfiles-xdg-test:*` 태그로 남고, 컨테이너는 `dotfiles-xdg-*` 이름만 쓰고 끝나면 지운다. `GH_TOKEN`은 BuildKit secret으로만 넘긴다.
- 호스트에서는 `run.sh`만 실행한다. 설치, tmux, vim, nvim은 컨테이너 안에서만 돈다.

## 한계

- Linux(Ubuntu/Debian) 전용이다. Windows WezTerm 클라이언트는 파일을 손으로 복사한다([WezTerm SSH 런처](#wezterm-ssh-런처) 참고).
- cron과 systemd는 `env.bash`를 읽지 않는다. 그쪽 작업에 필요한 PATH와 환경변수는 crontab이나 unit에 직접 적는다.
- `XDG_*` 값은 `~/.bashrc`보다 먼저 정해져 있어야 한다.
- vim 9.1.0327 미만은 plain vim으로 뜨고, tmux 3.2 미만은 지원하지 않는다.
- bell, noti, `claude()` 연결은 대화형 셸에서만 생긴다. 비대화형 맥락에서 띄운 `claude`에는 plugin 인자와 알림이 없다.
- `~/.config/{bash,fzf,readline}`는 repo 디렉터리로의 링크라서, 도구가 그 안에 만든 파일은 repo 작업 트리에 생긴다. `.gitignore`의 `*`에 가려 `git status`에는 안 보이고 `dotfiles status`가 보고한다.
- `common.bash`는 repo의 `fzf.bash`를 직접 읽는다. `~/.config/fzf`에 keep으로 답해도 repo 버전이 로드된다.
- fzf clone(`~/.local/opt/fzf`)이 없으면(`dotfiles bootstrap user` 전의 새 계정) 셸이 시작할 때 `fzf.bash`가 `key-bindings.bash`를 찾지 못하고 `_fzf_setup_completion` 오류를 출력한다. 예전 레이아웃에서도 같았다.
- kime `environment.d`는 데스크톱 로그인 세션에서만 적용되고 Docker 테스트로 검증하지 않는다.
- 사용 중 여부는 명령을 실행한 호스트의 `/proc`만 보고 판단한다. NFS 홈에서는 다른 호스트의 프로세스가 보이지 않는다.
  - `/proc`에서 읽을 수 없는 non-dumpable 프로세스(sshd 세션 프로세스, ssh-agent 등)와 zombie는 판단에서 빠진다.
  - 이 uid가 소유한 프로세스인데 environ을 읽을 수 없으면 사용 중으로 본다.
- `$HOME` 자체가 git 작업 트리인 계정(repo를 `~`에 clone한 옛 방식)에서는 install과 `uninstall-legacy`가 휴대용 모드로 보고 거부한다.
- 옛 계정의 `~/.npm`은 옮기지 않는다. `dotfiles status`가 보고한다.
- gh-dash의 `repoPaths`(`~/:repo`)는 이 repo를 `~/dotfiles`에서 찾는다. 새로 설치한 계정이나 `migrate cleanup`으로 `~/dotfiles` 링크를 지운 계정에서는 이 repo PR의 `C` 키가 동작하지 않는다.

## Linux 데스크톱

### 폰트

- repo의 D2Coding Ligature Nerd Font는 install이 `~/.local/share/fonts/`에 링크하고 `fc-cache`를 실행한다.
- 다른 머신은 [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts#font-installation)에서 받는다. D2Coding: https://github.com/ryanoasis/nerd-fonts/releases/latest/download/D2Coding.tar.xz

### 키보드 매핑 (kanata)

https://github.com/jtroo/kanata/releases 에서 kanata를 받아 `~/.local/bin/kanata`로 저장한다.

```systemd
[Unit]
Description=Kanata keyboard remapper
Documentation=https://github.com/jtroo/kanata

[Service]
Type=simple
ExecStart=/home/{USERNAME}/.local/bin/kanata --cfg /home/{USERNAME}/.config/kanata/tenkeyless.key
Restart=never

[Install]
WantedBy=default.target
```

그 다음 `systemctl daemon-reload / start / enable`. kime 환경변수는 아래 kime 절을 따른다.

### 한글 입력 (kime)

참고: https://osg.kr/archives/3109

1. 설치

    ```bash
    sudo apt install kime
    ```

2. IM 등록 (`im-config`로 kime 선택 또는 `~/.xinputrc`에 `run_im kime`)

    ```bash
    im-config -n kime
    ```

    환경변수 `GTK_IM_MODULE=kime`, `QT_IM_MODULE=kime`, `XMODIFIERS=@im=kime`는 `~/.config/environment.d/kime.conf`(dotfiles에 포함, install이 링크)가 데스크톱 세션에 설정한다. 다시 로그인해야 적용된다.

3. GNOME 입력 소스에서 ibus를 제거한다. 안 하면 한/영 토글이 ibus-hangul로 가서 kime 레이아웃이 먹지 않는다.

    ```bash
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
    pkill -f 'ibus-(daemon|engine|x11|portal|dconf|extension)'
    ```

4. 설정 파일 (dotfiles에 포함)

    - `~/.config/kime/config.yaml`: 신세벌식 P2(`sebeolsik-3sin-p2`), `ComposeChoseongSsang`과 `ComposeJongseongSsang`(세벌식 한정)
    - 한/영 토글 키: 우측 Alt, Hangul, Muhenkan, Super+Space, Shift+Space

5. 데몬 기동

    ```bash
    pkill -x kime; pkill -x kime-indicator; pkill -x kime-xim
    nohup kime >/dev/null 2>&1 & disown
    ```

### 데스크톱 패키지

- 미디어: `sudo apt install mpv ffmpeg libsixel-bin timg ranger` (img2sixel은 `libsixel-bin`), yt-dlp는 https://github.com/yt-dlp/yt-dlp?tab=readme-ov-file#release-files
- GNOME: `sudo apt install gnome-shell-extensions gnome-tweaks`, 타일링은 https://github.com/pop-os/shell (단축키: https://support.system76.com/articles/pop-keyboard-shortcuts/)
- 오디오: `sudo apt install pavucontrol`
- 블루투스: `sudo apt install blueman`

### Kitty

`~/.config/kitty/kitty.conf`:

```conf
# Truecolor 활성화
enable_true_color yes

# 외부 앱이 kitty 기능 제어 가능하게 허용
allow_remote_control yes

# (선택) 기본 TERM
term xterm-kitty
```

tmux 쪽은 `~/.config/tmux/tmux.conf`의 블록 아래(로컬 구역)에 넣는다.

```tmux
set -ga terminal-overrides ',xterm-kitty:Tc:sitm=\E[3m' # kitty

# 256 color
set -g default-terminal "xterm-kitty" # kitty

# true color
set -as terminal-features ',xterm-kitty:RGB' # kitty

# 터미널 에뮬레이터 고유 기능 사용을 위해 escape sequences tmux가 가로채지 않도록 하는 기능
set -g allow-passthrough on # kitty
```

## Windows 클라이언트

### X11 forwarding (Xming)

1. Windows에서 Xming을 XLaunch로 다음처럼 설정해 실행한다. Xming 바로가기 속성에 `-ac`를 추가한다.

    ```text
    Multiple windows
    Start no client
    Clipboard: 체크 (optional)
    No access control  ← 꼭 체크 (외부 접속 허용)
    ```

2. SSH 접속 시 `-X` 또는 `-Y` 옵션을 쓴다.

    ```bash
    ssh -X <id>@<ubuntu-ip>
    ssh -Y <id>@<ubuntu-ip>
    ```

3. 서버 SSH 설정(`/etc/ssh/sshd_config`)을 바꾸고 `sudo systemctl restart ssh`.

    ```text
    X11Forwarding yes
    X11DisplayOffset 10
    X11UseLocalhost no
    ```

4. `$DISPLAY`는 SSH 접속이면 `~/.config/bash/common.bash`가 설정한다.

### WezTerm SSH 런처

WezTerm 설정은 두 파일로 나뉜다. 두 파일은 같은 디렉터리에 있어야 한다(`wezterm.config_dir` 기준으로 읽는다).

- `wezterm.lua`: 이 머신 전용 진입점. SSH 서버 레지스트리(호스트, IP)를 여기에만 적는다. 내부 IP가 들어가므로 repo에 커밋하지 않는다.
- `common.lua`: 공통(dotfiles 추적). 키맵, 외관, 테마 토글, SSH 런처 빌더가 들어 있다. 고치면 WezTerm이 자동으로 다시 읽는다.

배치:

- Linux: install이 `~/.config/wezterm/common.lua`를 링크하고, 없으면 `~/.config/wezterm/wezterm.lua`를 템플릿으로 만든다.
- Windows: install을 쓰지 않는다. `lib/templates/wezterm.lua`를 `%USERPROFILE%\.config\wezterm\wezterm.lua`로, `.config/wezterm/common.lua`를 같은 디렉터리의 `common.lua`로 손으로 복사한다. 옛 `%USERPROFILE%\.wezterm.lua`와 `%USERPROFILE%\.wezterm.common.lua`는 지운다.

`wezterm.lua`의 `servers` 목록에 항목을 추가하면 런처(`Ctrl+Shift+Alt+L`)에 `SSH <name>`과 `BTOP on <name>` 메뉴가 생긴다.

```lua
local servers = {
  { name = "Dev", host = "192.168.0.42", user = "you",
    enter = "tmux attach || tmux new-session", autossh = true },
}
```

| 필드      | 설명                                                                              |
| --------- | --------------------------------------------------------------------------------- |
| `name`    | 런처에 표시될 라벨                                                                |
| `host`    | IP, 호스트명, `~/.ssh/config` 별칭                                                |
| `user`    | (선택) SSH 사용자명                                                               |
| `key`     | (선택) 개인키 파일명 (`$HOME` 기준). 생략하면 기본 키(`~/.ssh/id_ed25519`)를 쓴다 |
| `cwd`     | (선택) 런처 프로세스의 작업 디렉터리                                              |
| `enter`   | (선택) 접속 시 실행할 원격 명령 (위 예 참고)                                      |
| `autossh` | (선택) `true`면 끊겨도 자동 재접속 (PS 재시도 루프와 ServerAlive keepalive)       |

#### Windows는 SSH 키 인증만 쓰는 이유

런처는 Windows에서 네이티브 OpenSSH(`C:\Windows\System32\OpenSSH\ssh.exe`)만 쓰고 인증은 SSH 키로 한다. 비밀번호 자동입력을 두 방식으로 시도했으나 모두 실패했다.

- sshpass + MSYS2 ssh: sshpass는 같은 MSYS2 런타임으로 빌드된 ssh의 프롬프트만 가로챌 수 있어 `C:\msys64\usr\bin\ssh.exe`를 써야 한다. 이 Cygwin PTY 계층이 WezTerm의 ConPTY 위에서 tty 출력을 바이트 단위 저속 경로로 떨궈 스크롤과 출력이 기어간다. 네트워크나 GPU 문제가 아니라 로컬 PTY 변환 오버헤드라 로컬 VM도 똑같이 느려진다.
- plink (PuTTY): charset을 지정하는 CLI 옵션이 없어 원격 UTF-8을 시스템 코드페이지(CP949)로 오독해 한글 mojibake가 난다. 기본 `-sanitise-stdout`이 제어문자(ESC)를 `?`로 뭉개 tmux, nvim, powerline이 깨진다.

네이티브 ssh는 바이트를 그대로 흘려보내 UTF-8과 ANSI가 온전하고 빠르다. Unix 쪽은 Cygwin 페널티가 없어 `server.password` + `sshpass` 옵션이 그대로 유효하다.

#### 키 등록 (PowerShell, 1회)

```powershell
# 1) 키 생성 (무passphrase — 무인 재접속용)
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -C "me@wezterm"

# 2) 서버에 공개키 등록 — 비번 1회 입력
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh you@192.168.0.42 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

# 3) 확인 — 비번 없이 hostname이 뜨면 성공
ssh you@192.168.0.42 hostname
```

PowerShell 5.1 함정: 원격 명령 문자열 안에 `"$VAR"`처럼 따옴표와 변수를 넣으면 PS가 ssh로 넘기며 따옴표를 뭉개(native 인자 파싱 버그) 원격 셸에서 단어 분할이 일어난다. 위처럼 공개키는 stdin으로만 흘리고(`Get-Content | ssh … "cat >> …"`) 원격 명령에는 따옴표와 `$`를 쓰지 않는다.

등록 후 WezTerm을 재시작하고 런처로 접속하면 비번 없이 붙고 tty도 빠르다.
