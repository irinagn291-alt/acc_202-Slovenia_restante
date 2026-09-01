import SwiftUI

/// Role: Presentation. Cancellation geometry. Path only, never a chrome image.
struct DateStampRing: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.86,
            y: center.y - radius * 0.86,
            width: radius * 1.72,
            height: radius * 1.72
        ))
        return path
    }
}

/// Role: Presentation. Wavy killer bars for empty frames and the header strip.
struct KillerBars: Shape {
    var waves: Int = 5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.height / CGFloat(max(waves, 1) + 1)
        for index in 1 ... max(waves, 1) {
            let y = step * CGFloat(index)
            path.move(to: CGPoint(x: rect.minX, y: y))
            var x = rect.minX
            var flip: CGFloat = 1
            while x < rect.maxX {
                let width = rect.width / 10
                path.addQuadCurve(
                    to: CGPoint(x: min(x + width, rect.maxX), y: y),
                    control: CGPoint(x: x + width / 2, y: y + 5 * flip)
                )
                x += width
                flip *= -1
            }
        }
        return path
    }
}

/// Role: Presentation. Empty pigeonhole frame.
struct HeldWindow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect.insetBy(dx: 8, dy: 8))
        path.addRect(rect.insetBy(dx: 18, dy: 22))
        return path
    }
}
