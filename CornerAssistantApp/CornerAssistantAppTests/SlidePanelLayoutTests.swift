import XCTest
@testable import Peek

final class SlidePanelLayoutTests: XCTestCase {
    func testSavedPanelSizeDefaultsAndClamps() {
        XCTAssertEqual(SlidePanelLayout.savedWidth(from: 0), 528)
        XCTAssertEqual(SlidePanelLayout.savedWidth(from: 100), 576)
        XCTAssertEqual(SlidePanelLayout.savedWidth(from: 700), 700)
        XCTAssertEqual(SlidePanelLayout.savedWidth(from: 1_200), 900)

        XCTAssertEqual(SlidePanelLayout.savedHeight(from: 0), 750)
        XCTAssertEqual(SlidePanelLayout.savedHeight(from: 100), 600)
        XCTAssertEqual(SlidePanelLayout.savedHeight(from: 900), 900)
        XCTAssertEqual(SlidePanelLayout.savedHeight(from: 1_500), 1_200)
    }

    func testHotspotRectsMatchEveryHotCorner() {
        let screenFrame = CGRect(x: 100, y: 200, width: 1_600, height: 900)

        XCTAssertEqual(
            SlidePanelLayout.hotspotRect(hotCorner: .bottomLeft, screenFrame: screenFrame),
            CGRect(x: 100, y: 200, width: 12, height: 140)
        )
        XCTAssertEqual(
            SlidePanelLayout.hotspotRect(hotCorner: .bottomRight, screenFrame: screenFrame),
            CGRect(x: 1_688, y: 200, width: 12, height: 140)
        )
        XCTAssertEqual(
            SlidePanelLayout.hotspotRect(hotCorner: .topLeft, screenFrame: screenFrame),
            CGRect(x: 100, y: 960, width: 12, height: 140)
        )
        XCTAssertEqual(
            SlidePanelLayout.hotspotRect(hotCorner: .topRight, screenFrame: screenFrame),
            CGRect(x: 1_688, y: 960, width: 12, height: 140)
        )
    }

    func testShownFramesAnchorToEveryHotCorner() {
        let visibleFrame = CGRect(x: 10, y: 30, width: 1_600, height: 900)
        let width: CGFloat = 640
        let height: CGFloat = 700

        XCTAssertEqual(
            SlidePanelLayout.shownFrame(hotCorner: .bottomLeft, visibleFrame: visibleFrame, windowWidth: width, windowHeight: height),
            CGRect(x: 24, y: 40, width: 640, height: 700)
        )
        XCTAssertEqual(
            SlidePanelLayout.shownFrame(hotCorner: .bottomRight, visibleFrame: visibleFrame, windowWidth: width, windowHeight: height),
            CGRect(x: 956, y: 40, width: 640, height: 700)
        )
        XCTAssertEqual(
            SlidePanelLayout.shownFrame(hotCorner: .topLeft, visibleFrame: visibleFrame, windowWidth: width, windowHeight: height),
            CGRect(x: 24, y: 220, width: 640, height: 700)
        )
        XCTAssertEqual(
            SlidePanelLayout.shownFrame(hotCorner: .topRight, visibleFrame: visibleFrame, windowWidth: width, windowHeight: height),
            CGRect(x: 956, y: 220, width: 640, height: 700)
        )
    }

    func testShownFrameLimitsHeightToVisibleArea() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 800)
        let frame = SlidePanelLayout.shownFrame(
            hotCorner: .bottomLeft,
            visibleFrame: visibleFrame,
            windowWidth: 640,
            windowHeight: 2_000
        )

        XCTAssertEqual(frame.height, 780)
    }

    func testConcealedFramesMoveOffscreenAwayFromHotCorner() {
        let shownFrame = CGRect(x: 24, y: 40, width: 640, height: 700)

        let bottomLeft = SlidePanelLayout.concealedFrame(hotCorner: .bottomLeft, shownFrame: shownFrame)
        XCTAssertEqual(bottomLeft.maxX, shownFrame.minX - 12)
        XCTAssertEqual(bottomLeft.maxY, shownFrame.minY - 12)

        let bottomRight = SlidePanelLayout.concealedFrame(hotCorner: .bottomRight, shownFrame: shownFrame)
        XCTAssertEqual(bottomRight.minX, shownFrame.maxX + 12)
        XCTAssertEqual(bottomRight.maxY, shownFrame.minY - 12)

        let topLeft = SlidePanelLayout.concealedFrame(hotCorner: .topLeft, shownFrame: shownFrame)
        XCTAssertEqual(topLeft.maxX, shownFrame.minX - 12)
        XCTAssertEqual(topLeft.minY, shownFrame.maxY + 12)

        let topRight = SlidePanelLayout.concealedFrame(hotCorner: .topRight, shownFrame: shownFrame)
        XCTAssertEqual(topRight.minX, shownFrame.maxX + 12)
        XCTAssertEqual(topRight.minY, shownFrame.maxY + 12)
    }

    func testGlobalMouseDownCollapsePolicyRespectsPinnedAndResizingStates() {
        let windowFrame = CGRect(x: 100, y: 100, width: 500, height: 600)
        let inside = CGPoint(x: 200, y: 200)
        let outside = CGPoint(x: 20, y: 20)

        XCTAssertFalse(SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: false,
            isResizing: false,
            isPinned: false,
            windowFrame: windowFrame,
            clickLocation: outside
        ))
        XCTAssertFalse(SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: true,
            isResizing: true,
            isPinned: false,
            windowFrame: windowFrame,
            clickLocation: outside
        ))
        XCTAssertFalse(SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: true,
            isResizing: false,
            isPinned: true,
            windowFrame: windowFrame,
            clickLocation: outside
        ))
        XCTAssertFalse(SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: true,
            isResizing: false,
            isPinned: false,
            windowFrame: windowFrame,
            clickLocation: inside
        ))
        XCTAssertTrue(SlidePanelLayout.shouldCollapseOnGlobalMouseDown(
            isExpanded: true,
            isResizing: false,
            isPinned: false,
            windowFrame: windowFrame,
            clickLocation: outside
        ))
    }
}
