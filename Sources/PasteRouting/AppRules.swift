import Foundation

/// One application whose ⌘V becomes Ctrl+V while the clipboard holds an image.
public struct AppRule: Codable, Equatable, Identifiable {
    /// How the image reaches the app. Only `image` (Ctrl+V) is implemented; `path` is reserved for a
    /// later file-path mode, so the field already exists in apps.json and such a rule is listed but not routed.
    public enum Paste: String, Codable, CaseIterable { case image, path }
    /// `terminalInput` routes only while the focused text control carries `inputLabel`, as Orca's terminal does.
    public enum Scope: String, Codable, CaseIterable { case app, terminalInput }

    public static let defaultInputLabel = "Terminal input"

    public var bundleID: String
    public var name: String
    public var enabled: Bool
    public var paste: Paste
    public var scope: Scope
    public var inputLabel: String?

    public var id: String { bundleID }
    /// The label `terminalInput` requires on the focused control.
    public var requiredLabel: String { inputLabel ?? Self.defaultInputLabel }
    /// Whether ⌘V is rewritten in this app at all.
    public var routes: Bool { enabled && paste == .image }

    public init(bundleID: String, name: String, enabled: Bool = true, paste: Paste = .image,
                scope: Scope = .app, inputLabel: String? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.enabled = enabled
        self.paste = paste
        self.scope = scope
        self.inputLabel = inputLabel
    }

    private enum CodingKeys: String, CodingKey { case bundleID, name, enabled, paste, scope, inputLabel }

    /// Lenient for hand edits: only `bundleID` is required; the rest falls back to the defaults.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID).trimmingCharacters(in: .whitespacesAndNewlines)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? bundleID
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        paste = try container.decodeIfPresent(Paste.self, forKey: .paste) ?? .image
        scope = try container.decodeIfPresent(Scope.self, forKey: .scope) ?? .app
        inputLabel = try container.decodeIfPresent(String.self, forKey: .inputLabel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(paste, forKey: .paste)
        try container.encode(scope, forKey: .scope)
        try container.encodeIfPresent(inputLabel, forKey: .inputLabel)
    }
}

/// The contents of apps.json.
public struct AppList: Codable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var apps: [AppRule]

    public init(apps: [AppRule]) {
        version = Self.currentVersion
        self.apps = apps
    }

    public enum Problem: Error, Equatable, CustomStringConvertible {
        case newerVersion(Int)
        case emptyBundleID
        case duplicate(String)

        public var description: String {
            switch self {
            case .newerVersion(let version): "it was written by a newer version (\(version))"
            case .emptyBundleID: "an app has an empty “bundleID”"
            case .duplicate(let bundleID): "it lists \(bundleID) twice"
            }
        }
    }

    /// The list that earlier builds compiled in, in the order the menu shows it. Super was then
    /// switched by its own menu item, so its earlier choice carries over.
    public static func defaults(superEngineeringEnabled: Bool = true) -> AppList {
        AppList(apps: [
            AppRule(bundleID: "com.mitchellh.ghostty", name: "Ghostty"),
            AppRule(bundleID: "com.stablyai.orca", name: "Orca", scope: .terminalInput, inputLabel: AppRule.defaultInputLabel),
            AppRule(bundleID: "engineering.super.app", name: "super.engineering", enabled: superEngineeringEnabled),
            AppRule(bundleID: "com.googlecode.iterm2", name: "iTerm"),
            AppRule(bundleID: "dev.warp.Warp-Stable", name: "Warp"),
            AppRule(bundleID: "com.apple.Terminal", name: "Terminal"),
        ])
    }

    private enum CodingKeys: String, CodingKey { case version, apps }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        apps = try container.decode([AppRule].self, forKey: .apps)
    }

    public static func decode(_ data: Data) throws -> AppList {
        let list = try JSONDecoder().decode(AppList.self, from: data)
        if list.version > currentVersion { throw Problem.newerVersion(list.version) }
        var seen = Set<String>()
        for rule in list.apps {
            if rule.bundleID.isEmpty { throw Problem.emptyBundleID }
            if !seen.insert(rule.bundleID).inserted { throw Problem.duplicate(rule.bundleID) }
        }
        return list
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(self)
        data.append(0x0A)
        return data
    }

    public func rule(for bundleID: String) -> AppRule? { apps.first { $0.bundleID == bundleID } }

    /// Appends the rule unless its bundle ID is already listed.
    @discardableResult
    public mutating func add(_ rule: AppRule) -> Bool {
        guard !rule.bundleID.isEmpty, self.rule(for: rule.bundleID) == nil else { return false }
        apps.append(rule)
        return true
    }

    public mutating func remove(_ bundleID: String) {
        apps.removeAll { $0.bundleID == bundleID }
    }

    public mutating func update(_ bundleID: String, _ change: (inout AppRule) -> Void) {
        guard let index = apps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        change(&apps[index])
        if apps[index].scope == .terminalInput && apps[index].inputLabel == nil {
            apps[index].inputLabel = AppRule.defaultInputLabel
        }
    }
}

/// What the menu and the Apps tab say about one listed app.
public enum AppStatus: Equatable {
    case off, filePathUnavailable, notRunning, connected, cannotAttach, waiting

    public static func of(_ rule: AppRule, running: Bool, attached: Bool, failed: Bool) -> AppStatus {
        if !rule.enabled { return .off }
        if rule.paste != .image { return .filePathUnavailable }
        if !running { return .notRunning }
        if attached { return .connected }
        if failed { return .cannotAttach }
        return .waiting
    }

    public var text: String {
        switch self {
        case .off: "off"
        case .filePathUnavailable: "file path not available"
        case .notRunning: "not running"
        case .connected: "connected"
        case .cannotAttach: "can’t attach"
        case .waiting: "waiting"
        }
    }
}
