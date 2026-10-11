import Foundation
import PasteRouting

/// Launch at Login through a LaunchAgent that runs this copy of the helper.
enum LoginItem {
    static var url: URL { LoginAgent.url(home: FileManager.default.homeDirectoryForCurrentUser) }
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: url.path) }

    static func enable() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try expectedPropertyList().write(to: url, options: .atomic)
    }

    /// Points an existing agent at this copy again after an update or move; a turned-off item stays off.
    static func refreshIfEnabled() throws {
        guard isEnabled else { return }
        let data = try expectedPropertyList()
        if (try? Data(contentsOf: url)) != data { try data.write(to: url, options: .atomic) }
    }

    /// Removes the file, so launchd does not load the agent at the next login. It is not booted out:
    /// a helper started at login is that agent's own process, and `bootout` would quit it.
    static func disable() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private static func expectedPropertyList() throws -> Data {
        let executable = Bundle.main.executablePath ?? Bundle.main.bundlePath + "/Contents/MacOS/TermPaste"
        return try LoginAgent.propertyList(executablePath: executable, bundleIdentifier: Bundle.main.bundleIdentifier ?? LoginAgent.label)
    }
}
