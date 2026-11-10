import SwiftUI

extension GraphicsContext {
    /// Draws `string` along a circle, centred on `midAngle` and truncated to `maxLength` points of arc.
    /// Text runs clockwise with glyph tops pointing outward, except near the bottom of the circle,
    /// where it flips so it never reads upside down.
    func drawArcText(
        _ string: String,
        font: Font,
        color: Color,
        center: CGPoint,
        radius: CGFloat,
        midAngle: Double,
        maxLength: CGFloat,
        tracking: CGFloat = 0.4
    ) {
        func glyph(_ character: Character) -> (text: GraphicsContext.ResolvedText, width: CGFloat) {
            let resolved = resolve(Text(verbatim: String(character)).font(font).foregroundStyle(color))
            return (resolved, resolved.measure(in: CGSize(width: 200, height: 200)).width + tracking)
        }

        var glyphs = string.map(glyph)
        var length = glyphs.reduce(0) { $0 + $1.width }
        if length > maxLength {
            let ellipsis = glyph("…")
            while !glyphs.isEmpty, length + ellipsis.width > maxLength {
                length -= glyphs.removeLast().width
            }
            // A stub of one or two letters says nothing; leave the shape bare instead.
            guard glyphs.count >= 3 else { return }
            glyphs.append(ellipsis)
            length += ellipsis.width
        }
        guard radius > 0, !glyphs.isEmpty else { return }

        let flipped = sin(midAngle) > 0.5
        let direction: Double = flipped ? -1 : 1
        var offset = -length / 2
        for item in glyphs {
            let angle = midAngle + direction * Double((offset + item.width / 2) / radius)
            var context = self
            context.translateBy(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            context.rotate(by: .radians(angle + (flipped ? -.pi / 2 : .pi / 2)))
            context.draw(item.text, at: .zero, anchor: .center)
            offset += item.width
        }
    }
}
