import AppKit

/// 입력 상태를 애니메이션 값으로 바꾸고, 실제 그리기는 `Mascot` 과 `Stage` 에 맡긴다.
///
/// 애니메이션은 "목표값을 향해 매 프레임 조금씩 다가가는" 방식이다.
/// 모든 값이 목표에 도달하면 타이머를 완전히 정지시킨다. → 입력이 없으면 CPU 0%.
final class MascotView: NSView {

    // MARK: - 외부에서 넣어주는 목표 상태

    var leftKeyDown = false {
        didSet {
            guard leftKeyDown != oldValue else { return }
            if leftKeyDown { leftHoldUntil = CACurrentMediaTime() + minPressDuration }
            kick()
        }
    }

    var rightKeyDown = false {
        didSet {
            guard rightKeyDown != oldValue else { return }
            if rightKeyDown {
                let now = CACurrentMediaTime()
                rightHoldUntil = now + minPressDuration
                lastRightKeyTime = now
                mouseTookOver = false
            }
            kick()
        }
    }

    /// 트랙패드 탭투클릭은 눌림이 50~80ms 밖에 안 되므로, 그림에서는 최소 시간만큼 붙잡아 둔다.
    var mouseButtons = Set<Int>() {
        didSet {
            guard mouseButtons != oldValue else { return }
            if !mouseButtons.isEmpty {
                shownButtons = mouseButtons
                mouseHoldUntil = CACurrentMediaTime() + minPressDuration
                leaveKeyboard()
            }
            kick()
        }
    }

    /// 커서의 화면 내 상대 위치 (0...1, 좌하단 원점).
    var cursorNorm = CGPoint(x: 0.5, y: 0.5) { didSet { kick() } }

    /// 커서가 캐릭터 위에 겹쳐 있으면 흐려진다. 클릭은 통과하지만 시야는 가리기 때문이다.
    var cursorOverlaps = false {
        didSet { if cursorOverlaps != oldValue { kick() } }
    }

    /// 스크롤은 누름/뗌이 없으므로 짧게 눌렀다 떼는 동작으로 흉내낸다.
    /// 휠은 속도를 받아 관성으로 굴러간다. 이벤트가 올 때만 움직이면
    /// 휠 마우스처럼 이벤트가 드문 입력에서는 눈금이 툭툭 끊긴다.
    func scrolled(by delta: Double) {
        wheelVelocity += CGFloat(delta) * 0.35
        wheelVelocity = max(-7, min(7, wheelVelocity))
        scrollNudgeUntil = CACurrentMediaTime() + minPressDuration
        leaveKeyboard()
        kick()
    }

    /// 커서가 실제로 움직였을 때 호출된다. 손이 마우스로 돌아온다.
    /// 키를 누르고 있는 중이어도 마우스가 이긴다 —
    /// 손 없이 마우스만 혼자 미끄러지는 그림이 더 이상하기 때문이다.
    /// 다음 오른손 키를 치면 다시 키보드로 돌아온다.
    func cursorMoved() {
        leaveKeyboard()
        mouseTookOver = true
        kick()
    }

    /// 마우스를 쓰기 시작하면 키보드에 머무는 여운을 즉시 끊는다.
    private func leaveKeyboard() {
        lastRightKeyTime = -10
        rightHoldUntil = 0
    }

    // MARK: - 보간되는 실제 상태

    private let mascot: Mascot = SheepMascot()

    /// 키를 누르고 있는 동안 1. 손을 내려친 자리에 붙잡아 두고 납작하게 눌러 준다.
    private var leftHold: CGFloat = 0
    private var rightHold: CGFloat = 0

    private var rightBias: CGFloat = 0       // 0 = 마우스 위, 1 = 키보드 위
    private var mousePress: CGFloat = 0      // 마우스 버튼 눌림 정도
    private var fingerSide: CGFloat = -1     // -1 왼쪽 버튼, 0 휠, +1 오른쪽 버튼
    private var fingerOut: CGFloat = 0       // 0 주먹, 1 손가락 뻗음
    private var wheelPhase: CGFloat = 0      // 휠 눈금 누적 회전량
    private var wheelVelocity: CGFloat = 0   // 휠이 굴러가는 속도 (관성)
    private var hoverFade: CGFloat = 0       // 0 = 선명, 1 = 흐림

