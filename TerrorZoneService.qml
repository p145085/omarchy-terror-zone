import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Polls d2runewizard.com's public terror-zone tracker on an interval and
// keeps the last good current/next reading visible across transient network
// failures. One instance runs per mounted bar widget (see KumaService in the
// sibling uptime-kuma plugin for the same shape).
Item {
  id: root

  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int refreshIntervalSec: Math.max(15, parseInt(String(setting("refreshIntervalSec", 45)), 10) || 45)

  property string current: ""
  property string next: ""
  property bool online: false
  property bool loading: false
  property string lastError: ""
  property var lastUpdated: null

  signal updated()

  function refresh() {
    if (loading) return
    loading = true
    // -q (must be first) ignores ~/.curlrc, --proto/--proto-redir pin the
    // transport to https, --max-filesize caps a hostile/compromised response.
    fetchProc.command = ["curl", "-q", "-fsS", "--proto", "=https", "--proto-redir", "=https",
      "--max-time", "8", "--max-filesize", "200000", "--", Model.API_URL]
    fetchProc.running = true
  }

  Process {
    id: fetchProc
    running: false
    command: []
    stdout: StdioCollector { id: fetchStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) {
        root.online = false
        root.lastError = "Can't reach d2runewizard.com"
        retryTimer.restart()
        return
      }
      var parsed = Model.parseResponse(fetchStdout.text)
      if (!parsed) {
        root.online = false
        root.lastError = "Unexpected response from d2runewizard.com"
        retryTimer.restart()
        return
      }
      root.current = parsed.current
      root.next = parsed.next
      root.online = true
      root.lastError = ""
      root.lastUpdated = new Date()
      root.updated()
    }
  }

  Timer {
    id: retryTimer
    interval: 5000
    repeat: false
    onTriggered: if (!root.loading) root.refresh()
  }

  Timer {
    id: pollTimer
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
