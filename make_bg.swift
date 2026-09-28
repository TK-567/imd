import AppKit

let argv = CommandLine.arguments
let outPath = argv.count > 1 ? argv[1] : "bg.png"

let w = 600
let h = 340

// 精确 1x 像素, 避免 Retina 2x 导致背景与窗口坐标错位
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: w * 4, bitsPerPixel: 32
)!
rep.size = NSSize(width: w, height: h)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 背景
NSColor(calibratedWhite: 0.97, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: w, height: h).fill()

// 顶部文字
let title = "拖动 imd 到 Applications 文件夹即可安装" as NSString
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 1)
]
let ts = title.size(withAttributes: titleAttrs)
title.draw(at: NSPoint(x: (CGFloat(w) - ts.width) / 2, y: CGFloat(h) - 50), withAttributes: titleAttrs)

// 单箭头 -> : 左->右渐变线 + 实心箭头, 与图标垂直中心对齐 (中心 y 从底=175)
let accent = NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)
let cy: CGFloat = 175
let cx: CGFloat = CGFloat(w) / 2

let lineRect = NSRect(x: cx - 95, y: cy - 3, width: 150, height: 6)
let linePath = NSBezierPath(roundedRect: lineRect, xRadius: 3, yRadius: 3)
NSGraphicsContext.current?.saveGraphicsState()
linePath.addClip()
let grad = NSGradient(starting: accent.withAlphaComponent(0.15), ending: accent.withAlphaComponent(0.70))!
grad.draw(in: lineRect, angle: 0)
NSGraphicsContext.current?.restoreGraphicsState()

let head = NSBezierPath()
head.move(to: NSPoint(x: cx + 52, y: cy - 15))
head.line(to: NSPoint(x: cx + 92, y: cy))
head.line(to: NSPoint(x: cx + 52, y: cy + 15))
head.close()
accent.withAlphaComponent(0.80).setFill()
head.fill()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("render failed\n", stderr)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
