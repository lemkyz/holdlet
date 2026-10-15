import AppKit
import Foundation

let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
func draw(size: Int, name: String) throws {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw CocoaError(.fileWriteUnknown) }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scaleX(by: scale, yBy: scale); transform.concat()
    let rect = NSRect(x: 80, y: 80, width: 864, height: 864)
    let path = NSBezierPath(roundedRect: rect, xRadius: 192, yRadius: 192)
    NSGradient(starting: NSColor(calibratedWhite: 0.33, alpha: 1), ending: NSColor(calibratedWhite: 0.12, alpha: 1))!.draw(in: path, angle: -70)
    NSColor.white.withAlphaComponent(0.24).setStroke(); path.lineWidth = 3; path.stroke()
    let tiles: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(224, 548, 576, 232), (224, 244, 272, 264), (536, 244, 264, 264)]
    for (x, y, w, h) in tiles {
        let tile = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: 72, yRadius: 72)
        NSColor(calibratedWhite: 0.96, alpha: y > 500 ? 0.9 : 0.45).setFill(); tile.fill()
        NSColor.white.withAlphaComponent(0.55).setStroke(); tile.lineWidth = 2; tile.stroke()
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try png.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
}
for size in [16, 32, 128, 256, 512] {
    try draw(size: size, name: "icon_\(size)x\(size).png")
    try draw(size: size * 2, name: "icon_\(size)x\(size)@2x.png")
}
