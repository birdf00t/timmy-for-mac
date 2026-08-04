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

    func drawUpperBody(in ctx: CGContext, expression: Expression) {
        drawEars(in: ctx)
        drawHead()

        // 머리 실루엣만 털 뒤에 두면 얼굴 아래쪽이 털에 품긴 것처럼 보인다.
        drawWool()

        // 얼굴 표정은 털보다 나중에 그린다. 그래야 코·입이 털에 가리지 않고 앞으로 나온다.
        drawForeheadTuft()
        drawMuzzle(expression)
        drawEyes(expression)
        drawSweat(expression)
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

    /// 눈 흰자. 오래 안 깜빡이면 빨개진다.
    private func eyeWhite(_ redness: CGFloat) -> NSColor {
        NSColor(calibratedRed: 1.0,
                green: 1.0 - 0.45 * redness,
                blue: 1.0 - 0.42 * redness,
                alpha: 1.0)
    }

    private func drawEyes(_ expression: Expression) {
        let eyeRects = [CGFloat(136), CGFloat(164)].map {
            NSRect(x: $0 - 14, y: 172, width: 28, height: 30)
        }

        // 큼직한 흰 눈
        for rect in eyeRects {
            fillStroke(NSBezierPath(ovalIn: rect),
                       fill: eyeWhite(expression.redness), stroke: palette.ink, width: 2.8)
        }

        // 눈동자는 보는 방향으로 움직인다. 흰자 밖으로 나가지 않을 만큼만.
        let look = CGPoint(x: expression.gaze.x * 4.2, y: expression.gaze.y * 7.0)
        palette.accent.setFill()
        for x in [CGFloat(138), CGFloat(166)] {
            NSBezierPath(ovalIn: NSRect(x: x - 6 + look.x, y: 181 + look.y,
                                        width: 12, height: 12)).fill()
        }

        drawEyebrows(expression)
        drawEyelids(over: eyeRects, expression: expression)
    }

    /// 미간 쪽으로 찌푸린 눈썹. 눈꺼풀만 살짝 내려오면 졸린 것처럼 보이는데,
    /// 눈썹이 안쪽(코 쪽)으로 내려가야 화난 듯 집중한 표정으로 읽힌다.
    private func drawEyebrows(_ expression: Expression) {
        guard expression.heat > 0.02 else { return }
        let h = expression.heat

        // (안쪽 x, 바깥쪽 x) — 안쪽 끝이 내려가고 바깥쪽 끝이 올라가면
        // 두 눈썹이 가운데서 만나 "V" 자로 찌푸린 모양이 된다.
        //
        // 바깥쪽 끝은 머리 실루엣의 둥근 모서리 안쪽에 머물러야 한다 — 머리는
        // 둥근 사각형이라 가장자리로 갈수록(x 가 110 에 가까워질수록) 위쪽
        // 경계가 빠르게 낮아진다. x=130 근처에서도 경계가 y≈204 라서
        // 여유를 넉넉히 두고 y=199 까지만 올린다.
        let brows: [(inner: CGFloat, outer: CGFloat)] = [(148, 130), (152, 170)]
        palette.ink.setStroke()
        for (inner, outer) in brows {
            let brow = NSBezierPath()
            brow.move(to: CGPoint(x: inner, y: 197 - h * 4))
            brow.line(to: CGPoint(x: outer, y: 197 + h * 2))
            brow.lineWidth = 3.2
            brow.lineCapStyle = .round
            brow.stroke()
        }
    }

    private func drawMuzzle(_ expression: Expression) {
        // 콧구멍
        palette.accent.setFill()
        for x in [CGFloat(144), CGFloat(156)] {
            NSBezierPath(ovalIn: NSRect(x: x - 1.8, y: 161.5, width: 3.6, height: 3)).fill()
        }

        // 입. 평소엔 웃는 곡선이고, 집중하거나(땀) 졸릴 때는 웃을 상황이 아니므로
        // 다문 일자에 가까워진다 — 곡선의 처짐 정도를 곧게 펴는 식이다.
        // 둘 중 더 강한 쪽이 표정을 끌고 간다.
        let notSmiling = max(expression.heat, expression.drowsiness)
        let curveY = lerp(150, 155, notSmiling)
        palette.accent.setStroke()
        let mouth = NSBezierPath()
        mouth.move(to: CGPoint(x: 142, y: 156))
        mouth.curve(to: CGPoint(x: 158, y: 156),
                    controlPoint1: CGPoint(x: 146, y: curveY),
                    controlPoint2: CGPoint(x: 154, y: curveY))
        mouth.lineWidth = 2.5
        mouth.lineCapStyle = .round
        mouth.stroke()
    }

    // MARK: - 졸린 눈 / 집중한 눈

    /// 눈꺼풀은 얼굴 색으로 눈 위쪽을 덮는다. 눈 타원 안으로 잘라내야
    /// 눈 밖으로 삐져나온 사각형처럼 보이지 않는다.
    ///
    /// 같은 눈꺼풀을 두 가지 용도로 함께 쓴다 — 졸릴 때는 많이 덮어 나른하게,
    /// 땀이 날 때(집중할 때)는 살짝만 덮어 눈을 가늘게 뜬 것처럼 보이게 한다.
    private func drawEyelids(over eyes: [NSRect], expression: Expression) {
        let sleepy = expression.drowsiness * (0.40 + 0.58 * expression.lidPhase)
        // 살짝만 — 눈썹이 화난 표정의 주된 신호이고, 이건 보조 정도로만 거든다.
        let squint = expression.heat * 0.08
        let coverage = max(sleepy, squint)
        guard coverage > 0.01 else { return }

        for rect in eyes {
            let eye = NSBezierPath(ovalIn: rect)
            NSGraphicsContext.saveGraphicsState()
            eye.addClip()

            let lidHeight = rect.height * coverage
            let lidY = rect.maxY - lidHeight
            palette.limb.setFill()
            NSRect(x: rect.minX - 2, y: lidY,
                   width: rect.width + 4, height: lidHeight + 2).fill()

            // 눈꺼풀 접힌 선
            palette.ink.setStroke()
            let edge = NSBezierPath()
            edge.move(to: CGPoint(x: rect.minX - 2, y: lidY))
            edge.line(to: CGPoint(x: rect.maxX + 2, y: lidY))
            edge.lineWidth = 2.4
            edge.stroke()

            NSGraphicsContext.restoreGraphicsState()

            // 잘라낸 뒤 눈 외곽선을 다시 그려 테두리가 끊기지 않게 한다.
            palette.ink.setStroke()
            eye.lineWidth = 2.8
            eye.stroke()
        }
    }

    // MARK: - 땀

    /// 빠르게 타이핑하면 양쪽 뺨을 타고 땀이 흘러내린다.
    /// 위쪽은 트여 있다 — 피부 위쪽에서 계속 배어 나오는 것처럼 보이도록,
    /// 끝을 막지 않고 잘라낸다. 아래쪽만 U 자로 둥글게 마감한다.
    /// 머리는 좌우 대칭이라 오른쪽 자리를 그대로 뒤집으면 왼쪽 자리가 나온다.
    private func drawSweat(_ expression: Expression) {
        guard expression.heat > 0.02 else { return }

        // 눈 아래, 뺨이 드러나는 좁은 자리. 위(눈 밑)에서 아래(턱 쪽)로 흘러내린다.
        let rightTop = CGPoint(x: 180, y: 172)
        let leftTop = CGPoint(x: 300 - rightTop.x, y: rightTop.y)
        let anchors: [(top: CGPoint, offset: CGFloat)] = [
            (rightTop, 0.0),
            (leftTop, 0.5),
        ]

        let travelDistance: CGFloat = 20
        let streakWidth: CGFloat = 6.5
        let streakLength: CGFloat = 15

        for (top, offset) in anchors {
            // 두 뺨이 다른 위상에서 흘러야 동시에 움직이는 것처럼 안 보인다.
            var phase = expression.sweatPhase + offset
            if phase > 1 { phase -= 1 }

            // 시작할 때 배어 나오듯 서서히 나타나고, 끝에서는 빠르게 사라진다.
            let fadeIn = min(1, phase * 6)
            let fadeOut = min(1, (1 - phase) * 4)
            let alpha = expression.heat * fadeIn * fadeOut
            guard alpha > 0.02 else { continue }

            let center = CGPoint(x: top.x, y: top.y - phase * travelDistance)

            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: center.x, yBy: center.y)
            transform.concat()

            let streak = sweatStreak(width: streakWidth, length: streakLength)
            NSColor.white.withAlphaComponent(alpha * 0.9).setFill()
            streak.fill()
            palette.ink.withAlphaComponent(alpha).setStroke()
            streak.lineWidth = 2.2
            streak.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// 위는 트여 있고 아래만 U 자로 둥근 땀 줄기. 원점 (0,0) 을 중심으로 세워서 그린다.
    /// 위쪽 가장자리는 닫지 않는다 — 피부에서 계속 흘러나오는 것처럼 보이려면
    /// 끝을 막으면 안 된다.
    private func sweatStreak(width w: CGFloat, length l: CGFloat) -> NSBezierPath {
        let half = w / 2
        let topY = l / 2
        let curveY = -l / 2 + half
        // 위쪽은 좁게 시작해서 아래로 갈수록 U 자 폭까지 자연스럽게 벌어진다.
        // 옆면도 완전한 직선이 아니라 살짝 배가 부른 곡선으로 그린다 —
        // 평행한 직선 두 개는 자로 그린 것처럼 각지게 보인다.
        let topHalf = half * 0.45

        let p = NSBezierPath()
        p.move(to: CGPoint(x: -topHalf, y: topY))
        p.curve(to: CGPoint(x: -half, y: curveY),
                controlPoint1: CGPoint(x: -topHalf - half * 0.35, y: topY - l * 0.25),
                controlPoint2: CGPoint(x: -half - half * 0.15, y: curveY + l * 0.30))
        // clockwise: true 로 두면 180도에서 위쪽(90도)을 지나 0도로 가서
        // 위로 볼록한 ∩ 모양이 된다. 아래로 볼록한 U 가 되려면 아래쪽(270도)을
        // 지나야 하므로 false 로 돌린다.
        p.appendArc(withCenter: CGPoint(x: 0, y: curveY), radius: half,
                   startAngle: 180, endAngle: 0, clockwise: false)
        p.curve(to: CGPoint(x: topHalf, y: topY),
                controlPoint1: CGPoint(x: half + half * 0.15, y: curveY + l * 0.30),
                controlPoint2: CGPoint(x: topHalf + half * 0.35, y: topY - l * 0.25))
        // 경로를 닫지 않는다. fill() 은 채우기 위해 끝점을 자동으로 이어 붙이지만,
        // stroke() 는 그 이어붙인 선까지 그리지 않는다 — 그래서 채워진 부분은
        // 매끈하게 마감되면서도 위쪽 테두리 선(검은 윤곽)만 트여서 배어 나오듯 보인다.
        return p
    }

}
