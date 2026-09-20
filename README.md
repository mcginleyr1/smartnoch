# SmartNotch

A macOS notch utility modeled on Bartender Pro's Top Shelf: the notch expands on hover into a
Dynamic-Island-style panel, and shows live activities in the "wings" beside it while collapsed.

## Features

- **Hover to expand** from the notch (on Macs without a notch, a pill at the top center of the menu bar).
- **Widgets tab**: now playing (Music / Spotify) with artwork and transport controls, upcoming calendar events, current weather.
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

## Layout

| File | Responsibility |
| --- | --- |
| `main.swift` | App bootstrap, status item, wiring monitors to HUD flashes |
| `AppModel.swift` | Observable UI state, notch geometry, current activity |
| `NotchController.swift` | Borderless panel over the notch, mouse tracking for expand/collapse |
| `NotchView.swift` / `TabViews.swift` | SwiftUI for collapsed activities and the expanded tabs |
| `SystemMonitors.swift` | Volume (CoreAudio), brightness (private DisplayServices, polled), battery (IOKit) |
| `NowPlaying.swift` | Player distributed notifications + AppleScript for artwork/controls |
| `Shelf.swift`, `ClipboardHistory.swift`, `CalendarWeather.swift` | Tab data sources (weather via open-meteo.com) |

## Not yet replicated

- Replacing the system volume/brightness HUD (ours shows alongside it; suppressing it needs a media-key event tap + Accessibility).
- Now playing for arbitrary apps/browsers (needs the private MediaRemote framework, which macOS 15.4+ restricts).
- Settings UI, keyboard shortcuts, clipboard search window, per-app clipboard ignore list, retention timers.
- Multi-display placement (the panel lives on the notched display, else the primary one).
- Calendar "join meeting" links, precipitation alerts, AI-agent live activities.
