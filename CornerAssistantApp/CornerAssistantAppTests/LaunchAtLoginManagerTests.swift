import XCTest
@testable import Peek

final class LaunchAtLoginManagerTests: XCTestCase {
    func testIsEnabledReflectsServiceState() {
        let service = FakeLaunchAtLoginService()
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertFalse(manager.isEnabled)

        service.isEnabled = true

        XCTAssertTrue(manager.isEnabled)
    }

    func testEnableRegistersLaunchAtLoginService() {
        let service = FakeLaunchAtLoginService()
        let manager = LaunchAtLoginManager(service: service)

        manager.enable()

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertTrue(manager.isEnabled)
    }

    func testDisableUnregistersLaunchAtLoginService() {
        let service = FakeLaunchAtLoginService()
        service.isEnabled = true
        let manager = LaunchAtLoginManager(service: service)

        manager.disable()

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertFalse(manager.isEnabled)
    }

    func testSynchronizeDelegatesToService() {
        let service = FakeLaunchAtLoginService()
        let manager = LaunchAtLoginManager(service: service)

        manager.synchronize()

        XCTAssertEqual(service.synchronizeCallCount, 1)
    }

    func testServiceErrorsDoNotEscapeLaunchAtLoginActions() {
        let service = FakeLaunchAtLoginService()
        service.registerError = FakeLaunchAtLoginService.Error.registerFailed
        service.unregisterError = FakeLaunchAtLoginService.Error.unregisterFailed
        let manager = LaunchAtLoginManager(service: service)

        manager.enable()
        service.isEnabled = true
        manager.disable()

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 1)
    }
}

private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    enum Error: Swift.Error {
        case registerFailed
        case unregisterFailed
    }

    var isEnabled = false
    var registerError: Swift.Error?
    var unregisterError: Swift.Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var synchronizeCallCount = 0

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        isEnabled = true
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        isEnabled = false
    }

    func synchronize() {
        synchronizeCallCount += 1
    }
}
