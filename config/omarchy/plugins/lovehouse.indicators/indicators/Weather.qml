import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  property string status: ""
  property string temp: ""

  active: temp !== ""
  activeText: temp
  inactiveText: temp
  activeTooltipText: status !== "" ? status : "날씨"
  inactiveTooltipText: activeTooltipText
  fixedWidth: temp !== "" ? Math.max(Style.bar.statusSlot, temp.length * Style.font.caption * 0.62) : Style.bar.statusSlot

  function applyStatus(raw) {
    var text = String(raw || "").trim()
    status = text
    var match = text.match(/Temp\s+(-?\d+)/)
    temp = match ? match[1] + "°" : ""
  }

  onPressed: function() {
    if (!root.bar || root.status === "") return
    root.bar.run("omarchy-notification-send " + Util.shellQuote("날씨") + " " + Util.shellQuote(root.status))
  }

  Process {
    id: weatherProc
    command: ["omarchy-weather-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!weatherProc.running) weatherProc.running = true
  }
}
