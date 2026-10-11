import Foundation

/// The LaunchAgent that starts the helper at login. It runs the app's own executable, so
/// System Settings → Login Items lists it by name; an agent that ran `/usr/bin/open` would be
/// listed as "open" from an unknown developer. There is no KeepAlive: quitting from the menu
/// keeps the helper quit until the next login.
public enum LoginAgent {
    public static let label = "com.suatkocar.termpaste"

    public static func url(home: URL) -> URL {
        home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public static func propertyList(executablePath: String, bundleIdentifier: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "AssociatedBundleIdentifiers": [bundleIdentifier],
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    /// Only an installed copy registers itself; a build inside the repository never does.
    public static func isInstalledLocation(_ appPath: String, home: URL) -> Bool {
        guard appPath.hasSuffix(".app") else { return false }
        return appPath.hasPrefix("/Applications/") || appPath.hasPrefix(home.appendingPathComponent("Applications").path + "/")
    }
}
