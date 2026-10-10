# Champagne Ridge low-power motion

User-owned fork of Omarchy background. Keeps wallpaper selection, click handlers and theme transitions.

- Uses one cached still image, decoded near display resolution.
- Slow pan: 144-second cycle, frame-synchronised interpolation, 2.4% overscan.
- Reduced travel: 0.4% horizontal and 0.15% vertical, filtered texture translation.
- Pausing preserves the current position; no brightness pulsation.
- Stops on ANY app window on the active workspace, special workspace, 20 seconds without input, or display DPMS off (within 2 seconds while active).
- No video decoder, extra process, custom shader, blur pass, or animation while paused.
- Monitor status uses internal Hyprland IPC every 2 seconds only while an empty active desktop could animate.
- Idle timer ignores inhibitors so media playback does not keep wallpaper animation awake.

Runtime controls (until shell restart):
```
omarchy shell background setMotion false
omarchy shell background setMotion true
omarchy shell background motionStatus
```

Restore stock renderer permanently:
Use `omarchy plugin disable lovehouse.background` and `omarchy plugin enable omarchy.background`, then `omarchy restart shell`.
Original unmodified source is Background.qml.original.

Verification: real empty workspace increased tick counter; occupied workspace held counter constant. Test screenshots saved under /tmp/motion-before.png and /tmp/motion-after.png. Whole-shell CPU sample includes bar and all plugins, so is not an isolated wallpaper CPU benchmark.
