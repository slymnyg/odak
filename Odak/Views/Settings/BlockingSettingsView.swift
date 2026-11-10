import SwiftUI

struct BlockingSettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.blockDistractions) private var isEnabled = Preferences.Default.blockDistractions
    @AppStorage(Preferences.Key.blockedSites) private var sitesText = Preferences.Default.blockedSites

    var body: some View {
        Form {
            Section {
                Toggle("Block distractions during focus sessions", isOn: $isEnabled)
                    .onChange(of: isEnabled) {
                        model.blockingPreferenceChanged()
                    }
            } footer: {
                Text("Blocking stays on while a session is paused and turns off during breaks. Changes to the lists apply from the next focus session.")
            }

            Section("Websites") {
                TextEditor(text: $sitesText)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .frame(minHeight: 110)
                HStack {
                    Text("One site per line. Pasted links are fine; www and mobile versions are included.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clean Up") {
                        sitesText = DomainParser.parse(sitesText).joined(separator: "\n")
                    }
                }
            }

            BlockedAppsSection()
            HelperSection()
        }
        .formStyle(.grouped)
    }
}
