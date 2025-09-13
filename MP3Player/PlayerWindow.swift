import Cocoa

class PlayerWindow: NSWindow {
    weak var playerDelegate: AppDelegate?
    
    override func keyDown(with event: NSEvent) {
        guard playerDelegate != nil else {
            super.keyDown(with: event)
            return
        }
            
        // let characters = event.charactersIgnoringModifiers ?? ""
        let keyCode = event.keyCode
        
        switch keyCode {
        case 49:  // Space
            playerDelegate?.togglePause()  // Safe now due to guard
        case 82:  // 0
            playerDelegate?.restartTrack()
        case 123:  // Left arrow
            playerDelegate?.skipBack()
        case 124:  // Right arrow
            playerDelegate?.skipForward()
        case 43:   // , (comma)
            playerDelegate?.prevTrack()
        case 47:   // . (period)
            playerDelegate?.nextTrack()
        case 76:   // KP_0 (keypad 0)
            playerDelegate?.restartTrack()
        default:
            super.keyDown(with: event)
        }
    }
    
    override var canBecomeKey: Bool {
        return true  // Allow borderless window to be key
    }
    
    override var canBecomeMain: Bool {
        return true  // Allow it to be main window
    }
}
