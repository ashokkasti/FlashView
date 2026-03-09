import SwiftUI

struct ThumbnailStripView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(Array(appState.viewImages.enumerated()), id: \.element) { index, url in
                        ThumbnailItemView(
                            url: url,
                            isSelected: index == appState.currentIndex,
                            rating: appState.imageRatings[url]
                        )
                        .id(url)
                        .onTapGesture {
                            appState.currentIndex = index
                        }
                    }
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            .onChange(of: appState.currentIndex) { newIndex in
                let list = appState.viewImages
                if newIndex >= 0 && newIndex < list.count {
                    let url = list[newIndex]
                    withAnimation {
                        proxy.scrollTo(url, anchor: .center)
                    }
                }
            }
        }
    }
}

struct ThumbnailItemView: View {
    let url: URL
    let isSelected: Bool
    let rating: Int?
    
    @State private var thumbnail: NSImage?
    @State private var isHovered: Bool = false
    
    var ratingColor: Color {
        if let r = rating {
            if r == 3 { return .green }
            if r == 2 { return .yellow }
            if r == 1 { return .red }
        }
        return .clear
    }
    
    var body: some View {
        ZStack {
            if let img = thumbnail {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(ProgressView())
            }
            
            if isHovered && !isSelected {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
            }
            
            // Top Right Badge
            if rating != nil {
                VStack {
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ratingColor)
                            .frame(width: 14, height: 14)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white, lineWidth: 1))
                            .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .border(isSelected ? Color.accentColor : Color.clear, width: isSelected ? 3 : 0)
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: url) { _ in
            loadThumbnail()
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    private func loadThumbnail() {
        ImageProcessor.shared.generateThumbnail(for: url) { img in
            self.thumbnail = img
        }
    }
}
