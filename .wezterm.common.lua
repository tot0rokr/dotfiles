-- ~/.wezterm.common.lua - shared, dotfiles-tracked WezTerm configuration.
-- Portable settings live here: keybindings, appearance, the SSH launcher
-- builder, and the theme/background toggles. This machine's SSH server
-- registry is defined in ~/.wezterm.lua and passed into M.apply(config, servers).
local wezterm = require 'wezterm'

local M = {}

local home = wezterm.home_dir
local sep  = package.config:sub(1,1)  -- 윈도우 '\' / 유닉스 '/'

-- Build an `ssh` (or `autossh`) argv for the given server.
--   key_prefix : path prefix prepended to `server.key` (e.g. ".\\" on Windows,
--                "$HOME/" on Unix). Ignored when the server has no key.
--   opts.remote_cmd : optional command to run on the remote (e.g. "btop").
--                     When set, `-t` is added so the remote command gets a TTY.
--   opts.autossh_bin : when true, prefix with real `autossh -M 0` (Unix).
--   opts.keepalive   : when true, add ServerAlive* opts so ssh detects a
--                      stalled TCP session in ~6s (used by both real autossh
--                      on Unix and the PS retry-loop wrapper on Windows).
local function build_ssh_argv(server, key_prefix, opts)
  opts = opts or {}
  local remote_cmd = opts.remote_cmd
  local argv
  if opts.autossh_bin then
    argv = { "autossh", "-M", "0" }
  else
    argv = { "ssh" }
  end
  if opts.keepalive then
    table.insert(argv, "-o"); table.insert(argv, "ServerAliveInterval=3")
    table.insert(argv, "-o"); table.insert(argv, "ServerAliveCountMax=2")
  end
  if server.key then
    table.insert(argv, "-i")
    table.insert(argv, (key_prefix or "") .. server.key)
  end
  table.insert(argv, remote_cmd and "-t" or "-Y")
  local target = server.host
  if server.user and server.user ~= "" then
    target = server.user .. "@" .. server.host
  end
  table.insert(argv, target)
  if remote_cmd then
    table.insert(argv, remote_cmd)
  end
  return argv
end

-- Three independent per-server switches:
--   server.enter (string)   : optional remote command. 그대로 `ssh -t host <enter>`
--                             에 전달됨. tmux/체이닝/무엇이든 이 문자열 안에서
--                             직접 조립하세요.
--                               예: enter = "tmux attach || tmux new-session"
--                                   enter = "~/enter.sh; tmux attach || tmux new-session"
--   server.autossh (bool)   : true면 autossh(또는 PATH의 autossh shim)로 실행.
--                             ssh가 stall/drop 시 자동 재시도. enter와 무관하게
--                             독립적으로 켜고 끌 수 있음. 원격 상태를 유지하려면
--                             enter에 tmux를 함께 넣어두는 게 일반적.
--   server.password (str)   : optional plaintext password. 있으면 sshpass 로
--                             매 접속 자동 인증. 재접속마다 조용히 붙음.
--                             .wezterm.lua는 machine-local — repo에 절대 커밋 금지.
--                             sshpass 바이너리가 PATH 에 있어야 함.
local function has_enter(server) return server.enter and server.enter ~= "" end

local function ssh_remote_cmd(server)
  if has_enter(server) then return server.enter end
  return nil
end

-- NOTE (Windows): the launcher uses NATIVE Windows OpenSSH (ssh.exe) only.
-- Password auto-fill on Windows was tried two ways and both failed:
--   * sshpass needs MSYS2 ssh, whose Cygwin PTY layer makes tty output crawl
--     under WezTerm's ConPTY (스크롤/출력이 기어감).
--   * plink has no charset flag → mangles UTF-8 as CP949, and sanitises
--     control bytes (ESC → '?'), breaking tmux/nvim/powerline.
-- So on Windows we authenticate with SSH KEYS: native ssh passes UTF-8/ANSI
-- through untouched and stays fast. (Unix still supports optional sshpass
-- password auth below — Linux ssh has no Cygwin PTY penalty.)

-- PS-literal for a Lua string: single-quoted, with any embedded ' doubled.
local function ps_single_quote(a)
  return "'" .. a:gsub("'", "''") .. "'"
end

