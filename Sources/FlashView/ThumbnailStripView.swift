import SwiftUI

struct ThumbnailStripView: View {
    @EnvironmentObject var appState: AppState
    private let thumbnailWindowRadius = 30

    private var visibleIndices: Range<Int> {
        let count = appState.viewImages.count
        guard count > 0 else { return 0..<0 }

        let lower = max(0, appState.currentIndex - thumbnailWindowRadius)
        let upper = min(count, appState.currentIndex + thumbnailWindowRadius + 1)
        return lower..<upper
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 4) {
                    let urls = appState.viewImages
                    ForEach(Array(visibleIndices), id: \.self) { index in
                        let url = urls[index]
                        ThumbnailItemView(
                            url: url,
                            isSelected: index == appState.currentIndex,
                            rating: appState.imageRatings[url],
                            reloadToken: appState.imageReloadToken,
                            onSelect: { appState.selectImage(at: index) }
                        )
                        .id(url)
                    }
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
            }
            .background(
                ScrollDetector(onScroll: { _ in }, translateVerticalToHorizontal: true)
            )
            .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
            .onChange(of: appState.currentIndex) { newIndex in
                let list = appState.viewImages
                if newIndex >= 0 && newIndex < list.count {
                    let url = list[newIndex]
                    DispatchQueue.main.async {
                        proxy.scrollTo(url, anchor: .leading)
                    }
                }
            }
            .onChange(of: appState.isGridViewActive) { isActive in
                if !isActive {
                    scrollToCurrentItem(proxy: proxy)
                }
            }
            .onAppear {
                scrollToCurrentItem(proxy: proxy)
            }
        }
    }
    
    private func scrollToCurrentItem(proxy: ScrollViewProxy) {
        let list = appState.viewImages
        let index = appState.currentIndex
        if index >= 0 && index < list.count {
            let url = list[index]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(url, anchor: .leading)
            }
        }
    }
}


struct ThumbnailItemView: View {
    let url: URL
    let isSelected: Bool
    let rating: Int?
    let reloadToken: UUID
    var onSelect: (() -> Void)? = nil
    
    @State private var thumbnail: NSImage?
    @State private var isHovered: Bool = false
    @State private var thumbnailRequest: ImageProcessor.ThumbnailRequest?
    
    var ratingColor: Color {
        guard let r = rating, r > 0 else { return .clear }
        return RatingConfig.shared.color(for: r)
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
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 3 : 0)
        )
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            thumbnailRequest?.cancel()
            thumbnailRequest = nil
            thumbnail = nil
        }
        .onChange(of: url) { _ in
            thumbnailRequest?.cancel()
            thumbnailRequest = nil
            thumbnail = nil
            loadThumbnail()
        }
        .onChange(of: reloadToken) { _ in
            thumbnailRequest?.cancel()
            thumbnailRequest = nil
            thumbnail = nil
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
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect?()
        }
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
        .contextMenu {
            Button("Copy Image") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects([url as NSURL])
            }
            Button("Share") {
                let sharingPicker = NSSharingServicePicker(items: [url])
                if let window = NSApp.keyWindow, let view = window.contentView {
                    sharingPicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
                }
            }
        }
    }
    
    private func loadThumbnail() {
        thumbnailRequest?.cancel()
        let expectedURL = url
        thumbnailRequest = ImageProcessor.shared.generateThumbnail(for: url) { img in
            guard expectedURL == self.url else { return }
            self.thumbnail = img
            self.thumbnailRequest = nil
        }
    }
}
