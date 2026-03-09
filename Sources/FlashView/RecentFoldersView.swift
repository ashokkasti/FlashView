import SwiftUI

struct RecentFoldersView: View {
    @ObservedObject var folderManager: FolderManager
    var onFolderSelected: (String) -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            
            // Logo block
            let logoImage: NSImage? = {
                if let url = Bundle.main.url(forResource: "Logo", withExtension: "png"), let img = NSImage(contentsOf: url) { return img }
                if let img = NSImage(named: NSImage.Name("Logo")) { return img }
                if let img = NSImage(contentsOfFile: "FlashView.app/Contents/Resources/Logo.png") { return img }
                if let img = NSImage(contentsOfFile: "Sources/FlashView/Resources/Assets.xcassets/Logo.png") { return img }
                return nil
            }()
            
            if let nsImage = logoImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
            } else {
                Text("FlashView")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Button(action: {
                folderManager.openFolderPicker { path in
                    if let path = path {
                        onFolderSelected(path)
                    }
                }
            }) {
                Text("Open Folder")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            if !folderManager.recentFolders.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Folders")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(folderManager.recentFolders, id: \.self) { path in
                                RecentFolderRow(path: path) {
                                    // Move to top and open
                                    folderManager.addRecentFolder(path)
                                    onFolderSelected(path)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 250)
                }
                .frame(width: 400)
            }
            
            Spacer()
            
            HStack {
                Text("made with")
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("in nepal")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 10)
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 450)
    }
}

struct RecentFolderRow: View {
    let path: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text((path as NSString).lastPathComponent)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .truncationMode(.middle)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(10)
            .background(isHovered ? Color.secondary.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
