import AppKit

// icon.png 에서 앱 아이콘용 PNG 세트를 뽑는다.
// 사진 여백을 그대로 두면 아이콘이 실제보다 작아 보이므로,
// 투명하지 않은 영역만 잘라낸 뒤 정사각형 캔버스 가운데에 다시 앉힌다.
_ = NSApplication.shared

let sourcePath = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]

let source = NSBitmapImageRep(data: try! Data(contentsOf: URL(fileURLWithPath: sourcePath)))!
let sw = source.pixelsWide
let sh = source.pixelsHigh

// MARK: - 내용이 있는 영역 찾기

var minX = sw, minY = sh, maxX = -1, maxY = -1
for y in 0..<sh {
    for x in 0..<sw {
        guard let c = source.colorAt(x: x, y: y), c.alphaComponent > 0.02 else { continue }
        if x < minX { minX = x }
        if x > maxX { maxX = x }
        if y < minY { minY = y }
        if y > maxY { maxY = y }
    }
}
guard maxX >= minX, maxY >= minY else {
    FileHandle.standardError.write(Data("내용이 없는 이미지입니다\n".utf8))
    exit(1)
}

// colorAt 은 위쪽이 y = 0 이고, 그리기는 아래쪽이 y = 0 이다.
let crop = NSRect(x: CGFloat(minX),
                  y: CGFloat(sh - 1 - maxY),
                  width: CGFloat(maxX - minX + 1),
                  height: CGFloat(maxY - minY + 1))
print("  내용 영역 \(Int(crop.width))x\(Int(crop.height)) (원본 \(sw)x\(sh))")

let image = NSImage(size: NSSize(width: sw, height: sh))
image.addRepresentation(source)

/// 아이콘 한 변에서 그림이 차지할 비율. 나머지는 여백으로 둔다.
let fill: CGFloat = 0.92

func renderIcon(side: Int, to path: String) {
    let size = CGFloat(side)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: side, pixelsHigh: side,
                               bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let scale = size * fill / max(crop.width, crop.height)
    let drawn = NSSize(width: crop.width * scale, height: crop.height * scale)
    let dest = NSRect(x: (size - drawn.width) / 2,
                      y: (size - drawn.height) / 2,
                      width: drawn.width, height: drawn.height)
    image.draw(in: dest, from: crop, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: path))
    print("  \(side)x\(side) -> \(path)")
}

// Apple 아이콘셋 규격 이름
let entries: [(name: String, side: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, side) in entries {
    renderIcon(side: side, to: "\(outDir)/\(name).png")
}

exit(0)
