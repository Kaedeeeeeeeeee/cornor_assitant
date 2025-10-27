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
    private var hotCorner: HotCorner

    init(hotCorner: HotCorner) {
        self.hotCorner = hotCorner
        hostingController = NSHostingController(rootView: SlidePanelView(state: panelState))
        window = SlidePanelController.makeWindow(hostingController: hostingController)
    }

    func start() {
        prepareInitialFrame()
        installEventMonitors()
    }

    func stop() {
        removeMonitors()
    }

    func expandPanel() {
        guard let screen = targetScreen ?? NSScreen.main else { return }
        expand(on: screen)
    }

    func collapsePanel() {
        collapse()
    }

    func togglePanel() {
        if isExpanded {
            collapse()
        } else if let screen = targetScreen ?? NSScreen.main {
            expand(on: screen)
        }
    }

    func updateHotCorner(_ corner: HotCorner) {
        guard hotCorner != corner else { return }
        hotCorner = corner

        guard let screen = targetScreen ?? NSScreen.main else { return }
        let frame = concealedFrame(for: screen)
        window.setFrame(frame, display: false)
        if isExpanded {
            expand(on: screen)
        }
    }
}

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
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseMove()
            }
        }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleMouseDown()
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

    func handleMouseMove() {
        guard !isExpanded else { return }

        let location = NSEvent.mouseLocation
        guard let screen = screen(containing: location) else { return }
        targetScreen = screen

        if hotspotRect(for: screen).contains(location) {
            expand(on: screen)
        }
    }

    func handleMouseDown() {
        guard isExpanded else { return }
        let location = NSEvent.mouseLocation

        if !window.frame.contains(location) {
            collapse()
        }
    }

    func expand(on screen: NSScreen) {
        targetScreen = screen
        let visibleFrame = shownFrame(for: screen)

        if isExpanded {
            window.setFrame(visibleFrame, display: true, animate: true)
            return
        }

        isExpanded = true
        let hiddenFrame = concealedFrame(for: screen)

        window.setFrame(hiddenFrame, display: false)
        window.alphaValue = 1
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hostingController.view)
        NSApp.activate(ignoringOtherApps: true)
        panelState.requestAddressFocus()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(visibleFrame, display: true)
        }, completionHandler: {
            self.window.setFrame(visibleFrame, display: false)
        })
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false

        guard let screen = targetScreen ?? window.screen ?? NSScreen.main else {
            window.orderOut(nil)
            return
        }

        let destination = concealedFrame(for: screen)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Constants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(destination, display: true)
        }, completionHandler: {
            self.window.setFrame(destination, display: false)
            self.window.orderOut(nil)
        })
    }

    func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })
    }

    func hotspotRect(for screen: NSScreen) -> CGRect {
        switch hotCorner {
        case .bottomLeft:
            return CGRect(
                x: screen.frame.minX,
                y: screen.frame.minY,
                width: Constants.hotspotWidth,
                height: Constants.hotspotHeight
            )
        case .bottomRight:
            return CGRect(
                x: screen.frame.maxX - Constants.hotspotWidth,
                y: screen.frame.minY,
                width: Constants.hotspotWidth,
                height: Constants.hotspotHeight
            )
        case .topLeft:
            return CGRect(
                x: screen.frame.minX,
                y: screen.frame.maxY - Constants.hotspotHeight,
                width: Constants.hotspotWidth,
                height: Constants.hotspotHeight
            )
        case .topRight:
            return CGRect(
                x: screen.frame.maxX - Constants.hotspotWidth,
                y: screen.frame.maxY - Constants.hotspotHeight,
                width: Constants.hotspotWidth,
                height: Constants.hotspotHeight
            )
        }
    }

    func shownFrame(for screen: NSScreen) -> CGRect {
        let availableHeight = screen.visibleFrame.height - (Constants.verticalMargin * 2)
        let height = min(Constants.windowHeight, availableHeight)
        let width = Constants.windowWidth

        let x: CGFloat
        let y: CGFloat

        switch hotCorner {
        case .bottomLeft:
            x = screen.visibleFrame.minX + Constants.horizontalMargin
            y = screen.visibleFrame.minY + Constants.verticalMargin
        case .bottomRight:
            x = screen.visibleFrame.maxX - width - Constants.horizontalMargin
            y = screen.visibleFrame.minY + Constants.verticalMargin
        case .topLeft:
            x = screen.visibleFrame.minX + Constants.horizontalMargin
            y = screen.visibleFrame.maxY - height - Constants.verticalMargin
        case .topRight:
            x = screen.visibleFrame.maxX - width - Constants.horizontalMargin
            y = screen.visibleFrame.maxY - height - Constants.verticalMargin
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    func concealedFrame(for screen: NSScreen) -> CGRect {
        let shown = shownFrame(for: screen)
        let dx: CGFloat
        let dy: CGFloat

        switch hotCorner {
        case .bottomLeft:
            dx = -(shown.width + Constants.offscreenPadding)
            dy = -(shown.height + Constants.offscreenPadding)
        case .bottomRight:
            dx = shown.width + Constants.offscreenPadding
            dy = -(shown.height + Constants.offscreenPadding)
        case .topLeft:
            dx = -(shown.width + Constants.offscreenPadding)
            dy = shown.height + Constants.offscreenPadding
        case .topRight:
            dx = shown.width + Constants.offscreenPadding
            dy = shown.height + Constants.offscreenPadding
        }

        return shown.offsetBy(dx: dx, dy: dy)
    }
}
