import AppKit

// Dock 아이콘 없이 메뉴바에만 존재하는 accessory 앱으로 실행한다.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