    /// 커서가 겹쳤을 때 남기는 불투명도. 완전히 숨기면 어디 있었는지 알 수 없다.
    private static let hoverAlpha: CGFloat = 0.15
    private var padPos = CGPoint(x: 0.5, y: 0.5)

    /// 마지막으로 오른손 키를 친 시각. 오른손이 키보드에 머무는 기준이 된다.
    private var lastRightKeyTime: CFTimeInterval = -10

    /// 커서가 움직여서 손이 마우스로 넘어간 상태. 다음 오른손 키에서 풀린다.
    private var mouseTookOver = false
    private var scrollNudgeUntil: CFTimeInterval = 0
    private var ticker: Timer?

    /// 아주 짧은 입력도 눈에 보이도록 붙잡아 두는 최소 시간.
    /// 트랙패드 탭투클릭은 눌림이 50~80ms 밖에 안 되므로 이게 없으면 그림에 나타나지 않는다.
    private let minPressDuration: CFTimeInterval = 0.12

    private var leftHoldUntil: CFTimeInterval = 0
    private var rightHoldUntil: CFTimeInterval = 0
    private var mouseHoldUntil: CFTimeInterval = 0

    /// 그림에 표시할 마우스 버튼. 실제 눌림이 끝난 뒤에도 최소 시간까지 유지된다.
    private var shownButtons = Set<Int>()

    /// 마지막 타이핑 후 오른손이 키보드 위에 머무는 시간.
    /// 이 시간이 지나거나, 그전에 마우스를 쓰면 마우스로 돌아간다.
    private let keyboardLinger: CFTimeInterval = 1.0

    // MARK: - 초기화

    init() {
        super.init(frame: NSRect(origin: .zero, size: Layout.canvas))
        wantsLayer = true
        layer?.isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 애니메이션 구동

    /// 상태가 바뀌었을 때만 타이머를 깨운다.
    private func kick() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func sleepTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func step() {
        let now = CACurrentMediaTime()
        let lingering = now - lastRightKeyTime < keyboardLinger
        // 휠이 아직 충분히 돌고 있으면 스크롤 중인 것으로 본다. 손가락이 휠에 머문다.
        let spinning = abs(wheelVelocity) > 0.15
        let scrolling = now < scrollNudgeUntil || spinning

        // 실제 눌림이 이미 끝났어도 최소 시간 동안은 눌린 것으로 취급한다.
        let holdingLeft = leftKeyDown || now < leftHoldUntil
        let holdingRight = rightKeyDown || now < rightHoldUntil
        let holdingMouse = !mouseButtons.isEmpty || now < mouseHoldUntil
        let anyHold = holdingLeft || holdingRight || holdingMouse

        if !holdingMouse && !shownButtons.isEmpty { shownButtons.removeAll() }

        // 오른손이 키보드에 머무는 조건은 오른손 키 기준이다.
        // 왼손만 치고 있으면 오른손은 할 일이 없으므로 마우스로 돌아간다.
        // 커서가 움직였으면 키를 누르고 있어도 마우스가 이긴다.
        let wantsKeyboard = (holdingRight && !mouseTookOver) || lingering
        let pressing = holdingMouse || scrolling

        // 어느 손가락을 뻗을지. 아무것도 안 누르면 마지막 손가락 자리에서 그대로 접힌다.
        var sideTarget = fingerSide
        if scrolling || shownButtons.contains(2) {
            sideTarget = 0
        } else if shownButtons.contains(0) {
            sideTarget = -1
        } else if shownButtons.contains(1) {
            sideTarget = 1
        }

        var moving = false

        // 휠 관성. 스크롤이 멈추면 서서히 느려지다가 선다.
        if wheelVelocity != 0 {
            wheelPhase += wheelVelocity
            wheelVelocity *= 0.88
            if abs(wheelVelocity) < 0.02 { wheelVelocity = 0 }
            moving = true
        }

        moving = approach(&fingerSide, sideTarget, 0.40) || moving
        moving = approach(&fingerOut, pressing ? 1 : 0, 0.45) || moving

        moving = approach(&leftHold, holdingLeft ? 1 : 0, 0.55) || moving
        moving = approach(&rightHold, holdingRight ? 1 : 0, 0.55) || moving
        moving = approach(&rightBias, wantsKeyboard ? 1 : 0, 0.20) || moving
        moving = approach(&mousePress, pressing ? 1 : 0, 0.60) || moving

        moving = approach(&padPos.x, cursorNorm.x, 0.30) || moving
        moving = approach(&padPos.y, cursorNorm.y, 0.30) || moving

        // 흐려지는 건 그림 내용과 무관하므로 다시 그리지 않고 레이어 투명도만 바꾼다.
        if approach(&hoverFade, cursorOverlaps ? 1 : 0, 0.20) {
            alphaValue = lerp(1, Self.hoverAlpha, hoverFade)
            moving = true
        }

        if moving { needsDisplay = true }

        // 붙잡아 둔 시간이나 여운이 남아 있으면 계속 돌려야 한다.
        if !moving && !lingering && !scrolling && !anyHold {
            sleepTicker()
        }
    }

    @discardableResult
    private func approach(_ value: inout CGFloat, _ target: CGFloat, _ rate: CGFloat) -> Bool {
        let delta = target - value
        if abs(delta) < 0.0015 {
            if value != target { value = target; return true }
            return false
        }
        value += delta * rate
        return true
    }

    // MARK: - 그리기

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let scale = bounds.width / Layout.canvas.width

        ctx.saveGState()
        ctx.scaleBy(x: scale, y: scale)
        drawScene(in: ctx)
        ctx.restoreGState()
    }

