import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omarchy.agents"
  ipcTarget: "omarchy.agents"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property color themeGreen: "#9bd3ad"
  property color themeYellow: "#e0af68"
  property color themeOrange: "#eb927b"
  property color themeRed: root.urgent

  FileView {
    id: themeColorsFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadThemeColors(text())
    onFileChanged: reload()
  }

  function loadThemeColors(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
      if (!match) continue
      if (match[1] === "green") themeGreen = match[2]
      else if (match[1] === "yellow") themeYellow = match[2]
      else if (match[1] === "orange") themeOrange = match[2]
      else if (match[1] === "red") themeRed = match[2]
    }
  }

  function percentColor(percent) {
    if (typeof percent !== "number" || isNaN(percent) || percent < 0) return root.foreground
    if (percent >= 0.90) return root.themeRed
    if (percent >= 0.80) return root.themeOrange
    if (percent >= 0.50) return root.themeYellow
    return root.themeGreen
  }

  function colorToHex(c) {
    if (!c) return "#ffffff"
    if (typeof c === "string" && c.charAt(0) === "#") return c
    var r = Math.round((c.r || 0) * 255).toString(16).padStart(2, "0")
    var g = Math.round((c.g || 0) * 255).toString(16).padStart(2, "0")
    var b = Math.round((c.b || 0) * 255).toString(16).padStart(2, "0")
    return "#" + r + g + b
  }

  readonly property var providers: usage.enabledProviders
  // The selection follows the provider, not the slot it happens to sit in: a
  // provider whose first scan lands while the panel is open would otherwise
  // shift the list underneath you and swap out what you were reading.
  property string selectedProviderId: ""
  readonly property int providerIndex: {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === selectedProviderId) return i
    return 0
  }
  readonly property var provider: providers.length > 0 ? providers[providerIndex] : null

  property bool cursorActive: false

  // Countdowns and "updated" read this instead of Date.now() so the
  // panel keeps telling the truth while it sits open.
  property double nowMs: Date.now()

  readonly property var limits: limitWindows(provider)
  readonly property var models: modelRows(provider)
  readonly property var headline: bindingWindow(provider)
  readonly property var balance: provider ? (provider.balance || null) : null
  // A prepaid account runs low the way a subscription window fills up: the
  // last 10% of the funded credits lights the same alarm.
  readonly property bool balanceAlarming: !!balance && balance.funded > 0
    && balance.remaining / balance.funded <= 0.1
  readonly property bool alarming: (!!headline && headline.percent >= 0.9) || balanceAlarming

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function selectProvider(index) {
    if (providers.length === 0) return
    var wrapped = ((index % providers.length) + providers.length) % providers.length
    selectedProviderId = providers[wrapped].providerId
  }

  function refreshNow() {
    usage.refreshAll(true)
  }

  function launchAgent() {
    if (root.bar) root.bar.run("omarchy-agent --pick")
    root.close()
  }

  // ---------------------------------------------------------------- limits
  //
  // Both providers report the same two shapes: a short rolling session window
  // and a long weekly one. Everything below normalizes them into one record so
  // the meters and the hero speak a single language.

  // Claude spells its windows out ("Session (5-hour)"), Codex abbreviates
  // them ("5h window", "30m window"). Both have to land on the same record.
  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0) return "Monthly"
    if (windowIsLong(text)) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  // A collector that already knows which window a limit belongs to says so,
  // and that beats reading it back out of the label: a model-scoped limit is
  // titled after its model, and a name like "Opus 5 (1M context)" would parse
  // as a one-minute window.
  function limitWindow(label, percent, resetAt, title) {
    return {
      label: String(label || ""),
      title: String(title || "") !== "" ? String(title) : windowTitle(label),
      percent: Number(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(p) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title))
    }
    return out
  }

  // The window that decides how much room is left — the fullest one, since
  // that is what stops the next prompt.
  function bindingWindow(p) {
    var windows = limitWindows(p)
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || w.resetAt === "") return -1
    var ms = new Date(w.resetAt).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  // ---------------------------------------------------------------- balance
  //
  // Prepaid agents report a credit ledger instead of rate-limit windows: the
  // record's balance object carries remaining, funded, and spent amounts.

  function currencyPrefix(currency) {
    var code = String(currency || "USD").toUpperCase()
    if (code === "USD") return "$"
    if (code === "EUR") return "€"
    if (code === "GBP") return "£"
    return code + " "
  }

  function formatMoney(value, currency) {
    var amount = Number(value)
    if (!isFinite(amount)) amount = 0
    return currencyPrefix(currency) + amount.toFixed(2)
  }

  function balanceDetailText(b) {
    if (!b || !(b.funded > 0)) return ""
    var text = formatMoney(b.spent, b.currency) + " spent of " + formatMoney(b.funded, b.currency) + " funded"
    if (b.estimated) text += " · estimated"
    return text
  }

  // ---------------------------------------------------------------- content

  // The plan you pay for, under the name of the tool it pays for. Limits live
  // in their own section; the hero just says what this is.
  function heroMeta(p) {
    if (!p) return ""
    if (String(p.usageStatusText || "") !== "") return p.usageStatusText
    var tier = String(p.tierLabel || "")
    if (tier === "") return "Subscription"
    return tier.charAt(0).toUpperCase() + tier.slice(1)
  }

  // Local calendar date, recomputed from nowMs so a panel left open across
  // midnight moves the "Today" row with the clock.
  function todayDate() {
    var now = new Date(root.nowMs)
    return now.getFullYear()
      + "-" + String(now.getMonth() + 1).padStart(2, "0")
      + "-" + String(now.getDate()).padStart(2, "0")
  }

  function dayName(date) {
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()]
  }

  function dayLabel(date, today) {
    if (today) return "Today"
    return dayName(date)
  }

  function dayTooltip(day, today) {
    if (!day) return ""
    var parsed = new Date(String(day.date) + "T00:00:00")
    var label = isNaN(parsed.getTime())
      ? String(day.date)
      : dayName(day.date) + " " + (parsed.getMonth() + 1) + "/" + parsed.getDate()
    var text = label + " · " + usage.formatTokenCount(Number(day.messageCount || 0)) + " tokens"
    // Prompt and session counts only exist for today, so they ride along here
    // instead of taking a section of their own. Billing-API agents never
    // count prompts, and "0 prompts" would read as a quiet day, not a gap.
    if (today && provider && provider.hasPromptStats !== false)
      text += " · " + Number(provider.todayPrompts || 0) + " prompts · "
        + Number(provider.todaySessions || 0) + " sessions"
    return text
  }

  function weekPeak(p) {
    var days = p ? (p.recentDays || []) : []
    var peak = 0
    for (var i = 0; i < days.length; i++) peak = Math.max(peak, Number(days[i].messageCount || 0))
    return peak
  }

  function modelRows(p) {
    var usageByModel = p ? (p.modelUsage || {}) : {}
    var rows = []
    for (var id in usageByModel) {
      var bucket = usageByModel[id] || {}
      var input = Number(bucket.inputTokens || 0)
      var output = Number(bucket.outputTokens || 0)
      var cacheRead = Number(bucket.cacheReadInputTokens || 0)
      var cacheWrite = Number(bucket.cacheCreationInputTokens || 0)
      rows.push({
        name: usage.friendlyModelName(id),
        total: input + output + cacheRead + cacheWrite,
        input: input,
        output: output,
        cacheRead: cacheRead,
        cacheWrite: cacheWrite
      })
    }
    rows.sort(function(a, b) { return b.total - a.total })
    return rows.slice(0, 4)
  }

  function modelTooltip(row) {
    if (!row) return ""
    return "In " + usage.formatTokenCount(row.input)
      + " · out " + usage.formatTokenCount(row.output)
      + " · cache read " + usage.formatTokenCount(row.cacheRead)
      + " · cache write " + usage.formatTokenCount(row.cacheWrite)
  }

  // Only speaks up when the numbers cover more than this machine.
  function footerText() {
    if (usage.syncStatusText !== "") return usage.syncStatusText
    if (provider && provider.syncEnabled && provider.syncDeviceCount > 0)
      return "Merged from " + provider.syncDeviceCount + " device" + (provider.syncDeviceCount === 1 ? "" : "s")
    return ""
  }

  // Agents that ship a white mark carry an `assets/<id>-light.svg` twin for
  // light surfaces; marks that work on both (Claude's brand-orange) ship one
  // file. The luminance check decides which candidate to try first.
  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  // Marks resolve by convention, so a new agent's data file needs nothing
  // from this panel: assets/<id>.svg if it ships one, the module's bar glyph
  // if it doesn't.
  function iconCandidatesForProvider(p, surfaceColor) {
    if (!p) return []
    var candidates = []
    if (colorLuminance(surfaceColor || Color.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + p.providerId + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + p.providerId + ".svg"))
    return candidates
  }

  // Nothing to report, nothing in the bar: Bar.qml collapses a slot whose item
  // is invisible, so the icon appears the moment the first scan finds usage and
  // stays away entirely on a machine that has never run either CLI.
  visible: urgentWindow !== null
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onProviderIndexChanged: if (panelFlick) panelFlick.contentY = 0
  onOpenedChanged: if (opened) {
    cursorActive = false
    nowMs = Date.now()
    if (panelFlick) panelFlick.contentY = 0
    usage.refreshLimits()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Main {
    id: usage
    settings: root.settings
  }

  // Cheap enough to keep running: it only re-evaluates text bindings, and a
  // stale "resets in 2h" on a panel that is open is worse than a timer.
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshNow(); return "ok" }
    function summary(): string { return JSON.stringify(root.providers.map(function(p) { return {
      id: p.providerId, name: root.cardName(p), remaining: root.overviewLine(p), reset: root.cardReset(p), stale: root.oldData(p)
    }})) }
    function next(): string { root.selectProvider(root.providerIndex + 1); return "ok" }
  }

  // Show both subscription allowances without opening the detail panel.
  function subscription(id) {
    for (var i = 0; i < providers.length; i++)
      if (providers[i].providerId === id) return providers[i]
    return null
  }

  function oldData(p) {
    var stamp = p ? Date.parse(p.updatedAt || "") : NaN
    return !isFinite(stamp) || root.nowMs - stamp > 30 * 60000
  }

  function shortWindow(w) {
    var title = String(w.title || "").toLowerCase()
    if (title === "weekly") return "7d"
    if (title === "monthly") return "30d"
    return title === "session" ? "5h" : w.title
  }

  function subscriptionLabel(id, name) {
    var p = subscription(id)
    if (!p) return name + " —"
    var windows = limitWindows(p)
    var parts = []
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      if (w.title !== "Session" && w.title !== "Weekly" && w.title !== "Monthly") continue
      var expired = w.resetAt !== "" && Date.parse(w.resetAt) <= root.nowMs
      parts.push(shortWindow(w) + " " + (expired ? "…" : Math.round(w.percent * 100) + "%"))
    }
    if (parts.length === 0) return name + " —"
    return name + " " + parts.join(" / ") + (p.usageStatusText !== "" || oldData(p) ? " *" : "")
  }

  function subscriptionRichLabel(id, name) {
    var p = subscription(id)
    var dimHex = colorToHex(root.dim)
    if (!p) return name + ' <font color="' + dimHex + '">—</font>'
    var windows = limitWindows(p)
    var parts = []
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      if (w.title !== "Session" && w.title !== "Weekly" && w.title !== "Monthly") continue
      var win = shortWindow(w)
      var expired = w.resetAt !== "" && Date.parse(w.resetAt) <= root.nowMs
      var pctText = expired ? "…" : Math.round(w.percent * 100) + "%"
      var c = expired ? dimHex : colorToHex(percentColor(w.percent))
      parts.push('<font color="' + dimHex + '">' + win + ' </font><font color="' + c + '"><b>' + pctText + '</b></font>')
    }
    if (parts.length === 0) return name + ' <font color="' + dimHex + '">—</font>'
    var sep = ' <font color="' + dimHex + '">/</font> '
    var warn = (p.usageStatusText !== "" || oldData(p)) ? ' <font color="' + colorToHex(root.urgent) + '">*</font>' : ''
    return name + " " + parts.join(sep) + warn
  }

  function subscriptionTooltip(id, name) {
    var p = subscription(id)
    if (!p) return name + ": 사용량 확인 중"
    var lines = [name + " · " + p.tierLabel + " · 사용한 비율"]
    var windows = limitWindows(p)
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      lines.push(w.title + ": " + Math.round(w.percent * 100) + "%" +
        (w.resetAt ? " · 초기화 " + new Date(w.resetAt).toLocaleString() : ""))
    }
    if (p.usageStatusText) lines.push(p.usageStatusText)
    if (p.updatedAt) lines.push("갱신: " + new Date(p.updatedAt).toLocaleString())
    if (oldData(p)) lines.push("* 오래된 데이터입니다. 새로고침이 필요합니다.")
    return lines.join("\n")
  }

  readonly property bool anyAlarming: {
    for (var i = 0; i < providers.length; i++) {
      var w = bindingWindow(providers[i])
      if (w && w.percent >= 0.9) return true
    }
    return false
  }

  // The fullest limit still in force. A reset window is ignored until every
  // window has reset, because that one is what stops the next prompt.
  readonly property var urgentWindow: {
    var best = null
    var list = providers || []
    var pass
    for (pass = 0; pass < 2 && !best; ++pass) {
      var includeExpired = pass === 1
      for (var i = 0; i < list.length; i++) {
        var windows = limitWindows(list[i])
        for (var j = 0; j < windows.length; j++) {
          var w = windows[j]
          if (!(w.percent >= 0)) continue
          var expired = w.resetAt !== "" && Date.parse(w.resetAt) <= nowMs
          if (expired && !includeExpired) continue
          if (!best || w.percent > best.window.percent)
            best = { window: w, provider: list[i] }
        }
      }
    }
    return best
  }

  function barShortName(p) {
    if (!p) return ""
    if (p.providerId === "claude") return "Claude"
    if (p.providerId === "cursor") return "Cursor"
    return p.providerName || p.providerId
  }

  // Two letters on the bar. The tooltip still uses the full name.
  function barMark(p) {
    if (!p) return ""
    if (p.providerId === "gemini") return "Ge"
    if (p.providerId === "codex") return "Cx"
    if (p.providerId === "claude") return "Cl"
    if (p.providerId === "cursor") return "Cu"
    if (p.providerId === "fireworks") return "Fw"
    var name = barShortName(p)
    return name.length <= 3 ? name : name.slice(0, 2)
  }

  // Session, week, month, and Cursor's Auto/API pair need no extra word:
  // their order is the label. Anything else (Fable, GPT) keeps a short tag.
  function windowTag(title) {
    var text = String(title || "").toLowerCase()
    if (text === "session" || text === "weekly" || text === "monthly" || text === "auto" || text === "api")
      return ""
    if (text.indexOf("gpt") >= 0) return "GPT"
    if (text.indexOf("fable") >= 0) return "Fable"
    var word = String(title || "").split(" ")[0]
    return word
  }

  function windowExpired(w) {
    return !!w && w.resetAt !== "" && Date.parse(w.resetAt) <= root.nowMs
  }

  function percentText(w) {
    if (!w || !(w.percent >= 0)) return "—"
    if (windowExpired(w)) return "…"
    return String(Math.round(w.percent * 100))
  }

  // Bare numbers that share a tag stay in one run: 2·11, then GPT 0·63.
  function windowGroups(p) {
    var windows = limitWindows(p)
    var groups = []
    var current = null
    for (var i = 0; i < windows.length; i++) {
      var tag = windowTag(windows[i].title)
      if (!current || current.tag !== tag) {
        current = { tag: tag, windows: [] }
        groups.push(current)
      }
      current.windows.push(windows[i])
    }
    return groups
  }

  function barLabel() {
    var chunks = []
    for (var i = 0; i < providers.length; i++) {
      var p = providers[i]
      var groups = windowGroups(p)
      var bits = [barMark(p)]
      if (groups.length === 0) {
        bits.push("—")
      } else {
        for (var g = 0; g < groups.length; g++) {
          var numbers = []
          for (var n = 0; n < groups[g].windows.length; n++)
            numbers.push(percentText(groups[g].windows[n]))
          bits.push((groups[g].tag === "" ? "" : groups[g].tag + " ") + numbers.join("·"))
        }
      }
      if (p.usageStatusText !== "" || oldData(p)) bits.push("*")
      chunks.push(bits.join(" "))
    }
    return chunks.join(" · ")
  }

  function barRichLabel() {
    var dim = colorToHex(root.dim)
    var dot = '<font color="' + dim + '">·</font>'
    var chunks = []
    for (var i = 0; i < providers.length; i++) {
      var p = providers[i]
      var groups = windowGroups(p)
      var bits = ['<font color="' + dim + '">' + barMark(p) + '</font>']
      if (groups.length === 0) {
        bits.push('<font color="' + dim + '">—</font>')
      } else {
        for (var g = 0; g < groups.length; g++) {
          var numbers = []
          for (var n = 0; n < groups[g].windows.length; n++) {
            var w = groups[g].windows[n]
            var text = percentText(w)
            var color = text === "…" || text === "—" ? root.dim : percentColor(w.percent)
            numbers.push('<font color="' + colorToHex(color) + '"><b>' + text + '</b></font>')
          }
          var run = numbers.join(dot)
          if (groups[g].tag !== "")
            run = '<font color="' + dim + '">' + groups[g].tag + ' </font>' + run
          bits.push(run)
        }
      }
      if (p.usageStatusText !== "" || oldData(p))
        bits.push('<font color="' + colorToHex(root.urgent) + '">*</font>')
      chunks.push(bits.join(" "))
    }
    return chunks.join(' <font color="' + dim + '">·</font> ')
  }

  function barTooltip() {
    var parts = ["앞쪽 숫자가 먼저 차오르는 한도입니다. Ge·Cl은 세션 다음 주간, Cu는 Auto 다음 API입니다."]
    if (root.urgentWindow) {
      var urgent = root.urgentWindow
      parts.push("가장 급한 한도 · " + barShortName(urgent.provider) + " " + urgent.window.title
        + " " + Math.round(urgent.window.percent * 100) + "%")
    }
    for (var i = 0; i < providers.length; i++) {
      var p = providers[i]
      parts.push(subscriptionTooltip(p.providerId, barShortName(p)))
    }
    parts.push("5분마다 자동 갱신\n클릭: 상세 보기 · 오른쪽 클릭: 새로고침 · 가운데 클릭: 구독 전환")
    return parts.join("\n\n")
  }

  // Quota percentages below are REMAINING; API records remain unmodified.
  function quotaLabel(w) {
    var t = String(w.title || "")
    if (t === "Session") {
      var span = windowSpanMs(w.label)
      return span > 0 ? (span >= 3600000 ? (span / 3600000) + "h" : (span / 60000) + "m") : "세션"
    }
    if (t === "Weekly") return "7d"
    if (t === "Monthly") return "月"
    if (t === "Claude/GPT Session") return "C/G·5h"
    if (t === "Claude/GPT Weekly") return "C/G·7d"
    if (t === "Fable Weekly") return "Fable"
    return t
  }
  function remainingText(w) {
    if (!w || !isFinite(w.percent)) return "—"
    if (windowExpired(w)) return "…"
    var remaining = clamp((1 - w.percent) * 100, 0, 100)
    return remaining > 0 && remaining < 1 ? "<1%" : Math.floor(remaining) + "%"
  }
  function cardName(p) {
    return p.providerId === "claude" ? "Claude" : p.providerName
  }
  function cardReset(p) {
    var w = bindingWindow(p)
    if (oldData(p)) return "갱신 필요"
    if (p.usageStatusText) return "확인 필요"
    if (!w || !w.resetAt) return "잔여"
    var ms = resetMsFor(w)
    if (!(ms > 0)) return "갱신 대기"
    var minutes = Math.ceil(ms / 60000)
    return "↻" + (minutes >= 1440 ? Math.floor(minutes / 1440) + "d"
      : minutes >= 60 ? Math.floor(minutes / 60) + "h" + (minutes % 60) + "m" : minutes + "m")
  }
  function cardTooltip(p) {
    var lines = [cardName(p) + " · " + (p.tierLabel || "구독") + " · 남은 한도"]
    var windows = limitWindows(p)
    for (var i = 0; i < windows.length; i++) {
      var w = windows[i]
      lines.push(w.title + ": 잔여 " + remainingText(w) + " / 사용 " + Math.round(w.percent * 100) + "%"
        + (w.resetAt ? "\n  리셋 " + new Date(w.resetAt).toLocaleString() : ""))
    }
    if (windows.length === 0) lines.push("한도 데이터 없음 — 무제한이라는 뜻은 아닙니다.")
    lines.push("↻는 가장 많이 사용한 한도의 리셋까지 남은 시간입니다.")
    if (p.usageStatusText) lines.push(p.usageStatusText)
    if (oldData(p)) lines.push("주의: 30분 이상 지난 데이터입니다.")
    if (p.updatedAt) lines.push("갱신 " + new Date(p.updatedAt).toLocaleString())
    lines.push("클릭: 이 구독 상세 · 오른쪽 클릭: 새로고침")
    return lines.join("\n")
  }
  function overviewLine(p) {
    return (oldData(p) ? "이전 값* " : "") + (limitWindows(p).map(function(w) { return quotaLabel(w) + " " + remainingText(w) }).join("   ") || "한도 확인 중")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "구독 잔여 한도"
    labelVisible: false
    interactive: false
    horizontalMargin: 2
    fixedWidth: quotaCards.implicitWidth + 4

    Row {
      id: quotaCards
      anchors.centerIn: parent
      spacing: 5
      Repeater {
        model: root.providers
        delegate: WidgetButton {
          id: providerCard
          required property var modelData
          required property int index
          readonly property var windows: root.limitWindows(modelData)
          bar: root.bar
          text: root.cardName(modelData)
          labelVisible: false
          fixedWidth: Math.max(cardHeading.implicitWidth, quotaRow.implicitWidth) + 14
          fixedHeight: button.barSize
          tooltipText: root.cardTooltip(modelData)
          onPressed: function(code) {
            if (code === Qt.RightButton) { root.refreshNow(); return }
            var same = root.selectedProviderId === modelData.providerId
            root.selectedProviderId = modelData.providerId
            if (root.opened && same) root.close(); else root.open()
          }
          Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 5
            color: Qt.rgba(root.surface.r, root.surface.g, root.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }
          Column {
            anchors.centerIn: parent
            spacing: 0
            Row {
              id: cardHeading
              spacing: 7
              Text {
                text: root.cardName(providerCard.modelData)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 11
                font.bold: true
                renderType: Text.NativeRendering
              }
              Text {
                text: "잔여 · " + root.cardReset(providerCard.modelData).replace(/^잔여$/, "—")
                color: root.oldData(providerCard.modelData) || providerCard.modelData.usageStatusText ? root.themeYellow : root.foreground
                opacity: 0.65
                font.family: root.fontFamily
                font.pixelSize: 10
                renderType: Text.NativeRendering
              }
            }
            Row {
              id: quotaRow
              spacing: 7
              Repeater {
                model: providerCard.windows
                delegate: Column {
                  id: quotaCell
                  required property var modelData
                  spacing: 0
                  readonly property bool unknown: root.windowExpired(modelData) || root.oldData(providerCard.modelData) || !!providerCard.modelData.usageStatusText
                  Row {
                    spacing: 3
                    Text {
                      text: root.quotaLabel(quotaCell.modelData)
                      color: root.foreground
                      opacity: 0.65
                      font.family: root.fontFamily
                      font.pixelSize: 11
                      renderType: Text.NativeRendering
                    }
                    Text {
                      text: root.remainingText(quotaCell.modelData) + (root.oldData(providerCard.modelData) ? "*" : "")
                      color: quotaCell.unknown ? root.foreground : root.percentColor(quotaCell.modelData.percent)
                      font.family: root.fontFamily
                      font.pixelSize: 11
                      font.bold: true
                      renderType: Text.NativeRendering
                    }
                  }
                  Rectangle {
                    width: parent.implicitWidth
                    height: 2
                    radius: 1
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    Rectangle {
                      width: parent.width * root.clamp(1 - quotaCell.modelData.percent, 0, 1)
                      height: 2
                      radius: 1
                      visible: !quotaCell.unknown
                      color: root.percentColor(quotaCell.modelData.percent)
                    }
                  }
                }
              }
              Text {
                visible: providerCard.windows.length === 0
                text: "한도 정보 없음"
                color: root.foreground
                opacity: 0.65
                font.family: root.fontFamily
                font.pixelSize: 11
              }
            }
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    // Taller than the control panels on purpose: this one is a dashboard, and
    // the whole point is reading limits and history without scrolling.
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.selectProvider(root.providerIndex + dx)
        }
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.refreshNow()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refreshNow() }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Text {
            text: "구독 한눈에 · 남은 한도"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Column {
            width: parent.width
            spacing: 4
            Repeater {
              model: root.providers
              delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: 42
                radius: 6
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 3
                  Text {
                    text: root.cardName(modelData) + "  ·  " + root.cardReset(modelData)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                  }
                  Text {
                    text: root.overviewLine(modelData)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 10
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  onClicked: root.selectedProviderId = parent.modelData.providerId
                }
              }
            }
          }

          // ---------- Hero: provider mark · name · plan ----------
          PanelHero {
            id: hero
            visible: !!root.provider
            width: parent.width
            title: root.provider ? root.provider.providerName : ""
            meta: root.heroMeta(root.provider)
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                id: heroMark
                property var candidates: root.iconCandidatesForProvider(root.provider, root.surface)
                // Provider objects are rebuilt on every refresh, which churns the
                // array's identity without changing its content. Restart the fallback
                // walk only when the URLs change: re-pointing source at a URL whose
                // load already failed emits no statusChanged, so an identity-only
                // reset would strand the walker on a missing -light twin.
                property string candidatesKey: candidates.join("\n")
                property int candidateIndex: 0
                onCandidatesKeyChanged: candidateIndex = 0

                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  anchors.fill: parent
                  source: heroMark.candidateIndex < heroMark.candidates.length ? heroMark.candidates[heroMark.candidateIndex] : ""
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                  // Advancing source from inside its own status change trips the
                  // binding-loop detector; defer the step one tick.
                  onStatusChanged: if (status === Image.Error && heroMark.candidateIndex < heroMark.candidates.length)
                    Qt.callLater(function() { heroMark.candidateIndex++ })
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: heroMarkImage.status !== Image.Ready
                  text: "󱚣"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
          }

          Text {
            visible: root.providers.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: "No AI coding subscriptions found.\nAgents show up here once you've used them."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---------- Provider switch ----------
          Row {
            id: providerSwitch
            visible: root.providers.length > 1
            width: parent.width
            spacing: Style.spacing.md

            readonly property real cellWidth: root.providers.length > 0
              ? (width - spacing * (root.providers.length - 1)) / root.providers.length
              : 0

            Repeater {
              model: root.providers

              Button {
                required property var modelData
                required property int index

                width: providerSwitch.cellWidth
                text: modelData.providerName
                selected: index === root.providerIndex
                hasCursor: root.cursorActive && index === root.providerIndex
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.cursorActive = true
                  root.selectProvider(index)
                }
                onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
              }
            }
          }

          // ---------- Status ----------
          BorderSurface {
            visible: !!root.provider && String(root.provider.usageStatusText || "") !== ""
            width: parent.width
            implicitHeight: statusText.implicitHeight + Style.spacing.xl * 2
            color: root.alpha(root.urgent, 0.10)
            borderSpec: Border.flat(root.alpha(root.urgent, 0.35), 1)
            radius: Style.cornerRadius

            Text {
              id: statusText
              textFormat: Text.PlainText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              text: root.provider ? String(root.provider.authHelpText || "") : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---------- Balance / limits ----------
          PanelSeparator {
            visible: balanceSection.visible || limitsSection.visible
            foreground: root.foreground
          }

          Column {
            id: balanceSection
            visible: !!root.balance
            width: parent.width
            spacing: Style.space(10)

            // The meter shows what is left, not what is used: a prepaid
            // account drains toward empty rather than filling toward a cap.
            readonly property real ratio: root.balance && root.balance.funded > 0
              ? root.clamp(root.balance.remaining / root.balance.funded, 0, 1)
              : -1

            PanelSectionHeader {
              width: parent.width
              text: "BALANCE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(balanceLabel.implicitHeight, balanceValue.implicitHeight)

              Text {
                id: balanceLabel
                text: "Prepaid credits"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: balanceValue
                textFormat: Text.PlainText
                text: root.balance ? root.formatMoney(root.balance.remaining, root.balance.currency) : ""
                color: root.balanceAlarming ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter {
              visible: balanceSection.ratio >= 0
              width: parent.width
              value: balanceSection.ratio
              alarming: root.balanceAlarming
            }

            Text {
              textFormat: Text.PlainText
              visible: text !== ""
              width: parent.width
              text: root.balanceDetailText(root.balance)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Column {
            id: limitsSection
            visible: root.limits.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "사용한 한도 · 위 요약은 잔여량"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.limits

              LimitRow {
                required property var modelData
                width: limitsSection.width
                window: modelData
              }
            }
          }

          // ---------- Usage ----------
          PanelSeparator {
            visible: usageSection.visible
            foreground: root.foreground
          }

          Column {
            id: usageSection
            visible: !!root.provider && root.provider.recentDays && root.provider.recentDays.length > 0
            width: parent.width
            spacing: Style.spacing.md

            readonly property var days: root.provider ? (root.provider.recentDays || []) : []
            readonly property real peak: Math.max(1, root.weekPeak(root.provider))

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY DAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: usageSection.days

              DayRow {
                required property var modelData
                required property int index

                width: usageSection.width
                day: modelData
                ratio: Number(modelData.messageCount || 0) / usageSection.peak
                // By date, not by position: the Claude stats-cache fallback can
                // hand us a window that stops short of today.
                today: String(modelData.date || "") === root.todayDate()
              }
            }
          }

          // ---------- Models ----------
          PanelSeparator {
            visible: modelSection.visible
            foreground: root.foreground
          }

          Column {
            id: modelSection
            visible: root.models.length > 0
            width: parent.width
            spacing: Style.spacing.md

            PanelSectionHeader {
              width: parent.width
              text: "TOKENS BY MODEL"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.models

              ModelRow {
                required property var modelData
                width: modelSection.width
                row: modelData
                // Scaled to the heaviest model, so the top row is always full —
                // the same scale-to-peak the weekly chart uses for its busiest day.
                share: modelData.total / Math.max(1, root.models[0].total)
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: text !== ""
            width: parent.width
            topPadding: Style.space(2)
            text: root.footerText()
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // A limit window: label and percentage, meter, and reset countdown.
  component LimitRow: Column {
    id: limitRow
    property var window: null

    readonly property bool alarming: window && window.percent >= 0.9

    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: Math.max(limitLabel.implicitHeight, limitValue.implicitHeight)

      Text {
        id: limitLabel
        textFormat: Text.PlainText
        // A model-scoped window is titled after its model, and those names run
        // long enough to reach the percentage, so the title gives way first.
        text: limitRow.window ? limitRow.window.title : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.right: limitValue.left
        anchors.rightMargin: Style.spacing.sm
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: limitValue
        textFormat: Text.PlainText
        text: limitRow.window && limitRow.window.percent >= 0
          ? Math.round(limitRow.window.percent * 100) + "%"
          : "—"
        color: limitRow.window ? root.percentColor(limitRow.window.percent) : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      value: limitRow.window ? limitRow.window.percent : -1
      alarming: limitRow.alarming
      fillColor: limitRow.window ? root.percentColor(limitRow.window.percent) : root.foreground
    }

    Text {
      id: resetText
      textFormat: Text.PlainText
      width: parent.width
      text: {
        var remainingMs = root.resetMsFor(limitRow.window)
        return remainingMs > 0 ? "Resets in " + root.formatDuration(remainingMs) : ""
      }
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Rounded track showing the percentage of the allowance used.
  component Meter: Item {
    id: meter
    property real value: -1
    property bool alarming: false
    property color fillColor: alarming ? root.urgent : (value >= 0 ? root.percentColor(value) : root.foreground)
    property real thickness: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

    implicitHeight: thickness

    Rectangle {
      id: meterTrack
      anchors.fill: parent
      radius: height / 2
      color: root.track
    }

    Rectangle {
      anchors.left: meterTrack.left
      anchors.verticalCenter: meterTrack.verticalCenter
      height: meterTrack.height
      radius: meterTrack.radius
      width: meterTrack.width * root.clamp(meter.value, 0, 1)
      color: meter.fillColor

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

  }

  // One row per day: label, bar, tokens. Today is picked out in full
  // foreground so the week reads as a run-up to right now.
  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    property bool today: false

    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.spacing.sm

    Text {
      id: dayLabel
      textFormat: Text.PlainText
      text: root.dayLabel(dayRow.day ? dayRow.day.date : "", dayRow.today)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: dayRow.today
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(dayRow.ratio, 0, 1)
        color: dayRow.today ? root.foreground : root.alpha(root.foreground, 0.55)

        Behavior on width {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      id: dayValue
      textFormat: Text.PlainText
      text: usage.formatTokenCount(dayRow.day ? Number(dayRow.day.messageCount || 0) : 0)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    MouseArea {
      id: dayHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: dayHover.containsMouse
      text: root.dayTooltip(dayRow.day, dayRow.today)
      fontFamily: root.fontFamily
    }
  }

  // Model rows read as a table: the share bar fills the row behind the label
  // instead of stacking under it, which keeps the whole dashboard on one screen.
  component ModelRow: Item {
    id: modelRow
    property var row: null
    property real share: 0

    implicitHeight: modelName.implicitHeight + Style.spacing.lg

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.05)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * root.clamp(modelRow.share, 0, 1)
      radius: Style.cornerRadius
      color: root.alpha(root.foreground, 0.14)

      Behavior on width {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }
    }

    Text {
      id: modelName
      textFormat: Text.PlainText
      text: modelRow.row ? modelRow.row.name : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: modelTokens.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: modelTokens
      textFormat: Text.PlainText
      text: modelRow.row ? usage.formatTokenCount(modelRow.row.total) : ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    MouseArea {
      id: modelHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: modelHover.containsMouse
      text: root.modelTooltip(modelRow.row)
      fontFamily: root.fontFamily
    }
  }
}
