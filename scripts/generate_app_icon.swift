import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(colorSpace: colorSpace, components: [247 / 255, 248 / 255, 250 / 255, 1])!)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Original DSH lettering, drawn on a shared geometric grid rather than a font
// or a provider logo. Wide counters and one stroke weight survive small sizes.
context.setStrokeColor(CGColor(colorSpace: colorSpace, components: [65 / 255, 118 / 255, 230 / 255, 1])!)
context.setLineWidth(56)
context.setLineCap(.round)
context.setLineJoin(.round)

// D: a straight spine and a rounded outer bowl.
context.move(to: CGPoint(x: 176, y: 356))
context.addLine(to: CGPoint(x: 176, y: 668))
context.addLine(to: CGPoint(x: 232, y: 668))
context.addCurve(to: CGPoint(x: 344, y: 552), control1: CGPoint(x: 296, y: 668), control2: CGPoint(x: 344, y: 616))
context.addLine(to: CGPoint(x: 344, y: 472))
context.addCurve(to: CGPoint(x: 232, y: 356), control1: CGPoint(x: 344, y: 408), control2: CGPoint(x: 296, y: 356))
context.closePath()
context.strokePath()

// S: two opposing quarter-round turns with open horizontal terminals.
context.move(to: CGPoint(x: 608, y: 668))
context.addLine(to: CGPoint(x: 492, y: 668))
context.addQuadCurve(to: CGPoint(x: 432, y: 608), control: CGPoint(x: 432, y: 668))
context.addLine(to: CGPoint(x: 432, y: 572))
context.addQuadCurve(to: CGPoint(x: 492, y: 512), control: CGPoint(x: 432, y: 512))
context.addLine(to: CGPoint(x: 548, y: 512))
context.addQuadCurve(to: CGPoint(x: 608, y: 452), control: CGPoint(x: 608, y: 512))
context.addLine(to: CGPoint(x: 608, y: 416))
context.addQuadCurve(to: CGPoint(x: 548, y: 356), control: CGPoint(x: 608, y: 356))
context.addLine(to: CGPoint(x: 432, y: 356))
context.strokePath()

// H: the same vertical rhythm, joined at the optical center.
context.move(to: CGPoint(x: 700, y: 356))
context.addLine(to: CGPoint(x: 700, y: 668))
context.move(to: CGPoint(x: 848, y: 356))
context.addLine(to: CGPoint(x: 848, y: 668))
context.move(to: CGPoint(x: 700, y: 512))
context.addLine(to: CGPoint(x: 848, y: 512))
context.strokePath()

let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write app icon") }
