import AppKit
import SwiftUI
import QuartzCore

@MainActor
final class SlidePanelController {
    private enum Constants {
        static let hotspotWidth: CGFloat = 12
        static let hotspotHeight: CGFloat = 140
        static let windowWidth: CGFloat = 528
        static let windowHeight: CGFloat = 750
        static let animationDuration: TimeInterval = 0.18
        static let horizontalMargin: CGFloat = 14
        static let verticalMargin: CGFloat = 10
        static let offscreenPadding: CGFloat = 12
    }

    private let window: NSWindow
    private let hostingController: NSHostingController<SlidePanelView>
    private let panelState = SlidePanelState()
    private var moveMonitor: Any?
    private var clickMonitor: Any?
    private var isExpanded = false
    private var targetScreen: NSScreen?
    private var hideWorkItem: DispatchWorkItem?

    init() {
        let hosting = NSHostingController(rootView: SlidePanelView(state: panelState))
        hostingController = hosting
        window = SlidePanelController.makeWindow(hostingController: hosting)
    }

    func start() {
        prepareInitialFrame()
        installEventMonitors()
    }

    func stop() {
        removeMonitors()
    }
}

// MARK: - Setup & Events

private extension SlidePanelController {
    static func makeWindow(hostingController: NSHostingController<SlidePanelView>) -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        window.hasShadow = true
        window.backgroundColor = .windowBackgroundColor
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false

        return window
    }

    func prepareInitialFrame() {
        guard let screen = NSScreen.main else { return }
        targetScreen = screen
        let hiddenFrame = concealedFrame(for: screen)
        window.setFrame(hiddenFrame, display: false)
        window.orderOut(nil)
    }

    func installEventMonitors() {
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseMove(event: event)
            }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMouseDown(event: event)
            }
        }
    }

    func removeMonitors() {
        if let moveMonitor {
            NSEvent.removeMonitor(moveMonitor)
            self.moveMonitor = nil
        }
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

// MARK: - Event handling

private extension SlidePanelController {
    func handleMouseMove(event: NSEvent) {
        guard !isExpanded else { return }

        let location = NSEvent.mouseLocation
        guard let screen = screen(containing: location) else { return }
        targetScreen = screen

        if hotspotRect(for: screen).contains(location) {
            expand(on: screen)
        }
    }

    func handleMouseDown(event: NSEvent) {
        guard isExpanded else { return }
        let location = NSEvent.mouseLocation

        if !window.frame.contains(location) {
            collapse()
        }
    }
}

// MARK: - Window transitions

private extension SlidePanelController {
    func expand(on screen: NSScreen) {
        guard !isExpanded else { return }
        isExpanded = true

        hideWorkItem?.cancel()
        hideWorkItem = nil

        let visibleFrame = shownFrame(for: screen)
        let hiddenFrame = concealedFrame(for: screen)

        window.setFrame(hiddenFrame, display: false)
        window.alphaValue = 1
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hostingController.view)
        NSApp.activate(ignoringOtherApps: true)
        panelState.requestAddressFocus()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(visibleFrame, display: true)
        }
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false

        guard let screen = targetScreen ?? window.screen ?? NSScreen.main else {
            window.orderOut(nil)
            return
        }

        let destination = concealedFrame(for: screen)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(destination, display: true)
        }

        let workItem = DispatchWorkItem { [weak window] in
            if let window, !window.isKeyWindow {
                window.orderOut(nil)
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDuration, execute: workItem)
    }
}

// MARK: - Geometry helpers

private extension SlidePanelController {
    func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
    }

    func hotspotRect(for screen: NSScreen) -> CGRect {
        CGRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: Constants.hotspotWidth,
            height: Constants.hotspotHeight
        )
    }

    func shownFrame(for screen: NSScreen) -> CGRect {
        let availableHeight = screen.visibleFrame.height - (Constants.verticalMargin * 2)
        let height = min(Constants.windowHeight, availableHeight)
        return CGRect(
            x: screen.visibleFrame.minX + Constants.horizontalMargin,
            y: screen.visibleFrame.minY + Constants.verticalMargin,
            width: Constants.windowWidth,
            height: height
        )
    }

    func concealedFrame(for screen: NSScreen) -> CGRect {
        let shown = shownFrame(for: screen)
        return shown.offsetBy(
            dx: -(shown.width + Constants.offscreenPadding),
            dy: -(shown.height + Constants.offscreenPadding)
        )
    }
}
