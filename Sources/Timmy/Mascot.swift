import AppKit

/// 캐릭터 하나의 색 구성.
struct Palette {
    let ink: NSColor        // 외곽선
    let body: NSColor       // 몸통 채움
    let limb: NSColor       // 팔·손 채움
    let limbLine: NSColor   // 손 위에 그리는 발가락·주름 선
    let accent: NSColor     // 귀 안쪽, 코 같은 포인트
}

/// 캐릭터마다 다른 부분만 정의한다.
/// 책상·키보드·마우스·팔·손은 캐릭터와 무관하게 `Stage` 가 그린다.
protocol Mascot {
    var palette: Palette { get }
    var leftShoulder: CGPoint { get }
    var rightShoulder: CGPoint { get }

    /// 책상 위로 드러나는 상체. 책상 아래를 잘라내는 건 호출자가 한다.
    func drawUpperBody(in ctx: CGContext)
}

/// 화면 배치. 모든 좌표는 이 논리 캔버스 기준이며 그릴 때 뷰 크기에 맞춰 스케일된다.
enum Layout {
    static let canvas = CGSize(width: 320, height: 220)

    /// 책상 상판 높이. 캐릭터는 이 선 아래로 그려지지 않는다.
    static let deskTop: CGFloat = 52

    static let deskRect = NSRect(x: 4, y: 16, width: 312, height: 36)
    static let keyboardRect = NSRect(x: 38, y: 44, width: 172, height: 20)

    static let leftPawX: CGFloat = 100
    static let rightPawX: CGFloat = 180

    /// 자판 위에 떠 있는 높이.
    static let pawIdleY: CGFloat = 88
    /// 키를 내려쳤을 때의 높이. 누르고 있는 동안 이 자리에 머문다.
    static let pawStrikeY: CGFloat = 74

    /// 커서 위치(0...1)를 마우스 중심 좌표로 옮기는 범위.
    /// 마우스패드가 없으니 세로 폭은 좁게 둬야 마우스가 책상에서 떠 보이지 않는다.
    static func mouseCenter(forCursor p: CGPoint) -> CGPoint {
        CGPoint(x: 240 + p.x * 46, y: 58 + p.y * 8)
    }
}

// MARK: - 그리기 잡동사니 (여러 파일에서 함께 쓴다)

func fillStroke(_ path: NSBezierPath, fill: NSColor, stroke: NSColor, width: CGFloat) {
    fill.setFill()
    path.fill()
    stroke.setStroke()
    path.lineWidth = width
    path.stroke()
}

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}
