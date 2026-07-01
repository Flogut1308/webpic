import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

// Renders the WebPic app icon (concept "Komprimieren": two chevrons squeezing a bar) to a
// 1024×1024 PNG using only CoreGraphics — no external tooling, fully reproducible.
// Usage: swift Scripts/make-icon.swift <output.png>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let dim = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(data: nil, width: dim, height: dim, bitsPerComponent: 8, bytesPerRow: 0,
                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("could not create context")
}

// Top-left origin, matching design coordinates.
ctx.translateBy(x: 0, y: CGFloat(dim))
ctx.scaleBy(x: 1, y: -1)

// macOS icon grid: 824×824 rounded square centered in 1024 with a soft contact shadow.
let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 185
let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

// Contact shadow.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 34, color: CGColor(gray: 0, alpha: 0.22))
ctx.addPath(squircle); ctx.setFillColor(rgb(0x0A84FF)); ctx.fillPath()
ctx.restoreGState()

// Brand gradient fill (5AC8FA → 0A84FF, top to bottom).
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [rgb(0x5AC8FA), rgb(0x0A84FF)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: rect.midX, y: rect.minY),
                       end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
ctx.restoreGState()

// White glyph, centered. Coordinates are in the 160pt preview space, scaled to the 824 squircle.
ctx.saveGState()
ctx.translateBy(x: rect.midX, y: rect.midY)
let s = rect.width / 160
ctx.scaleBy(x: s, y: s)
ctx.setFillColor(rgb(0xFFFFFF))

ctx.beginPath()                                   // top chevron (pointing down)
ctx.move(to: CGPoint(x: -24, y: -48))
ctx.addLine(to: CGPoint(x: 24, y: -48))
ctx.addLine(to: CGPoint(x: 0, y: -22))
ctx.closePath(); ctx.fillPath()

ctx.addPath(CGPath(roundedRect: CGRect(x: -27, y: -12, width: 54, height: 24),
                   cornerWidth: 6, cornerHeight: 6, transform: nil))
ctx.fillPath()                                    // the bar being squeezed

ctx.beginPath()                                   // bottom chevron (pointing up)
ctx.move(to: CGPoint(x: -24, y: 48))
ctx.addLine(to: CGPoint(x: 24, y: 48))
ctx.addLine(to: CGPoint(x: 0, y: 22))
ctx.closePath(); ctx.fillPath()
ctx.restoreGState()

guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil) else {
    fatalError("could not encode PNG")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write PNG") }
print("wrote \(outPath)")
