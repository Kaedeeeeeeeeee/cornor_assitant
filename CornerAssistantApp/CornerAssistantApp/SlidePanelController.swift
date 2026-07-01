import AppKit
import SwiftUI
import QuartzCore

// MARK: - Custom Window Class for Keyboard Events

/// 自定义窗口类，确保能够正确处理键盘事件和快捷键
final class KeyboardAwareWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 首先尝试让菜单系统处理快捷键
        if NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
            return true
        }
        
        // 然后尝试让响应链处理
        return super.performKeyEquivalent(with: event)
    }
}

private final class ResizeCursorOverlayView: NSView {
    var cursorRectProvider: (() -> [(CGRect, NSCursor)])?
    var resizeDirectionProvider: ((CGPoint) -> ResizeDirection)?

    override func resetCursorRects() {
        discardCursorRects()
        guard let provider = cursorRectProvider else { return }
        for (rect, cursor) in provider() where !rect.isEmpty {
            addCursorRect(rect, cursor: cursor)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let direction = resizeDirectionProvider?(point) ?? .none
        guard bounds.contains(point),
              direction != .none else {
            return nil
        }
        return self
    }

    override var acceptsFirstResponder: Bool {
        false
    }
}

// MARK: - Resize Direction

/// 拖拽调整方向
private enum ResizeDirection {
    case horizontal  // 水平方向（调整宽度）
    case vertical    // 垂直方向（调整高度）
    case diagonal    // 对角线方向（同时调整宽度和高度）
    case none
}

enum SlidePanelLayout {
    static let hotspotWidth: CGFloat = 12
    static let hotspotHeight: CGFloat = 140
    static let defaultWindowWidth: CGFloat = 528
    static let defaultWindowHeight: CGFloat = 750
    static let minWindowWidth: CGFloat = 576
    static let maxWindowWidth: CGFloat = 900
    static let minWindowHeight: CGFloat = 600
    static let maxWindowHeight: CGFloat = 1200
    static let animationDuration: TimeInterval = 0.18
    static let horizontalMargin: CGFloat = 14
    static let verticalMargin: CGFloat = 10
    static let offscreenPadding: CGFloat = 12
    static let widthUserDefaultsKey = "SlidePanelWindowWidth"
    static let heightUserDefaultsKey = "SlidePanelWindowHeight"
    static let resizeEdgeWidth: CGFloat = 20
    static let resizeEdgeWidthExit: CGFloat = 28

    static func savedWidth(from value: Double) -> CGFloat {
        guard value > 0 else { return defaultWindowWidth }
        return max(minWindowWidth, min(maxWindowWidth, CGFloat(value)))
    }

    static func savedHeight(from value: Double) -> CGFloat {
        guard value > 0 else { return defaultWindowHeight }
        return max(minWindowHeight, min(maxWindowHeight, CGFloat(value)))
    }

    static func maxAllowedHeight(visibleFrame: CGRect) -> CGFloat {
        min(maxWindowHeight, visibleFrame.height - (verticalMargin * 2))
    }

