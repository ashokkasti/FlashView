import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var folderManager: FolderManager
    
    var body: some View {
        List {
            Section(header: Text("Recent Folders")) {
                ForEach(folderManager.recentFolders, id: \.self) { path in
                    FolderOutlineView(
                        path: path,
                        isExpanded: path == appState.currentFolder,
                        counts: folderManager.folderCounts[path] ?? [:],
                        onSelect: {
                            appState.openFolder(path)
                        },
                        onFilterSelect: { rating in
                            if path != appState.currentFolder {
                                appState.openFolder(path)
                            }
                            appState.selectedRatingFilter = rating
                        }
                    )
                    .onAppear {
                        folderManager.loadCounts(for: path)
                    }
                }
            }
            
            Section {
                Button(action: {
                    folderManager.openFolderPicker { path in
                        if let validPath = path {
                            appState.openFolder(validPath)
                        }
                    }
                }) {
                    Label("Add Folder", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
        }
        .listStyle(SidebarListStyle())
    }
}

// Tree structure for folder
struct FolderOutlineView: View {
    let path: String
    let isExpanded: Bool
    let counts: [Int: Int]
    let onSelect: () -> Void
    let onFilterSelect: (Int?) -> Void
    
    @State private var overrideExpanded: Bool? = nil
    @EnvironmentObject var appState: AppState
    
    var effectiveExpanded: Bool {
        overrideExpanded ?? isExpanded
    }
    
    var isSelected: Bool {
        appState.currentFolder == path
    }
    
    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { effectiveExpanded },
                set: { overrideExpanded = $0 }
            ),
            content: {
                if effectiveExpanded {
                    FilterRowView(title: "All", count: counts[0] ?? 0, rating: nil, path: path, onFilterSelect: onFilterSelect)
                    FilterRowView(title: "Good", count: counts[3] ?? 0, rating: 3, color: .green, path: path, onFilterSelect: onFilterSelect)
                    FilterRowView(title: "Maybe", count: counts[2] ?? 0, rating: 2, color: .yellow, path: path, onFilterSelect: onFilterSelect)
                    FilterRowView(title: "Bad", count: counts[1] ?? 0, rating: 1, color: .red, path: path, onFilterSelect: onFilterSelect)
                }
            },
            label: {
                FolderLabelView(path: path, isSelected: isSelected, onSelect: onSelect)
            }
        )
    }
}

struct FolderLabelView: View {
    let path: String
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: "folder")
                Text((path as NSString).lastPathComponent)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(isSelected && appState.selectedRatingFilter == nil ? Color.gray.opacity(0.4) : (isHovered ? Color.gray.opacity(0.2) : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from Recent") {
                appState.folderManager.removeRecentFolder(path)
                if appState.currentFolder == path {
                    appState.currentFolder = nil
                    appState.images = []
                    appState.imageRatings = [:]
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

struct FilterRowView: View {
    let title: String
    let count: Int
    let rating: Int?
    var color: Color = .primary
    let path: String
    let onFilterSelect: (Int?) -> Void
    
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false
    
    var isSelected: Bool {
        appState.currentFolder == path && appState.selectedRatingFilter == rating
    }
    
    var body: some View {
        Button(action: {
            onFilterSelect(rating)
        }) {
            HStack {
                Circle().fill(rating != nil ? color : .clear).frame(width: 8, height: 8)
                Text(title)
                Spacer()
                Text("\(count)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.gray.opacity(0.4) : (isHovered ? Color.gray.opacity(0.2) : Color.clear))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
