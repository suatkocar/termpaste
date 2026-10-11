import Foundation

/// The process macOS records for the session's Secure Input.
public struct SecureInputOwner: Equatable {
    public var pid: Int32
    public var name: String?
    public var bundleID: String?
    public var isRunning: Bool

    public init(pid: Int32, name: String?, bundleID: String?, isRunning: Bool) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
        self.isRunning = isRunning
    }
}

/// What the menu says while Secure Input is on. While any process holds it, macOS hides keystrokes
/// from event taps, so image paste pauses everywhere.
///
/// The only source for a name is the undocumented `kCGSSessionSecureInputPID` key of the console
/// session, and it does not always name the process that turned Secure Input on: in three tests on
/// macOS 27, a background process turned it on and the key named whichever app was in front. The
/// text therefore says which app macOS names, and when that is the app in front, the advice also
/// covers a password app in the background.
public enum SecureInputReport {
    public static let loginwindowBundleID = "com.apple.loginwindow"

    /// The recorded PID in the IOConsoleUsers session dictionaries; absent or zero means none.
    public static func ownerPID(in sessions: [[String: Any]]) -> Int32? {
        for session in sessions {
            if let value = session["kCGSSessionSecureInputPID"] as? NSNumber, value.int32Value != 0 {
                return value.int32Value
            }
        }
        return nil
    }

    /// Two lines: what macOS reports, then what usually ends it.
    public static func lines(owner: SecureInputOwner?, frontmostPID: Int32?, listedBundleIDs: Set<String>) -> [String] {
        guard let owner else {
            return ["macOS doesn’t name the app that turned it on.",
                    "If it lasts, lock and unlock your Mac."]
        }
        let name = owner.name ?? "pid \(owner.pid)"
        if owner.bundleID == loginwindowBundleID || owner.name == "loginwindow" {
            return ["macOS names loginwindow.",
                    "If it lasts, quit password apps, or lock and unlock your Mac."]
        }
        if !owner.isRunning {
            return ["The process macOS names (pid \(owner.pid)) has quit.",
                    "Lock and unlock your Mac; log out if it lasts."]
        }
        if owner.pid == frontmostPID {
            if let bundleID = owner.bundleID, listedBundleIDs.contains(bundleID) {
                return ["macOS names \(name), the app in front.",
                        "If it lasts, turn off Secure Keyboard Entry in \(name), or quit password apps."]
            }
            return ["macOS names \(name), the app in front.",
                    "Usually a focused password field; if it lasts, quit password apps."]
        }
        return ["macOS names \(name).",
                "Finish its password prompt or quit it; if it lasts, lock and unlock your Mac."]
    }
}
