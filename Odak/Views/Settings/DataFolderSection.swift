import SwiftUI

/// Where plans, history and project time live. Pointing it at a synced folder shares them
/// between Macs; the syncing itself is left to the system.
struct DataFolderSection: View {
    @Environment(AppModel.self) private var model
    @State private var failed = false

    var body: some View {
        let root = model.storage.root
        let isLocal = root == Storage.localRoot
        let iCloud = Storage.iCloudRoot

        Section("Data") {
            LabeledContent("Data folder") {
                Text(verbatim: isLocal ? String(localized: "On this Mac") : Self.displayPath(root))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Text(verbatim: root.path))
            }
            HStack {
                if let iCloud, root != iCloud {
                    Button("Keep in iCloud Drive") { move(to: iCloud) }
                }
                Button("Choose…", action: choose)
                if !isLocal {
                    Button("Keep on This Mac") { move(to: nil) }
                }
                Spacer()
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([root])
                }
            }
            if Storage.isFallingBack {
                Text("The chosen data folder can't be reached, so Odak is saving on this Mac for now.")
                    .font(.caption)
                    .foregroundStyle(OdakPalette.warning)
            }
            if failed {
                Text("Odak can't write to that folder.")
                    .font(.caption)
                    .foregroundStyle(OdakPalette.warning)
            }
            Text("Plans, focus history and project time are kept here. Keep the folder in iCloud Drive, or any synced folder, and choose the same one on your other Macs to see them there too. What is already in either place is merged. Settings and block lists stay on each Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func move(to folder: URL?) {
        failed = !model.moveData(to: folder)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = model.storage.root
        if panel.runModal() == .OK, let url = panel.url {
            move(to: url)
        }
    }

    /// `iCloud Drive/Odak` for the iCloud folder, otherwise the path with `~`.
    static func displayPath(_ url: URL) -> String {
        let drive = URL.libraryDirectory.appending(path: "Mobile Documents/com~apple~CloudDocs").path
        if url.path.hasPrefix(drive) {
            return "iCloud Drive" + url.path.dropFirst(drive.count)
        }
        return (url.path as NSString).abbreviatingWithTildeInPath
    }
}
