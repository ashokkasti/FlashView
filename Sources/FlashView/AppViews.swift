import SwiftUI
import AppKit

// MARK: - Scroll Detector Helper
struct ScrollDetector: NSViewRepresentable {
    var onScroll: (CGPoint) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollViewWrapper()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ScrollViewWrapper: NSView {
        var onScroll: ((CGPoint) -> Void)?
        private var monitor: Any?
        
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            
            if let window = newWindow {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                    guard let self = self else { return event }
                    // Check if mouse is over this view
                    let windowLoc = event.locationInWindow
                    let viewPoint = self.convert(windowLoc, from: nil)
                    
                    if self.bounds.contains(viewPoint) {
                        let dx = event.scrollingDeltaX
                        let dy = event.scrollingDeltaY
                        
                        // We use the raw delta for more consistency
                        self.onScroll?(CGPoint(x: dx, y: dy))
                    }
                    return event
                }
            }
        }
        
        deinit {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
