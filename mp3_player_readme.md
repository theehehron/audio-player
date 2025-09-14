# MP3 Player - macOS Overlay Player

A minimalist macOS MP3 player that displays a floating overlay window at the top of your screen. Control playback with keyboard shortcuts and navigate through entire folders of MP3 files.

## Features

- **Floating overlay window** - Always visible at the top of your screen
- **Keyboard controls** - No need to click, just use keys
- **Folder playback** - Automatically plays all MP3s in the same folder
- **"Open With" support** - Right-click any MP3 in Finder to open with this player
- **Auto-advance** - Automatically moves to the next track when one finishes

## Limitations
- **Only supports MP3 files at this time**

## Keyboard Controls

- **Space** - Play/Pause
- **R** - Restart current track
- **Left Arrow** - Skip back 3 seconds
- **Right Arrow** - Skip forward 3 seconds
- **Comma (,)** - Previous track
- **Period (.)** - Next track
- **CMD+Q** - Quit

## Building from Source

### 1. Clone or Download the Project
```bash
git clone https://github.com/theehehron/audio-player.git
```

### 2. Open in Xcode
- Open `MP3Player.xcodeproj` in Xcode

### 3. Build the App
- **Press ⌘+B** to build
- **Or Product → Build**

### 4. Export for Distribution
**Quick Test Build**
1. **Product → Show Build Folder in Finder**
2. **Navigatate to .app file and Copy the .app file** to your Applications folder

### GUI Usage
1. **Copy the app** to your Applications folder
2. **Right-click any MP3** in Finder
3. **Open With** → Select MP3Player
4. **Or drag MP3 files** onto the app icon

### Command Line Usage
```bash
./MP3Player /path/to/your/song.mp3
```

### Register as MP3 Handler
If the app doesn't appear in "Open With" menus:
1. **Right-click any MP3** → **Get Info**
2. **Open with:** → **Choose your app**
3. **Click "Change All..."** to set as default

## Key Files

- **AppDelegate.swift** - Contains all the music playback logic, file handling, and UI management
- **PlayerWindow.swift** - Custom NSWindow subclass that handles keyboard input
- **Info.plist** - Configures the app to handle MP3 files

## Customization

- **Change keyboard shortcuts** - Edit the key codes in PlayerWindow.swift
- **Modify overlay appearance** - Edit setupWindow() in AppDelegate.swift  
- **Add More Features** - Do whatever you want lol