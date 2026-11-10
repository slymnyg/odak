import SwiftUI

/// The colour of the light at each part of the day. The planner washes its paper and the dial's
/// bands with it, so the hour can be felt before it is read.
enum Daylight {
    static func tint(_ segment: DaySegment) -> Color {
        switch segment {
        case .night: OdakPalette.dynamic(light: 0x8E9CCB, dark: 0x2A3F8F)
        case .morning: OdakPalette.dynamic(light: 0x9CCFE6, dark: 0x1F6E8C)
        case .afternoon: OdakPalette.dynamic(light: 0xF2C55C, dark: 0x9A6B14)
        case .evening: OdakPalette.dynamic(light: 0xEE8E5A, dark: 0xA8431F)
        }
    }
}

/// Light spilling from the dial across the window: strongest at the dial's rim, gone by the far edge.
struct DaylightGlow: View {
    let segment: DaySegment
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let tint = Daylight.tint(segment)
            let anchor = UnitPoint(
                x: center.x / max(geometry.size.width, 1),
                y: center.y / max(geometry.size.height, 1)
            )
            ZStack {
                tint.opacity(0.07)
                RadialGradient(
                    colors: [tint.opacity(0.42), tint.opacity(0.14), tint.opacity(0)],
                    center: anchor,
                    startRadius: radius * 0.85,
                    endRadius: radius * 2.3
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
