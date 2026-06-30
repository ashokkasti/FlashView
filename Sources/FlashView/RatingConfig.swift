import SwiftUI

struct RatingLabel: Identifiable, Codable, Equatable {
    var id: Int { value }
    let value: Int
    var name: String
    var colorName: String
    var shortcut: String

    var color: Color {
        switch colorName {
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

    static let allColorNames = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
}

class RatingConfig: ObservableObject {
    static let shared = RatingConfig()

    @AppStorage("ratingLabelsJSON") private var labelsJSON: String = ""

    @Published var labels: [RatingLabel] = [] {
        didSet { save() }
    }

    private init() {
        load()
    }

    var sortedLabels: [RatingLabel] {
        labels.sorted { $0.value < $1.value }
    }

    func label(for value: Int) -> RatingLabel? {
        labels.first { $0.value == value }
    }

    func name(for value: Int) -> String {
        if value == 0 { return "Unrated" }
        return label(for: value)?.name ?? "Rating \(value)"
    }

    func color(for value: Int) -> Color {
        if value == 0 { return .gray }
        return label(for: value)?.color ?? .gray
    }

    func shortcut(for value: Int) -> String? {
        if value == 0 { return "0" }
        return label(for: value)?.shortcut
    }

    func allShortcuts() -> [(String, Int)] {
        var result: [(String, Int)] = [("0", 0)]
        for label in sortedLabels {
            if !label.shortcut.isEmpty {
                result.append((label.shortcut, label.value))
            }
        }
        return result
    }

    func addLabel(name: String, colorName: String, shortcut: String) {
        let nextValue = (labels.map(\.value).max() ?? 0) + 1
        labels.append(RatingLabel(value: nextValue, name: name, colorName: colorName, shortcut: shortcut))
    }

    func removeLabel(_ value: Int) {
        labels.removeAll { $0.value == value }
    }

    func updateLabel(_ value: Int, name: String? = nil, colorName: String? = nil, shortcut: String? = nil) {
        guard let index = labels.firstIndex(where: { $0.value == value }) else { return }
        if let name = name { labels[index].name = name }
        if let colorName = colorName { labels[index].colorName = colorName }
        if let shortcut = shortcut { labels[index].shortcut = shortcut }
        labels = labels // trigger didSet
    }

    func resetToDefaults() {
        labels = Self.defaults
    }

    static let defaults: [RatingLabel] = [
        RatingLabel(value: 1, name: "Bad", colorName: "red", shortcut: "1"),
        RatingLabel(value: 2, name: "Maybe", colorName: "yellow", shortcut: "2"),
        RatingLabel(value: 3, name: "Good", colorName: "green", shortcut: "3"),
    ]

    private func save() {
        if let data = try? JSONEncoder().encode(labels),
           let str = String(data: data, encoding: .utf8) {
            labelsJSON = str
        }
    }

    private func load() {
        if labelsJSON.isEmpty {
            labels = Self.defaults
            return
        }
        guard let data = labelsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RatingLabel].self, from: data) else {
            labels = Self.defaults
            return
        }
        labels = decoded.isEmpty ? Self.defaults : decoded
    }
}