    static func hotspotRect(hotCorner: HotCorner, screenFrame: CGRect) -> CGRect {
        switch hotCorner {
        case .bottomLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: hotspotWidth,
                height: hotspotHeight
            )
        case .bottomRight:
            return CGRect(
                x: screenFrame.maxX - hotspotWidth,
                y: screenFrame.minY,
                width: hotspotWidth,
                height: hotspotHeight
            )
        case .topLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - hotspotHeight,
                width: hotspotWidth,
                height: hotspotHeight
            )
        case .topRight:
            return CGRect(
                x: screenFrame.maxX - hotspotWidth,
                y: screenFrame.maxY - hotspotHeight,
                width: hotspotWidth,
                height: hotspotHeight
            )
        }
    }

    static func shownFrame(
        hotCorner: HotCorner,
        visibleFrame: CGRect,
        windowWidth: CGFloat,
        windowHeight: CGFloat
    ) -> CGRect {
        let availableHeight = visibleFrame.height - (verticalMargin * 2)
        let height = min(windowHeight, availableHeight)
        let width = windowWidth

        let x: CGFloat
        let y: CGFloat

        switch hotCorner {
        case .bottomLeft:
            x = visibleFrame.minX + horizontalMargin
            y = visibleFrame.minY + verticalMargin
        case .bottomRight:
            x = visibleFrame.maxX - width - horizontalMargin
            y = visibleFrame.minY + verticalMargin
        case .topLeft:
            x = visibleFrame.minX + horizontalMargin
            y = visibleFrame.maxY - height - verticalMargin
        case .topRight:
            x = visibleFrame.maxX - width - horizontalMargin
            y = visibleFrame.maxY - height - verticalMargin
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func concealedFrame(hotCorner: HotCorner, shownFrame: CGRect) -> CGRect {
        let dx: CGFloat
        let dy: CGFloat

        switch hotCorner {
        case .bottomLeft:
            dx = -(shownFrame.width + offscreenPadding)
            dy = -(shownFrame.height + offscreenPadding)
        case .bottomRight:
            dx = shownFrame.width + offscreenPadding
            dy = -(shownFrame.height + offscreenPadding)
        case .topLeft:
            dx = -(shownFrame.width + offscreenPadding)
            dy = shownFrame.height + offscreenPadding
        case .topRight:
            dx = shownFrame.width + offscreenPadding
            dy = shownFrame.height + offscreenPadding
        }

        return shownFrame.offsetBy(dx: dx, dy: dy)
    }

    static func shouldCollapseOnGlobalMouseDown(
        isExpanded: Bool,
        isResizing: Bool,
        isPinned: Bool,
        windowFrame: CGRect,
        clickLocation: CGPoint
    ) -> Bool {
        guard isExpanded else { return false }
        guard !isResizing else { return false }
        guard !isPinned else { return false }
        return !windowFrame.contains(clickLocation)
    }
}

@MainActor
final class SlidePanelController {
    private let window: NSWindow
    private let hostingController: NSHostingController<AnyView>
    private let resizeCursorOverlay = ResizeCursorOverlayView()
    private let panelState = SlidePanelState()
    private var moveMonitor: Any?
    private var clickMonitor: Any?
    private var keyboardMonitor: Any?
    private var isExpanded = false
    private var targetScreen: NSScreen?
    private var hotCorner: HotCorner
    
    // 边缘拖拽相关
    private var localMouseMonitor: Any?
    private var isResizing = false
    private var hoveredResizeDirection: ResizeDirection = .none
    private var resizeDirection: ResizeDirection = .none
    private var resizeStartLocation: CGPoint = .zero
    private var resizeStartFrame: CGRect = .zero
    
    /// 当前窗口宽度（可动态调整）
    private var currentWindowWidth: CGFloat
    
    /// 当前窗口高度（可动态调整）
    private var currentWindowHeight: CGFloat

    init(hotCorner: HotCorner) {
        self.hotCorner = hotCorner
        self.currentWindowWidth = SlidePanelController.loadSavedWidth()
        self.currentWindowHeight = SlidePanelController.loadSavedHeight()
        let rootView: AnyView = AnyView(
            SlidePanelView(state: panelState)
                .environmentObject(LocalizationManager.shared)
        )
        hostingController = NSHostingController(rootView: rootView)
        window = SlidePanelController.makeWindow(
            hostingController: hostingController,
            resizeCursorOverlay: resizeCursorOverlay
        )
        configureResizeCursorOverlay()
    }
    
    private static func loadSavedWidth() -> CGFloat {
        let saved = UserDefaults.standard.double(forKey: SlidePanelLayout.widthUserDefaultsKey)
        return SlidePanelLayout.savedWidth(from: saved)
    }
    
    private static func loadSavedHeight() -> CGFloat {
        let saved = UserDefaults.standard.double(forKey: SlidePanelLayout.heightUserDefaultsKey)
        return SlidePanelLayout.savedHeight(from: saved)
    }
    
    private func saveCurrentSize() {
        UserDefaults.standard.set(currentWindowWidth, forKey: SlidePanelLayout.widthUserDefaultsKey)
        UserDefaults.standard.set(currentWindowHeight, forKey: SlidePanelLayout.heightUserDefaultsKey)
    }

    private func configureResizeCursorOverlay() {
        resizeCursorOverlay.cursorRectProvider = { [weak self] in
            guard let self = self else { return [] }
            return self.makeResizeCursorRects(in: self.resizeCursorOverlay.bounds)
        }
        resizeCursorOverlay.resizeDirectionProvider = { [weak self] point in
            guard let self = self else { return .none }
            return self.getResizeDirection(
                in: self.resizeCursorOverlay.bounds,
                at: point,
                edgeWidth: SlidePanelLayout.resizeEdgeWidthExit
            )
        }
    }
    
    /// 根据 HotCorner 判断水平拖拽应该在哪一边
    private func isHorizontalHandleOnRightEdge() -> Bool {
        switch hotCorner {
        case .topLeft, .bottomLeft:
            return true  // 窗口在左边，拖拽右边缘
        case .topRight, .bottomRight:
            return false // 窗口在右边，拖拽左边缘
        }
    }
    
    /// 根据 HotCorner 判断垂直拖拽应该在哪一边
    private func isVerticalHandleOnTopEdge() -> Bool {
        switch hotCorner {
        case .bottomLeft, .bottomRight:
            return true  // 窗口在下边，拖拽上边缘
        case .topLeft, .topRight:
            return false // 窗口在上边，拖拽下边缘
        }
    }
    
    /// 获取最大允许高度（考虑屏幕可用高度）
    private func getMaxAllowedHeight() -> CGFloat {
        guard let screen = targetScreen ?? NSScreen.main else {
            return SlidePanelLayout.maxWindowHeight
        }
        return SlidePanelLayout.maxAllowedHeight(visibleFrame: screen.visibleFrame)
    }
    
    /// 检查屏幕坐标是否在拖拽区域内，返回拖拽方向
    private func getResizeDirection(at screenPoint: CGPoint, edgeWidth: CGFloat) -> ResizeDirection {
        guard isExpanded else { return .none }
        
        let windowFrame = window.frame
        
        // 检查点是否在窗口内或边缘附近
        let expandedFrame = windowFrame.insetBy(dx: -5, dy: -5)
        guard expandedFrame.contains(screenPoint) else { return .none }

        return getResizeDirection(in: windowFrame, at: screenPoint, edgeWidth: edgeWidth)
    }

    private func getResizeDirection(in rect: CGRect, at point: CGPoint, edgeWidth: CGFloat) -> ResizeDirection {
        guard isExpanded else { return .none }

        for (direction, resizeRect) in makeResizeRegions(in: rect, edgeWidth: edgeWidth) where resizeRect.contains(point) {
            return direction
        }

        return .none
    }
    
    /// 获取角落拖拽区域（根据 HotCorner 决定是哪个角）
    private func getCornerResizeRect(for windowFrame: CGRect, size: CGFloat) -> CGRect {
        switch hotCorner {
        case .bottomLeft:
            // 窗口在左下角，可拖拽的角落在右上角
            return CGRect(
                x: windowFrame.maxX - size,
                y: windowFrame.maxY - size,
                width: size,
                height: size
            )
        case .bottomRight:
            // 窗口在右下角，可拖拽的角落在左上角
            return CGRect(
                x: windowFrame.minX,
                y: windowFrame.maxY - size,
                width: size,
                height: size
            )
        case .topLeft:
            // 窗口在左上角，可拖拽的角落在右下角
            return CGRect(
                x: windowFrame.maxX - size,
                y: windowFrame.minY,
                width: size,
                height: size
            )
        case .topRight:
            // 窗口在右上角，可拖拽的角落在左下角
            return CGRect(
                x: windowFrame.minX,
                y: windowFrame.minY,
                width: size,
                height: size
            )
        }
    }

    private func makeResizeCursorRects(in bounds: CGRect) -> [(CGRect, NSCursor)] {
        guard isExpanded else { return [] }

        let edgeWidth = SlidePanelLayout.resizeEdgeWidthExit
        return makeResizeRegions(in: bounds, edgeWidth: edgeWidth).map { region in
            (region.1, cursorForDirection(region.0))
        }
    }

    private func makeResizeRegions(in rect: CGRect, edgeWidth: CGFloat) -> [(ResizeDirection, CGRect)] {
        var regions: [(ResizeDirection, CGRect)] = []

        let cornerRect = getCornerResizeRect(for: rect, size: edgeWidth)
        regions.append((.diagonal, cornerRect))

        // 检查水平边缘（排除角落区域）
        let horizontalEdgeRect: CGRect
        if isHorizontalHandleOnRightEdge() {
            let yOffset = isVerticalHandleOnTopEdge() ? 0 : edgeWidth
            let heightReduction = edgeWidth
            horizontalEdgeRect = CGRect(
                x: rect.maxX - edgeWidth,
                y: rect.minY + yOffset,
                width: edgeWidth,
                height: rect.height - heightReduction
            )
        } else {
            let yOffset = isVerticalHandleOnTopEdge() ? 0 : edgeWidth
            let heightReduction = edgeWidth
            horizontalEdgeRect = CGRect(
                x: rect.minX,
                y: rect.minY + yOffset,
                width: edgeWidth,
                height: rect.height - heightReduction
            )
        }
        regions.append((.horizontal, horizontalEdgeRect))

        // 检查垂直边缘（排除角落区域）
        let verticalEdgeRect: CGRect
        if isVerticalHandleOnTopEdge() {
            let xOffset = isHorizontalHandleOnRightEdge() ? 0 : edgeWidth
            let widthReduction = edgeWidth
            verticalEdgeRect = CGRect(
                x: rect.minX + xOffset,
                y: rect.maxY - edgeWidth,
                width: rect.width - widthReduction,
                height: edgeWidth
            )
        } else {
            let xOffset = isHorizontalHandleOnRightEdge() ? 0 : edgeWidth
            let widthReduction = edgeWidth
            verticalEdgeRect = CGRect(
                x: rect.minX + xOffset,
                y: rect.minY,
                width: rect.width - widthReduction,
                height: edgeWidth
            )
        }
        regions.append((.vertical, verticalEdgeRect))

        return regions
    }
    
    /// 获取对应拖拽方向的光标
    private func cursorForDirection(_ direction: ResizeDirection) -> NSCursor {
        switch direction {
        case .horizontal:
            return .resizeLeftRight
        case .vertical:
            return .resizeUpDown
        case .diagonal:
            // 根据角落位置返回正确的对角线光标
            return getDiagonalCursor()
        case .none:
            return .arrow
        }
    }
    
    /// 获取对角线拖拽的光标
    private func getDiagonalCursor() -> NSCursor {
        // 根据角落方向选择合适的光标
        // bottomLeft 窗口拖拽右上角 -> 需要 NESW (↗↙) 光标
        // topRight 窗口拖拽左下角 -> 需要 NESW (↗↙) 光标
        // bottomRight 窗口拖拽左上角 -> 需要 NWSE (↖↘) 光标
        // topLeft 窗口拖拽右下角 -> 需要 NWSE (↖↘) 光标
        switch hotCorner {
        case .bottomLeft, .topRight:
            return Self.neswCursor  // ↗↙
        case .bottomRight, .topLeft:
            return Self.nwseCursor  // ↖↘
        }
    }
    
    /// NWSE 方向的对角线光标（↖↘）
    private static let nwseCursor: NSCursor = createDiagonalCursor(nwse: true)

    /// NESW 方向的对角线光标（↗↙）
    private static let neswCursor: NSCursor = createDiagonalCursor(nwse: false)
    
    /// 创建自定义对角线光标（作为回退方案）
    private static func createDiagonalCursor(nwse: Bool) -> NSCursor {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            // 白色描边（背景）
            NSColor.white.setStroke()
            let bgPath = NSBezierPath()
            bgPath.lineWidth = 3.0
            
            if nwse {
                // NWSE: ↖↘
                bgPath.move(to: NSPoint(x: 2, y: 14))
                bgPath.line(to: NSPoint(x: 14, y: 2))
            } else {
                // NESW: ↗↙
                bgPath.move(to: NSPoint(x: 14, y: 14))
                bgPath.line(to: NSPoint(x: 2, y: 2))
            }
            bgPath.stroke()
            
            // 黑色前景
            NSColor.black.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.5
            
            if nwse {
                // NWSE: ↖↘
                path.move(to: NSPoint(x: 2, y: 14))
                path.line(to: NSPoint(x: 14, y: 2))
                // 左上箭头
                path.move(to: NSPoint(x: 2, y: 14))
                path.line(to: NSPoint(x: 6, y: 14))
                path.move(to: NSPoint(x: 2, y: 14))
                path.line(to: NSPoint(x: 2, y: 10))
                // 右下箭头
                path.move(to: NSPoint(x: 14, y: 2))
                path.line(to: NSPoint(x: 10, y: 2))
                path.move(to: NSPoint(x: 14, y: 2))
                path.line(to: NSPoint(x: 14, y: 6))
            } else {
                // NESW: ↗↙
                path.move(to: NSPoint(x: 14, y: 14))
                path.line(to: NSPoint(x: 2, y: 2))
                // 右上箭头
                path.move(to: NSPoint(x: 14, y: 14))
                path.line(to: NSPoint(x: 10, y: 14))
                path.move(to: NSPoint(x: 14, y: 14))
                path.line(to: NSPoint(x: 14, y: 10))
                // 左下箭头
                path.move(to: NSPoint(x: 2, y: 2))
                path.line(to: NSPoint(x: 6, y: 2))
                path.move(to: NSPoint(x: 2, y: 2))
                path.line(to: NSPoint(x: 2, y: 6))
            }
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 8))
    }

    private func updateResizeCursor(for direction: ResizeDirection) {
        switch direction {
        case .none:
            NSCursor.arrow.set()
        default:
            cursorForDirection(direction).set()
        }
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
        window.invalidateCursorRects(for: resizeCursorOverlay)
        if isExpanded {
            expand(on: screen)
        }
    }

    #if DEBUG
    func applyDebugScenario(_ scenario: String) {
        panelState.applyDebugScenario(scenario)
        expandPanel()
    }
    #endif
}

