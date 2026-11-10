import SwiftUI

struct BlockingSettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.blockDistractions) private var isEnabled = Preferences.Default.blockDistractions

    var body: some View {
        Form {
            Section {
                Toggle("Block distractions during focus sessions", isOn: $isEnabled)
                    .onChange(of: isEnabled) {
                        model.blockingPreferenceChanged()
                    }
            } footer: {
                Text("Blocking stays on while a session is paused and turns off during breaks. The lists are saved as you change them and apply right away.")
            }

            BlockedSitesSection()
            BlockedAppsSection()
            HelperSection()
        }
        .formStyle(.grouped)
    }
}
