// Draws Ferry's app icon: three window tiles on a cream squircle, the middle
// one picked out by the coral ring, as in the switcher itself.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-out")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func continuousRect(_ rect: CGRect, radius: CGFloat) -> CGPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPath
}

func draw(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = context.cgContext
    let k = s / 1024
    cg.scaleBy(x: k, y: k)

    // Body with the macOS grid's soft drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = continuousRect(body, radius: 185)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x000000, 0.22))
    cg.addPath(bodyPath)
    cg.setFillColor(color(0xf6e7d6))
    cg.fillPath()
    cg.restoreGState()

    cg.saveGState()
    cg.addPath(bodyPath)
    cg.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xfdf3e8), color(0xf1dfc8)] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    cg.restoreGState()

    // Two side tiles, receding.
    func tile(_ rect: CGRect, fill: CGColor, stroke: CGColor? = nil) {
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0x5a3a1c, 0.16))
        cg.addPath(continuousRect(rect, radius: 34))
        cg.setFillColor(fill)
        cg.fillPath()
        cg.restoreGState()
        if let stroke {
            cg.addPath(continuousRect(rect, radius: 34))
            cg.setStrokeColor(stroke)
            cg.setLineWidth(3)
            cg.strokePath()
        }
    }
    tile(CGRect(x: 168, y: 410, width: 196, height: 204), fill: color(0xfffaf3), stroke: color(0x231f1c, 0.06))
    tile(CGRect(x: 660, y: 410, width: 196, height: 204), fill: color(0xfffaf3), stroke: color(0x231f1c, 0.06))
    for x in [168.0, 660.0] {
        cg.setFillColor(color(0xe9d6c0))
        cg.addPath(continuousRect(CGRect(x: x + 30, y: 540, width: 136, height: 16), radius: 8))
        cg.addPath(continuousRect(CGRect(x: x + 30, y: 504, width: 96, height: 16), radius: 8))
        cg.fillPath()
    }

    // The selected tile: ink window inside a coral ring.
    let ring = CGRect(x: 342, y: 330, width: 340, height: 364)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x5a2a14, 0.24))
    cg.addPath(continuousRect(ring, radius: 62))
    cg.setFillColor(color(0xfffaf3))
    cg.fillPath()
    cg.restoreGState()
    cg.addPath(continuousRect(ring.insetBy(dx: 7, dy: 7), radius: 55))
    cg.setStrokeColor(color(0xe8664f))
    cg.setLineWidth(14)
    cg.strokePath()

    let window = ring.insetBy(dx: 34, dy: 34)
    cg.addPath(continuousRect(window, radius: 34))
    cg.setFillColor(color(0x231f1c))
    cg.fillPath()
    cg.setFillColor(color(0xe8664f))
    cg.fillEllipse(in: CGRect(x: window.minX + 30, y: window.maxY - 58, width: 28, height: 28))
    cg.setFillColor(color(0xfbf3ea, 0.22))
    cg.addPath(continuousRect(CGRect(x: window.minX + 30, y: window.minY + 92, width: 192, height: 18), radius: 9))
    cg.addPath(continuousRect(CGRect(x: window.minX + 30, y: window.minY + 56, width: 130, height: 18), radius: 9))
    cg.fillPath()

    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = out.appendingPathComponent("AppIcon.appiconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)@\(scale)x.png"
        try! draw(size: base * scale).write(to: iconset.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "xcode"]]
try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
try! draw(size: 512).write(to: out.appendingPathComponent("icon.png"))
try! draw(size: 180).write(to: out.appendingPathComponent("apple-touch-icon.png"))
try! draw(size: 64).write(to: out.appendingPathComponent("favicon.png"))
print("wrote \(out.path)")
