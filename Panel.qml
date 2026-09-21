import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar widget + dropdown for the D2R terror zone rotation. One QML entry
// point: the Panel base owns open/close lifecycle, this file owns the bar
// pill, the polling service, the popup content, and watch-list notifications.
Panel {
  id: root
  moduleName: "emila.terror-zone"
  ipcTarget: "emila.terror-zone"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var watchedZones: Model.normalizedWatchList(setting("watchedZones", []))
  readonly property bool notifyOnCurrent: setting("notifyOnCurrent", true) !== false
  readonly property bool notifyOnNext: setting("notifyOnNext", true) !== false

  readonly property var currentMatches: Model.matchingWatches(tz.current, watchedZones)
  readonly property var nextMatches: Model.matchingWatches(tz.next, watchedZones)

  // The bar (and everything mounted in it, including this widget) is
  // instantiated once per connected monitor - see Bar.qml's `Variants {
  // model: Quickshell.screens }`. Without a guard, each monitor's copy would
  // poll and notify independently, tripling watch-list notifications on a
  // multi-monitor setup. Only the instance on the (deterministically) first
  // screen actually sends notifications; the rest still poll and render
  // normally so their own bar pill/countdown stay correct.
  readonly property bool isNotifierInstance: Quickshell.screens.length === 0
    || Screen.name === Quickshell.screens[0].name

  // Self-computed 30-minute rotation clock, ticking every second so the
  // countdown is smooth and independent of how often the API actually
  // answers. `now` also drives a prompt refetch right as a cycle flips.
  property var now: new Date()
  readonly property var bounds: Model.cycleBoundaries(now)
  readonly property int msRemaining: Math.max(0, bounds.cycleEnd - now.getTime())

  // `bounds` is a fresh object every tick (new identity each second), so it
  // can't drive a "cycle just flipped" refresh directly - that would refetch
  // every second. Track the numeric boundary instead; its change notification
  // only fires the ~once per 30 minutes it actually changes.
  readonly property int currentCycleStart: bounds.cycleStart
  onCurrentCycleStartChanged: tz.refresh()

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  // ---- Persisting settings back to shell.json (see clock/Panel.qml's
  //      persistSettings for the same pattern).
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    for (var key in values) entry[key] = values[key]

    // Applied locally first so the panel reflects the change on the click
    // itself; the shell.json write comes back through the bar as the same
    // value (see clock/Panel.qml's persistSettings for the same pattern).
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setWatchedZones(values) {
    persistSettings({ watchedZones: values })
  }

  function toggleNotifyOnCurrent() {
    persistSettings({ notifyOnCurrent: !root.notifyOnCurrent })
  }

  function toggleNotifyOnNext() {
    persistSettings({ notifyOnNext: !root.notifyOnNext })
  }

  // ---- Notifications. Deduped per rotation cycle so a poll landing twice
  //      inside the same 30-minute window can't double-notify. Only checked
  //      right after a successful fetch, never off the ticking clock, so a
  //      reading that hasn't caught up with a just-flipped cycle can't fire
  //      early off stale data.
  property var notifiedCurrentAt: null
  property var notifiedNextAt: null

  function maybeNotify() {
    if (!root.isNotifierInstance) return
    var b = Model.cycleBoundaries(root.now)

    if (root.notifyOnCurrent && root.notifiedCurrentAt !== b.cycleStart) {
      root.notifiedCurrentAt = b.cycleStart
      var curMatches = Model.matchingWatches(tz.current, root.watchedZones)
      if (curMatches.length > 0)
        sendNotification("Terrorized now: " + curMatches.join(", "), tz.current)
    }

    if (root.notifyOnNext && root.notifiedNextAt !== b.nextCycleStart) {
      root.notifiedNextAt = b.nextCycleStart
      var nextMatches = Model.matchingWatches(tz.next, root.watchedZones)
      if (nextMatches.length > 0)
        sendNotification("Coming up next: " + nextMatches.join(", "), tz.next + " — in " + Model.formatCountdown(root.msRemaining))
    }
  }

  function sendNotification(headline, description) {
    notifyProc.command = ["omarchy-notification-send", "--app-name", "Terror Zone", "-u", "normal", headline, description]
    notifyProc.running = false
    notifyProc.running = true
  }

  function sendFullStatus() {
    sendNotification("Now: " + Model.shortLabel(tz.current), "Next (" + Model.formatCountdown(root.msRemaining) + "): " + Model.shortLabel(tz.next))
  }

  Process {
    id: notifyProc
    running: false
    command: []
  }

  TerrorZoneService {
    id: tz
    settings: root.settings
  }

  Connections {
    target: tz
    function onUpdated() { root.maybeNotify() }
  }

  readonly property string tooltipSummary: tz.current
    ? "Now: " + Model.shortLabel(tz.current) + "\nNext in " + Model.formatCountdown(root.msRemaining) + ": " + Model.shortLabel(tz.next)
    : "Terror Zone — fetching…"

  readonly property color barTextColor: root.currentMatches.length > 0 ? root.urgent : root.foreground

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) tz.refresh()

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { tz.refresh(); return "ok" }
    function status(): string { return tz.current + " | next: " + tz.next }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "☠ " + Model.formatCountdown(root.msRemaining)
    foreground: root.barTextColor
    tooltipText: root.tooltipSummary

    onPressed: function(b) {
      if (b === Qt.RightButton) root.sendFullStatus()
      else if (b === Qt.MiddleButton) tz.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") tz.refresh() }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: parent.width
          spacing: Style.space(14)

          // ---- Header ------------------------------------------------
          Item {
            width: parent.width
            implicitHeight: Math.max(titleText.implicitHeight, refreshButton.implicitHeight)

            Text {
              id: titleText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Terror Zone"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            PanelActionButton {
              id: refreshButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: tz.loading ? "󰦖" : "󰑐"
              tooltipText: "Refresh"
              foreground: root.foreground
              onClicked: tz.refresh()
            }
          }

          // ---- Current / next zone cards ------------------------------
          Column {
            width: parent.width
            spacing: Style.space(10)

            Rectangle {
              width: parent.width
              radius: Style.cornerRadius
              implicitHeight: curCol.implicitHeight + Style.space(20)
              color: root.currentMatches.length > 0
                ? Style.hoverFillFor(root.foreground, root.urgent)
                : Style.hoverFillFor(root.foreground, Color.accent)

              Column {
                id: curCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: "TERRORIZED NOW"
                  foreground: root.foreground
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: tz.current || "—"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: "ends in " + Model.formatCountdown(root.msRemaining)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Rectangle {
              width: parent.width
              radius: Style.cornerRadius
              implicitHeight: nextCol.implicitHeight + Style.space(20)
              color: root.nextMatches.length > 0
                ? Style.hoverFillFor(root.foreground, root.urgent)
                : Style.normalFillFor(root.foreground, Color.accent)

              Column {
                id: nextCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(10)
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: "NEXT"
                  foreground: root.foreground
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  wrapMode: Text.WordWrap
                  text: tz.next || "—"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  textFormat: Text.PlainText
                  text: "starts in " + Model.formatCountdown(root.msRemaining)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          // ---- Offline strip -------------------------------------------
          Rectangle {
            visible: !tz.online && tz.lastError !== ""
            width: parent.width
            implicitHeight: offlineText.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)

            Text {
              id: offlineText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: tz.current
                ? "Can't reach d2runewizard.com — showing last known state. " + tz.lastError
                : tz.lastError
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // ---- Notification settings ------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "NOTIFICATIONS"
              foreground: root.foreground
            }

            Toggle {
              width: parent.width
              label: "Zone is terrorized now"
              description: "Notify when a watched zone becomes the active terror zone."
              foreground: root.foreground
              checked: root.notifyOnCurrent
              onClicked: root.toggleNotifyOnCurrent()
            }

            Toggle {
              width: parent.width
              label: "Zone is coming up next"
              description: "Notify ~30 minutes early, as soon as a watched zone is queued next."
              foreground: root.foreground
              checked: root.notifyOnNext
              onClicked: root.toggleNotifyOnNext()
            }

            MultiSelect {
              width: parent.width
              label: "Watched zones"
              values: root.watchedZones
              options: Model.zoneOptions()
              placeholderText: "Search zones…"
              noSelectionText: "No zones watched"
              foreground: root.foreground
              onChanged: function(values) { root.setWatchedZones(values) }
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: "Data from d2runewizard.com" + (tz.lastUpdated ? " · updated " + Qt.formatTime(tz.lastUpdated, "HH:mm:ss") : "")
            color: Qt.darker(root.foreground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
