import AppKit

/// 캐릭터와 무관한 소품과 손을 그린다. 팔·손만 캐릭터 색을 따른다.
struct Stage {
    let palette: Palette

    /// 책상 위 물건들은 캐릭터 색과 무관하게 늘 같은 색이다.
    private let propFill = NSColor(calibratedWhite: 0.97, alpha: 1.0)
    private let propInk = NSColor(calibratedWhite: 0.07, alpha: 1.0)

    // MARK: - 책상

    func drawDesk() {
        let desk = NSBezierPath(roundedRect: Layout.deskRect, xRadius: 10, yRadius: 10)
        NSColor(calibratedWhite: 0.22, alpha: 0.45).setFill()
        desk.fill()
        NSColor(calibratedWhite: 0.05, alpha: 0.45).setStroke()
        desk.lineWidth = 2.5
        desk.stroke()
    }

    func drawKeyboard() {
        let rect = Layout.keyboardRect
        let board = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        fillStroke(board, fill: propFill, stroke: propInk, width: 4)

        NSColor(calibratedWhite: 0.55, alpha: 0.9).setStroke()
        for i in 1..<8 {
            let x = rect.minX + CGFloat(i) * (rect.width / 8)
            let line = NSBezierPath()
            line.move(to: CGPoint(x: x, y: rect.minY + 5))
            line.line(to: CGPoint(x: x, y: rect.maxY - 5))
            line.lineWidth = 2
            line.stroke()
        }
    }

    // MARK: - 마우스

