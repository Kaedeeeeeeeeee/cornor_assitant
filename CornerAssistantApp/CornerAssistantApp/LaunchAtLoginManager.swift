import Foundation
import ServiceManagement

protocol LaunchAtLoginServicing {
    var isEnabled: Bool { get }

    func register() throws
    func unregister() throws
    func synchronize()
}

final class SMAppLaunchAtLoginService: LaunchAtLoginServicing {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var isEnabled: Bool {
        service.status == .enabled
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func synchronize() {
        // SMAppService manages state automatically; no manual sync needed.
    }
}

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager(service: SMAppLaunchAtLoginService())

    private let service: LaunchAtLoginServicing

    init(service: LaunchAtLoginServicing) {
        self.service = service
    }

    var isEnabled: Bool {
        service.isEnabled
    }

    func enable() {
        do {
            try service.register()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }

    func disable() {
        do {
            try service.unregister()
        } catch {
            print("Failed to disable launch at login: \(error)")
        }
    }

    func synchronize() {
        service.synchronize()
    }
}
