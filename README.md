# Integrated Bash Eenvironment

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

https://osg.kr/archives/3109


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
