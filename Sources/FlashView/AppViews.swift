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
        
        override func scrollWheel(with event: NSEvent) {
            // Use precise scrolling delta if available, otherwise delta
            let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
            onScroll?(CGPoint(x: dx, y: dy))
        }
    }
}
