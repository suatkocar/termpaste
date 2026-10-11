import AppKit
import ApplicationServices
import Carbon
import PasteRouting

final class TerminalTap {
    let processID: pid_t
    let bundleID: String
    let keys = KeyRouter()
    weak var owner: EventRouter?
    var port: CFMachPort?
    var source: CFRunLoopSource?

    init(processID: pid_t, bundleID: String, owner: EventRouter) {
        self.processID = processID
        self.bundleID = bundleID
        self.owner = owner
    }

    func stop() {
        if let port { CGEvent.tapEnable(tap: port, enable: false); CFMachPortInvalidate(port) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
    }
    deinit { stop() }
}

final class EventRouter {
    static let supportURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TermPaste")
    static let statusURL = supportURL.appendingPathComponent("status.json")

    /// The apps from apps.json. A tap is attached to every running copy of an app whose rule routes.
    var rules: [AppRule] = [] {
        didSet {
            rulesByID = Dictionary(rules.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
            synchronize()
        }
    }
    var enabled = true { didSet { synchronize() } }
    var onChange: (() -> Void)?
    /// Called with the app's bundle ID for each image paste turned into Ctrl+V.
    var onRoute: ((String) -> Void)?
    /// Shown in status.json next to the routing state.
    var appsFileProblem: String?
    private(set) var rulesByID: [String: AppRule] = [:]
    private(set) var taps: [pid_t: TerminalTap] = [:]
    /// Listed apps that are running, whether or not they route.
    private(set) var runningListed: Set<String> = []
    /// Listed apps the helper could not attach to.
    private(set) var failed: Set<String> = []
    private(set) var secureInputOwner: SecureInputOwner?
    private(set) var routed = 0
    private(set) var textPassed = 0
    private(set) var lastRoute: [String: Any] = [:]
    private(set) var lastDecision: [String: Any] = [:]
    private var previousStatus = ""
    private var updateQueued = false

    var secureInput: Bool { IsSecureEventInputEnabled() }
    var trusted: Bool { AXIsProcessTrusted() }
    var attached: Set<String> { Set(taps.values.map(\.bundleID)) }

    func synchronize() {
        let running = NSWorkspace.shared.runningApplications.filter {
            !$0.isTerminated && rulesByID[$0.bundleIdentifier ?? ""] != nil
        }
        runningListed = Set(running.compactMap(\.bundleIdentifier))
        let applications = running.filter { rulesByID[$0.bundleIdentifier ?? ""]?.routes == true }
        let secure = secureInput
        secureInputOwner = secure ? SecureInputProbe.owner() : nil
        let eligible = enabled && trusted && !secure
        let wanted = eligible ? Set(applications.map(\.processIdentifier)) : []
        for pid in Array(taps.keys) where !wanted.contains(pid) { taps.removeValue(forKey: pid)?.stop() }
        failed = []
        if eligible {
            for application in applications where taps[application.processIdentifier] == nil {
                add(application)
            }
        }
        publishStatus()
    }

    private func add(_ application: NSRunningApplication) {
        let pid = application.processIdentifier
        guard let bundleID = application.bundleIdentifier else { return }
        let context = TerminalTap(processID: pid, bundleID: bundleID, owner: self)
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        let port = CGEvent.tapCreateForPid(pid: pid, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let context = Unmanaged<TerminalTap>.fromOpaque(info).takeUnretainedValue()
                guard let owner = context.owner else { return Unmanaged.passUnretained(event) }
                return owner.handle(context: context, type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(context).toOpaque())
        guard let port else { failed.insert(bundleID); return }
        context.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        context.source = source
        taps[pid] = context
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func handle(context: TerminalTap, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if enabled && trusted && !secureInput, let port = context.port { CGEvent.tapEnable(tap: port, enable: true) }
            queueStatus()
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == 9 else { return Unmanaged.passUnretained(event) }
        let own = event.getIntegerValueField(.eventSourceUserData) == EventMapping.marker
        let modifiers = EventMapping.modifiers(event)
        // A rule switched off or removed since this tap was attached stops routing at once.
        let rule = rulesByID[context.bundleID].flatMap { $0.routes ? $0 : nil }
        let frontmost = enabled && rule != nil && !secureInput &&
            NSWorkspace.shared.frontmostApplication?.processIdentifier == context.processID
        let pasteDown = type == .keyDown && modifiers == .command && frontmost && !own
        let kind = pasteDown
            ? ClipboardProbe.kind(.general) : .none
        let focusMatches = kind != .nativeImage || rule?.scope != .terminalInput ||
            TerminalFocus.isTerminalInput(processID: context.processID, label: rule?.requiredLabel ?? AppRule.defaultInputLabel)
        let eligible = frontmost && focusMatches
        let action = context.keys.handle(phase: type == .keyDown ? .down : .up, keyCode: keyCode,
            modifiers: modifiers, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
            ownEvent: own, eligible: eligible, clipboard: kind)
        if pasteDown {
            lastDecision = ["application": context.bundleID,
                            "time": ISO8601DateFormatter().string(from: Date()),
                            "result": action == .controlV ? "converted" :
                                (kind == .none ? "no-image" : "not-terminal-input")]
            queueStatus()
        }
        switch action {
        case .controlV:
            if type == .keyDown {
                routed += 1
                lastRoute = ["terminal": context.bundleID, "time": ISO8601DateFormatter().string(from: Date()),
                             "sourcePID": event.getIntegerValueField(.eventSourceUnixProcessID),
                             "pasteboardChangeCount": NSPasteboard.general.changeCount]
                onRoute?(context.bundleID)
                queueStatus()
            }
            EventMapping.controlV(event)
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .forward:
            if type == .keyDown && modifiers == .command && eligible && !own && kind == .none {
                textPassed += 1
                queueStatus()
            }
            return Unmanaged.passUnretained(event)
        }
    }

    private func queueStatus() {
        guard !updateQueued else { return }
        updateQueued = true
        DispatchQueue.main.async { [weak self] in
            self?.updateQueued = false
            self?.publishStatus()
        }
    }

    func stop() {
        for tap in taps.values { tap.stop() }
        taps.removeAll()
        publishStatus(running: false)
    }

    func snapshot(running: Bool = true) -> [String: Any] {
        var status: [String: Any] = [
            "running": running, "pid": ProcessInfo.processInfo.processIdentifier, "enabled": enabled,
            "accessibility": trusted, "secureInput": secureInput,
            "apps": rules.filter(\.routes).map(\.bundleID), "listedRunning": runningListed.sorted(),
            "terminals": taps.values.map(\.bundleID).sorted(),
            "routedImagePastes": routed, "textPastesPassed": textPassed, "lastRoute": lastRoute,
            "lastDecision": lastDecision, "errors": failed.sorted().map { "Could not attach to \(rulesByID[$0]?.name ?? $0)" },
        ]
        if let owner = secureInputOwner {
            status["secureInputNamedByMacOS"] = ["pid": owner.pid, "name": owner.name ?? "", "running": owner.isRunning]
        }
        if let appsFileProblem { status["appsFileProblem"] = appsFileProblem }
        return status
    }

    func publishStatus(running: Bool = true) {
        let status = snapshot(running: running)
        guard let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys, .prettyPrinted]),
              let text = String(data: data, encoding: .utf8), text != previousStatus else { return }
        previousStatus = text
        do {
            try FileManager.default.createDirectory(at: Self.statusURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: Self.statusURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: Self.statusURL.path)
        } catch { NSLog("Could not write routing status: %@", error.localizedDescription) }
        onChange?()
    }
}