    /// 앞에서 본 마우스. 캐릭터가 우리를 마주보고 있으니 마우스도 앞쪽이 우리 쪽을 향한다.
    /// 몸통 뒷부분은 어차피 손등에 가려 보이지 않으므로, 실제로 보이는
    /// **버튼 앞면과 그 사이로 튀어나온 휠**만 그린다.
    func drawMouse(at c: CGPoint, shownButtons: Set<Int>, wheelPhase: CGFloat) {
        let face = NSBezierPath(roundedRect: NSRect(x: c.x - 23, y: c.y - 12,
                                                    width: 46, height: 24),
                                xRadius: 11, yRadius: 11)

        propFill.setFill()
        face.fill()

        // 눌린 버튼 음영
        NSGraphicsContext.saveGraphicsState()
        face.addClip()
        NSColor(calibratedWhite: 0.68, alpha: 1.0).setFill()
        if shownButtons.contains(0) {
            NSRect(x: c.x - 24, y: c.y - 13, width: 24, height: 26).fill()
        }
        if shownButtons.contains(1) {
            NSRect(x: c.x, y: c.y - 13, width: 24, height: 26).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        propInk.setStroke()
        face.lineWidth = 3.5
        face.stroke()

        // 휠은 위로 살짝만 튀어나오고 아래로 길다. 두 버튼 사이를 가르는 역할도 하므로
        // 따로 홈 선을 긋지 않는다 (작은 크기에서는 선이 겹쳐 휠이 파묻힌다).
        drawScrollWheel(centeredAt: CGPoint(x: c.x, y: c.y + 4),
                        phase: wheelPhase,
                        pressed: shownButtons.contains(2))
    }

    /// 스크롤 휠. 눈금이 실제 스크롤 양·방향만큼 흘러간다.
    private func drawScrollWheel(centeredAt c: CGPoint, phase: CGFloat, pressed: Bool) {
        // 아래를 마우스 바닥까지 내리면 두 버튼이 완전히 갈라져 보인다. 여유를 둔다.
        let rect = NSRect(x: c.x - 5.5, y: c.y - 11, width: 11, height: 22)
        let wheel = NSBezierPath(roundedRect: rect, xRadius: 5.5, yRadius: 5.5)

        NSColor(calibratedWhite: pressed ? 0.60 : 0.82, alpha: 1.0).setFill()
        wheel.fill()

        NSGraphicsContext.saveGraphicsState()
        wheel.addClip()
        NSColor(calibratedWhite: 0.32, alpha: 1.0).setStroke()
        // 손가락에 덮이지 않는 아래쪽 구간에 눈금이 여러 개 들어가야
        // 굴러가는 게 보인다. 그래서 간격을 좁게 둔다.
        let spacing: CGFloat = 3
        var offset = phase.truncatingRemainder(dividingBy: spacing)
        if offset < 0 { offset += spacing }
        for i in -1...9 {
            let y = rect.minY + CGFloat(i) * spacing + offset
            let tick = NSBezierPath()
            tick.move(to: CGPoint(x: rect.minX + 1.4, y: y))
            tick.line(to: CGPoint(x: rect.maxX - 1.4, y: y))
            tick.lineWidth = 1.7
            tick.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()

        propInk.setStroke()
        wheel.lineWidth = 2.2
        wheel.stroke()
    }

    // MARK: - 팔과 손

    /// 어깨에서 손까지 이어지는 팔. 아래로 살짝 늘어지게 휘어 준다.
    /// size 는 손 크기 배율. 팔이 손보다 굵어 보이지 않도록 같이 가늘어진다.
    func drawLimb(from a: CGPoint, to b: CGPoint, size: CGFloat) {
        let sag = min(14, abs(b.x - a.x) * 0.18 + 4)
        let control = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 - sag)
        let taper = 0.72 + 0.28 * size

        let limb = NSBezierPath()
        limb.move(to: a)
        limb.curve(to: b, controlPoint1: control, controlPoint2: control)
        limb.lineCapStyle = .round

        palette.ink.setStroke()
        limb.lineWidth = 21 * taper
        limb.stroke()

        palette.limb.setStroke()
        limb.lineWidth = 14 * taper
        limb.stroke()
    }

    /// 손. 기본은 동그란 주먹이고, fingerOut 이 커지면 손가락 하나가 아래로 삐죽 나온다.
    ///
    /// - press: 1 에 가까울수록 납작하게 눌린다. 짧은 탭도 눈에 띄게 만드는 장치.
    /// - size: 손 크기 배율. 마우스 위에서는 작게 그려야 버튼이 가려지지 않는다.
    /// - fingerSide: -1 왼쪽 버튼, 0 휠, +1 오른쪽 버튼.
    /// - fingerOut: 0 이면 주먹, 1 이면 손가락을 다 뻗은 상태.
    func drawHand(at c: CGPoint, press: CGFloat, size: CGFloat,
                  fingerSide: CGFloat, fingerOut: CGFloat) {
        let w = (30 + press * 5) * size
        let h = (20 - press * 4) * size
        let fist = NSBezierPath(ovalIn: NSRect(x: c.x - w / 2, y: c.y - h / 2,
                                               width: w, height: h))

        let border = 4.5 * size
        // 손가락 외곽선은 손등보다 얇다. 두꺼우면 버튼과 휠을 덮어 버린다.
        let fingerBorder = 2.8 * size
        let fingerWidth = 11 * size

        // 손가락은 양끝이 둥근 캡슐이다. 뾰족하게 하면 못처럼 보인다.
        // 길이는 버튼이든 휠이든 같다. 좌우 구분은 어느 쪽으로 뻗는지로 충분하다.
        var finger: NSBezierPath?
        if fingerOut > 0.02 {
            let length = (6 + press * 2) * fingerOut
            let baseY = c.y - 1
            let path = NSBezierPath()
            path.move(to: CGPoint(x: c.x + fingerSide * 4 * fingerOut, y: baseY))
            path.line(to: CGPoint(x: c.x + fingerSide * 9 * fingerOut, y: baseY - length))
            path.lineCapStyle = .round
            finger = path
        }

        // 외곽선을 손등·손가락 한 덩어리로 먼저 깔고, 그 위를 채운다.
        // 순서를 반대로 하면 손등 외곽선이 손가락 밑동을 가로질러 선이 생긴다.
        palette.ink.setFill()
        palette.ink.setStroke()
        if let finger {
            finger.lineWidth = fingerWidth + fingerBorder * 2
            finger.stroke()
        }
        fist.fill()
        fist.lineWidth = border * 2
        fist.stroke()

        palette.limb.setFill()
        palette.limb.setStroke()
        fist.fill()
        if let finger {
            finger.lineWidth = fingerWidth
            finger.stroke()
        }

        // 주먹일 때만 발가락 선을 보여 준다.
        let toeAlpha = 1 - min(1, fingerOut * 2)
        guard toeAlpha > 0.02 else { return }
        palette.limbLine.withAlphaComponent(toeAlpha).setStroke()
        for dx in [CGFloat(-5), CGFloat(5)] {
            let toe = NSBezierPath()
            toe.move(to: CGPoint(x: c.x + dx * size, y: c.y - 7 * size))
            toe.line(to: CGPoint(x: c.x + dx * size, y: c.y - 1 * size))
            toe.lineWidth = 3 * size
            toe.lineCapStyle = .round
            toe.stroke()
        }
    }
}
