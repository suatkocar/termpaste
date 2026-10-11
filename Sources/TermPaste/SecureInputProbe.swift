import AppKit
import IOKit
import PasteRouting

/// Reads the process macOS records for the session's Secure Input. See `SecureInputReport`
/// for why that name is reported as what macOS names, not as the holder.
enum SecureInputProbe {
    static func owner() -> SecureInputOwner? {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }
        guard let sessions = IORegistryEntrySearchCFProperty(root, kIOServicePlane, "IOConsoleUsers" as CFString,
                                                             kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)) as? [[String: Any]],
              let pid = SecureInputReport.ownerPID(in: sessions) else { return nil }
        let application = NSRunningApplication(processIdentifier: pid)
        let running = application != nil || kill(pid, 0) == 0 || errno == EPERM
        return SecureInputOwner(pid: pid, name: application?.localizedName ?? (running ? processName(pid) : nil),
                                bundleID: application?.bundleIdentifier, isRunning: running)
    }

    private static func processName(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
