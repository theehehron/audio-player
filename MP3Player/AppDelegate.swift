import Cocoa
import AVFoundation
import UniformTypeIdentifiers

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, AVAudioPlayerDelegate, NSWindowDelegate {

    var window: PlayerWindow!
    var player: AVAudioPlayer?
    var fileWasOpened = false
    var audioFiles: [String] = []
    var currentIndex: Int = 0
    var isPaused = false
    var finishedCurrentTrack = false
    var folder: String = ""
    var progressTimer: Timer?
    var playbackRate: Float = 1.0
    var floatsOnTop = true
    var floatMenuItem: NSMenuItem?

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard FileManager.default.fileExists(atPath: filename) else {
            print("File not found: \(filename)")
            return false
        }

        folder = (filename as NSString).deletingLastPathComponent
        audioFiles = (try? FileManager.default.contentsOfDirectory(atPath: folder)
            .filter { Self.isSupportedAudio($0) }
            .sorted()) ?? []

        guard let index = audioFiles.firstIndex(of: (filename as NSString).lastPathComponent) else {
            print("Audio file not in folder.")
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
        bindFloatMenu()

        // Xcode passes flags like -NSDocumentRevisionsDebugMode; only treat real paths as files.
        if let audioFile = CommandLine.arguments.dropFirst().first(where: { arg in
            !arg.hasPrefix("-") && Self.isSupportedAudio(arg)
        }) {
            if FileManager.default.fileExists(atPath: audioFile) {
                _ = application(NSApp, openFile: audioFile)
            } else {
                print("File not found: \(audioFile)")
                ensureWindow()
                window.setIdleMessage("File not found")
                presentWindow()
            }
        } else if !fileWasOpened {
            ensureWindow()
            window.setIdleMessage("Open an audio file to start")
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
        window.setFloatsOnTop(floatsOnTop)
        window.setSpeedPercent(Int((playbackRate * 100).rounded()))
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

    private func bindFloatMenu() {
        guard let windowMenu = NSApp.mainMenu?.item(withTitle: "Window")?.submenu else { return }
        let item = NSMenuItem(
            title: "Float on Top",
            action: #selector(toggleFloatOnTop(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.state = floatsOnTop ? .on : .off
        windowMenu.insertItem(item, at: 0)
        windowMenu.insertItem(.separator(), at: 1)
        floatMenuItem = item
    }

    @objc func toggleFloatOnTop(_ sender: Any?) {
        floatsOnTop.toggle()
        floatMenuItem?.state = floatsOnTop ? .on : .off
        ensureWindow()
        window.setFloatsOnTop(floatsOnTop)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.supportedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an audio file to play this folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = application(NSApp, openFile: url.path)
    }

    func playFile(at index: Int, start: TimeInterval) {
        guard !audioFiles.isEmpty else { return }
        currentIndex = min(max(index, 0), audioFiles.count - 1)

        let filePath = (folder as NSString).appendingPathComponent(audioFiles[currentIndex])
        let url = URL(fileURLWithPath: filePath)

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.enableRate = true
            player?.rate = playbackRate
            player?.prepareToPlay()
            let duration = player?.duration ?? 0
            player?.currentTime = min(max(0, start), max(0, duration - 0.01))
            player?.play()
            player?.rate = playbackRate
            isPaused = false
            finishedCurrentTrack = false
            window.setTrackName(displayName(for: audioFiles[currentIndex]))
            window.setPlaying(true)
            window.setSpeedPercent(Int((playbackRate * 100).rounded()))
            updateTimeDisplay()
        } catch {
            print("Error loading \(filePath): \(error)")
            player?.stop()
            player = nil
            isPaused = true
            finishedCurrentTrack = false
            window.setIdleMessage("Couldn’t load \(audioFiles[currentIndex])")
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
        seek(to: player.currentTime - heardSkipDelta())
    }

    func skipForward() {
        guard let player = player else { return }
        let target = player.currentTime + heardSkipDelta()
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

    func setPlaybackPercent(_ percent: Int) {
        let clamped = min(max(percent, 10), 100)
        playbackRate = Float(clamped) / 100
        if let player = player {
            player.enableRate = true
            player.rate = playbackRate
        }
        window.setSpeedPercent(clamped)
    }

    private func heardSkipDelta() -> TimeInterval {
        3.0 * Double(playbackRate)
    }

    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        player.currentTime = min(max(0, time), max(0, player.duration))
        updateTimeDisplay()
    }

    func finishSliderSeek(to time: TimeInterval) {
        guard let player = player else { return }
        let duration = player.duration
        if duration > 0, time >= duration - 0.05, currentIndex < audioFiles.count - 1 {
            nextTrack()
            return
        }
        seek(to: time)
    }

    func prevTrack() {
        playFile(at: max(0, currentIndex - 1), start: 0)
    }

    func nextTrack() {
        playFile(at: min(currentIndex + 1, audioFiles.count - 1), start: 0)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag && !isPaused && currentIndex < audioFiles.count - 1 {
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

    private static let supportedExtensions: Set<String> = [
        "mp3", "wav", "aif", "aiff", "aac", "m4a", "caf", "flac"
    ]

    private static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.mp3, .wav, .aiff, .mpeg4Audio]
        if let aac = UTType("public.aac-audio") { types.append(aac) }
        if let caf = UTType("com.apple.coreaudio-format") { types.append(caf) }
        if let flac = UTType("org.xiph.flac") ?? UTType("public.flac") { types.append(flac) }
        return types
    }

    private static func isSupportedAudio(_ filename: String) -> Bool {
        supportedExtensions.contains((filename as NSString).pathExtension.lowercased())
    }
}
