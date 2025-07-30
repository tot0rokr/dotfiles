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
