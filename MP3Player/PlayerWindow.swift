import Cocoa

class PlayerWindow: NSWindow {
    weak var playerDelegate: AppDelegate?

    let titleLabel = NSTextField(labelWithString: "No Track")
    let timeLabel = NSTextField(labelWithString: "0:00 / 0:00")
    let speedLabel = NSTextField(labelWithString: "100%")
    let progressSlider = NSSlider()
    let playPauseButton = NSButton()
    let prevButton = NSButton()
    let nextButton = NSButton()
    let backButton = NSButton()
    let forwardButton = NSButton()

    private var isSeeking = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupChrome()
        setupContent()
    }

    convenience init() {
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 148),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if handleKeyEvent(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isNumpadZero(event) {
            playerDelegate?.restartTrack()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func insertText(_ insertString: Any) {
        let text = (insertString as? String) ?? (insertString as? NSString as String?) ?? ""
        // Keypad 0 often arrives as insertText instead of a command keyDown.
        // Top-row 0 is keyCode 29 and is handled in keyDown as 100% speed.
        if text == "0", let event = NSApp.currentEvent, event.keyCode != 29 {
            playerDelegate?.restartTrack()
            return
        }
        super.insertText(insertString)
    }

    /// Returns true if the event was a player command (so the caller should swallow it).
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard playerDelegate != nil else { return false }

        if isNumpadZero(event) {
            playerDelegate?.restartTrack()
            return true
        }

        switch event.keyCode {
        case 49: // Space
            playerDelegate?.togglePause()
        case 15, 36: // R, Return
            playerDelegate?.restartTrack()
        case 29: // keyboard 0
            playerDelegate?.setPlaybackPercent(100)
        case 18:
            playerDelegate?.setPlaybackPercent(10)
        case 19:
            playerDelegate?.setPlaybackPercent(20)
        case 20:
            playerDelegate?.setPlaybackPercent(30)
        case 21:
            playerDelegate?.setPlaybackPercent(40)
        case 23:
            playerDelegate?.setPlaybackPercent(50)
        case 22:
            playerDelegate?.setPlaybackPercent(60)
        case 26:
            playerDelegate?.setPlaybackPercent(70)
        case 28:
            playerDelegate?.setPlaybackPercent(80)
        case 25:
            playerDelegate?.setPlaybackPercent(90)
        case 123:
            playerDelegate?.skipBack()
        case 124:
            playerDelegate?.skipForward()
        case 43:
            playerDelegate?.prevTrack()
        case 47:
            playerDelegate?.nextTrack()
        default:
            return false
        }
        return true
    }

    private func isNumpadZero(_ event: NSEvent) -> Bool {
        if event.keyCode == 82 { return true }
        let chars = event.charactersIgnoringModifiers ?? ""
        return event.modifierFlags.contains(.numericPad) && chars == "0"
    }

    func setPlaying(_ playing: Bool) {
        playPauseButton.image = NSImage(
            systemSymbolName: playing ? "pause.fill" : "play.fill",
            accessibilityDescription: playing ? "Pause" : "Play"
        )
    }

    func setTrackName(_ name: String) {
        titleLabel.stringValue = name
        self.title = name
    }

    func setTime(current: TimeInterval, duration: TimeInterval) {
        timeLabel.stringValue = "\(formatTime(current)) / \(formatTime(duration))"
        guard !isSeeking, duration > 0 else { return }
        progressSlider.maxValue = duration
        progressSlider.doubleValue = current
    }

    func setIdleMessage(_ message: String) {
        titleLabel.stringValue = message
        self.title = "MP3 Player"
        timeLabel.stringValue = "0:00 / 0:00"
        progressSlider.doubleValue = 0
        progressSlider.maxValue = 1
        setPlaying(false)
    }

    func setSpeedPercent(_ percent: Int) {
        speedLabel.stringValue = "\(percent)%"
    }

    func setFloatsOnTop(_ floats: Bool) {
        level = floats ? .floating : .normal
    }

    private func setupChrome() {
        title = "MP3 Player"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        backgroundColor = .windowBackgroundColor
        level = .floating
    }

    private func setupContent() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 148))
        root.wantsLayer = true
        contentView = root

        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .center
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        speedLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        speedLabel.textColor = .secondaryLabelColor
        speedLabel.alignment = .right
        speedLabel.translatesAutoresizingMaskIntoConstraints = false

        progressSlider.minValue = 0
        progressSlider.maxValue = 1
        progressSlider.doubleValue = 0
        progressSlider.target = self
        progressSlider.action = #selector(sliderChanged(_:))
        progressSlider.refusesFirstResponder = true
        progressSlider.isContinuous = true
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        _ = progressSlider.sendAction(on: [.leftMouseDown, .leftMouseDragged, .leftMouseUp])

        configureButton(prevButton, symbol: "backward.end.fill", action: #selector(prevTapped), tooltip: "Previous track")
        configureButton(backButton, symbol: "gobackward", action: #selector(backTapped), tooltip: "Skip back 3 seconds")
        configureButton(playPauseButton, symbol: "play.fill", action: #selector(playPauseTapped), tooltip: "Play/Pause")
        configureButton(forwardButton, symbol: "goforward", action: #selector(forwardTapped), tooltip: "Skip forward 3 seconds")
        configureButton(nextButton, symbol: "forward.end.fill", action: #selector(nextTapped), tooltip: "Next track")

        let controls = NSStackView(views: [prevButton, backButton, playPauseButton, forwardButton, nextButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12
        controls.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(titleLabel)
        root.addSubview(progressSlider)
        root.addSubview(timeLabel)
        root.addSubview(speedLabel)
        root.addSubview(controls)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            progressSlider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            progressSlider.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            progressSlider.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),

            timeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 2),
            timeLabel.centerXAnchor.constraint(equalTo: root.centerXAnchor),

            speedLabel.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            speedLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            speedLabel.leadingAnchor.constraint(greaterThanOrEqualTo: timeLabel.trailingAnchor, constant: 8),

            controls.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 8),
            controls.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            controls.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -12)
        ])
    }

    private func configureButton(_ button: NSButton, symbol: String, action: Selector, tooltip: String) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.target = self
        button.action = action
        button.refusesFirstResponder = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 28).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    @objc private func playPauseTapped() {
        playerDelegate?.togglePause()
        makeFirstResponder(self)
    }

    @objc private func prevTapped() {
        playerDelegate?.prevTrack()
        makeFirstResponder(self)
    }

    @objc private func nextTapped() {
        playerDelegate?.nextTrack()
        makeFirstResponder(self)
    }

    @objc private func backTapped() {
        playerDelegate?.skipBack()
        makeFirstResponder(self)
    }

    @objc private func forwardTapped() {
        playerDelegate?.skipForward()
        makeFirstResponder(self)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        isSeeking = true
        let eventType = NSApp.currentEvent?.type
        if eventType == .leftMouseUp {
            playerDelegate?.finishSliderSeek(to: sender.doubleValue)
            isSeeking = false
            makeFirstResponder(self)
        } else {
            playerDelegate?.seek(to: sender.doubleValue)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time >= 0 else { return "0:00" }
        let total = Int(time.rounded(.down))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
