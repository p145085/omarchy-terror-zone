// Pure helpers for the terror-zone widget: response parsing, the 30-minute
// rotation clock, watch-list matching, and display formatting. Kept free of
// QML/Quickshell types so it can be unit tested with plain node/mjs.

// d2runewizard.com's public tracker endpoint (no key, no auth). Cached at the
// edge for 30-60s, so polling faster than that just re-reads the same cache.
var API_URL = "https://d2runewizard.com/api/trackers/terror-zone"

// Individual D2R terror-zone areas, grouped by act. The live API returns a
// comma-joined "zone group" string (e.g. "Lost City, Valley of Snakes, and
// Claw Viper Temple"); watch-list matching is done as a case-insensitive
// substring test against these single area names, so the exact wording/
// grouping the API uses for a given rotation doesn't need to match this list
// verbatim - only the area name itself has to appear somewhere in it.
function zoneOptions() {
  var acts = [
    ["Act I", ["Blood Moor", "Den of Evil", "Cold Plains", "Cave", "Burial Grounds", "Crypt",
      "Mausoleum", "Stony Field", "Underground Passage", "Dark Wood", "Black Marsh", "The Hole",
      "The Forgotten Tower", "Jail", "Barracks", "Cathedral", "Catacombs", "Pit", "Tristram"]],
    ["Act II", ["Rocky Waste", "Stony Tomb", "Dry Hills", "Halls of the Dead", "Far Oasis",
      "Lost City", "Valley of Snakes", "Claw Viper Temple", "Ancient Tunnels", "Arcane Sanctuary",
      "Tal Rasha's Tomb", "Tal Rasha's Chamber"]],
    ["Act III", ["Spider Forest", "Spider Cavern", "Great Marsh", "Flayer Jungle", "Flayer Dungeon",
      "Kurast Bazaar", "Ruined Temple", "Disused Fane", "Travincal", "Durance of Hate"]],
    ["Act IV", ["Outer Steppes", "Plains of Despair", "River of Flame", "City of the Damned",
      "Chaos Sanctuary"]],
    ["Act V", ["Bloody Foothills", "Frigid Highlands", "Abaddon", "Glacial Trail", "Drifter Cavern",
      "Crystalline Passage", "Frozen River", "Nihlathak's Temple", "Halls of Anguish",
      "Halls of Pain", "Halls of Vaught", "Ancient's Way", "Icy Cellar", "Arreat Plateau",
      "Pit of Acheron", "Worldstone Keep", "Throne of Destruction"]]
  ]
  var out = []
  for (var a = 0; a < acts.length; a++) {
    var act = acts[a][0]
    var names = acts[a][1]
    for (var i = 0; i < names.length; i++)
      out.push({ value: names[i], label: names[i], description: act })
  }
  return out
}

// Accepts the raw JSON text from API_URL. Returns { current, next } (either
// may be "" if the field was missing) or null if the body wasn't parseable.
function parseResponse(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  try {
    var data = JSON.parse(text)
    var current = typeof data.current === "string" ? data.current
      : (data.currentTerrorZone && data.currentTerrorZone.zone) || ""
    var next = typeof data.next === "string" ? data.next
      : (data.nextTerrorZone && data.nextTerrorZone.zone) || ""
    if (!current && !next) return null
    return { current: String(current), next: String(next) }
  } catch (e) {
    return null
  }
}

// Terror zones flip on a fixed 30-minute wall-clock grid (:00 and :30),
// independent of timezone - the same rule the public trackers use client-side.
function cycleBoundaries(now) {
  var d = new Date(now.getTime())
  d.setSeconds(0, 0)
  d.setMinutes(d.getMinutes() < 30 ? 0 : 30)
  var cycleStart = d.getTime()
  var cycleEnd = cycleStart + 30 * 60 * 1000
  return { cycleStart: cycleStart, cycleEnd: cycleEnd, nextCycleStart: cycleEnd, nextCycleEnd: cycleEnd + 30 * 60 * 1000 }
}

function formatCountdown(ms) {
  var total = Math.max(0, Math.round(ms / 1000))
  var m = Math.floor(total / 60)
  var s = total % 60
  return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
}

// First area/location in a comma-joined zone-group string, for compact
// display (bar pill, notification titles).
function shortLabel(zoneString) {
  var s = String(zoneString || "").trim()
  if (!s) return ""
  return s.split(",")[0].trim()
}

function normalizedWatchList(values) {
  var out = []
  var seen = {}
  var arr = (values && typeof values.length === "number") ? values : []
  for (var i = 0; i < arr.length; i++) {
    var v = String(arr[i] || "").trim()
    if (!v) continue
    var key = v.toLowerCase()
    if (seen[key]) continue
    seen[key] = true
    out.push(v)
  }
  return out
}

// Which watched entries appear (case-insensitively) in zoneString. Returns
// the watch-list's own labels (not lowercased) so callers can display them.
function matchingWatches(zoneString, watchList) {
  var haystack = String(zoneString || "").toLowerCase()
  if (!haystack) return []
  var out = []
  var list = normalizedWatchList(watchList)
  for (var i = 0; i < list.length; i++) {
    if (haystack.indexOf(list[i].toLowerCase()) !== -1) out.push(list[i])
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = {
    API_URL: API_URL,
    zoneOptions: zoneOptions,
    parseResponse: parseResponse,
    cycleBoundaries: cycleBoundaries,
    formatCountdown: formatCountdown,
    shortLabel: shortLabel,
    normalizedWatchList: normalizedWatchList,
    matchingWatches: matchingWatches
  }
}
