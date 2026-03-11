import SwiftUI
import AppKit

// MARK: - Scroll Detector Helper
struct ScrollDetector: NSViewRepresentable {
    var onScroll: (CGPoint) -> Void
    var translateVerticalToHorizontal: Bool = false
    
    func makeNSView(context: Context) -> NSView {
        let view = ScrollViewWrapper()
        view.onScroll = onScroll
        view.translateVerticalToHorizontal = translateVerticalToHorizontal
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class ScrollViewWrapper: NSView {
        var onScroll: ((CGPoint) -> Void)?
        var translateVerticalToHorizontal: Bool = false
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
                        let dyStr = Double(event.scrollingDeltaY)
                        let dxStr = Double(event.scrollingDeltaX)
                        
                        
                        // Intercept vertical scrolling when no horizontal scrolling is present, IF requested
                        if self.translateVerticalToHorizontal && abs(dyStr) > 0 && abs(dxStr) == 0 {
                            guard let cgOriginal = event.cgEvent else { return event }
                            guard let cgEvent = cgOriginal.copy() else { return event }
                            
                            // Map Y delta properties to X delta properties
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: dyStr) // X Axis
                            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: 0)     // Y Axis
                            
                            let dyPoint = cgOriginal.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
                            cgEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: dyPoint)
                            cgEvent.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
                            
                            if let newEvent = NSEvent(cgEvent: cgEvent) {
                                return newEvent
                            }
                        } else {
                            // Raw delta for zoom/pan
                            self.onScroll?(CGPoint(x: event.scrollingDeltaX, y: event.scrollingDeltaY))
                        }
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

// MARK: - Native Translucency
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

