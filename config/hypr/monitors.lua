-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- LG TV: EDID preferred timing is 1366x768 at 59.79 Hz (native panel resolution).
-- Match the display description so another HDMI monitor keeps auto detection.
-- 1920x1080 was tried but the TV downscales it to the 1366x768 panel, which
-- softens text and causes eye strain. Native mode avoids the TV scaler.
hl.monitor({
  output = "desc:LG Electronics 2D HD LG TV 0x01010101",
  mode = "1366x768@59.79",
  position = "auto",
  scale = 1,
})
-- Previous trial (blurry, TV rescales to panel):
-- hl.monitor({
--   output = "desc:LG Electronics 2D HD LG TV 0x01010101",
--   mode = "1920x1080@60",
--   position = "auto",
--   scale = 1,
-- })
