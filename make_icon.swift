import AppKit

let argv = CommandLine.arguments
let outPath = argv.count > 1 ? argv[1] : "icon_1024.png"

let size = 1024
let margin: CGFloat = 100
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let rect = NSRect(x: margin, y: margin, width: CGFloat(size) - margin * 2, height: CGFloat(size) - margin * 2)
let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.height * 0.225)
NSColor.black.setFill()
bg.fill()

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont(name: "HelveticaNeue-Bold", size: 300) ?? NSFont.boldSystemFont(ofSize: 300),
    .foregroundColor: NSColor.white
]
let text = "imd" as NSString
let textSize = text.size(withAttributes: attrs)
let origin = NSPoint(
    x: (CGFloat(size) - textSize.width) / 2,
    y: (CGFloat(size) - textSize.height) / 2 - textSize.height * 0.06
)
text.draw(at: origin, withAttributes: attrs)

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("render failed\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
