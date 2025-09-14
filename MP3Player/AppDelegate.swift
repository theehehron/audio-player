import Cocoa
import AVFoundation

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate {
    
    var window: PlayerWindow!
    var player: AVAudioPlayer?
    var fileWasOpened = false
    var mp3Files: [String] = []
    var currentIndex: Int = 0
    var currentPos: TimeInterval = 0.0
    var isPaused = false
    var folder: String = ""
    var autoAdvanceTimer: Timer?
    var statusLabel: NSTextField!
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // This gets called when a file is opened with your app
        guard FileManager.default.fileExists(atPath: filename) else {
            print("File not found: \(filename)")
            return false
        }
        
        folder = (filename as NSString).deletingLastPathComponent
        mp3Files = (try? FileManager.default.contentsOfDirectory(atPath: folder)
            .filter { $0.lowercased().hasSuffix(".mp3") }
            .sorted()) ?? []
        
        guard let index = mp3Files.firstIndex(of: (filename as NSString).lastPathComponent) else {
            print("MP3 not in folder.")
            return false
        }
        currentIndex = index
        fileWasOpened = true
        
        // Setup window if not already done
        if window == nil {
            setupWindow()
        }
        
        // Load and play the selected track
        playFile(at: currentIndex, start: 0.0)
        
        // Start auto-advance timer if not already running
        if autoAdvanceTimer == nil {
            autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                guard let player = self.player else { return }
                if !player.isPlaying && !self.isPaused && player.currentTime >= (player.duration - 0.1) {
                    self.nextTrack()
                }
            }
        }
        
        // Make window key and front
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(statusLabel)
        
        return true
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide any default windows that might have been created
        for window in NSApp.windows {
            if window !== self.window {
                window.orderOut(nil)
            }
        }
        
        // Check if launched with command-line arguments
        let args = CommandLine.arguments
        if args.count > 1 {
            // Launched from command line with file path
            let mp3File = args[1]
            guard FileManager.default.fileExists(atPath: mp3File) else {
                print("File not found: \(mp3File)")
                NSApp.terminate(nil)
                return
            }
            _ = application(NSApp, openFile: mp3File)
        } else {
            // Launched normally - setup window and wait for file via "Open With"
            setupWindow()
            if fileWasOpened == false {
                updateOverlay("Drop MP3 onto app icon or use 'Open With'...")
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeFirstResponder(statusLabel)
        }
    }
    
    func setupWindow() {
        window = PlayerWindow()
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.level = .floating  // Always on top
        window.hasShadow = false
        window.backgroundColor = .black
        window.isOpaque = true
        
        // Center at top
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenWidth = screen.frame.width
        window.setFrame(NSRect(x: (screenWidth - 450)/2, y: screen.frame.height - 60, width: 450, height: 30), display: true)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.drawsBackground = false
        statusLabel.isBordered = false
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.focusRingType = .none
        window.contentView = statusLabel
        
        // CHANGE THIS: Set first responder to statusLabel instead of window
        window.makeFirstResponder(statusLabel)
        
        // MOVE AND ADD: Set window.delegate after content setup, and add playerDelegate
        window.delegate = self  // For potential window events (NSWindowDelegate)
        window.playerDelegate = self  // ADD THIS: Custom delegate for key handling
        
    }
    
    func updateOverlay(_ text: String) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = text
        }
    }
    
    func playFile(at index: Int, start: TimeInterval) {
        currentIndex = index % mp3Files.count
        currentPos = start
        let filePath = (folder as NSString).appendingPathComponent(mp3Files[currentIndex])
        guard let url = URL(string: "file://\(filePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else { return }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.currentTime = start
            player?.play()
            isPaused = false
            updateOverlay("⏸ \(mp3Files[currentIndex])")
        } catch {
            print("Error loading \(filePath): \(error)")
        }
    }
    
    func togglePause() {
        guard let player = player else {
            print("No player available—skipping toggle")
            return
        }
        if isPaused {
            player.play()
            isPaused = false
            updateOverlay("⏸ \(mp3Files[currentIndex])")
        } else {
            player.pause()
            isPaused = true
            updateOverlay("▶ \(mp3Files[currentIndex])")
            // Short delay to let pause settle before allowing auto-advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Optional: Force a state check here if needed
            }
        }
    }
    
    func restartTrack() {
        playFile(at: currentIndex, start: 0.0)
    }
    
    func skipBack() {
        guard let player = player else { return }
        currentPos = max(0, player.currentTime - 3)
        playFile(at: currentIndex, start: currentPos)
    }
    
    func skipForward() {
        guard let player = player else { return }
        currentPos = player.currentTime + 3
        playFile(at: currentIndex, start: currentPos)
    }
    
    func prevTrack() {
        playFile(at: max(0, currentIndex - 1), start: 0.0)
    }
    
    func nextTrack() {
        playFile(at: min(currentIndex + 1, mp3Files.count - 1), start: 0.0)
    }
    
    // AVAudioPlayerDelegate: Auto-advance on finish
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && !isPaused {  // Already has this, but confirm
            nextTrack()
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        player?.stop()
        autoAdvanceTimer?.invalidate()
    }
}

// MARK: - NSApplicationDelegate extension for window events (if needed)
extension AppDelegate: NSWindowDelegate {
    // Override if you need window close handling
}
