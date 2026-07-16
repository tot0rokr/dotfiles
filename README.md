# Integrated Bash Eenvironment

## Quick Start

세 가지 사용 방식이 있다.

### A. 홈에 영구 적용 (일반 데스크톱/서버)

repo를 별도 위치에 두고 dotfiles를 `$HOME`으로 복사한다.

```bash
git clone https://github.com/tot0rokr/dotfiles ~/.dotfiles
~/.dotfiles/install.sh      # dotfiles를 $HOME으로 복사 (install.sh/enter.sh/README은 제외)
exec bash                    # 새 셸에서 적용
```

### B. 휴대용 HOME (공유 계정·임시 서버 — 계정 안 건드림)

아무것도 복사하지 않고 `$HOME`(+`XDG_*`)만 이 체크아웃으로 돌린다. 되돌리기는 `rm -rf` 하나.

```bash
git clone https://github.com/tot0rokr/dotfiles ~/.myhome
~/.myhome/enter.sh                 # 인터랙티브 진입 (exit로 원래 셸 복귀)
~/.myhome/enter.sh tmux            # tmux로 바로 (전용 소켓)
ssh host -t '~/.myhome/enter.sh'   # SSH 접속 즉시 내 환경
```

### 도구 설치 (bootstrap)

설치 후 인터랙티브 셸에서 순서대로. 함수는 `.bashrc.common`이 정의한다.

```bash
bootstrap_system_tools   # sudo apt: build-essential/git/python3/ctags/wezterm... (root 필요, Ubuntu/Debian)
bootstrap_user_tools     # ~/.local: nvim/fzf/rg/bat/eza/starship/lazygit/tmux/bell/noti... (root 불필요, cargo 빌드로 느림)
bootstrap_agents         # ~/agents: Claude/Codex/OpenCode/Gemini 하네스 (~/.claude 등 심링크)
```

### 검증 (Docker)

클린 컨테이너에서 clone→install→bootstrap 전 과정을 자동 실행·검증한다. exit 0이면 통과.

```bash
test/run.sh            # smoke (install/system/agents, 빠름)
test/run.sh --full     # 전체 (+ bootstrap_user_tools, cargo 빌드까지)
test/run.sh --local    # 로컬 워킹트리로 검증 (push 전)
```

### 업데이트

```bash
cd ~/.dotfiles && git pull
./install.sh --dry-run     # 바뀔 내용 미리보기 (진입점은 마커 위쪽만 변경으로 표시)
./install.sh               # 적용 (B 방식이면 git pull만으로 충분)
```

`install.sh`는 머신 고유 파일을 덮어쓰지 않도록 보호한다.
- `.bashrc`·`.tmux.conf` — `# Machine-specific settings below` 마커 **아래(네 개인
  설정·시크릿)는 그대로 보존**하고 위쪽 템플릿 + `~/.*.common` 로드부만 갱신한다
  (변경 시 `<file>.bak.<ts>` 백업).
- `.wezterm.lua` — 파일 전체가 머신 전용 SSH 레지스트리라 **이미 있으면 안 덮고
  그대로 둔다**(첫 설치 때만 스켈레톤 배치).

그 외 dotfile(`.bashrc.common`·`.wezterm.common.lua`·`.fzf.bash`·`.gitconfig` 등)은
repo가 소스라 repo 버전으로 덮으니 `--dry-run`으로 먼저 확인하는 걸 권장.

### 머신 고유 설정 / 시크릿

- 이 머신 전용 설정은 `~/.bashrc`·`~/.tmux.conf`의 "Machine-specific" 구역에 적고 **repo로 커밋하지 않는다**.
- 셸 시크릿은 `~/.config/secrets.env`(chmod 600)에 두면 `.bashrc.common`이 자동 로드한다.
- noti webhook은 `~/.config/noti/webhook`(chmod 600).

## Step

### Install fonts

