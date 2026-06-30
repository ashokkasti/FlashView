import SwiftUI

struct RatingSettingsView: View {
    @ObservedObject var config = RatingConfig.shared
    @State private var editingLabel: RatingLabel? = nil
    @State private var newName = ""
    @State private var newColor = "red"
    @State private var newShortcut = ""
    @State private var isAddingNew = false
    @State private var showDuplicateShortcutAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Rating Labels")
                    .font(.headline)
                Spacer()
                Button(action: { config.resetToDefaults() }) {
                    Text("Reset Defaults")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // List of existing labels
            VStack(spacing: 0) {
                ForEach(config.sortedLabels) { label in
                    RatingLabelRow(
                        label: label,
                        onEdit: { startEditing(label) },
                        onDelete: { config.removeLabel(label.value) }
                    )
                    Divider().padding(.leading, 16)
                }
            }

            // Add new label
            if isAddingNew {
                Divider()
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.fromString(newColor))
                        .frame(width: 12, height: 12)
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Picker("", selection: $newColor) {
                        ForEach(RatingLabel.allColorNames, id: \.self) { colorName in
                            HStack {
                                Circle().fill(Color.fromString(colorName)).frame(width: 8, height: 8)
                                Text(colorName)
                            }
                            .tag(colorName)
                        }
                    }
                    .frame(width: 90)
                    TextField("Key", text: $newShortcut)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                        .onChange(of: newShortcut) { val in
                            newShortcut = String(val.prefix(1))
                        }
                    Button("Add") {
                        if !newName.isEmpty {
                            if shortcutConflict(newShortcut, excluding: nil) {
                                showDuplicateShortcutAlert = true
                            } else {
                                config.addLabel(name: newName, colorName: newColor, shortcut: newShortcut)
                                resetAddForm()
                            }
                        }
                    }
                    .disabled(newName.isEmpty)
                    Button("Cancel") { resetAddForm() }
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button(action: { isAddingNew = true }) {
                    Label("Add Label", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .disabled(isAddingNew)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .frame(width: 420)
        .alert("Duplicate Shortcut", isPresented: $showDuplicateShortcutAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This shortcut key is already used by another rating label.")
        }
    }

    private func startEditing(_ label: RatingLabel) {
        editingLabel = label
        newName = label.name
        newColor = label.colorName
        newShortcut = label.shortcut
    }

    private func resetAddForm() {
        isAddingNew = false
        newName = ""
        newColor = "red"
        newShortcut = ""
    }

    private func shortcutConflict(_ shortcut: String, excluding value: Int?) -> Bool {
        guard !shortcut.isEmpty else { return false }
        return config.labels.contains { $0.value != value && $0.shortcut == shortcut }
    }

    private func saveEditing() {
        guard let label = editingLabel else { return }
        if shortcutConflict(newShortcut, excluding: label.value) {
            showDuplicateShortcutAlert = true
            return
        }
        config.updateLabel(label.value, name: newName, colorName: newColor, shortcut: newShortcut)
        editingLabel = nil
    }
}

struct RatingLabelRow: View {
    let label: RatingLabel
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editColor = ""
    @State private var editShortcut = ""

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(label.color)
                .frame(width: 12, height: 12)

            if isEditing {
                TextField("Name", text: $editName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Picker("", selection: $editColor) {
                    ForEach(RatingLabel.allColorNames, id: \.self) { colorName in
                        HStack {
                            Circle().fill(Color.fromString(colorName)).frame(width: 8, height: 8)
                            Text(colorName)
                        }
                        .tag(colorName)
                    }
                }
                .frame(width: 90)
                TextField("Key", text: $editShortcut)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 40)
                    .onChange(of: editShortcut) { val in
                        editShortcut = String(val.prefix(1))
                    }
                Button("Save") {
                    RatingConfig.shared.updateLabel(label.value, name: editName, colorName: editColor, shortcut: editShortcut)
                    isEditing = false
                }
                .font(.caption)
                Button("Cancel") { isEditing = false }
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(label.name)
                    .frame(width: 100, alignment: .leading)
                Text("(\(label.value))")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(width: 30, alignment: .leading)
                Spacer()
                if !label.shortcut.isEmpty {
                    Text(label.shortcut.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                Button(action: {
                    editName = label.name
                    editColor = label.colorName
                    editShortcut = label.shortcut
                    isEditing = true
                }) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

extension Color {
    static func fromString(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray", "grey": return .gray
        default: return .gray
        }
    }

    var readableTextColor: Color {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return .white }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}
