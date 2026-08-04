import AppKit

/// 테두리 없는 투명 창. 항상 위에 떠 있고, 기본적으로 클릭이 통과한다.
final class OverlayWindow: NSWindow {

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// 잠금 해제하면 드래그로 옮길 수 있고, 잠그면 다시 클릭이 통과한다.
    var isLocked: Bool = true {
        didSet {
            ignoresMouseEvents = isLocked
            isMovableByWindowBackground = !isLocked
        }
    }
}
