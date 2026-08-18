# MP3 Player

A small native macOS folder jukebox for practice. Open one audio file and play the rest of that folder in name order, mostly from the keyboard.

## Features

- **Compact macOS window** — title, progress, and transport buttons
- **Keyboard-first** — play, scrub, restart, and skip tracks without the mouse
- **Folder playback** — other supported audio in the same folder, name order (types can mix)
- **Open With** — right-click a supported file in Finder → Open With → MP3Player
- **Auto-advance** — next track when one finishes
- **Hide on close** — red button hides the window; playback keeps going; Dock icon stays. ⌘Q quits.
- **Float on Top** — window stays above other apps (on by default). Toggle via **Window → Float on Top**.
- **Playback speed** — keyboard `1`–`9` set 10%–90%; keyboard `0` is 100%. `=` / `+` and `-` nudge by 1% (10%–400%). Shown as a percent on the window. Resets to 100% each launch.

## Supported formats

- MP3, WAV, AIFF (`.aif` / `.aiff`), AAC, M4A, CAF, FLAC
- Not supported: Ogg/Opus, WMA, and other formats Core Audio does not play

## Limitations

- A file that exists but will not decode still shows “Couldn’t load …” and stops (no auto-skip)

## Keyboard Controls

- **Space** — Play/Pause
- **R**, **Return**, or **numpad 0** — Restart current track
- **Keyboard 0** — 100% speed
- **1–9** — 10%–90% speed
- **=** or **+** — Increase speed by 1%
- **-** — Decrease speed by 1%
- **Left / Right Arrow** — Skip back / forward 3 seconds of **heard** time (scales with speed)
- **Comma (,)** — Previous track
- **Period (.)** — Next track
- **⌘O** — Open…
- **⌘Q** — Quit

## Launch

- Double-click the app or Run from Xcode → idle window: “Open an audio file to start”
- Finder: right-click a supported file → **Open With** → MP3Player
- Drag a file onto the Dock icon
- File → Open…
- Command line: `./MP3Player /path/to/your/song.wav`

If the app doesn’t appear in Open With:

1. Right-click a file → **Get Info**
2. **Open with:** → choose this app
3. **Change All…** if you want it as the default

## Building from Source

1. Open `MP3Player.xcodeproj` in Xcode
2. Scheme **MP3Player**, destination **My Mac**
3. Product → Run (⌘R), or Product → Build and open the `.app` in the build folder

## Key Files

- **AppDelegate.swift** — Playback, folder scan, launch, File → Open
- **PlayerWindow.swift** — Player window, controls, and keyboard input
- **Info.plist** — Registers the app for MP3 and the other supported types
