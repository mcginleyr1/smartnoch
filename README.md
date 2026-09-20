# SmartNotch

A macOS notch utility modeled on Bartender Pro's Top Shelf: the notch expands on hover into a
Dynamic-Island-style panel, and shows live activities in the "wings" beside it while collapsed.

## Features

- **Hover to expand** from the notch. The panel follows the mouse across displays; on a display without a notch it is
  invisible until you hover the top center of the menu bar, and only notifications (HUDs, agent done / needs you) pop a pill.
- **Widgets tab**: now playing (Music / Spotify) with artwork and transport controls, upcoming calendar events, current weather.
- **Agents tab**: live state of AI coding agent sessions (Claude Code, Mistral Vibe, anything with hooks) per project:
  working, waiting for you, done. The collapsed notch shows a spinner while an agent works, a yellow hand when one
  needs you, and flashes "Done" when a turn finishes. See [Agent hooks](#agent-hooks).
- **Files tab**: drag files onto the notch to shelve up to 6 items; drag them back out, click to open, or drop on the AirDrop tile.
- **Clipboard tab**: history of the last 30 copied texts/images; click to copy again. Entries marked concealed/transient
  by password managers are skipped. History lives in memory only.
- **Live activities**: volume, brightness, battery (plug/unplug, 20/10/5%), event starting within 5 minutes, and a
  now-playing indicator (artwork + waveform) while music plays.

## Build & run

```
just install    # build, copy to /Applications/SmartNotch.app, launch
just run        # build and launch the dev bundle from build/
just uninstall
just icon       # regenerate AppIcon.icns after editing Scripts/make-icon.swift
just clean
```

Requires macOS 14+, the Xcode toolchain, and [just](https://github.com/casey/just). Quit from the menu bar icon.
To start at login, add SmartNotch under System Settings > General > Login Items.

The app is ad-hoc signed, so macOS re-prompts for permissions after each rebuild:
Automation (Music/Spotify control and artwork), Calendars, and Location (weather).

Weather uses CoreLocation when allowed. If location access is denied or Location Services is off, it falls back
to an approximate position from your IP address via get.geojs.io.

## Agent hooks

Agents report state by running the app binary in hook mode, which forwards the event to the running app
(distributed notification) and exits:

```
/Applications/SmartNotch.app/Contents/MacOS/SmartNotch notify <agent> <state>
```

`<state>` is `working`, `waiting`, `idle`, `done`, `ended` (removes the session) or `tool` (working, turning into
waiting if nothing else arrives within 10s). The hook's JSON payload is read from stdin when present
(`session_id`, `cwd`, `tool_name`, ...); without one the session is keyed by the working directory.
Sessions with no events for 10 minutes (60 when waiting) are dropped.

- **Claude Code**: merge `hooks/claude-settings.json` into `~/.claude/settings.json`. Running sessions pick the
  hooks up without a restart.
- **Mistral Vibe**: copy `hooks/vibe-hooks.toml` to `~/.vibe/hooks.toml`. Vibe has no session-start, prompt or
  approval events, so sessions appear on their first tool call and "waiting" is inferred from a stalled tool call
  (a long-running tool looks the same).
- **Codex** and others: any tool that can run a command on lifecycle events can call the same CLI.

## Layout

| File | Responsibility |
| --- | --- |
| `main.swift` | App bootstrap, status item, wiring monitors to HUD flashes |
| `AppModel.swift` | Observable UI state, notch geometry, current activity |
| `NotchController.swift` | Borderless panel over the notch, mouse tracking for expand/collapse |
| `NotchView.swift` / `TabViews.swift` | SwiftUI for collapsed activities and the expanded tabs |
| `SystemMonitors.swift` | Volume (CoreAudio), brightness (private DisplayServices, polled), battery (IOKit) |
| `NowPlaying.swift` | Player distributed notifications + AppleScript for artwork/controls |
| `Agents.swift` | Coding-agent sessions: event receiver and the `notify` hook CLI |
| `Shelf.swift`, `ClipboardHistory.swift`, `CalendarWeather.swift` | Tab data sources (weather via open-meteo.com) |

## Not yet replicated

- Replacing the system volume/brightness HUD (ours shows alongside it; suppressing it needs a media-key event tap + Accessibility).
- Now playing for arbitrary apps/browsers (needs the private MediaRemote framework, which macOS 15.4+ restricts).
- Settings UI, keyboard shortcuts, clipboard search window, per-app clipboard ignore list, retention timers.
- One panel per display (a single panel follows the mouse between displays).
- Calendar "join meeting" links, precipitation alerts.
