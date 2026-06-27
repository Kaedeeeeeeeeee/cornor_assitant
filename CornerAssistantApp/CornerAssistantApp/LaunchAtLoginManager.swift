import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let service = SMAppService.mainApp

    private init() {}

    var isEnabled: Bool {
        service.status == .enabled
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
        // SMAppService manages state automatically; no manual sync needed.
    }
}
