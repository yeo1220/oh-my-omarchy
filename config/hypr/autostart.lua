-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- clipse clipboard history daemon (TUI opens with SUPER + SHIFT + V).
o.exec_on_start("clipse -listen")

-- Music ambient reactive effects daemon.
o.exec_on_start(os.getenv("HOME") .. "/.config/hypr/scripts/music-ambient.sh")

