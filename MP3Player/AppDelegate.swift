import Cocoa
import AVFoundation
import CoreMedia
import UniformTypeIdentifiers

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var window: PlayerWindow!
    var player: AVPlayer?
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
    private var endObserver: NSObjectProtocol?
    private var itemStatusObserver: NSKeyValueObservation?

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
        tearDownPlayer()
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

        guard FileManager.default.isReadableFile(atPath: filePath) else {
            print("Not readable: \(filePath)")
            failLoad()
            return
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? NSNumber)?.int64Value ?? -1
        if fileSize == 0 {
            print("Empty file: \(filePath)")
            failLoad(message: "Empty file: \(audioFiles[currentIndex])")
            return
        }

        tearDownPlayer()

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        player = newPlayer

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.itemDidFinish()
        }

        itemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleItemStatus(item)
            }
        }

        isPaused = true
        finishedCurrentTrack = false
        window.setTrackName(displayName(for: audioFiles[currentIndex]))
        window.setPlaying(true)
        window.setSpeedPercent(Int((playbackRate * 100).rounded()))
        seek(to: start) { [weak self] finished in
            guard let self, finished, self.player != nil else { return }
            self.isPaused = false
            self.playAtCurrentRate()
            self.updateTimeDisplay()
        }
    }

    func togglePause() {
        guard player != nil else { return }
        if finishedCurrentTrack || (durationSeconds() > 0 && currentSeconds() >= durationSeconds() - 0.05) {
            restartTrack()
            return
        }
        if isPaused {
            playAtCurrentRate()
            isPaused = false
            window.setPlaying(true)
        } else {
            player?.pause()
            isPaused = true
            window.setPlaying(false)
        }
        updateTimeDisplay()
    }

    func restartTrack() {
        guard player != nil else { return }
        isPaused = true
        window.setPlaying(true)
        seek(to: 0) { [weak self] finished in
            guard let self, finished, self.player != nil else { return }
            self.finishedCurrentTrack = false
            self.isPaused = false
            self.playAtCurrentRate()
            self.updateTimeDisplay()
        }
    }

    func skipBack() {
        guard player != nil else { return }
        finishedCurrentTrack = false
        seek(to: currentSeconds() - heardSkipDelta())
    }

    func skipForward() {
        guard player != nil else { return }
        let duration = durationSeconds()
        let target = currentSeconds() + heardSkipDelta()
        if duration > 0, target >= duration {
            seek(to: duration)
            player?.pause()
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
        if player != nil, !isPaused, !finishedCurrentTrack {
            playAtCurrentRate()
        }
        window.setSpeedPercent(clamped)
    }

    private func heardSkipDelta() -> TimeInterval {
        3.0 * Double(playbackRate)
    }

    func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        guard let player = player else {
            completion?(false)
            return
        }
        let duration = durationSeconds()
        let clamped = duration > 0 ? min(max(0, time), duration) : max(0, time)
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            DispatchQueue.main.async {
                self?.updateTimeDisplay()
                completion?(finished)
            }
        }
    }

    func finishSliderSeek(to time: TimeInterval) {
        guard player != nil else { return }
        let duration = durationSeconds()
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

    private func itemDidFinish() {
        if isPaused { return }
        if currentIndex < audioFiles.count - 1 {
            nextTrack()
        } else {
            isPaused = true
            finishedCurrentTrack = true
            window.setPlaying(false)
            updateTimeDisplay()
        }
    }

    private func handleItemStatus(_ item: AVPlayerItem) {
        guard item === player?.currentItem else { return }
        if item.status == .failed {
            print("Error loading item: \(item.error?.localizedDescription ?? "unknown")")
            failLoad()
        }
    }

    private func failLoad(message: String? = nil) {
        tearDownPlayer()
        isPaused = true
        finishedCurrentTrack = false
        window.setIdleMessage(message ?? "Couldn’t load \(audioFiles[currentIndex])")
    }

    private func playAtCurrentRate() {
        player?.play()
        player?.rate = playbackRate
    }

    private func tearDownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func currentSeconds() -> TimeInterval {
        guard let seconds = player?.currentTime().seconds, seconds.isFinite else { return 0 }
        return seconds
    }

    private func durationSeconds() -> TimeInterval {
        guard let seconds = player?.currentItem?.duration.seconds, seconds.isFinite else { return 0 }
        return seconds
    }

    private func startProgressTimer() {
        if progressTimer == nil {
            progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.updateTimeDisplay()
            }
        }
    }

    private func updateTimeDisplay() {
        guard player != nil else { return }
        window.setTime(current: currentSeconds(), duration: durationSeconds())
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
