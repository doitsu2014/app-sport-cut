// Rasterise one Sportcut brand SVG into a transparent PNG app icon.
//
// Called by tools/generate-app-icons.sh. macOS only: AppKit loads the SVG
// as a resolution-independent image, so strokes stay crisp at 16 px.
//
// Usage:
//   swift tools/render-app-icon.swift <source.svg> <output.png> <pixels>

import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(
        "usage: render-app-icon.swift <source.svg> <output.png> <pixels>\n".data(using: .utf8)!
    )
    exit(2)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let pixels = Int(CommandLine.arguments[3]), pixels > 0 else {
    FileHandle.standardError.write("render-app-icon: pixels must be a positive integer\n".data(using: .utf8)!)
    exit(2)
}

guard let image = NSImage(contentsOf: source) else {
    FileHandle.standardError.write("render-app-icon: could not read \(source.path)\n".data(using: .utf8)!)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write("render-app-icon: could not allocate \(pixels)px bitmap\n".data(using: .utf8)!)
    exit(1)
}
bitmap.size = NSSize(width: pixels, height: pixels)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high
image.draw(
    in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
    from: .zero,
    operation: .copy,
    fraction: 1.0
)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("render-app-icon: could not encode PNG\n".data(using: .utf8)!)
    exit(1)
}
do {
    try png.write(to: output)
} catch {
    FileHandle.standardError.write("render-app-icon: \(error)\n".data(using: .utf8)!)
    exit(1)
}
