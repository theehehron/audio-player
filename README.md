# MP3 Player

A small native macOS folder jukebox for practice. Open one MP3 and play the rest of that folder in name order, mostly from the keyboard.

## Features

- **Compact macOS window** — title, progress, and transport buttons
- **Keyboard-first** — play, scrub, restart, and skip tracks without the mouse
- **Folder playback** — other MP3s in the same folder, name order
- **Open With** — right-click an MP3 in Finder → Open With → MP3Player
- **Auto-advance** — next track when one finishes
- **Hide on close** — red button hides the window; playback keeps going; Dock icon stays. ⌘Q quits.
- **Float on Top** — window stays above other apps (on by default). Toggle via **Window → Float on Top**.
- **Playback speed** — keyboard `1`–`9` set 10%–90%; keyboard `0` is 100%. Shown as a percent on the window. Resets to 100% each launch.

## Limitations

- MP3 files only

## Keyboard Controls

- **Space** — Play/Pause
- **R**, **Return**, or **numpad 0** — Restart current track
- **Keyboard 0** — 100% speed
- **1–9** — 10%–90% speed
- **Left / Right Arrow** — Skip back / forward 3 seconds of **heard** time (scales with speed)
- **Comma (,)** — Previous track
- **Period (.)** — Next track
- **⌘O** — Open…
- **⌘Q** — Quit

## Launch

- Double-click the app or Run from Xcode → idle window: “Open an MP3 to start”
- Finder: right-click an `.mp3` → **Open With** → MP3Player
- Drag an MP3 onto the Dock icon
- File → Open…
- Command line: `./MP3Player /path/to/your/song.mp3`

If the app doesn’t appear in Open With:

1. Right-click any MP3 → **Get Info**
2. **Open with:** → choose this app
3. **Change All…** if you want it as the default

## Building from Source

1. Open `MP3Player.xcodeproj` in Xcode
2. Scheme **MP3Player**, destination **My Mac**
3. Product → Run (⌘R), or Product → Build and open the `.app` in the build folder

## Key Files

- **AppDelegate.swift** — Playback, folder scan, launch, File → Open
- **PlayerWindow.swift** — Player window, controls, and keyboard input
- **Info.plist** — Registers the app as an MP3 handler
