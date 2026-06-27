import XCTest
@testable import Peek

@MainActor
final class SlidePanelViewModelTests: XCTestCase {
    func testInitialPinnedSitesCreatePinnedTabs() throws {
        let chat = PinnedSite(name: "Chat", url: "https://chat.example/")
        let docs = PinnedSite(name: "Docs", url: "https://docs.example/")
        let viewModel = makeViewModel(initialPinnedSites: [chat, docs])

        XCTAssertEqual(viewModel.pinnedSites, [chat, docs])
        XCTAssertEqual(viewModel.tabs.count, 2)
        XCTAssertTrue(viewModel.regularTabs.isEmpty)
        XCTAssertFalse(viewModel.showingLauncher)
        XCTAssertEqual(viewModel.activeTab.addressText, chat.url)
        XCTAssertEqual(viewModel.activeTab.url?.absoluteString, chat.url)
    }

    func testEmptyPinnedSitesStartWithLauncherTab() {
        let viewModel = makeViewModel(initialPinnedSites: [])

        XCTAssertEqual(viewModel.tabs.count, 1)
        XCTAssertEqual(viewModel.regularTabs.count, 1)
        XCTAssertTrue(viewModel.showingLauncher)
        XCTAssertNil(viewModel.activeTab.url)
    }

    func testAddSelectAndCloseRegularTabs() throws {
        let viewModel = makeViewModel(initialPinnedSites: [])
        let firstTab = viewModel.activeTab

        viewModel.addTab()
        let secondTab = viewModel.activeTab
        XCTAssertNotEqual(firstTab.id, secondTab.id)
        XCTAssertEqual(viewModel.regularTabs.map(\.id), [firstTab.id, secondTab.id])
        XCTAssertTrue(viewModel.showingLauncher)

        let url = try XCTUnwrap(URL(string: "https://example.com/"))
        viewModel.updateActiveTabURL(url, addressText: "example.com")
        XCTAssertEqual(secondTab.url, url)
        XCTAssertEqual(secondTab.addressText, "example.com")

        viewModel.select(tab: firstTab)
        XCTAssertEqual(viewModel.activeTabID, firstTab.id)
        XCTAssertTrue(viewModel.showingLauncher)

        viewModel.close(tab: firstTab)
        XCTAssertEqual(viewModel.tabs.map(\.id), [secondTab.id])
        XCTAssertEqual(viewModel.activeTabID, secondTab.id)
        XCTAssertFalse(viewModel.showingLauncher)
    }

    func testPinAndUnpinRegularTab() throws {
        let recorder = PinnedSiteSaveRecorder()
        let viewModel = makeViewModel(initialPinnedSites: [], recorder: recorder)
        let tab = viewModel.activeTab
        let url = try XCTUnwrap(URL(string: "https://example.com/guide"))
        viewModel.updateActiveTabURL(url, addressText: url.absoluteString)
        tab.title = "Example Guide"

        XCTAssertTrue(viewModel.canPin(tab: tab))
        viewModel.pin(tab: tab)

        XCTAssertEqual(viewModel.pinnedSites.map(\.name), ["Example Guide"])
        XCTAssertEqual(viewModel.pinnedSites.map(\.url), [url.absoluteString])
        XCTAssertTrue(viewModel.regularTabs.isEmpty)
        XCTAssertEqual(recorder.saves.last, viewModel.pinnedSites)

        let site = try XCTUnwrap(viewModel.pinnedSites.first)
        XCTAssertTrue(viewModel.isPinnedActive(site))
        viewModel.unpin(site: site)

        XCTAssertTrue(viewModel.pinnedSites.isEmpty)
        XCTAssertEqual(viewModel.regularTabs.map(\.id), [tab.id])
        XCTAssertEqual(recorder.saves.last, [])
    }

    func testActivatePinnedSiteSelectsExistingPinnedTab() {
        let one = PinnedSite(name: "One", url: "https://one.example/")
        let two = PinnedSite(name: "Two", url: "https://two.example/")
        let viewModel = makeViewModel(initialPinnedSites: [one, two])
        let targetTab = viewModel.tabs[1]

        let activatedTab = viewModel.activatePinned(site: two)

        XCTAssertTrue(activatedTab === targetTab)
        XCTAssertEqual(viewModel.activeTabID, targetTab.id)
        XCTAssertFalse(viewModel.showingLauncher)
        XCTAssertEqual(targetTab.addressText, two.url)
        XCTAssertEqual(targetTab.url?.absoluteString, two.url)
    }

    func testPinnedAndRegularTabReordering() {
        let one = PinnedSite(name: "One", url: "https://one.example/")
        let two = PinnedSite(name: "Two", url: "https://two.example/")
        let viewModel = makeViewModel(initialPinnedSites: [one, two])

        viewModel.movePinnedSite(from: 0, to: 1)
        XCTAssertEqual(viewModel.pinnedSites, [two, one])

        viewModel.addTab()
        let regularOne = viewModel.activeTab
        viewModel.addTab()
        let regularTwo = viewModel.activeTab
        XCTAssertEqual(viewModel.regularTabs.map(\.id), [regularOne.id, regularTwo.id])

        viewModel.moveRegularTab(from: 0, to: 1)
        XCTAssertEqual(viewModel.regularTabs.map(\.id), [regularTwo.id, regularOne.id])
    }

    private func makeViewModel(
        initialPinnedSites: [PinnedSite],
        recorder: PinnedSiteSaveRecorder? = nil
    ) -> SlidePanelViewModel {
        SlidePanelViewModel(
            initialPinnedSites: initialPinnedSites,
            storedPinnedSites: [],
            savePinnedSites: { sites in
                recorder?.saves.append(sites)
            }
        )
    }
}

private final class PinnedSiteSaveRecorder {
    var saves: [[PinnedSite]] = []
}