private extension SlidePanelController {
    static func makeWindow(
        hostingController: NSHostingController<AnyView>,
        resizeCursorOverlay: ResizeCursorOverlayView
    ) -> NSWindow {
        let window = KeyboardAwareWindow(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        let containerController = NSViewController()
        let containerView = NSView(frame: .zero)
        containerController.view = containerView
        containerController.addChild(hostingController)

        hostingController.view.frame = containerView.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        containerView.addSubview(hostingController.view)

        resizeCursorOverlay.frame = containerView.bounds
        resizeCursorOverlay.autoresizingMask = [.width, .height]
        containerView.addSubview(resizeCursorOverlay, positioned: .above, relativeTo: hostingController.view)

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
        window.contentViewController = containerController
        window.isReleasedWhenClosed = false
        // 确保窗口能够接收鼠标移动事件
        window.acceptsMouseMovedEvents = true
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
        // 全局鼠标移动监听（用于触发面板展开）
        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseMove()
            }
        }

        // 全局点击监听（用于点击外部关闭面板）
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleGlobalMouseDown()
            }
        }
        
        // 本地鼠标事件监听（用于边缘拖拽 - 在事件传递给视图之前拦截）
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            guard let self = self else { return event }
            return self.handleLocalMouseEvent(event)
        }
        
        // 添加键盘事件监听器，捕获编辑快捷键
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isExpanded else { return event }
            
            // 检查是否是 Command+X/C/V/A
            if event.modifierFlags.contains(.command) {
                let keyCode = event.keyCode
                let chars = event.charactersIgnoringModifiers?.lowercased()
                
                // Command+X (剪切)
                if chars == "x" || keyCode == 7 {
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                        return nil
                    }
                }
                // Command+C (复制)
                else if chars == "c" || keyCode == 8 {
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                        return nil
                    }
                }
                // Command+V (粘贴)
                else if chars == "v" || keyCode == 9 {
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                        return nil
                    }
                }
                // Command+A (全选)
                else if chars == "a" || keyCode == 0 {
                    if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) {
                        return nil
                    }
                }
            }
            
            return event
        }
    }
    
    /// 处理本地鼠标事件（用于边缘拖拽）
    func handleLocalMouseEvent(_ event: NSEvent) -> NSEvent? {
        let screenPoint = NSEvent.mouseLocation
        
        switch event.type {
        case .mouseMoved:
            if isResizing {
                updateResizeCursor(for: resizeDirection)
                return event
            }

            let direction = getResizeDirection(at: screenPoint, edgeWidth: SlidePanelLayout.resizeEdgeWidthExit)
            if direction != hoveredResizeDirection {
                hoveredResizeDirection = direction
                updateResizeCursor(for: direction)
            }

            return event  // 传递事件
            
        case .leftMouseDown:
            let direction = getResizeDirection(at: screenPoint, edgeWidth: SlidePanelLayout.resizeEdgeWidthExit)
            if direction != .none {
                // 开始拖拽
                isResizing = true
                hoveredResizeDirection = direction
                resizeDirection = direction
                resizeStartLocation = screenPoint
                resizeStartFrame = window.frame
                updateResizeCursor(for: direction)
                return nil  // 消费事件，不传递
            }
            return event
            
        case .leftMouseDragged:
            if isResizing {
                performResize(currentLocation: screenPoint)
                return nil  // 消费事件
            }
            return event
            
        case .leftMouseUp:
            if isResizing {
                isResizing = false
                hoveredResizeDirection = .none
                resizeDirection = .none
                saveCurrentSize()
                updateResizeCursor(for: .none)
                window.invalidateCursorRects(for: resizeCursorOverlay)
                return nil  // 消费事件
            }
            return event
            
        default:
            return event
        }
    }
    
    /// 执行窗口大小调整
    func performResize(currentLocation: CGPoint) {
        let maxAllowedHeight = getMaxAllowedHeight()
        
        // 使用拖拽开始时的 frame 作为基准
        var newWidth = resizeStartFrame.width
        var newHeight = resizeStartFrame.height
        var newX = resizeStartFrame.origin.x
        var newY = resizeStartFrame.origin.y
        
        switch resizeDirection {
        case .horizontal:
            if isHorizontalHandleOnRightEdge() {
                // 窗口在左侧，拖拽右边缘
                // 新宽度 = 鼠标 X - 窗口左边缘
                newWidth = currentLocation.x - resizeStartFrame.origin.x
                newWidth = max(SlidePanelLayout.minWindowWidth, min(SlidePanelLayout.maxWindowWidth, newWidth))
                // X 坐标保持不变
            } else {
                // 窗口在右侧，拖拽左边缘
                // 右边缘固定
                let rightEdge = resizeStartFrame.origin.x + resizeStartFrame.width
                newWidth = rightEdge - currentLocation.x
                newWidth = max(SlidePanelLayout.minWindowWidth, min(SlidePanelLayout.maxWindowWidth, newWidth))
                newX = rightEdge - newWidth
            }
            
            currentWindowWidth = newWidth
            
        case .vertical:
            if isVerticalHandleOnTopEdge() {
                // 窗口在下边（bottomLeft/bottomRight），拖拽上边缘
                // 底边缘固定，新高度 = 鼠标 Y - 窗口底部
                newHeight = currentLocation.y - resizeStartFrame.origin.y
                newHeight = max(SlidePanelLayout.minWindowHeight, min(maxAllowedHeight, newHeight))
                // Y 坐标保持 resizeStartFrame.origin.y 不变
            } else {
                // 窗口在上边（topLeft/topRight），拖拽下边缘
                // 顶边缘固定
                let topEdge = resizeStartFrame.origin.y + resizeStartFrame.height
                newHeight = topEdge - currentLocation.y
                newHeight = max(SlidePanelLayout.minWindowHeight, min(maxAllowedHeight, newHeight))
                newY = topEdge - newHeight
            }
            
            currentWindowHeight = newHeight
            
        case .diagonal:
            // 水平方向
            if isHorizontalHandleOnRightEdge() {
                newWidth = currentLocation.x - resizeStartFrame.origin.x
                newWidth = max(SlidePanelLayout.minWindowWidth, min(SlidePanelLayout.maxWindowWidth, newWidth))
            } else {
                let rightEdge = resizeStartFrame.origin.x + resizeStartFrame.width
                newWidth = rightEdge - currentLocation.x
                newWidth = max(SlidePanelLayout.minWindowWidth, min(SlidePanelLayout.maxWindowWidth, newWidth))
                newX = rightEdge - newWidth
            }
            
            // 垂直方向
            if isVerticalHandleOnTopEdge() {
                newHeight = currentLocation.y - resizeStartFrame.origin.y
                newHeight = max(SlidePanelLayout.minWindowHeight, min(maxAllowedHeight, newHeight))
            } else {
                let topEdge = resizeStartFrame.origin.y + resizeStartFrame.height
                newHeight = topEdge - currentLocation.y
                newHeight = max(SlidePanelLayout.minWindowHeight, min(maxAllowedHeight, newHeight))
                newY = topEdge - newHeight
            }
            
            currentWindowWidth = newWidth
            currentWindowHeight = newHeight
            
        case .none:
            return
        }
        
        let newFrame = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        window.setFrame(newFrame, display: true)
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
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
    }

    func handleGlobalMouseMove() {
        guard !isExpanded else { return }

        let location = NSEvent.mouseLocation
        guard let screen = screen(containing: location) else { return }
        targetScreen = screen

        if hotspotRect(for: screen).contains(location) {
            expand(on: screen)
        }
    }

    func handleGlobalMouseDown() {
        let location = NSEvent.mouseLocation

        if SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: isExpanded,
            isResizing: isResizing,
            isPinned: panelState.isPinned,
            windowFrame: window.frame,
            clickLocation: location
        ) {
            collapse()
        }
    }

    func expand(on screen: NSScreen) {
        targetScreen = screen
        let visibleFrame = shownFrame(for: screen)

        if isExpanded {
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
            window.invalidateCursorRects(for: resizeCursorOverlay)
            window.setFrame(visibleFrame, display: true, animate: true)
            return
        }

        isExpanded = true
        let hiddenFrame = concealedFrame(for: screen)

        window.setFrame(hiddenFrame, display: false)
        window.alphaValue = 1
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.invalidateCursorRects(for: resizeCursorOverlay)
        
        // 确保窗口成为 key window 并能够接收键盘事件
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.window.makeKey()
            self.window.makeFirstResponder(self.hostingController.view)
            self.panelState.requestAddressFocus()
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = SlidePanelLayout.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(visibleFrame, display: true)
        }, completionHandler: {
            self.window.setFrame(visibleFrame, display: false)
        })
    }

    func collapse() {
        isExpanded = false
        
        // 重置拖拽状态
        isResizing = false
        hoveredResizeDirection = .none
        resizeDirection = .none
        updateResizeCursor(for: .none)

        guard let screen = targetScreen ?? window.screen ?? NSScreen.main else {
            window.orderOut(nil)
            return
        }

        let destination = concealedFrame(for: screen)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = SlidePanelLayout.animationDuration
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
        SlidePanelLayout.hotspotRect(hotCorner: hotCorner, screenFrame: screen.frame)
    }

    func shownFrame(for screen: NSScreen) -> CGRect {
        SlidePanelLayout.shownFrame(
            hotCorner: hotCorner,
            visibleFrame: screen.visibleFrame,
            windowWidth: currentWindowWidth,
            windowHeight: currentWindowHeight
        )
    }

    func concealedFrame(for screen: NSScreen) -> CGRect {
        let shown = shownFrame(for: screen)
        return SlidePanelLayout.concealedFrame(hotCorner: hotCorner, shownFrame: shown)
    }
}
