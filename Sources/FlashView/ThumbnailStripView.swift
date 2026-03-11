import SwiftUI

struct ThumbnailStripView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 4) {
                    ForEach(Array(appState.viewImages.enumerated()), id: \.element) { index, url in
                        ThumbnailItemView(
                            url: url,
                            isSelected: index == appState.currentIndex,
                            rating: appState.imageRatings[url],
                            reloadToken: appState.imageReloadToken
                        )
                        .id(url)
                        .onTapGesture {
                            appState.selectImage(at: index)
                        }
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
                    withAnimation {
                        proxy.scrollTo(url, anchor: .center)
                    }
                }
            }
            .onChange(of: appState.isGridViewActive) { isActive in
                if !isActive {
                    scrollToCurrentItem(proxy: proxy)
                }
            }
            .onAppear {
                // When coming back from Grid View, or initial load
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
                withAnimation {
                    proxy.scrollTo(url, anchor: .center)
                }
            }
        }
    }
}


struct ThumbnailItemView: View {
    let url: URL
    let isSelected: Bool
    let rating: Int?
    let reloadToken: UUID
    
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
        // Force reload when token changes (e.g. after save in place)
        .onChange(of: reloadToken) { _ in
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
        .contextMenu {
            // Can't use AppState directly without injecting it here or passing closure,
            // let's just make it simple
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
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
    }
    
    private func loadThumbnail() {
        ImageProcessor.shared.generateThumbnail(for: url) { img in
            self.thumbnail = img
        }
    }
}
