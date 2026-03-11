import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditingPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                // Film Simulations
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Film Simulation")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if appState.adjustments.filmSimulation != .none {
                            Button("Clear") {
                                appState.adjustments.filmSimulation = .none
                                appState.requestPreviewUpdate()
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .buttonStyle(.plain)
                        }
                    }
                    
                    DisclosureGroup(
                        isExpanded: $appState.isFilmSimulationExpanded,
                        content: {
                            FilmSimulationGridView()
                                .padding(.top, 8)
                        },
                        label: {
                            Text(appState.adjustments.filmSimulation == .none ? "Apply Filters" : appState.adjustments.filmSimulation.rawValue)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        appState.isFilmSimulationExpanded.toggle()
                                    }
                                }
                        }
                    )
                }
                
                Divider()
                
                // MARK: - Background Removal
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Background")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        appState.toggleBackgroundRemoval()
                    }) {
                        HStack {
                            Image(systemName: appState.adjustments.backgroundRemoved ? "person.fill.checkmark" : "person.and.background.dotted")
                            Text(appState.adjustments.backgroundRemoved ? "Restore Background" : "Remove Background")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.isRemovingBackground)
                    
                    if appState.isRemovingBackground {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                Divider()
                
                // MARK: - Crop & Rotate Section
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Crop & Rotate")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Rotation buttons
                    HStack(spacing: 8) {
                        Button(action: { appState.rotateLeft90() }) {
                            Label("90° Left", systemImage: "rotate.left")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: { appState.rotateRight90() }) {
                            Label("90° Right", systemImage: "rotate.right")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Free rotation slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Free Rotation")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.1f°", appState.adjustments.rotationAngle))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $appState.adjustments.rotationAngle, in: -45.0...45.0)
                    }
                    
                    // Crop button
                    Button(action: {
                        appState.isCropRotateMode.toggle()
                    }) {
                        HStack {
                            Image(systemName: "crop")
                            Text(appState.isCropRotateMode ? "Exit Crop Mode" : "Crop Image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if appState.adjustments.isCropped {
                        Button("Reset Crop") {
                            appState.adjustments.cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                            appState.requestPreviewUpdate()
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // MARK: - Save / Export Section
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Save / Export")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Save in Place") {
                        if appState.skipSaveInPlaceConfirmation {
                            appState.saveImageInPlace()
                        } else {
                            appState.showSaveConfirmation = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("Export a Copy…") {
                        appState.showExportSheet = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                Button("Reset All") {
                    appState.adjustments = ImageAdjustments()
                    appState.isCropRotateMode = false
                    appState.requestPreviewUpdate()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
        // Save confirmation alert
        .alert("Save in Place?", isPresented: $appState.showSaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Overwrite Original", role: .destructive) {
                appState.saveImageInPlace()
            }
            Button("Always Overwrite this Session") {
                appState.skipSaveInPlaceConfirmation = true
                appState.saveImageInPlace()
            }
        } message: {
            Text("This will overwrite the original file with all current edits applied. This action cannot be undone.")
        }
        // Export sheet
        .sheet(isPresented: $appState.showExportSheet) {
            ExportSheetView()
                .environmentObject(appState)
        }
    }
}

// MARK: - Export Sheet

struct ExportSheetView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFormat: ExportFormat = .jpeg
    @State private var jpegQuality: Double = 85.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Export Image")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("Format")
                    .font(.subheadline)
                Picker("", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            if selectedFormat == .jpeg {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Quality")
                        Spacer()
                        Text("\(Int(jpegQuality))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $jpegQuality, in: 60...100, step: 1)
                }
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    appState.showExportSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Export…") {
                    showExportSavePanel()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
    
    private func showExportSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Export Image"
        panel.canCreateDirectories = true
        
        let defaultExt: String
        let allowedTypes: [UTType]
        switch selectedFormat {
        case .jpeg:
            defaultExt = "jpg"
            allowedTypes = [.jpeg]
        case .png:
            defaultExt = "png"
            allowedTypes = [.png]
        case .tiff:
            defaultExt = "tiff"
            allowedTypes = [.tiff]
        }
        
        if let currentURL = appState.currentImage {
            let baseName = currentURL.deletingPathExtension().lastPathComponent
            panel.nameFieldStringValue = "\(baseName)_edited.\(defaultExt)"
        }
        
        panel.allowedContentTypes = allowedTypes
        
        if panel.runModal() == .OK, let url = panel.url {
            appState.exportImage(to: url, format: selectedFormat, quality: jpegQuality)
            appState.showExportSheet = false
        }
    }
}

// MARK: - Film Simulation Grid Components

struct FilmSimulationGridView: View {
    @EnvironmentObject var appState: AppState
    
    // We use a LazyVGrid with 3 columns 
    let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    
    var body: some View {
        if let currentURL = appState.currentImage {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FilmSimulation.allCases) { sim in
                    FilmSimulationItemView(url: currentURL, simulation: sim)
                }
            }
        } else {
            Text("No Image Selected")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct FilmSimulationItemView: View {
    @EnvironmentObject var appState: AppState
    let url: URL
    let simulation: FilmSimulation
    
    @State private var isHovered = false
    
    var isSelected: Bool {
        appState.adjustments.filmSimulation == simulation
    }
    
    private var filterGradient: LinearGradient {
        switch simulation {
        case .none: return LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .provia: return LinearGradient(colors: [.blue.opacity(0.6), .green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .velvia: return LinearGradient(colors: [.red.opacity(0.7), .yellow.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .classicChrome: return LinearGradient(colors: [.brown.opacity(0.6), .gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .astia: return LinearGradient(colors: [.pink.opacity(0.6), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .eterna: return LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .nostalgicNeg: return LinearGradient(colors: [.orange.opacity(0.7), .yellow.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .classicNeg: return LinearGradient(colors: [.green.opacity(0.5), .brown.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sepia: return LinearGradient(colors: [.brown.opacity(0.5), .orange.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.gray.opacity(0.5), .black.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Rectangle()
                    .fill(filterGradient)
                    .frame(height: 60)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "camera.filters")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 20))
                    )
                
                if isHovered && !isSelected {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 60)
                        .cornerRadius(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            
            Text(simulation.rawValue
                .replacingOccurrences(of: " (Standard)", with: "")
                .replacingOccurrences(of: " (Vivid)", with: "")
                .replacingOccurrences(of: " (Soft)", with: "")
                .replacingOccurrences(of: " (Cinema)", with: "")
            )
            .font(.system(size: 9, weight: isSelected ? .bold : .regular))
            .foregroundColor(isSelected ? .accentColor : .primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture {
            // Apply the simulation
            if simulation != .none {
                appState.adjustments.filmSimulation = simulation
                appState.requestPreviewUpdate()
            } else {
                appState.adjustments.filmSimulation = .none
                appState.requestPreviewUpdate()
            }
        }
    }
}
