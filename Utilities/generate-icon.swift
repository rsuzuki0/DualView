import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon.png"
let pixelSize = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Could not create icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let canvas = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
NSColor.clear.setFill()
canvas.fill()

let background = NSBezierPath(
    roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900),
    xRadius: 205,
    yRadius: 205
)
NSColor(calibratedRed: 0.055, green: 0.065, blue: 0.09, alpha: 1).setFill()
background.fill()

let landscapeShadow = NSBezierPath(
    roundedRect: NSRect(x: 120, y: 285, width: 600, height: 390),
    xRadius: 46,
    yRadius: 46
)
NSColor(calibratedWhite: 0, alpha: 0.42).setFill()
landscapeShadow.fill()

let landscape = NSBezierPath(
    roundedRect: NSRect(x: 105, y: 305, width: 600, height: 390),
    xRadius: 46,
    yRadius: 46
)
NSColor(calibratedRed: 0.12, green: 0.72, blue: 0.96, alpha: 1).setFill()
landscape.fill()

let landscapeInset = NSBezierPath(
    roundedRect: NSRect(x: 145, y: 345, width: 520, height: 310),
    xRadius: 24,
    yRadius: 24
)
NSColor(calibratedRed: 0.035, green: 0.105, blue: 0.16, alpha: 1).setFill()
landscapeInset.fill()

let portraitShadow = NSBezierPath(
    roundedRect: NSRect(x: 610, y: 145, width: 285, height: 620),
    xRadius: 43,
    yRadius: 43
)
NSColor(calibratedWhite: 0, alpha: 0.48).setFill()
portraitShadow.fill()

let portrait = NSBezierPath(
    roundedRect: NSRect(x: 590, y: 165, width: 285, height: 620),
    xRadius: 43,
    yRadius: 43
)
NSColor(calibratedRed: 0.98, green: 0.31, blue: 0.57, alpha: 1).setFill()
portrait.fill()

let portraitInset = NSBezierPath(
    roundedRect: NSRect(x: 625, y: 205, width: 215, height: 540),
    xRadius: 22,
    yRadius: 22
)
NSColor(calibratedRed: 0.14, green: 0.035, blue: 0.09, alpha: 1).setFill()
portraitInset.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}
try png.write(to: URL(fileURLWithPath: outputPath))
