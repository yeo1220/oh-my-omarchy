import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property int count: 0
  property string packages: ""

  active: count > 0
  activeText: count > 9 ? "9+" : String(count)
  inactiveText: activeText
  activeTooltipText: count > 0 ? "대기 중인 앱 " + count + "개\n" + packages + "\n클릭하면 이 앱만 갱신합니다" : "대기 중인 앱 없음"
  inactiveTooltipText: activeTooltipText

  onPressed: function() {
    if (!root.bar || root.count < 1) return
    root.bar.run("omarchy-launch-floating-terminal-with-presentation lovehouse-app-update")
  }

  Process {
    id: pendingProc
    command: [Quickshell.env("HOME") + "/.local/bin/lovehouse-app-updates"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n").filter(function(line) { return line !== "" })
        root.count = lines.length
        root.packages = lines.join("\n")
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.count = 0
        root.packages = ""
      }
    }
  }

  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!pendingProc.running) pendingProc.running = true
  }
}
