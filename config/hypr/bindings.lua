-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Remote work hosts over Tailscale
o.bind("SUPER + SHIFT + R", "Remote Work", os.getenv("HOME") .. "/.local/bin/remote-work")

-- clipse clipboard manager. Omarchy's own manager stays on SUPER + CTRL + V.
-- The TUI.float app-id picks up Omarchy's floating-window rules automatically.
o.bind("SUPER + SHIFT + V", "Clipboard history (clipse)", "foot --app-id=TUI.float -e clipse")

-- Orbit Desk: focus timer, note and quick actions.
o.bind("SUPER + CTRL + SHIFT + O", "Orbit Desk", "omarchy shell shell toggle lovehouse.orbit")

o.bind("SUPER + CTRL + ALT + 1", "Orbit 작업 환경", os.getenv("HOME") .. "/.local/bin/orbit-tools scenes")
o.bind("SUPER + CTRL + ALT + 2", "Orbit 파일 선반", os.getenv("HOME") .. "/.local/bin/orbit-tools shelf")
o.bind("SUPER + CTRL + ALT + 3", "Orbit 전체 창", os.getenv("HOME") .. "/.local/bin/orbit-tools overview")
o.bind("SUPER + CTRL + ALT + 4", "Orbit 똑똑한 붙여넣기", os.getenv("HOME") .. "/.local/bin/orbit-tools paste")
o.bind("SUPER + CTRL + ALT + 5", "Orbit 문서 검색", os.getenv("HOME") .. "/.local/bin/orbit-tools search")
o.bind("SUPER + CTRL + ALT + 6", "Orbit 문구 자동 입력", os.getenv("HOME") .. "/.local/bin/orbit-tools snippets")
