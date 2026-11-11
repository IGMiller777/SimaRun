import AppKit

/// The characters that can run in the menu bar. Each one is drawn entirely in code.
/// To add another: add a case, a title, a canvas size and a drawing function.
enum RunnerCharacter: String, CaseIterable {
    case cat, dog, rabbit, bird, fan

    var title: String {
        switch self {
        case .cat: "Cat"
        case .dog: "Dog"
        case .rabbit: "Rabbit"
        case .bird: "Bird"
        case .fan: "Fan"
        }
    }

    /// Drawing area in points at the base size; the view scales it to the chosen icon size.
    var canvas: NSSize {
        switch self {
        case .fan: NSSize(width: 18, height: 18)
        default: NSSize(width: 28, height: 18)
        }
    }

    static let frameCount = 10

    /// Frames are rasterized once up front, so animating costs no drawing work.
    /// Only the alpha channel matters: the view uses each frame as a mask over the menu bar text colour.
    func makeFrames() -> [CGImage] {
        (0..<Self.frameCount).compactMap { index in
            rasterize(phase: Double(index) / Double(Self.frameCount) * 2 * .pi)
        }
    }

    private func rasterize(phase: Double) -> CGImage? {
        let scale = 4 // enough pixels to stay sharp at the Large size on Retina displays
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(canvas.width) * scale, pixelsHigh: Int(canvas.height) * scale,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // Drawing code works in canvas points; scale it up to fill the bitmap's pixels.
        context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        NSColor.black.set()
        draw(phase: phase)
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }

    /// Draws one pose of the animation cycle. Origin is bottom-left; characters face right.
    private func draw(phase: Double) {
        switch self {
        case .cat: Drawing.quadruped(phase: phase, style: .cat)
        case .dog: Drawing.quadruped(phase: phase, style: .dog)
        case .rabbit: Drawing.quadruped(phase: phase, style: .rabbit)
        case .bird: Drawing.bird(phase: phase)
        case .fan: Drawing.fan(phase: phase)
        }
    }
}

private enum Drawing {
    struct QuadrupedStyle {
        enum Ears { case pointed, floppy, long }
        enum Tail { case long, short, puff }

        var ears: Ears
        var tail: Tail
        var snout: Bool
        var bodyHeight: Double   // height of the body centre above the canvas bottom
        var bounce: Double
        var legSegment: Double

        static let cat = QuadrupedStyle(ears: .pointed, tail: .long, snout: false, bodyHeight: 9.6, bounce: 0.5, legSegment: 3.3)
        static let dog = QuadrupedStyle(ears: .floppy, tail: .short, snout: true, bodyHeight: 9.6, bounce: 0.5, legSegment: 3.3)
        static let rabbit = QuadrupedStyle(ears: .long, tail: .puff, snout: false, bodyHeight: 8.3, bounce: 0.8, legSegment: 2.7)
    }

    // MARK: - Four-legged runners

    static func quadruped(phase: Double, style: QuadrupedStyle) {
        let bodyY = style.bodyHeight + sin(phase * 2) * style.bounce // bounces twice per stride

        // Body
        NSBezierPath(roundedRect: NSRect(x: 6.5, y: bodyY - 2.8, width: 14, height: 5.6),
                     xRadius: 2.8, yRadius: 2.8).fill()

        // Head
        let headX = style.snout ? 21.4 : 22.2
        let head = NSPoint(x: headX, y: bodyY + 2.6 + sin(phase * 2 + 0.8) * 0.3)
        NSBezierPath(ovalIn: NSRect(x: head.x - 3.1, y: head.y - 2.9, width: 6.2, height: 5.8)).fill()
        if style.snout {
            NSBezierPath(roundedRect: NSRect(x: head.x, y: head.y - 2.6, width: 6.0, height: 3.4),
                         xRadius: 1.6, yRadius: 1.6).fill()
        }

        // Ears
        switch style.ears {
        case .pointed:
            for earX in [head.x - 2.0, head.x + 1.0] {
                polygon([NSPoint(x: earX - 1.3, y: head.y + 1.6),
                         NSPoint(x: earX + 0.1, y: head.y + 5.0),
                         NSPoint(x: earX + 1.4, y: head.y + 1.6)])
            }
        case .floppy:
            let flap = sin(phase * 2) * 1.6 // the ear flaps behind the head as the dog bounces
            polygon([NSPoint(x: head.x - 0.5, y: head.y + 2.8),
                     NSPoint(x: head.x - 5.6, y: head.y + 1.6 + flap),
                     NSPoint(x: head.x - 2.4, y: head.y - 0.6)])
        case .long:
            let lean = sin(phase * 2 + 1.2) * 0.8
            for (dx, tilt) in [(-1.2, -2.6), (0.6, -1.2)] {
                line(from: NSPoint(x: head.x + dx, y: head.y + 2.0),
                     to: NSPoint(x: head.x + dx + tilt - lean, y: head.y + 6.2), width: 1.9)
            }
        }

        // Tail
        let wave = sin(phase + 1.0)
        switch style.tail {
        case .long:
            let tail = NSBezierPath()
            tail.move(to: NSPoint(x: 7.5, y: bodyY + 0.8))
            tail.curve(to: NSPoint(x: 1.6, y: bodyY + 4.4 + wave * 2.2),
                       controlPoint1: NSPoint(x: 4.2, y: bodyY + 0.6),
                       controlPoint2: NSPoint(x: 3.2, y: bodyY + 2.2 + wave * 2.2))
            tail.lineWidth = 1.7
            tail.lineCapStyle = .round
            tail.stroke()
        case .short:
            line(from: NSPoint(x: 7.5, y: bodyY + 1.4),
                 to: NSPoint(x: 4.2 + wave * 1.2, y: bodyY + 5.6), width: 1.9)
        case .puff:
            NSBezierPath(ovalIn: NSRect(x: 4.6, y: bodyY - 0.2, width: 3.8, height: 3.8)).fill()
        }

        // Legs: front pair and rear pair swing in opposition, like a gallop.
        let hipY = bodyY - 1.6
        leg(hip: NSPoint(x: 18.6, y: hipY), phase: phase, segment: style.legSegment)
        leg(hip: NSPoint(x: 17.0, y: hipY), phase: phase + 0.7, segment: style.legSegment)
        leg(hip: NSPoint(x: 9.6, y: hipY), phase: phase + .pi, segment: style.legSegment)
        leg(hip: NSPoint(x: 8.0, y: hipY), phase: phase + .pi + 0.7, segment: style.legSegment)
    }

