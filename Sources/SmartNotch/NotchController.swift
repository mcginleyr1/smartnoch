import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class NotchController {
    private let model: AppModel
    private let panel: NotchPanel
    private var pendingCollapse: DispatchWorkItem?

    init(model: AppModel) {
        self.model = model
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: NotchView().environment(model))

        place()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.place()
        }
        let mouseEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] _ in self?.trackMouse() }
        NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            self?.trackMouse()
            return event
        }
    }

    private var screen: NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens[0]
    }

    private func place() {
        let screen = screen
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, screen.safeAreaInsets.top > 0 {
            model.notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            model.notchSize = CGSize(width: 180, height: max(24, screen.frame.maxY - screen.visibleFrame.maxY))
        }
        let size = AppModel.expandedSize
        panel.setFrame(NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height), display: true)
    }

    private func trackMouse() {
        let size = model.currentSize
        let frame = screen.frame
        let hotZone = NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height, width: size.width, height: size.height)
            .insetBy(dx: -4, dy: -4)

        if hotZone.contains(NSEvent.mouseLocation) {
            pendingCollapse?.cancel()
            pendingCollapse = nil
            model.expanded = true
        } else if model.expanded, pendingCollapse == nil {
            let collapse = DispatchWorkItem { [weak self] in
                self?.model.expanded = false
                self?.pendingCollapse = nil
            }
            pendingCollapse = collapse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: collapse)
        }
    }
}
