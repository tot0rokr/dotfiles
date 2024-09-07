# Integrated Bash Eenvironment

## Step

### Install fonts

[Download Nerd Fonts](https://github.com/ryanoasis/nerd-fonts#font-installation)


### Install & Run

#### root

```
apt update \
&& apt install -y git \
&& rm -f ~/.* \
|| git clone https://github.com/tot0rokr/bash.git ~ \
&& bash
```

#### others

```
sudo apt update \
&& sudo apt install -y git \
&& rm -f ~/.* \
|| git clone https://github.com/tot0rokr/bash.git ~ \
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
