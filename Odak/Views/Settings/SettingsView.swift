import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            BlockingSettingsView()
                .tabItem { Label("Blocking", systemImage: "hand.raised") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
        }
        .frame(width: 500, height: 560)
        .onAppear {
            NSApp.activate()
        }
    }
}
