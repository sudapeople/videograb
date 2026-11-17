// GitHub 대표 이미지(social preview, 1280x640) 생성
// 사용: swift scripts/make-social-preview.swift   ->  docs/social-preview.png
import AppKit

let W = 1280, H = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// 배경: 어두운 회색 + 왼쪽 위에 아이콘 빨강을 옅게
NSColor(white: 0.08, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()
NSGradient(starting: NSColor(red: 0.85, green: 0.10, blue: 0.12, alpha: 0.35), ending: .clear)!
    .draw(fromCenter: NSPoint(x: 160, y: 560), radius: 0, toCenter: NSPoint(x: 160, y: 560), radius: 620, options: [])

// 왼쪽: 아이콘, 이름, 소개
NSImage(contentsOfFile: "docs/icon.png")!.draw(in: NSRect(x: 48, y: 388, width: 200, height: 200))

func text(_ s: String, _ font: NSFont, _ color: NSColor, _ rect: NSRect) {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = 6
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        .draw(with: rect, options: [.usesLineFragmentOrigin])
}
text("VideoGrab", .systemFont(ofSize: 76, weight: .bold), .white, NSRect(x: 72, y: 290, width: 520, height: 100))
text("⌘V 한 번으로 유튜브 영상을\n최고 화질로 받는 맥 앱", .systemFont(ofSize: 32, weight: .semibold),
     NSColor(white: 0.92, alpha: 1), NSRect(x: 72, y: 180, width: 520, height: 100))
text("Paste a YouTube link, get the best quality.", .systemFont(ofSize: 22, weight: .regular),
     NSColor(white: 0.62, alpha: 1), NSRect(x: 72, y: 130, width: 520, height: 34))
text("macOS 14+  ·  Apple Silicon  ·  MIT  ·  yt-dlp", .systemFont(ofSize: 20, weight: .medium),
     NSColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1), NSRect(x: 72, y: 60, width: 520, height: 30))

// 오른쪽: 사용 화면 (원본 680x440 을 1:1 로, 둥근 모서리 + 그림자)
let shot = NSRect(x: 560, y: 100, width: 680, height: 440)
let clip = NSBezierPath(roundedRect: shot, xRadius: 14, yRadius: 14)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(white: 0, alpha: 0.6)
shadow.shadowBlurRadius = 40
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
NSColor(white: 0.12, alpha: 1).setFill()
clip.fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
clip.addClip()
NSImage(contentsOfFile: "docs/screenshots/downloading.png")!.draw(in: shot)
NSGraphicsContext.restoreGraphicsState()
NSColor(white: 1, alpha: 0.12).setStroke()
clip.lineWidth = 1
clip.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/social-preview.png"))
print("docs/social-preview.png")
