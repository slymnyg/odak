import AppKit
import SwiftUI

/// Small-caps label that opens a group of content.
struct SectionLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .kerning(0.7)
            .foregroundStyle(OdakPalette.ink.opacity(0.5))
    }
}

/// The one filled button on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OdakPalette.onTask)
            .padding(.horizontal, 18)
            .frame(height: 36)
            .background(OdakPalette.accent.opacity(isEnabled ? 1 : 0.4), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// Secondary actions: a soft capsule that stays out of the primary button's way.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(OdakPalette.ink.opacity(isEnabled ? 0.85 : 0.35))
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(OdakPalette.bands[configuration.isPressed ? 2 : 1], in: Capsule())
            .contentShape(Capsule())
    }
}

/// Text-only actions in footers.
struct FooterButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(OdakPalette.ink.opacity(isHovered ? 0.9 : 0.55))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

/// A row of choices with an ink capsule that slides to the selected one.
struct ChipPicker<Value: Hashable, Label: View>: View {
    let options: [Value]
    @Binding var selection: Value
    /// Spread the chips over the full width instead of hugging their labels.
    var fillsWidth = false
    @ViewBuilder let label: (Value) -> Label

    @Namespace private var chips

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                        selection = option
                    }
                } label: {
                    label(option)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? OdakPalette.paper : OdakPalette.ink.opacity(0.55))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: fillsWidth ? .infinity : nil)
                        .frame(height: 24)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(OdakPalette.ink)
                                    .matchedGeometryEffect(id: "selection", in: chips)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A raised surface for a group of related content.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OdakPalette.face.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Lets the paper run under the title bar of a window SwiftUI created for us.
struct PaperWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(OdakPalette.paper)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
