// Renders the app icon and writes an .iconset directory: swift Scripts/make-icon.swift <out.iconset>
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fillGradient(_ ctx: CGContext, in path: CGPath, from top: UInt32, to bottom: UInt32) {
    let box = path.boundingBox
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
    ctx.restoreGState()
}

/// Draws on a 1024pt canvas (origin bottom-left) following Apple's 824pt icon tile grid.
func draw(_ ctx: CGContext) {
    let tile = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(tile)
    ctx.setFillColor(color(0x1B1140))
    ctx.fillPath()
    ctx.restoreGState()

    fillGradient(ctx, in: tile, from: 0x6C63FF, to: 0x1B1140)
    ctx.addPath(tile)
    ctx.clip()

    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [color(0x9F8CFF, 0.55), color(0x9F8CFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 760), startRadius: 0, endCenter: CGPoint(x: 512, y: 760), endRadius: 480, options: [])

    // the expanded panel the notch grows into
    ctx.addPath(roundedRect(CGRect(x: 172, y: 340, width: 680, height: 700), 110))
    ctx.setFillColor(color(0x000000, 0.45))
    ctx.fillPath()
    for (x, width) in [(CGFloat(222), CGFloat(250)), (492, 170), (682, 120)] {
        ctx.addPath(roundedRect(CGRect(x: x, y: 400, width: width, height: 240), 44))
    }
    ctx.setFillColor(color(0xFFFFFF, 0.2))
    ctx.fillPath()

    // the notch, hanging from the top edge
    ctx.addPath(roundedRect(CGRect(x: 272, y: 700, width: 480, height: 400), 80))
    ctx.setFillColor(color(0x000000))
    ctx.fillPath()

    // live activity inside it: artwork and a waveform
    fillGradient(ctx, in: roundedRect(CGRect(x: 322, y: 756, width: 112, height: 112), 28), from: 0xFFB45E, to: 0xFF4F8B)
    for (index, height) in [CGFloat(48), 100, 66, 112, 58].enumerated() {
        let bar = CGRect(x: 522 + CGFloat(index) * 40, y: 812 - height / 2, width: 22, height: height)
        ctx.addPath(roundedRect(bar, 11))
    }
    ctx.setFillColor(color(0x63F5A8))
    ctx.fillPath()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    draw(ctx)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try! png(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try! png(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
