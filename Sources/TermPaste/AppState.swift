import AppKit
import Observation
import PasteRouting

/// Owns apps.json, the router and everything the menu and the Settings window show.
@Observable
final class AppState {
    /// The last active app other than this helper, offered as a one-click addition.
    struct OtherApp: Equatable {
        var bundleID: String
        var name: String
    }

    let router = EventRouter()
    let file = AppListFile(url: EventRouter.supportURL.appendingPathComponent("apps.json")) {
        // Super used to be switched by its own menu item; its earlier choice carries over.
        AppList.defaults(superEngineeringEnabled: UserDefaults.standard.object(forKey: "superAppWide") as? Bool ?? true)
    }
    /// Called after anything the menu bar picture or the open menu shows has changed.
    @ObservationIgnored var onChange: (() -> Void)?
    private let defaults = UserDefaults.standard
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    private let ownBundleID = Bundle.main.bundleIdentifier ?? LoginAgent.label

    private(set) var apps: [AppRule] = []
    private(set) var fileProblem: String?
    private(set) var trusted = false
    private(set) var secureInput = false
    private(set) var secureInputOwner: SecureInputOwner?
    private(set) var attached: Set<String> = []
    private(set) var runningListed: Set<String> = []
    private(set) var failed: Set<String> = []
    private(set) var paused = false
    private(set) var launchAtLogin = false
    private(set) var tally = PasteTally()
    private(set) var lastDecision: String?
    private(set) var previousApp: OtherApp?

