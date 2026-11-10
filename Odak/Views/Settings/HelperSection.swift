import SwiftUI

struct HelperSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let blocking = model.blocking
        Section("Website Blocking Helper") {
            LabeledContent("Status") {
                if blocking.isHelperInstalled {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Not installed")
                        .foregroundStyle(.secondary)
                }
            }

            Text("Odak blocks websites by adding them to /etc/hosts, which works in every browser. The helper is a small script in /Library/PrivilegedHelperTools plus a sudoers rule that lets Odak run only that script without asking for your password each time. Installing asks for your administrator password once.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let error = blocking.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                if blocking.isHelperInstalled {
                    Button("Uninstall…", role: .destructive) {
                        blocking.uninstallHelper()
                    }
                    Button("Reinstall…", action: model.installHelper)
                } else {
                    Button("Install Helper…", action: model.installHelper)
                }
            }
        }
        .onAppear {
            blocking.refreshHelperStatus()
        }
    }
}