-- Build a PowerShell -Command string that:
--   1) Emits OSC 2 (tab-title escape) so the tab is auto-labeled.
--   2) Runs `prog` (native Windows OpenSSH `ssh`, supplied by the caller)
--      with `argv` splatted through PS's `&` operator, which passes argv
--      straight to the exe. This bypasses
--      cmd.exe's fragile arg parsing — a prior `.cmd` shim
--      (`~/bin/autossh.cmd`) truncated remote commands at `||` and split
--      `Key=Value` args at the `=`.
--   3) Optionally wraps the invocation in a retry loop (autossh-style).
-- ESC/BEL via [char]27/[char]7 keeps this compatible with PS 5.1 (no
-- backtick-e / backtick-a escapes, no ||/&& pipeline operators).
local function ps_launcher_win(title, prog, argv, retry)
  local args_parts = {}
  for _, a in ipairs(argv) do
    args_parts[#args_parts + 1] = ps_single_quote(a)
  end
  local args_lit = "@(" .. table.concat(args_parts, ",") .. ")"

  local head =
    '[Console]::Write(([char]27) + "]2;' .. title .. '" + ([char]7)); ' ..
    '$prog = ' .. ps_single_quote(prog) .. '; ' ..
    '$sshArgs = ' .. args_lit .. '; '

  if retry then
    return head ..
      'while ($true) { & $prog @sshArgs; ' ..
      'if ($LASTEXITCODE -eq 0) { break }; ' ..
      'Write-Host ""; ' ..
      'Write-Host ("[autossh] ssh exited " + $LASTEXITCODE + ", retrying in 1s... (Ctrl+C to stop)"); ' ..
      'Start-Sleep -Seconds 1 }'
  else
    return head .. '& $prog @sshArgs'
  end
end

-- Append per-server menu entries (SSH + BTOP) to `menu`.
-- Each entry sets an initial tab title (server name-based) via OSC 2 so
-- tabs are auto-labeled without needing the Ctrl+Shift+Alt+R rename.
-- Windows uses powershell.exe as the wrapper (only way to reliably emit
-- the ESC byte inline, and PS's & operator preserves argv into exes).
-- Unix uses printf + sh -c.
-- When `server.password` is set, SSHPASS is exported so the PS launcher
-- (Windows) or a manually-added sshpass wrapper (Unix) can authenticate.
local function append_server_entries(menu, platform, servers)
  for _, s in ipairs(servers) do
    local key_prefix = home .. sep
    local has_pw     = s.password and s.password ~= ""
    local env = has_pw and { SSHPASS = s.password } or nil
    local ssh_title  = s.name
    local btop_title = "BTOP " .. s.name

    if platform == "windows" then
      -- Windows: native OpenSSH ssh only (see the NOTE near the top). No
      -- autossh binary / no -M 0; the retry loop lives in PS. Auth is via SSH
      -- keys, so reconnects are silent. If a server has no key enrolled yet,
      -- native ssh simply prompts for the password interactively.
      local ssh_argv  = build_ssh_argv(s, key_prefix,
        { remote_cmd = ssh_remote_cmd(s), keepalive = s.autossh })
      local btop_argv = build_ssh_argv(s, key_prefix, { remote_cmd = "btop" })
      -- Drop the leading "ssh" — ps_launcher_win supplies the program itself.
      table.remove(ssh_argv,  1)
      table.remove(btop_argv, 1)
      table.insert(menu, {
        label = "SSH " .. s.name,
        args  = { "powershell.exe", "-NoLogo", "-NoProfile", "-NoExit",
                  "-Command", ps_launcher_win(ssh_title, "ssh", ssh_argv, s.autossh) },
        cwd   = s.cwd or home,
      })
      table.insert(menu, {
        label = "BTOP on " .. s.name,
        args  = { "powershell.exe", "-NoLogo", "-NoProfile", "-NoExit",
                  "-Command", ps_launcher_win(btop_title, "ssh", btop_argv, false) },
        cwd   = s.cwd or home,
      })
    else
      -- Unix: real autossh binary handles retry + keepalive.
      local ssh_argv  = build_ssh_argv(s, key_prefix,
        { remote_cmd = ssh_remote_cmd(s), autossh_bin = s.autossh, keepalive = s.autossh })
      local btop_argv = build_ssh_argv(s, key_prefix, { remote_cmd = "btop" })
      if has_pw then
        -- Prepend sshpass -e to both argvs (drop leading "ssh"/"autossh" prog).
        local function wrap(argv)
          local out = { "sshpass", "-e" }
          for i = 1, #argv do out[#out + 1] = argv[i] end
          return out
        end
        ssh_argv  = wrap(ssh_argv)
        btop_argv = wrap(btop_argv)
      end
      local ssh_cmd  = table.concat(ssh_argv,  " ")
      local btop_cmd = table.concat(btop_argv, " ")
      local function prefix(t) return "printf '\\033]2;" .. t .. "\\007'; exec " end
      table.insert(menu, {
        label = "SSH " .. s.name,
        args  = { "sh", "-c", prefix(ssh_title)  .. ssh_cmd  },
        set_environment_variables = env,
      })
      table.insert(menu, {
        label = "BTOP on " .. s.name,
        args  = { "sh", "-c", prefix(btop_title) .. btop_cmd },
        set_environment_variables = env,
      })
    end
  end
end

-- Apply all shared configuration to `config`, building the launch menu from the
-- caller-supplied `servers` registry (may be empty).
function M.apply(config, servers)
  servers = servers or {}

  -- default_prog + launch menu (platform-specific), then per-server entries.
  if wezterm.target_triple:find("windows") then
    config.default_prog = { "powershell.exe", "-NoLogo"  }
    config.launch_menu = {
      { label = "PowerShell", args = { "powershell.exe" } },
      { label = "PowerShell 7", args = { "pwsh.exe" } },
      { label = "CMD", args = { "cmd.exe" } },
      -- UAC 프롬프트 → 관리자 cmd.exe가 별도 OS 윈도우로 뜸 (wezterm 탭 안에선 권한 격상 불가)
      { label = "Admin CMD", args = { "powershell.exe", "-NoProfile", "-Command", "Start-Process -Verb RunAs cmd.exe" } },
      { label = "Admin PowerShell", args = { "powershell.exe", "-NoProfile", "-Command", "Start-Process -Verb RunAs powershell.exe" } },
    }
    append_server_entries(config.launch_menu, "windows", servers)

  elseif wezterm.target_triple:find("darwin") then
    -- macOS
    config.default_prog = { "/bin/zsh", "-l" }
    config.launch_menu = {
      { label = "zsh (login)", args = { "/bin/zsh", "-l" } },
    }
    append_server_entries(config.launch_menu, "darwin", servers)

  elseif wezterm.target_triple:find("linux") then
    -- Linux
    config.default_prog = { "/bin/bash", "-l" }
    config.launch_menu = {
      { label = "bash (login)", args = { "/bin/bash", "-l" } },
    }
    append_server_entries(config.launch_menu, "linux", servers)
  end

  config.canonicalize_pasted_newlines = "LineFeed"

  -- config.ssh_domains = {
  --  {
  --    name = "dev-server",
  --    remote_address = "192.168.0.42",
  --    username = "user",
  --  },
  --}

  -- config.audible_bell = "SystemBeep"
  -- config.enable_tab_bar = true
  -- config.hide_tab_bar_if_only_one_tab = true
  -- config.use_fancy_tab_bar = true

  config.window_decorations = "RESIZE"
  config.scrollback_lines = 10000
  config.force_reverse_video_cursor = true

  -- 단축키
  config.disable_default_key_bindings = true
  config.keys = {
      -- 복사: Ctrl+Shift+C
      {
        key = 'C',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.CopyTo 'Clipboard',
      },
      -- 붙여넣기: Ctrl+Shift+V
      {
        key = 'V',
        mods = 'CTRL|SHIFT',
        action = wezterm.action.PasteFrom 'Clipboard',
      },
  -- 새 탭: Ctrl+Shift+T
  {
    key = 'T',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SpawnTab 'CurrentPaneDomain',
  },

  -- 탭 전환 (다음/이전): Ctrl+Tab / Ctrl+Shift+Tab
  {
    key = 'Tab',
    mods = 'CTRL',
    action = wezterm.action.ActivateTabRelative(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.ActivateTabRelative(-1),
  },

  -- 탭 순서 이동: Ctrl+Shift+Alt+PageUp/PageDown
  {
    key = 'PageUp',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.MoveTabRelative(-1),
  },
  {
    key = 'PageDown',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.MoveTabRelative(1),
  },

  -- 탭 닫기
  {
    key = 'W',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.CloseCurrentTab { confirm = true },
  },
  -- 탭 이름 변경: Ctrl+Shift+Alt+R
  {
    key = 'R',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.PromptInputLine {
      description = '새 탭 이름 입력 (빈 값 = 자동 제목으로 복귀)',
      action = wezterm.action_callback(function(window, pane, line)
        -- line == nil : ESC로 취소 / '' : 빈 입력 → 자동 제목 복귀
        if line then
          window:active_tab():set_title(line)
        end
      end),
    },
  },
  -- 전체화면
  {
    key = 'Enter',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ToggleFullScreen,
  },
  -- 새창
  {
    key = 'N',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SpawnWindow,
  },
  -- 탭 이동
  -- { key = '1', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(0) },
  -- { key = '2', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(1) },
  -- { key = '3', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(2) },
  -- { key = '4', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(3) },
  -- { key = '5', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(4) },
  -- { key = '6', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(5) },
  -- { key = '7', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(6) },
  -- { key = '8', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(7) },
  -- { key = '9', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivateTab(-1) },
  -- Search
  {
    key = 'F',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.Search 'CurrentSelectionOrEmptyString',
  },
  -- 커맨드 선택
  {
    key = 'P',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ActivateCommandPalette,
  },
  -- 테마 토글
  {
    key = 'M',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.EmitEvent 'toggle-theme',
  },
  -- 배경 화면 토글
      {
        key = 'B',
        mods = 'CTRL|SHIFT|ALT',
        action = wezterm.action.EmitEvent 'toggle-bg',
      },
  -- Launch menu
    {
      key = "L",
      mods = "CTRL|SHIFT|ALT",
      action = wezterm.action.ShowLauncher,
    },
  -- Pane split: Ctrl+Shift+Alt + H(가로 분할) / V(세로 분할)
  {
    key = 'H',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'V',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  -- Pane 이동: Ctrl+Shift+Alt + 화살표
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'RightArrow', mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT|ALT', action = wezterm.action.ActivatePaneDirection 'Down' },
  -- Pane 닫기: Ctrl+Shift+Alt+X
  {
    key = 'X',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.CloseCurrentPane { confirm = true },
  },
  -- Font size: Ctrl + (+/-/0)
  -- (+)는 키보드 레이아웃에 따라 '=' + SHIFT로 들어가는 경우가 많아서 둘 다 넣어둠
  {
    key = '=',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.DecreaseFontSize,
  },
  {
    key = '+',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.IncreaseFontSize,
  },
  {
    key = '_',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.DecreaseFontSize,
  },
  {
    key = '0',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ResetFontSize,
  },
  {
    key = ')',
    mods = 'CTRL|SHIFT|ALT',
    action = wezterm.action.ResetFontSize,
  },
  }

  config.exit_behavior = "Hold"

  config.set_environment_variables = {
    EDITOR = "nvim",
    LANG = "ko_KR.UTF-8",
  }

  -- For example, changing the initial geometry for new windows:
  config.initial_cols = 120
  config.initial_rows = 28

  config.font = wezterm.font { family = 'D2CodingLigature Nerd Font' }
  -- or, changing the font size and color scheme.
  config.font_size = 12
  -- 글자 크기 조절 시 창 크기는 고정하고 행/열 수만 조정 (창이 커졌다 줄었다 안 하게)
  config.adjust_window_size_when_changing_font_size = false
  -- config.color_scheme = 'BirdsOfParadise'
  config.color_scheme = 'BlulocoDark'
  -- config.color_scheme = 'Flatland'

  config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.8,
  }

  -- Background
  config.window_background_opacity = 0.95
  config.text_background_opacity = 0.9

  config.enable_scroll_bar = true
  -- config.min_scroll_bar_height = '2cell'
  config.colors = {
    scrollbar_thumb = 'black',
  }
end

-- 테마 토글
wezterm.on('toggle-theme', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.color_scheme then
    overrides.color_scheme = 'Flatland'
  else
    overrides.color_scheme = nil
  end
  window:set_config_overrides(overrides)
end)

-- Background layers (used by the toggle-bg handler below)
local bg_path = table.concat({ home, "terminal_background.jpg" }, sep)

local background = {
  -- This is the deepest/back-most layer. It will be rendered first
  {
    source = { File = bg_path, },
    -- The texture tiles vertically but not horizontally.
    -- When we repeat it, mirror it so that it appears "more seamless".
    -- An alternative to this is to set `width = "100%"` and have
    -- it stretch across the display
    repeat_x = 'Mirror',
    hsb = {
      brightness = 0.05,
      hue = 1.0,
      saturation = 1.0,
    },
    -- When the viewport scrolls, move this layer 10% of the number of
    -- pixels moved by the main viewport. This makes it appear to be
    -- further behind the text.
    attachment = { Parallax = 0.3 },
  },
  -- Subsequent layers are rendered over the top of each other
  {
    source = {
      File = '/Alien_Ship_bg_vert_images/Overlays/overlay_1_spines.png',
    },
    width = '100%',
    repeat_x = 'NoRepeat',

    -- position the spins starting at the bottom, and repeating every
    -- two screens.
    vertical_align = 'Bottom',
    repeat_y_size = '200%',
    hsb = dimmer,

    -- The parallax factor is higher than the background layer, so this
    -- one will appear to be closer when we scroll
    attachment = { Parallax = 0.2 },
  },
  {
    source = {
      File = '/Alien_Ship_bg_vert_images/Overlays/overlay_2_alienball.png',
    },
    width = '100%',
    repeat_x = 'NoRepeat',

    -- start at 10% of the screen and repeat every 2 screens
    vertical_offset = '10%',
    repeat_y_size = '200%',
    hsb = dimmer,
    attachment = { Parallax = 0.3 },
  },
}

wezterm.on('toggle-bg', function(window, pane)
  local overrides = window:get_config_overrides() or {}

  if overrides.background then
    print("🔄 배경화면 끔")
    overrides.background = nil
  else
    print("🖼️ 배경화면 켬")
    overrides.background = background
  end

  window:set_config_overrides(overrides)
end)

return M
