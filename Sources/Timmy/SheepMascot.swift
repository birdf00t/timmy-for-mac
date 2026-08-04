import AppKit

/// 양. 뭉게뭉게한 양털 몸통에 짙은 회색 얼굴과 긴 귀.
struct SheepMascot: Mascot {

    let palette = Palette(
        ink: NSColor(calibratedWhite: 0.07, alpha: 1.0),
        body: NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.91, alpha: 1.0),
        limb: NSColor(calibratedWhite: 0.30, alpha: 1.0),
        limbLine: NSColor(calibratedWhite: 0.58, alpha: 1.0),
        accent: NSColor(calibratedWhite: 0.10, alpha: 1.0))

    let leftShoulder = CGPoint(x: 118, y: 100)
    let rightShoulder = CGPoint(x: 192, y: 108)

    func drawUpperBody(in ctx: CGContext) {
        drawEars(in: ctx)
        drawHead()
        // 털을 머리보다 나중에 그려야 얼굴 아래쪽이 털에 품긴 것처럼 보인다.
        drawWool()
        drawForeheadTuft()
        drawFace()
    }

    // MARK: - 양털 몸통

    /// 몸통은 원을 여러 개 겹쳐 만든다.
    /// 큰 원들로 한 번 채워 외곽선을 만들고, 그 위에 작은 원들로 채우면
    /// 원 하나하나의 내부 선 없이 뭉게뭉게한 실루엣만 남는다.
    private var puffs: [(center: CGPoint, radius: CGFloat)] {
        var list: [(CGPoint, CGFloat)] = [
            (CGPoint(x: 150, y: 90), 30),
            (CGPoint(x: 124, y: 93), 24),
            (CGPoint(x: 176, y: 93), 24),
            // 얼굴 아래·양옆을 감싸는 부분. 몸통과 한 덩어리로 그려야 경계선이 생기지 않는다.
            // 입·콧구멍이 있는 턱 가운데(x 142~158)는 낮게 두어 표정을 가리지 않는다.
            (CGPoint(x: 112, y: 136), 14),
            (CGPoint(x: 130, y: 140), 12),
            (CGPoint(x: 170, y: 140), 12),
            (CGPoint(x: 188, y: 136), 14),
        ]
        let ring = 13
        for i in 0..<ring {
            let angle = CGFloat(i) / CGFloat(ring) * .pi * 2
            let radius: CGFloat = [21, 18, 23][i % 3]
            list.append((CGPoint(x: 150 + cos(angle) * 50,
                                 y: 90 + sin(angle) * 35), radius))
        }
        return list
    }

    /// 큰 원들로 한 번 채워 외곽선을 만들고, 그 위에 작은 원들로 채운다.
    private func fillPuffs(_ shapes: [(center: CGPoint, radius: CGFloat)]) {
        let outline = NSBezierPath()
        for (c, r) in shapes {
            let grown = r + 2.6
            outline.appendOval(in: NSRect(x: c.x - grown, y: c.y - grown,
                                          width: grown * 2, height: grown * 2))
        }
        palette.ink.setFill()
        outline.fill()

        let inside = NSBezierPath()
        for (c, r) in shapes {
            inside.appendOval(in: NSRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        palette.body.setFill()
        inside.fill()
    }

    private func drawWool() {
        let shapes = puffs
        fillPuffs(shapes)

        // 양털 결
        NSColor(calibratedWhite: 0.76, alpha: 0.65).setStroke()
        for (c, r) in shapes {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: c, radius: r * 0.55, startAngle: 205, endAngle: 335)
            arc.lineWidth = 2
            arc.lineCapStyle = .round
            arc.stroke()
        }
    }

    // MARK: - 머리

    private func drawEars(in ctx: CGContext) {
        for side in [CGFloat(-1), CGFloat(1)] {
            ctx.saveGState()
            ctx.translateBy(x: 150 + side * 48, y: 180)
            ctx.rotate(by: side * 20 * .pi / 180)
            let ear = NSBezierPath(ovalIn: NSRect(x: -25, y: -10, width: 50, height: 20))
            fillStroke(ear, fill: palette.limb, stroke: palette.ink, width: 5)

            // 귓구멍 자리를 나타내는 일자 선
            let canal = NSBezierPath()
            canal.move(to: CGPoint(x: -13, y: -2))
            canal.line(to: CGPoint(x: 13, y: -2))
            canal.lineWidth = 2.5
            canal.lineCapStyle = .round
            palette.accent.setStroke()
            canal.stroke()

            ctx.restoreGState()
        }
    }

    private func drawHead() {
        let head = NSBezierPath(roundedRect: NSRect(x: 110, y: 144, width: 80, height: 62),
                                xRadius: 31, yRadius: 31)
        fillStroke(head, fill: palette.limb, stroke: palette.ink, width: 5)
    }

    /// 이마 위 양털 한 줌.
    private func drawForeheadTuft() {
        fillPuffs([
            (CGPoint(x: 136, y: 199), 9),
            (CGPoint(x: 150, y: 204), 10),
            (CGPoint(x: 164, y: 199), 9),
        ])
    }

    private func drawFace() {
        // 큼직한 흰 눈
        for x in [CGFloat(136), CGFloat(164)] {
            let eye = NSBezierPath(ovalIn: NSRect(x: x - 14, y: 172, width: 28, height: 30))
            fillStroke(eye, fill: NSColor.white, stroke: palette.ink, width: 2.8)
        }

        palette.accent.setFill()
        for x in [CGFloat(139), CGFloat(167)] {
            NSBezierPath(ovalIn: NSRect(x: x - 6, y: 181, width: 12, height: 12)).fill()
        }

        // 콧구멍
        for x in [CGFloat(144), CGFloat(156)] {
            NSBezierPath(ovalIn: NSRect(x: x - 1.8, y: 161.5, width: 3.6, height: 3)).fill()
        }

        // 입
        palette.accent.setStroke()
        let mouth = NSBezierPath()
        mouth.move(to: CGPoint(x: 142, y: 156))
        mouth.curve(to: CGPoint(x: 158, y: 156),
                    controlPoint1: CGPoint(x: 146, y: 150),
                    controlPoint2: CGPoint(x: 154, y: 150))
        mouth.lineWidth = 2.5
        mouth.lineCapStyle = .round
        mouth.stroke()
    }
}
