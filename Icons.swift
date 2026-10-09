// Menu bar icons: "Sleepy Screen Face" (#14 from the icon studio).
// Drawn in code so they stay crisp at any scale. 18x18 pt, top-left origin.
import AppKit

private func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
            blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

private func roundRect(_ r: NSRect, fill: (NSBezierPath) -> Void, stroke: UInt32) {
    let p = NSBezierPath(roundedRect: r, xRadius: r.height > 4 ? 1.2 : 1, yRadius: r.height > 4 ? 1.2 : 1)
    fill(p)
    hex(stroke).setStroke(); p.lineWidth = 1; p.stroke()
}

private func solid(_ c: UInt32) -> (NSBezierPath) -> Void { { hex(c).setFill(); $0.fill() } }
private func vgrad(_ top: UInt32, _ bottom: UInt32) -> (NSBezierPath) -> Void {
    { NSGradient(starting: hex(top), ending: hex(bottom))?.draw(in: $0, angle: 90) }  // flipped: 90 = top→bottom
}

private func smile(_ x0: CGFloat, _ x1: CGFloat, y: CGFloat, dip: CGFloat, color: UInt32, width: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: x0, y: y))
    p.curve(to: NSPoint(x: x1, y: y), controlPoint1: NSPoint(x: x0 + (x1 - x0) / 3, y: y + dip),
            controlPoint2: NSPoint(x: x1 - (x1 - x0) / 3, y: y + dip))
    p.lineWidth = width; p.lineCapStyle = .round
    hex(color).setStroke(); p.stroke()
}

private func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: UInt32) {
    hex(c).setFill(); NSBezierPath(ovalIn: NSRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)).fill()
}

private let screen = NSRect(x: 3, y: 2.5, width: 12, height: 8.5)
private let base = NSRect(x: 1.5, y: 12, width: 15, height: 3)

/// Normal sleep: cool blue laptop with closed, sleepy eyes.
let sleepIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
    roundRect(screen, fill: solid(0x6b7ca3), stroke: 0x3a4660)
    smile(5.6, 8.4, y: 6.6, dip: 1.2, color: 0xdbe3f3, width: 1.3)
    smile(9.6, 12.4, y: 6.6, dip: 1.2, color: 0xdbe3f3, width: 1.3)
    roundRect(base, fill: solid(0x9aa7bd), stroke: 0x3a4660)
    return true
}

/// Staying awake: warm orange laptop, eyes open, smiling.
let awakeIcon = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
    roundRect(screen, fill: vgrad(0xffb84d, 0xf07f1e), stroke: 0xb8600f)
    dot(7, 6, 1.4, 0xffffff); dot(11, 6, 1.4, 0xffffff)
    dot(7, 6.1, 0.95, 0x4a2800); dot(11, 6.1, 0.95, 0x4a2800)
    smile(7, 11, y: 8.4, dip: 1.07, color: 0x4a2800, width: 1.2)
    roundRect(base, fill: vgrad(0xffd27a, 0xf08a2c), stroke: 0xb5570f)
    return true
}
