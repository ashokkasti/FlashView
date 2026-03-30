import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "FlashView"
    }

    private var shortVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.6"
    }

    private var buildVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? shortVersion
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 14) {
                infoRow(title: "App", value: appName)
                infoRow(title: "Version", value: "\(shortVersion) (Build \(buildVersion))")
                infoRow(title: "Platform", value: "macOS")

                section(title: "Highlights", items: [
                    "Fast folder preview and image culling",
                    "Viewer and grid modes",
                    "Ratings: Bad, Maybe, Good",
                    "Keyboard shortcuts and Eye Friendly theme"
                ])

                section(title: "Shortcuts", items: [
                    "Cmd+T new tab, Cmd+Shift+T move tab to window",
                    "Left/Right navigate, 1/2/3 rate, Cmd+R refresh"
                ])
            }
            .padding(20)

            Divider()

            HStack {
                Text("FlashView")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 420)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var header: some View {
        HStack(spacing: 16) {
            appIcon
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(appName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Fast image review for clear decisions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = NSApplication.shared.applicationIconImage {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.2))
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.accentColor)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
            Spacer()
        }
    }

    private func section(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.accentColor)
                    Text(item)
                        .font(.subheadline)
                }
            }
        }
    }
}