    private func drawScene(in ctx: CGContext) {
        let stage = Stage(palette: mascot.palette)

        // 몸통 아랫부분이 반투명 책상 너머로 비치지 않도록 잘라낸다.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: Layout.deskTop,
                                  width: Layout.canvas.width,
                                  height: Layout.canvas.height - Layout.deskTop)).addClip()
        mascot.drawUpperBody(in: ctx)
        NSGraphicsContext.restoreGraphicsState()

        stage.drawDesk()
        stage.drawKeyboard()

        let mouseCenter = Layout.mouseCenter(forCursor: padPos)
        stage.drawMouse(at: mouseCenter, shownButtons: shownButtons, wheelPhase: wheelPhase)

        // 왼손: 평소 자판 위에 떠 있고, 칠 때 내려치면서 납작하게 눌린다.
        // 누르고 있는 동안은 내려친 자리에 그대로 머문다.
        let leftHand = CGPoint(x: Layout.leftPawX,
                               y: lerp(Layout.pawIdleY, Layout.pawStrikeY, leftHold))
        stage.drawLimb(from: mascot.leftShoulder, to: leftHand, size: 1)
        stage.drawHand(at: leftHand, press: leftHold, size: 1,
                       fingerSide: 0, fingerOut: 0)

        // 오른손: 마우스 등 위와 키보드 사이를 오간다.
        // 손은 늘 마우스에 닿아 있어야 한다. 들어올리면 사이에 빈 공간이 보인다.
        let onMouse = CGPoint(x: mouseCenter.x, y: mouseCenter.y + 16 - mousePress * 2)
        let onKeyboard = CGPoint(x: Layout.rightPawX,
                                 y: lerp(Layout.pawIdleY, Layout.pawStrikeY, rightHold))
        let rightHand = CGPoint(x: lerp(onMouse.x, onKeyboard.x, rightBias),
                                y: lerp(onMouse.y, onKeyboard.y, rightBias))
        let rightSize = lerp(0.80, 1.0, rightBias)
        stage.drawLimb(from: mascot.rightShoulder, to: rightHand, size: rightSize)
        // 마우스 위에서는 클릭 눌림, 키보드 위에서는 내려친 정도가 눌림이 된다.
        stage.drawHand(at: rightHand,
                       press: lerp(mousePress, rightHold, rightBias),
                       size: rightSize,
                       fingerSide: fingerSide,
                       fingerOut: fingerOut * (1 - rightBias))
    }
}
