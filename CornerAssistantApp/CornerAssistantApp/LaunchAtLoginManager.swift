import Foundation

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private let label = "com.cornerassistant.launcher"
    private lazy var agentURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }()
    private lazy var expectedProgramArguments: [String] = {
        let bundleURL = Bundle.main.bundleURL.resolvingSymlinksInPath()
        return ["/usr/bin/open", "-a", bundleURL.path]
    }()

    private init() {}

    var isEnabled: Bool {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return false }
        return currentProgramArguments() == expectedProgramArguments
    }

    func enable() {
        do {
            try writeAgentPlist()
            reloadAgent()
        } catch {
            print("Failed to enable launch at login: \(error)")
        }
    }

    func disable() {
        do {
            unloadAgent()
            try FileManager.default.removeItem(at: agentURL)
        } catch {
            // ignore missing file errors
        }
    }

    func synchronize() {
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        guard currentProgramArguments() != expectedProgramArguments else { return }

        do {
            try writeAgentPlist()
            reloadAgent()
        } catch {
            print("Failed to synchronize launch agent: \(error)")
        }
    }

    private func writeAgentPlist() throws {
        let dict: [String: Any] = [
            "Label": label,
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProgramArguments": expectedProgramArguments
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: agentURL, options: .atomic)
    }

    private func reloadAgent() {
        unloadAgent()
        runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", agentURL.path])
    }

    private func unloadAgent() {
        runLaunchctl(arguments: ["bootout", "gui/\(getuid())", agentURL.path])
    }

    private func runLaunchctl(arguments: [String]) {
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }

    private func currentProgramArguments() -> [String]? {
        guard let data = try? Data(contentsOf: agentURL) else {
            return nil
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format),
            let dict = plist as? [String: Any],
            let args = dict["ProgramArguments"] as? [String]
        else {
            return nil
        }

        return args
    }
}
