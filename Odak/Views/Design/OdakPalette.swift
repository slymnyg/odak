import AppKit
import SwiftUI

/// Warm paper and ink, shared by every Odak window. Colour is reserved for tasks, data and the one
/// primary action on screen.
enum OdakPalette {
    static let paper = dynamic(light: 0xF3EFE8, dark: 0x15171C)
    static let face = dynamic(light: 0xFFFEFB, dark: 0x2B2F37)
    static let ink = dynamic(light: 0x1B1E26, dark: 0xF1EEE8)
    static let onTask = Color.white
    /// Odak green: the primary action and the focus lane.
    static let accent = dynamic(light: 0x179C56, dark: 0x2FBF70)
    static let warning = dynamic(light: 0xC2410C, dark: 0xF08A4B)

    /// Lane bands, from the clock face outward.
    static let bands = [
        dynamic(light: 0xECE7DD, dark: 0x1D2026),
        dynamic(light: 0xE5DFD3, dark: 0x22262D),
        dynamic(light: 0xDDD6C8, dark: 0x282C34),
    ]

    static func band(_ lane: TaskLane) -> Color {
        bands[lane.index % bands.count]
    }

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
