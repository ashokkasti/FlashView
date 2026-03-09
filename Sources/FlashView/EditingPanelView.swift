import SwiftUI

struct EditingPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                // Film Simulations
                VStack(alignment: .leading) {
                    Text("Film Simulation")
                        .font(.subheadline)
                    
                    Picker("", selection: $appState.adjustments.filmSimulation) {
                        ForEach(FilmSimulation.allCases) { sim in
                            Text(sim.rawValue).tag(sim)
                        }
                    }
                    .labelsHidden()
                }
                
                Divider()
                
                // Exposure
                VStack(alignment: .leading) {
                    HStack {
                        Text("Exposure")
                        Spacer()
                        Text(String(format: "%.2f", appState.adjustments.exposure))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.adjustments.exposure, in: -1.0...1.0)
                }
                
                // Contrast
                VStack(alignment: .leading) {
                    HStack {
                        Text("Contrast")
                        Spacer()
                        Text(String(format: "%.2f", appState.adjustments.contrast))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.adjustments.contrast, in: 0.0...2.0)
                }
                
                // Saturation
                VStack(alignment: .leading) {
                    HStack {
                        Text("Saturation")
                        Spacer()
                        Text(String(format: "%.2f", appState.adjustments.saturation))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $appState.adjustments.saturation, in: 0.0...2.0)
                }
                
                Spacer()
                
                Button("Save Edits to File") {
                    appState.saveImageEdits()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.top)
                
                Button("Reset Adjustments") {
                    appState.adjustments = ImageAdjustments()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .frame(width: 250)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
