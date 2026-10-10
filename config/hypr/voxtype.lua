-- Voxtype ↔ Hyprland 연동 (voxtype config.toml의 pre_recording/pre_output/post_output_command와 짝)
--
-- voxtype_recording : 녹음·전사 중 활성. F12로 취소. F9/SUPER+CTRL+X는 여기서도 동작해야 하므로 다시 바인딩.
-- voxtype_suppress  : 텍스트 타이핑 중 활성. 늦게 뗀 modifier 키(Super/Ctrl/Alt/Shift)가 단축키를 오발동하지 않게 무시.
-- 어느 submap에서든 SUPER+ESCAPE 로 강제 복귀 가능 (혹시 갇혔을 때 비상구).
-- 주의: voxtype_suppress 안에 Escape를 바인딩하면 wtype 첫 글자가 사라지므로 바인딩하지 않음.

if o.cmd_present("voxtype") then
  hl.define_submap("voxtype_recording", function()
    o.bind("F9", "Stop dictation (push-to-talk)", "voxtype record stop", { release = true })
    o.bind("SUPER + CTRL + X", "Toggle dictation", "voxtype record toggle")
    hl.bind("F12", function()
      hl.dispatch(hl.dsp.exec_cmd("voxtype record cancel"))
      hl.dispatch(hl.dsp.submap("reset"))
    end, { description = "Cancel dictation" })
    hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
  end)

  hl.define_submap("voxtype_suppress", function()
    for _, key in ipairs({ "SUPER_L", "SUPER_R", "Control_L", "Control_R", "Alt_L", "Alt_R", "Shift_L", "Shift_R" }) do
      hl.bind(key, hl.dsp.no_op())
    end
    hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
  end)
end
