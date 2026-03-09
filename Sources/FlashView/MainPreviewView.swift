import SwiftUI

struct MainPreviewView: View {
    @EnvironmentObject var appState: AppState
    @State private var loadedImage: NSImage?
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(colorForSimulation(appState.adjustments.filmSimulation))
                    .brightness(appState.adjustments.exposure)
                    .contrast(appState.adjustments.contrast)
                    .saturation(appState.adjustments.saturation * saturationForSimulation(appState.adjustments.filmSimulation))
                    .id(appState.currentImage?.absoluteString ?? "" + "\(appState.adjustments.filmSimulation)")
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.1), value: appState.currentImage)
                    .contextMenu {
                        Button("Good (3)") { appState.applyRating(3) }
                        Button("Maybe (2)") { appState.applyRating(2) }
                        Button("Bad (1)") { appState.applyRating(1) }
                        Divider()
                        Button("Delete", role: .destructive) { appState.deleteCurrentImage() }
                    }
            } else {
                ProgressView()
            }
            
            // Top Info Overlay
            VStack {
                HStack {
                    if let url = appState.currentImage {
                        let name = url.lastPathComponent
                        Text(name)
                            .font(.subheadline)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    if let r = appState.currentRating {
                        Text(ratingText)
                            .font(.subheadline).bold()
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(ratingColor)
                            .cornerRadius(12)
                            .foregroundColor(ratingColor == .yellow ? .black : .white)
                            .padding()
                    }
                }
                Spacer()
            }
            
            // Toast / Feedback Overlay
            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.title2)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: appState.toastMessage)
            }
        }
        .onChange(of: appState.currentImage) { newImage in
            loadImage(url: newImage)
        }
        .onAppear {
            loadImage(url: appState.currentImage)
        }
    }
    
    private var ratingText: String {
        if let r = appState.currentRating {
            if r == 3 { return "Good" }
            else if r == 2 { return "Maybe" }
            else if r == 1 { return "Bad" }
            else { return "\(r) Stars" }
        }
        return "Unrated"
    }
    
    private var ratingColor: Color {
        if let r = appState.currentRating {
            if r == 3 { return .green }
            else if r == 2 { return .yellow }
            else if r == 1 { return .red }
        }
        return .white
    }
    
    private func colorMultiply(for simulation: FilmSimulation) -> Color {
        return colorForSimulation(simulation)
    }
    
    // Simplistic Film Simulations using SwiftUI modifiers
    private func colorForSimulation(_ sim: FilmSimulation) -> Color {
        switch sim {
        case .none, .provia: return .white
        case .velvia: return Color(red: 1.05, green: 1.0, blue: 1.05)
        case .astia: return Color(red: 1.0, green: 0.95, blue: 0.95)
        case .classicChrome: return Color(red: 0.9, green: 0.95, blue: 0.9)
        }
    }
    
    private func saturationForSimulation(_ sim: FilmSimulation) -> Double {
        switch sim {
        case .none, .provia: return 1.0
        case .velvia: return 1.4
        case .astia: return 0.9
        case .classicChrome: return 0.7
        }
    }
    
    private func loadImage(url: URL?) {
        guard let url = url else {
            loadedImage = nil
            return
        }
        
        // Load on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let img = ImageProcessor.shared.loadLargeImage(from: url)
            DispatchQueue.main.async {
                self.loadedImage = img
            }
        }
    }
}
