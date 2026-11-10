import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BlockedAppsSection: View {
    @Environment(AppModel.self) private var model
    @AppStorage(Preferences.Key.blockedApps) private var appsData = Data()

    private var apps: [BlockedApp] {
        get { BlockedApp.decodeList(from: appsData) }
        nonmutating set { appsData = BlockedApp.encodeList(newValue) }
    }

    var body: some View {
        Section {
            if apps.isEmpty {
                Text("No apps blocked.")
                    .foregroundStyle(.secondary)
            }
            ForEach(apps) { app in
                HStack {
                    Image(nsImage: icon(for: app))
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(app.name)
                    Spacer()
                    Button {
                        apps.removeAll { $0.id == app.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove")
                }
            }
            Button {
                chooseApps()
            } label: {
                Label("Add App…", systemImage: "plus")
            }
        } header: {
            Text("Apps")
        } footer: {
            Text("Blocked apps are hidden whenever they come to the front during a focus session. They are never quit, so no work is lost.")
        }
        .onChange(of: appsData) {
            model.blockingPreferenceChanged()
        }
    }

    private func icon(for app: BlockedApp) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = String(localized: "Block")
        guard panel.runModal() == .OK else { return }

        var updated = apps
        for url in panel.urls {
            guard let app = blockedApp(at: url), !updated.contains(where: { $0.id == app.id }),
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            updated.append(app)
        }
        apps = updated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func blockedApp(at url: URL) -> BlockedApp? {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return BlockedApp(bundleIdentifier: identifier, name: name)
    }
}
