-- ~/.wezterm.common.lua - shared, dotfiles-tracked WezTerm configuration.
-- Portable settings live here: keybindings, appearance, the SSH launcher
-- builder, and the theme/background toggles. This machine's SSH server
-- registry is defined in ~/.wezterm.lua and passed into M.apply(config, servers).
local wezterm = require 'wezterm'

local M = {}

local home = wezterm.home_dir
local sep  = package.config:sub(1,1)  -- 윈도우 '\' / 유닉스 '/'

-- Build an `ssh` argv for the given server.
--   key_prefix : path prefix prepended to `server.key` (e.g. ".\\" on Windows,
--                "$HOME/" on Unix). Ignored when the server has no key.
--   remote_cmd : optional command to run on the remote (e.g. "btop").
--                When set, `-t` is added so the remote command gets a TTY.
local function build_ssh_argv(server, key_prefix, remote_cmd)
  local argv = { "ssh" }
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

-- Append per-server menu entries (SSH + BTOP) to `menu`.
local function append_server_entries(menu, platform, servers)
  for _, s in ipairs(servers) do
    if platform == "windows" then
      local key_prefix = home .. sep
      local ssh_line  = table.concat(build_ssh_argv(s, key_prefix, s.enter), " ")
      local btop_line = table.concat(build_ssh_argv(s, key_prefix, "btop"), " ")
      table.insert(menu, {
        label = "SSH " .. s.name,
        args  = { "cmd.exe", "/k", ssh_line },
        cwd   = s.cwd or home,
      })
      table.insert(menu, {
        label = "BTOP on " .. s.name,
        args  = { "cmd.exe", "/k", btop_line },
        cwd   = s.cwd or home,
      })
    else
      local key_prefix = home .. sep
      table.insert(menu, {
        label = "SSH " .. s.name,
        args  = build_ssh_argv(s, key_prefix, s.enter),
      })
      table.insert(menu, {
        label = "BTOP on " .. s.name,
        args  = build_ssh_argv(s, key_prefix, "btop"),
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
