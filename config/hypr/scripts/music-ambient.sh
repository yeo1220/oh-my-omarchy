#!/usr/bin/env bash
# systemd owns the single instance and restarts it after unexpected exits.
systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
exec systemctl --user start music-ambient.service
