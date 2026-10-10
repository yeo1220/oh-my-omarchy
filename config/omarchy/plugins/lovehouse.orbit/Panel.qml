import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "lovehouse.orbit"
  ipcTarget: "lovehouse.orbit"
  manageIpc: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property var state: ({phase: "idle", kind: "focus", remaining: 1500, duration: 1500, deadline: 0, note: "", today_sessions: 0, today_minutes: 0})
  property real now: Date.now() / 1000
  property string errorText: ""
  property bool noteDirty: false
  property var pending: []
  readonly property string engine: Qt.resolvedUrl("orbit.py").toString().replace("file://", "")
  readonly property bool activeTimer: state.phase === "running" || state.phase === "paused"
  readonly property int secondsLeft: state.phase === "running" ? Math.max(0, Math.ceil(state.deadline - now)) : state.remaining
  readonly property string timeLabel: String(Math.floor(secondsLeft / 60)).padStart(2, "0") + ":" + String(secondsLeft % 60).padStart(2, "0")
  readonly property string phaseLabel: state.phase === "paused" ? "잠시 멈춤" : state.phase === "done" ? "완료 · 수고하셨습니다" : state.phase === "running" ? (state.kind === "break" ? "편안하게 쉬어 가세요" : "지금은 한 가지에 집중") : "다음 몰입을 준비하세요"

  function request(action, value) {
    var args = ["/usr/bin/python3", engine, action]
    if (value !== undefined) args.push("--", String(value))
    if (worker.running) {
      if (action !== "status") pending = pending.concat([args])
      return
    }
    worker.command = args
    worker.running = true
  }
  function drain() {
    if (pending.length && !worker.running) {
      var args = pending[0]
      pending = pending.slice(1)
      worker.command = args
      worker.running = true
    }
  }
  function saveNote() { request("note", note.text) }
  function launch(args) { root.close(); Quickshell.execDetached(args) }
  function receive(raw) {
    try {
      var result = JSON.parse(raw)
      if (result.error) { errorText = result.error; return }
      errorText = ""
      state = result
      now = Date.now() / 1000
      if (!noteDirty) note.text = result.note
      else if (result.note === note.text) noteDirty = false
    } catch (e) { errorText = "상태를 읽지 못했습니다. 다시 열어 주세요." }
  }
  onOpenedChanged: if (opened) request("status")
  Component.onCompleted: request("status")

  Process {
    id: worker
    stdout: StdioCollector { onStreamFinished: root.receive(text) }
    onExited: function(code, status) {
      if (code !== 0 && !root.errorText) root.errorText = "작업을 처리하지 못했습니다."
      Qt.callLater(root.drain)
    }
  }
  Timer { interval: 1000; repeat: true; running: root.state.phase === "running"; onTriggered: root.now = Date.now() / 1000 }
  Timer { interval: root.activeTimer || root.opened ? 2000 : 15000; repeat: true; running: true; onTriggered: root.request("status") }
  IpcHandler {
    target: "lovehouse.orbit"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function state(): string { return JSON.stringify(root.state) }
    function action(action: string, value: string): void { root.request(action, value) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.activeTimer ? "◉ " + root.timeLabel : "◉ Orbit"
    foreground: root.activeTimer ? Color.accent : root.barForeground
    tooltipText: "Orbit Desk · 집중 / 메모 / 바로가기\nSuper + Ctrl + Shift + O"
    onPressed: root.toggle()
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: content
    contentWidth: fittedContentWidth(Style.space(380))
    contentHeight: fittedContentHeight(column.implicitHeight)

    Item {
      id: content
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.close()

      Column {
        id: column
        width: parent.width
        spacing: Style.space(13)

        Row {
          width: parent.width
          Text { text: "◉  ORBIT DESK"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true; width: parent.width - closeButton.width }
          Button { id: closeButton; text: "닫기"; focusable: true; onClicked: root.close() }
        }
        Text { text: root.phaseLabel; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
        Text { text: root.timeLabel; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.space(52); font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        Rectangle {
          width: parent.width; height: Style.space(4); radius: 2
          color: Qt.alpha(Color.foreground, 0.12)
          Rectangle {
            width: parent.width * (root.state.phase === "idle" ? 0 : Math.max(0, Math.min(1, 1 - root.secondsLeft / root.state.duration)))
            height: parent.height; radius: 2; color: Color.accent
            Behavior on width { NumberAnimation { duration: 250 } }
          }
        }
        Row {
          width: parent.width; spacing: Style.space(6)
          Repeater {
            model: [{minutes: 25, label: "25분 집중"}, {minutes: 50, label: "50분 집중"}, {minutes: 5, label: "5분 휴식"}]
            Button {
              required property var modelData
              width: (column.width - Style.space(12)) / 3
              text: modelData.label; bordered: true; focusable: true
              enabled: !root.activeTimer; opacity: enabled ? 1 : 0.4
              onClicked: root.request("start", modelData.minutes)
            }
          }
        }
        Row {
          visible: root.activeTimer
          width: parent.width; spacing: Style.space(6)
          Button { width: (column.width - Style.space(6)) / 2; text: root.state.phase === "paused" ? "계속하기" : "잠시 멈춤"; selected: true; focusable: true; onClicked: root.request(root.state.phase === "paused" ? "resume" : "pause") }
          Button { width: (column.width - Style.space(6)) / 2; text: "세션 종료"; bordered: true; focusable: true; onClicked: root.request("reset") }
        }
        Text { text: "오늘의 몰입   " + root.state.today_sessions + "회  ·  " + root.state.today_minutes + "분"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.foreground, 0.15) }
        Text { text: "지금 할 일"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.body; font.bold: true }
        TextField {
          id: note
          width: parent.width
          placeholderText: "한 가지 작업을 적어 보세요…"
          maximumLength: 240
          onTextEdited: root.noteDirty = true
          onAccepted: root.saveNote()
          Keys.onEscapePressed: root.close()
        }
        Row {
          width: parent.width
          Text { width: parent.width - save.width; text: root.noteDirty ? "Enter 또는 저장 · 로컬 보관" : "저장됨 · 이 기기에만 보관"; color: Qt.alpha(Color.foreground, 0.65); font.family: Style.font.family; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
          Button { id: save; text: "저장"; focusable: true; enabled: root.noteDirty; onClicked: root.saveNote() }
        }
        Rectangle { width: parent.width; height: 1; color: Qt.alpha(Color.foreground, 0.15) }
        Row {
          width: parent.width; spacing: Style.space(6)
          Button { width: (column.width - Style.space(12)) / 3; text: "작업 폴더"; bordered: true; focusable: true; onClicked: root.launch(["xdg-open", Quickshell.env("HOME") + "/Work"]) }
          Button { width: (column.width - Style.space(12)) / 3; text: "원격 작업"; bordered: true; focusable: true; onClicked: root.launch([Quickshell.env("HOME") + "/.local/bin/remote-work"]) }
          Button { width: (column.width - Style.space(12)) / 3; text: "클립보드"; bordered: true; focusable: true; onClicked: root.launch(["omarchy", "shell", "shell", "toggle", "omarchy.clipboard"]) }
        }
        Text { visible: root.errorText !== ""; width: parent.width; text: root.errorText; wrapMode: Text.Wrap; color: Color.urgent; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
        Button {
          width: parent.width
          text: "◈  Orbit Tools · 6가지 데스크톱 도구"
          bordered: true
          focusable: true
          onClicked: root.launch([Quickshell.env("HOME") + "/.local/bin/orbit-tools", "scenes"])
        }
      }
    }
  }
}
