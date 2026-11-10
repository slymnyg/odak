import SwiftUI

/// A slice of a lane between two times. `inset` shrinks every edge, so stroking the result with a
/// round join of twice that width gives a capsule with rounded corners that fills the original slice.
struct LaneArc: Shape {
    var center: CGPoint
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startMinutes: Double
    var endMinutes: Double
    var inset: CGFloat = 0

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startMinutes, endMinutes) }
        set {
            startMinutes = newValue.first
            endMinutes = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let inner = innerRadius + inset
        let outer = max(outerRadius - inset, inner)
        let angularInset = Double(inset / max((inner + outer) / 2, 1))
        let middle = (DialGeometry.angle(forMinutes: startMinutes) + DialGeometry.angle(forMinutes: endMinutes)) / 2
        let start = min(DialGeometry.angle(forMinutes: startMinutes) + angularInset, middle)
        let end = max(DialGeometry.angle(forMinutes: endMinutes) - angularInset, middle)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}
