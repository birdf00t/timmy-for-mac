import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var window: OverlayWindow!
    private var mascotView: MascotView!
    private let monitor = InputMonitor()
    private var statusItem: NSStatusItem!
    private var permissionPoll: Timer?

    /// 모든 화면을 합친 사각형. 커서 위치를 0...1 로 정규화하는 데 쓴다.
    private var screenUnion: CGRect = .zero

    /// 커서가 실제로 움직였는지 판단하기 위한 직전 위치.
    private var lastCursorPoint: CGPoint?

    private enum Key {
        static let originX = "originX"
        static let originY = "originY"
        static let scale = "scale"
        static let locked = "locked"
    }

    private var scale: CGFloat {
        let saved = UserDefaults.standard.double(forKey: Key.scale)
        return saved > 0 ? CGFloat(saved) : 1.0
    }

    // MARK: - 수명 주기

    func applicationDidFinishLaunching(_ notification: Notification) {
        recomputeScreenUnion()
        buildWindow()
        buildStatusItem()
        wireMonitor()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowMoved),
            name: NSWindow.didMoveNotification, object: window)

        requestAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: - 창

    private func buildWindow() {
        mascotView = MascotView()

        let size = NSSize(width: Layout.canvas.width * scale,
                          height: Layout.canvas.height * scale)
        window = OverlayWindow(contentRect: NSRect(origin: defaultOrigin(for: size), size: size))
        window.contentView = mascotView

        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.originX) != nil {
            let origin = NSPoint(x: defaults.double(forKey: Key.originX),
                                 y: defaults.double(forKey: Key.originY))
            if screenUnion.insetBy(dx: -size.width, dy: -size.height).contains(origin) {
                window.setFrameOrigin(origin)
            }
        }

        window.isLocked = defaults.object(forKey: Key.locked) == nil
            ? true
            : defaults.bool(forKey: Key.locked)

        window.orderFrontRegardless()
    }

    private func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return NSPoint(x: 100, y: 100) }
        let visible = screen.visibleFrame
        return NSPoint(x: visible.maxX - size.width - 24, y: visible.minY + 24)
    }

    private func applyScale(_ newScale: CGFloat) {
        UserDefaults.standard.set(Double(newScale), forKey: Key.scale)
        let size = NSSize(width: Layout.canvas.width * newScale,
                          height: Layout.canvas.height * newScale)
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true)
        mascotView.needsDisplay = true
    }

    @objc private func windowMoved() {
        UserDefaults.standard.set(Double(window.frame.origin.x), forKey: Key.originX)
        UserDefaults.standard.set(Double(window.frame.origin.y), forKey: Key.originY)
    }

    @objc private func screensChanged() {
        recomputeScreenUnion()
    }

    private func recomputeScreenUnion() {
        var union = CGRect.null
        for screen in NSScreen.screens { union = union.union(screen.frame) }
        screenUnion = union.isNull ? .zero : union
    }

    // MARK: - 입력 연결

    private func wireMonitor() {
        monitor.onHandChanged = { [weak self] left, right in
            self?.mascotView.leftKeyDown = left
            self?.mascotView.rightKeyDown = right
        }
        monitor.onMouseButtons = { [weak self] buttons in
            self?.mascotView.mouseButtons = buttons
        }
        monitor.onCursorMoved = { [weak self] point in
            guard let self, self.screenUnion.width > 0, self.screenUnion.height > 0 else { return }

            // 커서가 의미 있게 움직였으면 손을 마우스로 돌려보낸다.
            // 문턱을 두는 건 손을 얹어둔 트랙패드가 미세하게 흐르는 걸 걸러내기 위한 것이다.
            if let last = self.lastCursorPoint,
               hypot(point.x - last.x, point.y - last.y) > 4 {
                self.mascotView.cursorMoved()
            }
            self.lastCursorPoint = point

            self.mascotView.cursorNorm = CGPoint(
                x: min(max((point.x - self.screenUnion.minX) / self.screenUnion.width, 0), 1),
                y: min(max((point.y - self.screenUnion.minY) / self.screenUnion.height, 0), 1))

            // 창이 클릭을 통과시키므로 마우스 진입 이벤트를 받을 수 없다.
            // 대신 이미 추적 중인 커서 좌표가 창 안에 있는지로 판단한다.
            // 캐릭터는 창을 꽉 채우지 않으므로 가장자리를 조금 깎아 준다.
            let hot = self.window.frame.insetBy(dx: self.window.frame.width * 0.08,
                                                dy: self.window.frame.height * 0.06)
            self.mascotView.cursorOverlaps = hot.contains(point)
        }
        monitor.onScroll = { [weak self] delta in
            self?.mascotView.scrolled(by: delta)
        }
    }

    // MARK: - 손쉬운 사용 권한

    private func requestAccessibilityIfNeeded() {
        if AXIsProcessTrusted() {
            monitor.start()
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한이 필요해요"
        alert.informativeText = """
        Timmy 가 키보드와 마우스에 반응하려면 macOS 의 '손쉬운 사용' 권한이 필요합니다.

        시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용 에서
        Timmy 를 켜주세요. 켜는 즉시 자동으로 동작을 시작합니다.

        입력 내용은 기록되지 않으며, 왼손/오른손 판정에만 사용됩니다.
        """
        alert.addButton(withTitle: "설정 열기")
        alert.addButton(withTitle: "나중에")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        startPermissionPoll()
    }

    /// 권한을 켜자마자 재시작 없이 동작하도록 조용히 기다린다.
    private func startPermissionPoll() {
        guard permissionPoll == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] t in
            guard let self else { return }
            guard AXIsProcessTrusted() else { return }
            t.invalidate()
            self.permissionPoll = nil
            self.monitor.start()
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionPoll = timer
    }

    // MARK: - 메뉴바

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Self.makeStatusIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// 메뉴바용 양 머리 아이콘. 템플릿 이미지라 단색으로 그리고, 눈은 파내서 뚫는다.
    /// (SF Symbols 에 양이 없어서 직접 그린다.)
    private static func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()

            // 귀 — 머리보다 먼저 채워서 겹치는 부분이 자연스럽게 이어지게 한다.
            NSBezierPath(ovalIn: NSRect(x: 0, y: 8, width: 8, height: 3.2)).fill()
            NSBezierPath(ovalIn: NSRect(x: 11, y: 8, width: 8, height: 3.2)).fill()

            // 머리
            NSBezierPath(roundedRect: NSRect(x: 4, y: 1.5, width: 11, height: 12.5),
                         xRadius: 5.2, yRadius: 5.2).fill()

            // 눈 구멍
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: NSRect(x: 5.9, y: 7.4, width: 3.2, height: 3.8)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9.9, y: 7.4, width: 3.2, height: 3.8)).fill()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Timmy"
        return image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(
            title: monitor.isRunning ? "동작 중" : "손쉬운 사용 권한 대기 중…",
            action: monitor.isRunning ? nil : #selector(openAccessibilitySettings),
            keyEquivalent: "")
        status.target = self
        status.isEnabled = !monitor.isRunning
        menu.addItem(status)
        menu.addItem(.separator())

        let lock = NSMenuItem(title: "위치 고정", action: #selector(toggleLock), keyEquivalent: "")
        lock.target = self
        lock.state = window.isLocked ? .on : .off
        menu.addItem(lock)

        let sizeItem = NSMenuItem(title: "크기", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for value in [0.6, 0.75, 1.0, 1.25, 1.5] {
            let item = NSMenuItem(title: "\(Int(value * 100))%",
                                  action: #selector(changeScale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(Double(scale) - value) < 0.001 ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let reset = NSMenuItem(title: "위치 초기화", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleLock() {
        window.isLocked.toggle()
        UserDefaults.standard.set(window.isLocked, forKey: Key.locked)
    }

    @objc private func changeScale(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        applyScale(CGFloat(value))
    }

    @objc private func resetPosition() {
        window.setFrameOrigin(defaultOrigin(for: window.frame.size))
        windowMoved()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
