-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local home = wezterm.home_dir
local sep  = package.config:sub(1,1)  -- 윈도우 '\' / 유닉스 '/'

-- This is where you actually apply your config choices.
-- config.default_prog = { "/bin/bash" }

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
  mods = 'CTRL|SHIFT',
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

-- 탭 닫기: Ctrl+Shift+W
{
  key = 'W',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.CloseCurrentTab { confirm = true },
},
-- 전체화면
{
  key = 'Enter',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ToggleFullScreen,
},
-- 새창
{
  key = 'N',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.SpawnWindow,
},
-- 탭 이동
{
  key = '1',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ActivateTab(0),
},
{
  key = '2',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ActivateTab(1),
},
{
  key = '3',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ActivateTab(2),
},
{
  key = '4',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ActivateTab(3),
},
-- Search
{
  key = 'F',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.Search 'CurrentSelectionOrEmptyString',
},
-- 커맨드 선택
{
  key = 'P',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.ActivateCommandPalette,
},
-- 테마 토글
{
  key = 'T',
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
    mods = "CTRL|SHIFT",
    action = wezterm.action.ShowLauncher,
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

-------------

-- Finally, return the configuration to wezterm:
return config