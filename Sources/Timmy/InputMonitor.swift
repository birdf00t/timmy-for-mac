import AppKit
import CoreGraphics

/// 어느 쪽 손이 움직였는지.
enum Hand {
    case left
    case right
}

/// 전역 키보드/마우스 입력을 감지한다.
///
/// 개인정보에 대하여: 이벤트 탭은 `.listenOnly` 로 열리므로 입력을 가로채거나
/// 변형하지 않는다. 키 코드는 "왼손이냐 오른손이냐" 를 판정하는 데에만 쓰이고
/// 즉시 버려진다. 어떤 글자를 눌렀는지는 저장하지도, 어디로 보내지도 않는다.
/// 이 파일 어디에도 파일 쓰기나 네트워크 호출은 없다.
final class InputMonitor {

    var onHandChanged: ((Bool, Bool) -> Void)?          // (왼손 눌림, 오른손 눌림)
    var onMouseButtons: ((Set<Int>) -> Void)?           // 현재 눌려 있는 버튼 번호들
    var onCursorMoved: ((CGPoint) -> Void)?             // 화면 전역 좌표 (좌하단 원점)
    var onScroll: ((Double) -> Void)?                    // 세로 스크롤 양 (부호가 방향)

    /// 키를 하나 눌렀을 때. 타이핑 속도를 재는 데 쓴다.
    /// 손 판정과 따로 두는 이유 — 앞 키를 떼기 전에 다음 키를 누르면
    /// "왼손 눌림" 같은 상태값은 안 바뀌어서 빠른 타이핑을 놓친다.
    var onKeystroke: (() -> Void)?

    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// 현재 물리적으로 눌려 있는 키 코드. keyUp 누락으로 발이 붙박이는 걸 막는 용도.
    /// 현재 눌려 있는 키 코드와 눌린 시각.
    private var pressedKeys: [Int64: CFTimeInterval] = [:]
    private var mouseButtons = Set<Int>()
    private var lastMoveForward: CFTimeInterval = 0

    /// 이만큼 오래 눌려 있으면 뗌 신호를 놓친 것으로 보고 버린다.
    /// 사람이 1분 내내 키를 누르고 있는 경우는 없다고 본다.
    private let stuckKeyTimeout: CFTimeInterval = 60

    /// 왼손이 담당하는 키 (물리적 위치 기준, ANSI 배열).
    private static let leftHandKeys: Set<Int64> = [
        53, 50, 18, 19, 20, 21, 23,     // esc  `  1 2 3 4 5
        48, 12, 13, 14, 15, 17,         // tab  Q W E R T
        57, 0, 1, 2, 3, 5,              // caps A S D F G
        56, 6, 7, 8, 9, 11,             // lshift Z X C V B
        59, 58, 55,                     // lctrl lopt lcmd
    ]

    /// 스페이스바는 양손이 번갈아 치는 것으로 표현한다.
    private static let spaceKey: Int64 = 49
    private var spaceGoesLeft = true

    // MARK: - 시작 / 정지

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        tap = nil
        isRunning = false
        pressedKeys.removeAll()
        mouseButtons.removeAll()
        onHandChanged?(false, false)
        onMouseButtons?([])
    }

    // MARK: - 이벤트 처리

    private func handle(type: CGEventType, event: CGEvent) {
        pruneStuckKeys()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS 가 탭을 꺼버리는 경우가 있다. 다시 켠다.
            // 꺼져 있던 동안의 이벤트는 잃어버렸으므로 — 뗌 신호도 놓쳤을 수 있다 —
            // 눌림 상태를 비운다. 키가 눌린 채로 굳는 건 이때 생긴다.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            if !pressedKeys.isEmpty {
                pressedKeys.removeAll()
                publishHands()
            }

        case .keyDown:
            // 키 반복(auto-repeat)은 무시한다. 누르고 있는 동안 발이 내려가 있는 편이 자연스럽다.
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }
            onKeystroke?()
            keyChanged(event.getIntegerValueField(.keyboardEventKeycode), down: true)

        case .keyUp:
            keyChanged(event.getIntegerValueField(.keyboardEventKeycode), down: false)

        case .flagsChanged:
            // 수정자 키는 down/up 구분이 없으므로, 이미 눌린 상태였는지로 판정한다.
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            keyChanged(code, down: pressedKeys[code] == nil)

        case .leftMouseDown:
            mouseChanged(0, down: true)
        case .leftMouseUp:
            mouseChanged(0, down: false)
        case .rightMouseDown:
            mouseChanged(1, down: true)
        case .rightMouseUp:
            mouseChanged(1, down: false)
        case .otherMouseDown:
            mouseChanged(2, down: true)
        case .otherMouseUp:
            mouseChanged(2, down: false)

        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            forwardCursor()

        case .scrollWheel:
            // 트랙패드는 연속값(fixedPt)을, 휠 마우스는 단계값을 채워 준다.
            var delta = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
            if delta == 0 {
                delta = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            }
            guard delta != 0 else { return }
            onScroll?(delta)

        default:
            break
        }
    }

    private func keyChanged(_ code: Int64, down: Bool) {
        if down {
            guard pressedKeys[code] == nil else { return }
            pressedKeys[code] = CACurrentMediaTime()
        } else {
            guard pressedKeys.removeValue(forKey: code) != nil else { return }
        }

        if code == Self.spaceKey, down {
            spaceGoesLeft.toggle()
        }
        publishHands()
    }

    /// 다른 앱이 뗌 신호를 삼키면 키가 눌린 채로 남는다.
    /// 하드웨어 상태를 주기적으로 조회하는 방식은 실제로 누르고 있는 키를
    /// 눌려 있지 않다고 보고해서 손이 제멋대로 돌아가 버렸다.
    /// 그래서 폴링을 없애고, 이벤트가 올 때마다 너무 오래된 것만 버린다.
    private func pruneStuckKeys() {
        guard !pressedKeys.isEmpty else { return }
        let now = CACurrentMediaTime()
        let stale = pressedKeys.compactMap { now - $0.value > stuckKeyTimeout ? $0.key : nil }
        guard !stale.isEmpty else { return }
        for code in stale { pressedKeys.removeValue(forKey: code) }
        publishHands()
    }

    private func mouseChanged(_ button: Int, down: Bool) {
        if down { mouseButtons.insert(button) } else { mouseButtons.remove(button) }
        onMouseButtons?(mouseButtons)
        forwardCursor(force: true)
    }

    private func publishHands() {
        var left = false
        var right = false
        for code in pressedKeys.keys {
            if code == Self.spaceKey {
                if spaceGoesLeft { left = true } else { right = true }
            } else if Self.leftHandKeys.contains(code) {
                left = true
            } else {
                right = true
            }
        }
        onHandChanged?(left, right)
    }

    /// 고성능 마우스는 초당 1000회까지 이벤트를 쏜다. 화면은 어차피 60fps 이므로 솎아낸다.
    private func forwardCursor(force: Bool = false) {
        let now = CACurrentMediaTime()
        if !force && now - lastMoveForward < 1.0 / 90.0 { return }
        lastMoveForward = now
        onCursorMoved?(NSEvent.mouseLocation)
    }

}