    private static func leg(hip: NSPoint, phase: Double, segment: Double) {
        let swing = sin(phase) * 0.95              // thigh angle from straight down
        let bend = (1 + cos(phase)) * 0.45         // knee folds while the leg travels forward
        let knee = NSPoint(x: hip.x + sin(swing) * segment, y: hip.y - cos(swing) * segment)
        let footAngle = swing - bend
        let foot = NSPoint(x: knee.x + sin(footAngle) * segment, y: knee.y - cos(footAngle) * segment)

        let path = NSBezierPath()
        path.move(to: hip)
        path.line(to: knee)
        path.line(to: foot)
        path.lineWidth = 1.7
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Bird

    static func bird(phase: Double) {
        let flap = sin(phase)
        let y = 9.0 - flap * 0.9 // the body dips as the wings come up

        NSBezierPath(ovalIn: NSRect(x: 7, y: y - 2.6, width: 14.5, height: 5.2)).fill()         // body
        NSBezierPath(ovalIn: NSRect(x: 19.0, y: y - 0.6, width: 5.2, height: 5.0)).fill()       // head
        polygon([NSPoint(x: 23.6, y: y + 2.9), NSPoint(x: 27.6, y: y + 1.7), NSPoint(x: 23.6, y: y + 0.9)]) // beak
        polygon([NSPoint(x: 9.0, y: y + 0.8), NSPoint(x: 1.2, y: y + 2.6), NSPoint(x: 1.8, y: y - 2.0),
                 NSPoint(x: 9.0, y: y - 1.2)])                                                    // tail

        // Wing: hinged along the back, tip sweeps from high above to below the body.
        let wing = NSBezierPath()
        wing.move(to: NSPoint(x: 17.5, y: y + 1.2))
        wing.curve(to: NSPoint(x: 8.5, y: y + 0.5 + flap * 8.0),
                   controlPoint1: NSPoint(x: 15.5, y: y + 1.5 + flap * 5.0),
                   controlPoint2: NSPoint(x: 11.5, y: y + 1.0 + flap * 8.5))
        wing.line(to: NSPoint(x: 10.5, y: y + 0.6))
        wing.close()
        wing.lineWidth = 1.2
        wing.lineJoinStyle = .round
        wing.fill()
        wing.stroke()
    }

    // MARK: - Fan

    static func fan(phase: Double) {
        let centre = NSPoint(x: 9, y: 9)
        let blades = 3
        // One full animation cycle turns the fan by one blade, so the loop is seamless.
        let rotation = -phase / Double(blades)

        func point(_ radius: Double, _ angle: Double) -> NSPoint {
            NSPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius)
        }

        for blade in 0..<blades {
            let a = rotation + Double(blade) / Double(blades) * 2 * .pi
            let path = NSBezierPath()
            path.move(to: centre)
            path.curve(to: point(8.3, a), controlPoint1: point(4.5, a - 1.1), controlPoint2: point(8.8, a - 0.7))
            path.curve(to: centre, controlPoint1: point(6.0, a + 0.15), controlPoint2: point(3.0, a + 0.2))
            path.fill()
        }
        NSBezierPath(ovalIn: NSRect(x: centre.x - 2, y: centre.y - 2, width: 4, height: 4)).fill()
    }

    // MARK: - Helpers

    private static func polygon(_ points: [NSPoint]) {
        let path = NSBezierPath()
        path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }
        path.close()
        path.fill()
    }

    private static func line(from: NSPoint, to: NSPoint, width: Double) {
        let path = NSBezierPath()
        path.move(to: from)
        path.line(to: to)
        path.lineWidth = width
        path.lineCapStyle = .round
        path.stroke()
    }
}
