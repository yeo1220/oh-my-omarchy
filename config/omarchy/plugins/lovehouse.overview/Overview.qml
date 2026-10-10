import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property string query: ""
  property int workspaceFilter: 0
  readonly property var windows: Hyprland.toplevels.values.filter(function(w) {
    var data = w.lastIpcObject || {}
    return (!root.workspaceFilter || (w.workspace && w.workspace.id === root.workspaceFilter)) &&
      (w.title + " " + (data["class"] || "")).toLowerCase().indexOf(root.query.toLowerCase()) !== -1
  }).sort(function(a,b) { return (a.workspace ? a.workspace.id : 0) - (b.workspace ? b.workspace.id : 0) })
  function open(payload) {
    Hyprland.refreshToplevels()
    opened = true; query = ""; workspaceFilter = 0; search.text = ""; grid.currentIndex = 0
    Qt.callLater(function() { search.forceActiveFocus() })
  }
  function close() { opened = false }
  function toggle() { opened ? close() : open("{}") }
  function focusWindow(w) {
    if (!w) return
    var address = String(w.address)
    if (address.indexOf("0x") !== 0) address = "0x" + address
    close()
    Hyprland.dispatch('hl.dsp.focus({ window = "address:' + address + '" })')
  }
  function moveWindow(address, workspace) {
    if (!/^(0x)?[0-9a-f]+$/i.test(address)) return
    if (workspace < 1 || workspace > 10) return
    if (address.indexOf("0x") !== 0) address = "0x" + address
    Hyprland.dispatch('hl.dsp.window.move({ window = "address:' + address + '", workspace = "' + Number(workspace) + '", follow = false })')
    Hyprland.refreshToplevels()
  }
  function select(delta) { grid.currentIndex = Math.max(0, Math.min(windows.length - 1, grid.currentIndex + delta)); grid.positionViewAtIndex(grid.currentIndex, GridView.Contain) }
  IpcHandler {
    target: "lovehouse.overview"
    function open(): void { root.open("{}") }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function move(address: string, workspace: int): void { root.moveWindow(address, workspace) }
    function state(): string { return JSON.stringify({opened: root.opened, count: root.windows.length, previews: grid.contentItem.children.filter(function(c) { return c.previewReady === true }).length}) }
  }
  PanelWindow {
    id: panel
    visible: root.opened
    screen: Quickshell.screens.find(function(s) { return Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name }) || null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "orbit-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Rectangle { anchors.fill: parent; color: Qt.alpha(Color.background, 0.98) }
    Column {
      anchors.fill: parent
      anchors.margins: 32
      spacing: 16
      Row {
        width: parent.width
        Text { text: "◉  ORBIT OVERVIEW"; color: Color.accent; font.family: Style.font.family; font.pixelSize: 26; font.bold: true; width: parent.width - done.width }
        Button { id: done; text: "닫기 · Esc"; focusable: true; onClicked: root.close() }
      }
      Text { text: "창을 클릭해 전환 · 위의 작업 공간으로 드래그해 이동 · 방향키와 Enter로 선택"; color: Color.foreground; font.pixelSize: 13 }
      Row {
        width: parent.width; spacing: 8
        Button { text: "전체"; selected: root.workspaceFilter === 0; onClicked: root.workspaceFilter = 0 }
        Repeater {
          model: 10
          Button {
            id: workspaceButton
            required property int index
            text: "" + (index + 1)
            width: 50
            selected: root.workspaceFilter === index + 1 || drop.containsDrag
            onClicked: { root.workspaceFilter = index + 1; grid.currentIndex = 0 }
            DropArea {
              id: drop
              anchors.fill: parent
              keys: ["orbit-window"]
              onDropped: function(event) {
                if (event.source && event.source.address) { root.moveWindow(event.source.address, workspaceButton.index + 1); event.acceptProposedAction() }
              }
            }
          }
        }
      }
      TextField {
        id: search
        width: parent.width
        placeholderText: "창 제목이나 앱 이름으로 검색…"
        onTextChanged: { root.query = text; grid.currentIndex = 0 }
        onAccepted: root.focusWindow(root.windows[grid.currentIndex])
        Keys.onEscapePressed: root.close()
        Keys.onDownPressed: root.select(1)
        Keys.onUpPressed: root.select(-1)
        Keys.onTabPressed: root.select(1)
      }
      GridView {
        id: grid
        width: parent.width
        height: panel.height - 260
        clip: true
        cellWidth: width / Math.max(1, Math.floor(width / 300))
        cellHeight: 225
        model: root.windows
        delegate: Item {
          id: tile
          required property var modelData
          required property int index
          property bool previewReady: preview.hasContent
          width: grid.cellWidth; height: grid.cellHeight
          Rectangle {
            anchors.fill: parent; anchors.margins: 7
            color: Qt.alpha(Color.foreground, tile.index === grid.currentIndex ? 0.12 : 0.04)
            radius: 12; border.width: tile.index === grid.currentIndex ? 2 : 1
            border.color: tile.index === grid.currentIndex ? Color.accent : Qt.alpha(Color.foreground, 0.2)
            ScreencopyView {
              id: preview
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
              height: 148
              captureSource: root.opened ? tile.modelData.wayland : null
              live: root.opened
              constraintSize: Qt.size(width, height)
            }
            Text {
              anchors.centerIn: preview
              visible: !preview.hasContent
              text: tile.modelData.lastIpcObject["class"] || "미리보기 대기"
              color: Color.foreground; font.pixelSize: 18
            }
            Text {
              anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
              text: "[" + (tile.modelData.workspace ? tile.modelData.workspace.name : "?") + "] " + tile.modelData.title
              elide: Text.ElideRight; color: Color.foreground; font.pixelSize: 13; textFormat: Text.PlainText
            }
            MouseArea {
              id: mouse
              anchors.fill: parent; hoverEnabled: true
              drag.target: ghost
              onEntered: grid.currentIndex = tile.index
              onPressed: function(event) {
                var p = mapToItem(panel.contentItem, event.x, event.y)
                ghost.x = p.x; ghost.y = p.y; ghost.address = tile.modelData.address; ghost.caption = tile.modelData.title
              }
              onReleased: { if (ghost.Drag.active) ghost.Drag.drop(); ghost.dragging = false }
              onCanceled: ghost.dragging = false
              onClicked: root.focusWindow(tile.modelData)
              onPositionChanged: if (drag.active) ghost.dragging = true
            }
          }
        }
        Text { anchors.centerIn: parent; visible: root.windows.length === 0; text: "표시할 창이 없습니다"; color: Color.foreground }
      }
    }
    Rectangle {
      id: ghost
      property string address: ""
      property string caption: ""
      property bool dragging: false
      visible: dragging
      z: 100
      width: 180; height: 36; radius: 8; color: Color.accent
      Drag.active: dragging
      Drag.keys: ["orbit-window"]
      Drag.source: ghost
      Drag.hotSpot.x: 8; Drag.hotSpot.y: 8
      Text { anchors.fill: parent; anchors.margins: 8; text: ghost.caption; elide: Text.ElideRight; color: Color.background; textFormat: Text.PlainText }
    }
  }
}
