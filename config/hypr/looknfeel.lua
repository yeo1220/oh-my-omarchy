-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Balanced desktop tuning for the 1366x768 LG display (2026-09-20).
-- Keep visible focus borders while reclaiming space on the small desktop.
hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 5,
    border_size = 2,
  },
})

-- Preserve Omarchy's curves and effects, with shorter window transitions.
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "easeOutQuint", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 95%" })

-- Midnight Orbit: compact proportions and softly rounded surfaces.
hl.config({
  general = { gaps_in = 4, gaps_out = 7, border_size = 2 },
  decoration = {
    rounding = 10,
    shadow = { enabled = true, range = 12, render_power = 3, color = "rgba(00000038)" },
  },
})

-- Smart gaps: No gaps or borders when only one tiled window is present.
-- Reclaims maximum screen real estate on the 1366x768 display.
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({
  name = "no-gaps-wtv1",
  match = { float = false, workspace = "w[tv1]" },
  border_size = 0,
  rounding = 0,
})
hl.window_rule({
  name = "no-gaps-f1",
  match = { float = false, workspace = "f[1]" },
  border_size = 0,
  rounding = 0,
})


-- Graphite Atelier: quiet outlines, compact spacing, soft elevation.
hl.config({
  general = { gaps_in = 4, gaps_out = 8, border_size = 1 },
  decoration = {
    rounding = 8,
    shadow = { enabled = true, range = 16, render_power = 3, color = "rgba(00000045)" },
  },
})
