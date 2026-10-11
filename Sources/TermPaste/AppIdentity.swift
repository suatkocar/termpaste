import AppKit
import Security

/// Icons of listed apps, and this copy's own version and signature for Diagnostics.
enum AppIdentity {
    private static var icons: [String: NSImage] = [:]

    /// The installed app's icon, or the generic app icon when it is not installed.
    static func icon(for bundleID: String, size: CGFloat = 16) -> NSImage {
        let key = "\(bundleID)@\(size)"
        if let cached = icons[key] { return cached }
        let source = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application)
        let icon = source.copy() as! NSImage
        icon.size = NSSize(width: size, height: size)
        icons[key] = icon
        return icon
    }

    static var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let short = info["CFBundleShortVersionString"] as? String ?? "development build"
        return (info["CFBundleVersion"] as? String).map { "\(short) (\($0))" } ?? short
    }

    /// "Developer ID Application: Name (TEAM)", "ad hoc", or "not signed".
    static let signature: String = {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return "not signed" }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any] else { return "not signed" }
        guard let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate], let leaf = certificates.first else {
            return info[kSecCodeInfoIdentifier as String] == nil ? "not signed" : "ad hoc"
        }
        return SecCertificateCopySubjectSummary(leaf) as String? ?? "signed"
    }()
}