[Download Nerd Fonts](https://github.com/ryanoasis/nerd-fonts#font-installation)

- D2Coding
    - https://github.com/ryanoasis/nerd-fonts/releases/latest/download/D2Coding.tar.xz


### Install & Run

```
sudo apt update \
&& sudo apt install -y git \
&& \rm -f ~/.* \
; git clone https://github.com/tot0rokr/dotfiles.git ~ \
&& bash
```

### 셸 / tmux 설정 구조

이식 가능한 공통부와 머신 고유부를 분리한다. `.bashrc`와 `.tmux.conf`가 같은 패턴을 쓴다.

- `.bashrc` / `.tmux.conf` — 진입점(추적됨). clone/install 시 `~/`로 배치되는 기본 템플릿이다. 각각 `~/.bashrc.common` / `~/.tmux.common.conf`를 불러온 뒤, 이 머신 전용 설정을 그 아래에 직접 적어 쓴다.
- `.bashrc.common` — 이식 가능한 공통 셸 설정: history/PATH/prompt/git/completion, `bootstrap_user_tools`·`bootstrap_system_tools`·`bootstrap_agents` 등 설치 함수, starship/zoxide init. 시크릿 없음.
- `.tmux.common.conf` — 이식 가능한 공통 tmux 설정: 플러그인(TPM)·키바인딩·status·테마·truecolor. bell-bash 같은 도구 연동은 `~/.tmux.conf`에 머신 고유로 둔다.

진입점 파일(`~/.bashrc`·`~/.tmux.conf`)에 추가한 머신 고유 설정은 repo로 커밋하지 않는다(repo의 진입점은 기본 템플릿 상태 유지). 셸 시크릿은 `~/.config/secrets.env`(chmod 600)에 두면 `.bashrc.common`이 자동 로드한다.


### 휴대용 HOME 진입 (남의 계정 안 건드리기)

`install.sh`는 이 설정을 계정에 **영구 적용**한다(홈으로 복사). 반면 공유 계정이나 임시 서버처럼 **그 계정 환경을 건드리고 싶지 않을 때**는 `enter.sh`를 쓴다.

`enter.sh`는 아무것도 복사하지 않는다. 대신 `$HOME`(과 `XDG_*`)을 이 체크아웃으로 돌린 뒤 인터랙티브 셸을 띄운다. bash의 `~`·startup 파일·`git --global`·ssh·vim·fzf·starship·zoxide 등이 전부 `$HOME` 기준으로 홈을 찾으므로, **이 dotfiles로 로그인한 것처럼** 쓰인다. 계정 본래의 `~/.bashrc` 등은 아예 읽지 않는다.

```sh
# 대상 호스트에 별도 디렉터리로 clone → 이 체크아웃이 곧 휴대용 HOME
git clone https://github.com/tot0rokr/dotfiles.git ~/.myhome

~/.myhome/enter.sh                 # 인터랙티브 진입
~/.myhome/enter.sh tmux            # 전용 소켓으로 tmux 진입
ssh host -t '~/.myhome/enter.sh'   # SSH 접속 즉시 내 환경으로
```

되돌리기는 `rm -rf ~/.myhome` 하나면 끝(계정은 손댄 적 없음). 런타임 산출물(툴 설치·캐시·`.tmux/plugins`)은 전부 이 dir 안에 들어가고 `.gitignore`가 자동으로 무시한다.

한계: `$USER`/`whoami`/`id`, `~다른유저` 확장, `sudo`(HOME 리셋)는 여전히 실제 계정을 가리킨다. HOME은 "홈을 어디서 찾을지" 화살표만 바꾸는 것이지 chroot가 아니다. 또한 repo-local `.git/config`처럼 더 구체적인 설정원은 전역(`~/.gitconfig`)을 이기므로 HOME과 무관하게 그대로 적용된다.


### Desktop 사용

- mpv 설치
    - `sudo apt install mpv`
- ffmpeg 설치
    - `sudo apt install ffmpeg`
- yt-dlp 설치
    - https://github.com/yt-dlp/yt-dlp?tab=readme-ov-file#release-files
- img2sixel 설치
    - `sudo apt install libsixel-bin`
- timg 설치
    - `sudo apt install timg`
- ranger 설치
    - `sudo apt install ranger`


### Windows Xming from X11 on ssh

1. ✅ 1. Windows에서 Xming 실행
    - ```
    Xming을 실행할 때 반드시 **XLaunch**를 이용해서 다음처럼 설정해야 합니다:
    Multiple windows
    Start no client
    Clipboard: 체크 (optional)
    No access control ← 이거 꼭 체크하세요 (그래야 외부 접속 허용됨)
    ```
    - Xming 바로가기 파일 속성에 -ac 추가
1. SSH 접속 시 -X 또는 -Y 옵션 사용
    ```
    ssh -X <id>@<ubuntu-ip>
    ssh -Y <id>@<ubuntu-ip>
    ```
1. Server SSH 설정(/etc/ssh/sshd_config)
    ```
    X11Forwarding yes
    X11DisplayOffset 10
    X11UseLocalhost no
    ```
    sudo systemctl restart ssh
1. $DISPLAY 설정(.bashrc에 해놨음)

## If Linux Desktop

### Keyboard mapping

https://github.com/jtroo/kanata/releases
에서 kanata 설치 -> $HOME/.bin/kanata 로 저장

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

.xprofile에 kime 사용 등록
```sh
export GTK_IM_MODULE=kime
export QT_IM_MODULE=kime
export XMODIFIERS=@im=kime
```

그 다음 `systemctl daemon-reload / start / enable`


### Kime (Korean input)

참고: https://osg.kr/archives/3109

1. 설치

    ```sh
    sudo apt install kime
    ```

2. IM 등록 (`im-config`로 kime 선택 또는 `~/.xinputrc`에 `run_im kime`)

    ```sh
    im-config -n kime
    ```

    `.xprofile` / `.profile` 환경변수 (dotfiles에 포함):

    ```sh
    export GTK_IM_MODULE=kime
    export QT_IM_MODULE=kime
    export XMODIFIERS=@im=kime
    ```

3. GNOME 입력소스에서 ibus 제거 (안 하면 한/영 토글이 ibus-hangul로 가서 kime 레이아웃이 안 먹음)

    ```sh
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
    pkill -f 'ibus-(daemon|engine|x11|portal|dconf|extension)'
    ```

4. 설정 파일 배치 (dotfiles에 포함되어 있음)

    - `~/.config/kime/config.yaml` — 신세벌식 P2 (`sebeolsik-3sin-p2`), `ComposeChoseongSsang` + `ComposeJongseongSsang` (세벌식 한정)
    - 한/영 토글 키: 우측 Alt, Hangul, Muhenkan, Super+Space, Shift+Space

5. 데몬 기동

    ```sh
    pkill -x kime; pkill -x kime-indicator; pkill -x kime-xim
    nohup kime >/dev/null 2>&1 & disown
    ```


### Gnome-shell-extensions

sudo apt install gnome-shell-extensions
sudo apt install gnome-tweaks
https://support.system76.com/articles/pop-keyboard-shortcuts/
https://github.com/pop-os/shell

### Audio

sudo apt install pavucontrol    # audio manager

### Bluetooth

sudo apt install blueman        # bluetooth manager


### TMUX

```
# 1. 필요 패키지 설치
sudo apt update
sudo apt install -y git build-essential libevent-dev libncurses-dev bison pkg-config autotools-dev automake

# 2. 최신 tmux 소스 클론
git clone https://github.com/tmux/tmux.git
cd tmux

# 3. 최신 안정 버전으로 체크아웃 (예: 3.3a)
git checkout 3.3a

# 4. 빌드
sh autogen.sh
./configure
make

# 5. 설치 (옵션)
sudo make install
```


### Kitty

~/.config/kitty/kitty.conf

```
# Truecolor 활성화
enable_true_color yes

# 외부 앱이 kitty 기능 제어 가능하게 허용
allow_remote_control yes

# (선택) 기본 TERM
term xterm-kitty
```

.tmux.conf

```
set -ga terminal-overrides ',xterm-kitty:Tc:sitm=\E[3m' # kitty

# 256 color
set -g default-terminal "xterm-kitty" # kitty

# true color
set -as terminal-features ',xterm-kitty:RGB' # kitty

# 터미널 에뮬레이터 고유 기능 사용을 위해 escape sequences tmux가 가로채지 않도록 하는 기능
set -g allow-passthrough on # kitty
```


## WezTerm (Windows) — SSH 런처

Windows 클라이언트의 WezTerm 설정은 두 파일로 나뉩니다.

- `~/.wezterm.lua` — **이 머신 전용** 진입점. SSH 서버 레지스트리(호스트/IP)를 여기에만 적습니다. 내부 IP가 들어가므로 **레포에 커밋하지 않습니다.**
- `~/.wezterm.common.lua` — **포터블**(dotfiles 추적). 키맵·외관·테마 토글과 SSH 런처 빌더가 들어 있습니다.

`~/.wezterm.lua`의 `servers` 목록에 항목을 추가하면 런처(`Ctrl+Shift+Alt+L`)에 `SSH <name>` / `BTOP on <name>` 메뉴가 자동 생성됩니다.

```lua
local servers = {
  { name = "Dev", host = "192.168.0.42", user = "you",
    enter = "tmux attach || tmux new-session", autossh = true },
}
```

| 필드 | 설명 |
|------|------|
| `name`    | 런처에 표시될 라벨 |
| `host`    | IP·호스트명·`~/.ssh/config` 별칭 |
| `user`    | (선택) SSH 사용자명 |
| `key`     | (선택) 개인키 파일명(`$HOME` 기준). 생략 시 기본 키(`~/.ssh/id_ed25519`) 사용 |
| `cwd`     | (선택) 런처 프로세스의 작업 디렉터리 |
| `enter`   | (선택) 접속 시 실행할 원격 명령. 예: `tmux attach \|\| tmux new-session` |
| `autossh` | (선택) `true`면 끊겨도 자동 재접속(PS 재시도 루프 + ServerAlive 키프얼라이브) |

### Windows는 SSH 키 인증만 — 비밀번호 자동입력을 쓰지 않는 이유

런처는 Windows에서 **네이티브 OpenSSH(`C:\Windows\System32\OpenSSH\ssh.exe`)만** 사용하고 인증은 **SSH 키**로 합니다. 비밀번호 자동입력을 두 방식으로 시도했으나 모두 실패했기 때문입니다.

- **sshpass + MSYS2 ssh** — sshpass는 같은 MSYS2 런타임으로 빌드된 ssh의 프롬프트만 가로챌 수 있어 `C:\msys64\usr\bin\ssh.exe`를 써야 하는데, 이 Cygwin PTY 계층이 WezTerm의 ConPTY 위에서 tty 출력을 바이트 단위 저속 경로로 떨궈 **스크롤·출력이 기어갑니다.** (네트워크·GPU 문제가 아니라 로컬 PTY 변환 오버헤드 — 로컬 VM까지 동일하게 느려짐.)
- **plink (PuTTY)** — charset을 지정하는 CLI 옵션이 없어 원격 UTF-8을 시스템 코드페이지(CP949)로 오독해 **한글 mojibake**가 나고, 기본 `-sanitise-stdout`이 제어문자(ESC)를 `?`로 뭉개 **tmux·nvim·powerline이 깨집니다.**

네이티브 ssh는 바이트를 그대로 흘려보내 UTF-8·ANSI가 완벽하고 빠릅니다. (Unix 쪽은 Cygwin 페널티가 없어 `server.password` + `sshpass` 옵션이 그대로 유효합니다.)

### 키 등록 (일회성, PowerShell)

```powershell
# 1) 키 생성 (무passphrase — 무인 재접속용)
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\id_ed25519 -C "me@wezterm"

# 2) 서버에 공개키 등록 — 비번 1회 입력
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh you@192.168.0.42 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"

# 3) 확인 — 비번 없이 hostname이 뜨면 성공
ssh you@192.168.0.42 hostname
```

> **PowerShell 5.1 함정:** 원격 명령 문자열 안에 `"$VAR"` 처럼 따옴표+변수를 넣으면 PS가 ssh로 넘기며 따옴표를 뭉개(native 인자 파싱 버그), 원격 셸에서 단어 분할이 일어납니다. 위처럼 공개키는 **stdin으로만** 흘리고(`Get-Content | ssh … "cat >> …"`) 원격 명령에는 따옴표·`$`를 쓰지 마세요.

등록 후 WezTerm을 재시작하고 런처로 접속하면 비번 없이 붙고 tty도 빠릅니다.
