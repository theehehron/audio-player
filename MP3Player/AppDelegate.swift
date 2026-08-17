import Cocoa
import AVFoundation
import UniformTypeIdentifiers

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate, NSWindowDelegate {

    var window: PlayerWindow!
    var player: AVAudioPlayer?
    var fileWasOpened = false
    var mp3Files: [String] = []
    var currentIndex: Int = 0
    var isPaused = false
    var finishedCurrentTrack = false
    var folder: String = ""
    var progressTimer: Timer?

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
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

        ensureWindow()

        playFile(at: currentIndex, start: 0.0)
        startProgressTimer()
        presentWindow()
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for existing in NSApp.windows where existing !== window {
            existing.orderOut(nil)
        }

        bindOpenMenu()

        // Xcode passes flags like -NSDocumentRevisionsDebugMode; only treat real paths as files.
        if let mp3File = CommandLine.arguments.dropFirst().first(where: { arg in
            !arg.hasPrefix("-") && arg.lowercased().hasSuffix(".mp3")
        }) {
            if FileManager.default.fileExists(atPath: mp3File) {
                _ = application(NSApp, openFile: mp3File)
            } else {
                print("File not found: \(mp3File)")
                ensureWindow()
                window.setIdleMessage("File not found")
                presentWindow()
            }
        } else if !fileWasOpened {
            ensureWindow()
            window.setIdleMessage("Open an MP3 to start")
            presentWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ensureWindow()
        presentWindow()
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        player?.stop()
        progressTimer?.invalidate()
    }

    func ensureWindow() {
        if window == nil {
            window = PlayerWindow()
            window.delegate = self
            window.playerDelegate = self
            window.center()
        }
    }

    func presentWindow() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window)
    }

    private func bindOpenMenu() {
        guard let fileMenu = NSApp.mainMenu?.item(withTitle: "File")?.submenu,
              let openItem = fileMenu.items.first(where: { $0.title.hasPrefix("Open") && !$0.title.contains("Recent") }) else {
            return
        }
        openItem.target = self
        openItem.action = #selector(openDocument(_:))
        openItem.keyEquivalent = "o"
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an MP3 to play this folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = application(NSApp, openFile: url.path)
    }

    func playFile(at index: Int, start: TimeInterval) {
        guard !mp3Files.isEmpty else { return }
        currentIndex = min(max(index, 0), mp3Files.count - 1)

        let filePath = (folder as NSString).appendingPathComponent(mp3Files[currentIndex])
        let url = URL(fileURLWithPath: filePath)

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            let duration = player?.duration ?? 0
            player?.currentTime = min(max(0, start), max(0, duration - 0.01))
            player?.play()
            isPaused = false
            finishedCurrentTrack = false
            window.setTrackName(displayName(for: mp3Files[currentIndex]))
            window.setPlaying(true)
            updateTimeDisplay()
        } catch {
            print("Error loading \(filePath): \(error)")
            player?.stop()
            player = nil
            isPaused = true
            finishedCurrentTrack = false
            window.setIdleMessage("Couldn’t load \(mp3Files[currentIndex])")
        }
    }

    func togglePause() {
        guard let player = player else { return }
        if finishedCurrentTrack || player.currentTime >= player.duration - 0.05 {
            restartTrack()
            return
        }
        if isPaused {
            player.play()
            isPaused = false
            window.setPlaying(true)
        } else {
            player.pause()
            isPaused = true
            window.setPlaying(false)
        }
        updateTimeDisplay()
    }

    func restartTrack() {
        guard player != nil else { return }
        seek(to: 0)
        player?.play()
        isPaused = false
        finishedCurrentTrack = false
        window.setPlaying(true)
        updateTimeDisplay()
    }

    func skipBack() {
        guard let player = player else { return }
        finishedCurrentTrack = false
        seek(to: player.currentTime - 3)
    }

    func skipForward() {
        guard let player = player else { return }
        let target = player.currentTime + 3
        if target >= player.duration {
            player.currentTime = player.duration
            player.pause()
            isPaused = true
            finishedCurrentTrack = true
            window.setPlaying(false)
            updateTimeDisplay()
            return
        }
        seek(to: target)
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = min(max(0, time), max(0, player.duration))
        updateTimeDisplay()
    }

    func finishSliderSeek(to time: TimeInterval) {
        guard let player = player else { return }
        let duration = player.duration
        if duration > 0, time >= duration - 0.05, currentIndex < mp3Files.count - 1 {
            nextTrack()
            return
        }
        seek(to: time)
    }

    func prevTrack() {
        playFile(at: max(0, currentIndex - 1), start: 0)
    }

    func nextTrack() {
        playFile(at: min(currentIndex + 1, mp3Files.count - 1), start: 0)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && !isPaused && currentIndex < mp3Files.count - 1 {
            nextTrack()
        } else if flag {
            isPaused = true
            finishedCurrentTrack = true
            window.setPlaying(false)
            updateTimeDisplay()
        }
    }

    private func startProgressTimer() {
        if progressTimer == nil {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.updateTimeDisplay()
            }
        }
    }

    private func updateTimeDisplay() {
        guard let player = player else { return }
        window.setTime(current: player.currentTime, duration: player.duration)
    }

    private func displayName(for filename: String) -> String {
        (filename as NSString).deletingPathExtension
    }
}
