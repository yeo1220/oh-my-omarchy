import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Ui

BarIndicator {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property string signature: {
    var powered = adapter && adapter.enabled ? "1" : "0"
    var addresses = []
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (device && device.connected) addresses.push(String(device.address || device.name || i))
    }
    addresses.sort()
    return powered + "|" + addresses.join(",")
  }
  readonly property int connectedCount: {
    var count = 0
    for (var i = 0; i < devices.length; i++)
      if (devices[i] && devices[i].connected) count++
    return count
  }

  property double startedAt: Date.now()
  property bool flashing: false

  active: flashing
  activeText: !adapter || !adapter.enabled ? "󰂲" : (connectedCount > 0 ? "󰂱" : "󰂯")
  inactiveText: "󰂯"
  activeTooltipText: connectedCount > 0 ? "블루투스 기기 " + connectedCount + "대 연결됨" : "블루투스 상태가 바뀌었습니다"
  inactiveTooltipText: "블루투스"

  onPressed: function() {
    if (root.bar) root.bar.run("omarchy-shell shell toggle omarchy.bluetooth")
  }

  onSignatureChanged: {
    if (Date.now() - startedAt < 10000) return
    flashing = true
    flashTimer.restart()
  }

  Timer {
    id: flashTimer
    interval: 8000
    onTriggered: root.flashing = false
  }
}
