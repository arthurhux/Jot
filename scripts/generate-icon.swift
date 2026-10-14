import AppKit
import Foundation

// An original icon, drawn at each output size so its edges stay crisp.
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets", isDirectory: true)
let iconset = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let manager = FileManager.default
try manager.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func render(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    defer { NSGraphicsContext.restoreGraphicsState() }
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    // Soft lifted cream tile, with room for the native macOS icon silhouette.
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 28,
                      color: color(51, 39, 18, 0.19).cgColor)
    let tile = NSBezierPath(roundedRect: NSRect(x: 68, y: 68, width: 888, height: 888), xRadius: 202, yRadius: 202)
    color(255, 250, 239).setFill()
    tile.fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    let wash = NSGradient(starting: color(255, 253, 247), ending: color(240, 231, 210))!
    wash.draw(in: tile, angle: -75)
    color(255, 255, 255, 0.7).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // A casually tilted sheet of cobalt paper.
    context.saveGState()
    context.translateBy(x: 512, y: 512)
    context.rotate(by: -0.085)
    context.translateBy(x: -512, y: -512)
    context.setShadow(offset: CGSize(width: 0, height: -15), blur: 26,
                      color: color(23, 54, 116, 0.2).cgColor)
    let paper = NSBezierPath()
    paper.move(to: NSPoint(x: 352, y: 790))
    paper.line(to: NSPoint(x: 591, y: 790))
    paper.curve(to: NSPoint(x: 625, y: 776), controlPoint1: NSPoint(x: 605, y: 790), controlPoint2: NSPoint(x: 615, y: 786))
    paper.line(to: NSPoint(x: 738, y: 663))
    paper.curve(to: NSPoint(x: 752, y: 629), controlPoint1: NSPoint(x: 748, y: 653), controlPoint2: NSPoint(x: 752, y: 643))
    paper.line(to: NSPoint(x: 752, y: 307))
    paper.curve(to: NSPoint(x: 699, y: 254), controlPoint1: NSPoint(x: 752, y: 278), controlPoint2: NSPoint(x: 728, y: 254))
    paper.line(to: NSPoint(x: 352, y: 254))
    paper.curve(to: NSPoint(x: 299, y: 307), controlPoint1: NSPoint(x: 323, y: 254), controlPoint2: NSPoint(x: 299, y: 278))
    paper.line(to: NSPoint(x: 299, y: 737))
    paper.curve(to: NSPoint(x: 352, y: 790), controlPoint1: NSPoint(x: 299, y: 766), controlPoint2: NSPoint(x: 323, y: 790))
    paper.close()
    color(45, 100, 226).setFill()
    paper.fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    NSGradient(starting: color(74, 130, 248), ending: color(36, 83, 192))!.draw(in: paper, angle: -90)

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 605, y: 783))
    fold.line(to: NSPoint(x: 605, y: 681))
    fold.curve(to: NSPoint(x: 641, y: 645), controlPoint1: NSPoint(x: 605, y: 661), controlPoint2: NSPoint(x: 621, y: 645))
    fold.line(to: NSPoint(x: 745, y: 645))
    fold.close()
    color(154, 190, 255).setFill()
    fold.fill()

    func stroke(_ points: [(CGFloat, CGFloat)], width: CGFloat, tint: NSColor) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: points[0].0, y: points[0].1))
        for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        tint.setStroke()
        path.stroke()
    }
    // Handwritten marks keep the icon friendly and recognizable at small sizes.
    let scribble = NSBezierPath()
    scribble.move(to: NSPoint(x: 386, y: 582))
    scribble.curve(to: NSPoint(x: 476, y: 608), controlPoint1: NSPoint(x: 413, y: 625), controlPoint2: NSPoint(x: 450, y: 641))
    scribble.curve(to: NSPoint(x: 488, y: 510), controlPoint1: NSPoint(x: 499, y: 580), controlPoint2: NSPoint(x: 458, y: 513))
    scribble.curve(to: NSPoint(x: 649, y: 556), controlPoint1: NSPoint(x: 518, y: 507), controlPoint2: NSPoint(x: 600, y: 599))
    scribble.lineWidth = 31
    scribble.lineCapStyle = .round
    scribble.lineJoinStyle = .round
    color(255, 253, 246).setStroke()
    scribble.stroke()
    stroke([(388, 422), (566, 422)], width: 25, tint: color(255, 253, 246, 0.83))
    stroke([(388, 359), (495, 359)], width: 25, tint: color(255, 253, 246, 0.52))
    context.restoreGState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "JotIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode icon"])
    }
    return data
}

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    try render(size: size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size: size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(size: 1024).write(to: outputDirectory.appendingPathComponent("AppIcon.png"))
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", outputDirectory.appendingPathComponent("AppIcon.icns").path, iconset.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
print("Generated \(outputDirectory.appendingPathComponent("AppIcon.icns").path)")
