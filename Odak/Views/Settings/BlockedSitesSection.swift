import SwiftUI

/// The website list: add one address at a time, see it land in the list, remove with one click.
/// Every change is stored at once and, during a session, applied at once.
struct BlockedSitesSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.blockedSites) private var sitesText = Preferences.Default.blockedSites

    @State private var entry = ""
    @State private var notice: String? = nil

    private var sites: [String] { DomainParser.parse(sitesText) }

    var body: some View {
        Section {
            HStack {
                TextField("Add a site", text: $entry, prompt: Text(verbatim: "example.com"))
                    .autocorrectionDisabled()
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(OdakPalette.warning)
            }

            if sites.isEmpty {
                Text("No sites blocked.")
                    .foregroundStyle(.secondary)
            }
            ForEach(sites, id: \.self) { site in
                HStack {
                    Image(systemName: "globe")
                        .foregroundStyle(.secondary)
                    Text(verbatim: site)
                    Spacer()
                    Button {
                        remove(site)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
        } header: {
            Text("Websites")
        } footer: {
            if model.timer.isFocusing {
                Label("Saved. Changes apply to the running session right away.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(OdakPalette.accent)
            } else {
                Text("Saved as you go. Pasted links are fine; subdomains, www and mobile versions are included.")
            }
        }
        .onChange(of: sitesText) {
            model.blockingPreferenceChanged()
        }
    }

    private func add() {
        let parsed = DomainParser.parse(entry)
        guard !parsed.isEmpty else {
            notice = String(localized: "That doesn't look like a site address.")
            return
        }
        let current = sites
        let fresh = parsed.filter { !current.contains($0) }
        if fresh.isEmpty, let first = parsed.first {
            notice = String(localized: "\(first) is already on the list.")
        } else {
            sitesText = (current + fresh).joined(separator: "\n")
            notice = nil
        }
        entry = ""
    }

    private func remove(_ site: String) {
        sitesText = sites.filter { $0 != site }.joined(separator: "\n")
        notice = nil
    }
}
