import SwiftUI

struct BlockingSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.blockDistractions) private var isEnabled = Preferences.Default.blockDistractions
    @AppStorage(Preferences.Key.blockedSites) private var sitesText = Preferences.Default.blockedSites
    @AppStorage(Preferences.Key.blockedApps) private var appsData = Data()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $isEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block distractions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OdakPalette.ink)
                        if isEnabled {
                            Text(summary)
                                .font(.system(size: 11))
                                .foregroundStyle(OdakPalette.ink.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isEnabled) {
                    model.blockingPreferenceChanged()
                }

                if isEnabled && siteCount > 0 && !model.blocking.isHelperInstalled {
                    HStack {
                        Text("Website blocking needs a one-time setup.")
                            .font(.system(size: 11))
                            .foregroundStyle(OdakPalette.ink.opacity(0.7))
                        Spacer()
                        Button("Install Helper…", action: model.installHelper)
                            .controlSize(.small)
                    }
                }

                if let error = model.blocking.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(OdakPalette.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var siteCount: Int { DomainParser.parse(sitesText).count }
    private var appCount: Int { BlockedApp.decodeList(from: appsData).count }

    private var summary: String {
        guard siteCount > 0 || appCount > 0 else {
            return String(localized: "Add sites or apps to block in Settings.")
        }
        let sites = String(localized: "\(siteCount) sites")
        let apps = String(localized: "\(appCount) apps")
        if model.timer.isFocusing {
            return String(localized: "Blocking \(sites) and \(apps)")
        }
        return String(localized: "\(sites) and \(apps) will be blocked")
    }
}
