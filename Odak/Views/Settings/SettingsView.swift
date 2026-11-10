import AppKit
import SwiftUI

struct SettingsView: View {
    private enum Pane: Hashable, CaseIterable {
        case general, blocking, stats

        var title: LocalizedStringKey {
            switch self {
            case .general: "General"
            case .blocking: "Blocking"
            case .stats: "Stats"
            }
        }
    }

    @State private var pane = Pane.general

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(OdakPalette.ink)
                ChipPicker(options: Pane.allCases, selection: $pane) { Text($0.title) }
                    .padding(.leading, -10)
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)
            .padding(.bottom, 6)

            Group {
                switch pane {
                case .general: GeneralSettingsView()
                case .blocking: BlockingSettingsView()
                case .stats: StatsView()
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
        }
        .frame(width: 540, height: 640)
        .background(OdakPalette.paper)
        .background(PaperWindow())
        .tint(OdakPalette.accent)
        .onAppear {
            NSApp.activate()
        }
    }
}
