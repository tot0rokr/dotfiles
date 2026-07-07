-- ~/.wezterm.lua - WezTerm entry point.
-- Portable/shared config lives in ~/.wezterm.common.lua (tracked in dotfiles).
-- This file holds only THIS machine's SSH server registry — fill it in per host.
-- Do NOT commit real hosts/IPs back to the dotfiles repo; keep them machine-local
-- (same idea as the "machine-specific" section of ~/.bashrc).
local wezterm = require 'wezterm'
local config  = wezterm.config_builder()

local home = wezterm.home_dir
local sep  = package.config:sub(1,1)  -- 윈도우 '\' / 유닉스 '/'

-- ================================================================
-- SSH 서버 레지스트리 (이 머신 전용 — 여기에 직접 서버를 추가하세요)
-- 여기에 추가한 항목은 아래 launch menu(Ctrl+Shift+Alt+L)로 자동 생성됩니다.
--   name : 런처에 표시될 라벨
--   host : IP 주소, 호스트명, 또는 ~/.ssh/config 별칭
--   user : (선택) SSH 사용자명. 호스트 별칭에 이미 user가 있으면 생략 가능
--   key  : (선택) 개인키 파일명. $HOME 아래에서 탐색
--   cwd  : (선택, Windows 전용) cmd.exe의 작업 디렉터리
--   enter: (선택) 접속 시 실행할 원격 명령. 지정하면 "SSH <name>"
--          런처가 `ssh ... -t <enter>` 형태로 이 명령을 실행합니다.
--
-- 새 서버 항목 추가 시 일회성 SSH 키 등록 절차:
--
--   1. Ed25519 키 쌍 생성 (편한 쪽에서 만들면 됨. 최종적으로 개인키는
--      클라이언트에, 공개키는 서버에 있어야 합니다):
--        ssh-keygen -t ed25519 -f <key>.pem -C "<label>"
--      <key>.pem(개인키)과 <key>.pem.pub(공개키)이 생성됩니다.
--
--   2. 공개키를 서버 사용자의 authorized_keys에 등록:
--        ssh-copy-id -i <key>.pem.pub <user>@<host>
--      또는 서버에서 수동으로:
--        mkdir -p ~/.ssh && chmod 700 ~/.ssh
--        cat <key>.pem.pub >> ~/.ssh/authorized_keys
--        chmod 600 ~/.ssh/authorized_keys
--
--   3. 개인키를 Windows 클라이언트의 <cwd>\<key> 경로에 배치.
--      예: C:\Users\<you>\id_ed25519.pem
--      scp 등 안전한 채널로 전송하세요. 이메일/메신저로는 절대 보내지 말 것.
--
--   4. Windows에서 개인키 ACL을 잠가야 OpenSSH가 거부하지 않습니다
--      (PowerShell):
--        icacls $HOME\<key> /inheritance:r
--        icacls $HOME\<key> /grant:r "$($env:USERNAME):(R)"
--      Unix 동등: chmod 600 <key>
--
--   5. 클라이언트에서 비밀번호 없이 로그인되는지 확인:
--        ssh -i $HOME\<key> <user>@<host>
--      성공하면 자동 생성되는 "SSH <name>" / "BTOP on <name>" 런처 항목도
--      그대로 동작합니다.
-- ================================================================
local servers = {
  -- Examples:
  -- { name = "Dev",     host = "192.168.0.42", user = "you", key = "id_ed25519.pem", cwd = [[C:\Users\you]] },
  -- { name = "Aliased", host = "my-host-alias-from-ssh-config" },
  -- { name = "Box",     host = "10.0.0.5", user = "me", enter = "~/dotfiles/enter.sh ~" },
}

-- 공용 설정 적용 (dotfiles-tracked). common 을 수정하면 자동 리로드되도록 감시목록에 추가.
wezterm.add_to_config_reload_watch_list(home .. sep .. ".wezterm.common.lua")
dofile(home .. sep .. ".wezterm.common.lua").apply(config, servers)

return config