    func start() {
        if let data = defaults.data(forKey: "pasteTally"), let saved = try? JSONDecoder().decode(PasteTally.self, from: data) {
            tally = saved
        }
        paused = defaults.bool(forKey: "routingDisabled")
        router.enabled = !paused
        router.onChange = { [weak self] in self?.pull() }
        router.onRoute = { [weak self] bundleID in self?.recordRoute(bundleID) }
        file.refresh()
        router.appsFileProblem = file.problem
        router.rules = file.list.apps
        if let front = NSWorkspace.shared.frontmostApplication { noteActivation(front) }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                if name == NSWorkspace.didActivateApplicationNotification,
                   let application = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.noteActivation(application)
                }
                self?.router.synchronize()
            })
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        router.stop()
    }

    /// Re-reads apps.json if it changed, then re-checks permissions and running apps.
    func refresh() {
        if file.refresh() {
            router.appsFileProblem = file.problem
            router.rules = file.list.apps
        } else {
            router.synchronize()
        }
        pull()
    }

    // MARK: - What the menu and Settings show

    func status(for rule: AppRule) -> AppStatus {
        AppStatus.of(rule, running: runningListed.contains(rule.bundleID), attached: attached.contains(rule.bundleID),
                     failed: failed.contains(rule.bundleID))
    }

    var connectedNames: [String] { apps.filter { status(for: $0) == .connected }.map(\.name) }

    /// The app to offer as "Add …": the last other active app, when it is not listed yet.
    var quickAddCandidate: OtherApp? {
        guard let previousApp, !apps.contains(where: { $0.bundleID == previousApp.bundleID }) else { return nil }
        return previousApp
    }

    var appsFileURL: URL { file.url }

    var secureInputLines: [String] {
        SecureInputReport.lines(owner: secureInputOwner, frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                                listedBundleIDs: Set(apps.map(\.bundleID)))
    }

    /// "Last paste 14:02 in Ghostty · 3 today", or a note that none has been routed.
    func pasteSummary(now: Date = Date()) -> String {
        guard let time = tally.lastTime, let app = tally.lastApp else { return "No image pasted yet" }
        let when = Calendar.current.isDate(time, inSameDayAs: now)
            ? time.formatted(date: .omitted, time: .shortened)
            : time.formatted(.dateTime.month(.abbreviated).day())
        let today = tally.count(on: now)
        return "Last paste \(when) in \(app)" + (today > 0 ? " · \(today) today" : "")
    }

    // MARK: - Changes

    func setEnabled(_ bundleID: String, _ enabled: Bool) { edit { $0.update(bundleID) { $0.enabled = enabled } } }
    func setScope(_ bundleID: String, _ scope: AppRule.Scope) { edit { $0.update(bundleID) { $0.scope = scope } } }
    func remove(_ bundleID: String) { edit { $0.remove(bundleID) } }
    func restoreDefaults() { edit { $0 = AppList.defaults() } }

    func addPrevious() {
        guard let candidate = quickAddCandidate else { return }
        edit { $0.add(AppRule(bundleID: candidate.bundleID, name: candidate.name)) }
    }

    /// Adds the app at `url`; returns why it was not added, for an alert.
    func addApp(at url: URL) -> String? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            return "\(url.deletingPathExtension().lastPathComponent) has no bundle identifier, so it can’t be listed."
        }
        if bundleID == ownBundleID { return "TermPaste can’t route its own paste." }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        if let existing = file.list.rule(for: bundleID) { return "\(existing.name) is already on the list." }
        edit { $0.add(AppRule(bundleID: bundleID, name: name)) }
        return nil
    }

    func setPaused(_ paused: Bool) {
        defaults.set(paused, forKey: "routingDisabled")
        router.enabled = !paused
        pull()
    }

    func setLaunchAtLogin(_ on: Bool) {
        defaults.set(true, forKey: "launchAtLoginConfigured")
        do { if on { try LoginItem.enable() } else { try LoginItem.disable() } }
        catch { NSSound.beep(); NSLog("TermPaste: Launch at Login unchanged: %@", error.localizedDescription) }
        pull()
    }

    func revealAppsFile() { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
    func revealStatusFile() { NSWorkspace.shared.activateFileViewerSelecting([EventRouter.statusURL]) }

    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Internals

    private func edit(_ change: (inout AppList) -> Void) {
        var list = file.list
        change(&list)
        guard list != file.list else { return }
        do {
            try file.save(list)
        } catch {
            NSSound.beep()
            NSLog("TermPaste: apps.json not saved: %@", error.localizedDescription)
        }
        router.appsFileProblem = file.problem
        router.rules = file.list.apps
        pull()
    }

    private func recordRoute(_ bundleID: String) {
        tally.record(app: file.list.rule(for: bundleID)?.name ?? bundleID, at: Date())
        if let data = try? JSONEncoder().encode(tally) { defaults.set(data, forKey: "pasteTally") }
    }

    private func noteActivation(_ application: NSRunningApplication) {
        guard let bundleID = application.bundleIdentifier, bundleID != ownBundleID else { return }
        let other = OtherApp(bundleID: bundleID, name: application.localizedName ?? bundleID)
        if previousApp != other { previousApp = other }
    }

    /// Copies the router's state into observed properties, assigning only what changed.
    private func pull() {
        func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppState, Value>, _ value: Value) {
            if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
        }
        set(\.apps, file.list.apps)
        set(\.fileProblem, file.problem)
        set(\.trusted, router.trusted)
        set(\.secureInput, router.secureInput)
        set(\.secureInputOwner, router.secureInputOwner)
        set(\.attached, router.attached)
        set(\.runningListed, router.runningListed)
        set(\.failed, router.failed)
        set(\.paused, !router.enabled)
        set(\.launchAtLogin, LoginItem.isEnabled)
        set(\.lastDecision, Self.describe(router.lastDecision, names: file.list))
        onChange?()
    }

    private static func describe(_ decision: [String: Any], names: AppList) -> String? {
        guard let bundleID = decision["application"] as? String, let result = decision["result"] as? String else { return nil }
        let name = names.rule(for: bundleID)?.name ?? bundleID
        let time = (decision["time"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
            .map { " · " + $0.formatted(date: .omitted, time: .shortened) } ?? ""
        switch result {
        case "converted": return "Ctrl+V in \(name)\(time)"
        case "no-image": return "Normal ⌘V in \(name): no image on the clipboard\(time)"
        case "not-terminal-input":
            let label = names.rule(for: bundleID)?.requiredLabel ?? AppRule.defaultInputLabel
            return "Normal ⌘V in \(name): the focused field isn’t “\(label)”\(time)"
        default: return "\(result) in \(name)\(time)"
        }
    }
}
