# Omarchy Terror Zone

A [Diablo II: Resurrected](https://diablo2.blizzard.com/) terror zone tracker for the [Omarchy](https://omarchy.org/) bar (Hyprland + Quickshell). Shows the current and next terrorized zone, a countdown to the next rotation, and desktop notifications for zones you're watching.

## Why

D2R's terror zone rotates every 30 minutes and picking the right one matters for farming — this puts the current/next zone and a countdown directly in the bar, with notifications so you don't have to keep a browser tab open to catch a zone you actually want.

## Features

- **Bar pill** — skull icon + live countdown to the next rotation.
- **Dropdown panel** — current zone, next zone, and how long until each changes.
- **Watch list** — pick specific zones (searchable, grouped by act) to get notified about.
- **Notifications** — optional alerts when a watched zone is terrorized now, and ~30 minutes early when one's coming up next. Deduped per rotation cycle.
- **Right-click** the bar pill for an instant status notification; **middle-click** to force a refresh.
- Survives transient network failures — keeps showing the last known state rather than going blank.
- Multi-monitor safe — only one bar instance sends notifications, so you don't get tripled alerts.

## Requirements

- Omarchy / Hyprland + Quickshell.
- `curl`, for polling the tracker API.

## Install

```bash
omarchy plugin add https://github.com/p145085/omarchy-terror-zone.git --enable --yes
omarchy bar move emila.terror-zone --section right
```

Or by hand:

```bash
git clone https://github.com/p145085/omarchy-terror-zone.git ~/.config/omarchy/plugins/emila.terror-zone
omarchy-shell shell rescanPlugins
omarchy plugin enable emila.terror-zone right
```

## Configuration

Available from the widget's dropdown panel, or set directly on its entry in `~/.config/omarchy/shell.json` (`bar.layout.<section>`):

| Key | Default | Meaning |
|---|---|---|
| `refreshIntervalSec` | `45` | How often to poll the tracker API, in seconds (15–300). |
| `notifyOnCurrent` | `true` | Notify when a watched zone becomes the active terror zone. |
| `notifyOnNext` | `true` | Notify ~30 minutes early when a watched zone is queued next. |
| `watchedZones` | `[]` | Zone names to watch for notifications. |

## Data source

Zone data comes from [d2runewizard.com](https://d2runewizard.com/)'s public terror-zone tracker API (no key required, edge-cached ~30–60s).

## Known limitations

- Depends on d2runewizard.com's tracker staying available and accurate.
- The rotation countdown is self-computed on a fixed 30-minute clock and re-synced against the API each cycle, rather than reading a server-provided boundary directly.

## License

MIT — see [LICENSE](LICENSE).
