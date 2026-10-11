import AppKit
import ApplicationServices
import PasteRouting

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState()
    private var item: NSStatusItem!
    private let menu = NSMenu()
    private let header = StatusHeaderView()
    private let headerItem = NSMenuItem()
    private var settings: SettingsWindowController?
    private var appearanceObservation: NSKeyValueObservation?
    /// What the menu bar picture currently shows. Assigning a new image makes the button report its
    /// appearance again, so drawing only on a real change keeps that from looping.
    private var drawnGlyph: (tone: StatusGlyph.Tone, appearance: NSAppearance.Name)?
    private var menuIsOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? LoginAgent.label
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains(where: {
            $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }) { NSApp.terminate(nil); return }
        NSApp.mainMenu = Self.mainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        headerItem.view = header
        state.onChange = { [weak self] in self?.stateChanged() }
        appearanceObservation = item.button?.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.renderGlyph() }
        }
        setUpLaunchAtLogin()
        state.start()
        renderGlyph()
        if !state.trusted { requestPermission() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stop()
    }

    // MARK: - Menu bar picture

    private func stateChanged() {
        renderGlyph()
        if menuIsOpen {
            updateHeader()
            menu.itemChanged(headerItem)
        }
    }

    private var tone: StatusGlyph.Tone {
        if !state.trusted { return .needsAccessibility }
        if state.paused { return .paused }
        if state.secureInput { return .secureInput }
        return .on
    }

    private func renderGlyph() {
        guard let button = item?.button else { return }
        let tone = tone
        let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? .aqua
        if let drawnGlyph, drawnGlyph.tone == tone, drawnGlyph.appearance == appearance { return }
        drawnGlyph = (tone, appearance)
        button.image = StatusGlyph.image(tone, appearance: NSAppearance(named: appearance) ?? button.effectiveAppearance)
        let words = switch tone {
        case .on: "on"
        case .paused: "paused"
        case .needsAccessibility: "needs Accessibility"
        case .secureInput: "paused by Secure Input"
        }
        button.setAccessibilityLabel("TermPaste: \(words)")
        button.toolTip = "TermPaste — \(words)"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        state.refresh()
        buildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    private func buildMenu() {
        menu.removeAllItems()
        updateHeader()
        menu.addItem(headerItem)
        if !state.trusted { menu.addItem(actionItem("Open Accessibility Settings…", #selector(openAccessibilitySettings))) }
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: "Apps"))
        for rule in state.apps { menu.addItem(appItem(rule)) }
        if let candidate = state.quickAddCandidate {
            let add = actionItem("Add “\(candidate.name)”", #selector(addPrevious))
            add.attributedTitle = titleWithValue("Add “\(candidate.name)”", value: "frontmost app")
            add.image = AppIdentity.icon(for: candidate.bundleID)
            add.toolTip = "While the clipboard holds an image, ⌘V becomes Ctrl+V in \(candidate.name)."
            menu.addItem(add)
        }
        menu.addItem(actionItem("Edit Apps…", #selector(editApps)))
        menu.addItem(.separator())

        menu.addItem(actionItem(state.paused ? "Resume Image Paste" : "Pause Image Paste", #selector(togglePaused)))
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        // Shown as ⌘, on every layout, as Apple's apps do, instead of the key in the comma's US position.
        settingsItem.allowsAutomaticKeyEquivalentLocalization = false
        menu.addItem(settingsItem)
        let login = actionItem("Launch at Login", #selector(toggleLaunchAtLogin))
        login.state = state.launchAtLogin ? .on : .off
        menu.addItem(login)
        let quit = NSMenuItem(title: "Quit TermPaste", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func updateHeader() {
        if !state.trusted {
            header.update(tone: .failure, title: "Needs Accessibility",
                          lines: ["Image paste can’t see ⌘V until you allow it in System Settings."], warnings: fileWarnings)
        } else if state.paused {
            header.update(tone: .paused, title: "Paused", lines: ["⌘V stays a normal paste until you resume."], warnings: fileWarnings)
        } else if state.secureInput {
            header.update(tone: .warning, title: "Paused — Secure Input is on", lines: state.secureInputLines, warnings: fileWarnings)
        } else {
            let names = state.connectedNames
            let connected = switch names.count {
            case 0: "No listed app is running"
            case 1: "\(names[0]) is connected"
            default: names.dropLast().joined(separator: ", ") + " and \(names[names.count - 1]) are connected"
            }
            let failures = state.apps.filter { state.status(for: $0) == .cannotAttach }.map { "Can’t attach to \($0.name)" }
            header.update(tone: .on, title: "Image paste is on", lines: [connected, state.pasteSummary()],
                          warnings: failures + fileWarnings)
        }
    }

    private var fileWarnings: [String] {
        state.fileProblem.map { ["\($0). Using the last list that could be read."] } ?? []
    }

    private func appItem(_ rule: AppRule) -> NSMenuItem {
        let entry = NSMenuItem(title: rule.name, action: nil, keyEquivalent: "")
        var value = state.status(for: rule).text
        if rule.enabled && rule.scope == .terminalInput { value += " · terminal input" }
        entry.attributedTitle = titleWithValue(rule.name, value: value)
        entry.state = rule.enabled ? .on : .off
        entry.image = AppIdentity.icon(for: rule.bundleID)

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let enabled = actionItem("Enabled", #selector(toggleAppEnabled(_:)), app: rule.bundleID)
        enabled.state = rule.enabled ? .on : .off
        submenu.addItem(enabled)
        submenu.addItem(.separator())
        submenu.addItem(.sectionHeader(title: "Where"))
        let whole = actionItem("Whole app", #selector(chooseWholeApp(_:)), app: rule.bundleID)
        whole.state = rule.scope == .app ? .on : .off
        submenu.addItem(whole)
        let terminal = actionItem("Terminal input only", #selector(chooseTerminalInput(_:)), app: rule.bundleID)
        terminal.state = rule.scope == .terminalInput ? .on : .off
        terminal.toolTip = "Only while the focused field is named “\(rule.requiredLabel)”, as in Orca."
        submenu.addItem(terminal)
        submenu.addItem(.separator())
        submenu.addItem(actionItem("Remove “\(rule.name)”", #selector(removeApp(_:)), app: rule.bundleID))
        entry.submenu = submenu
        return entry
    }

    private func actionItem(_ title: String, _ action: Selector, app bundleID: String? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.representedObject = bundleID
        return entry
    }

    /// The value sits right-aligned in secondary text, as in System Settings menus.
    private func titleWithValue(_ title: String, value: String) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 300)]
        let font = NSFont.menuFont(ofSize: 0)
        let text = NSMutableAttributedString(string: title, attributes: [.font: font, .paragraphStyle: paragraph])
        text.append(NSAttributedString(string: "\t" + value, attributes: [
            .font: font, .paragraphStyle: paragraph, .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return text
    }

    // MARK: - Actions

    @objc private func toggleAppEnabled(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        state.setEnabled(bundleID, sender.state != .on)
    }

    @objc private func chooseWholeApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        state.setScope(bundleID, .app)
    }

    @objc private func chooseTerminalInput(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        state.setScope(bundleID, .terminalInput)
    }

    @objc private func removeApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        state.remove(bundleID)
    }

    @objc private func addPrevious() { state.addPrevious() }
    @objc private func editApps() { showSettings(.apps) }
    @objc private func openSettings() { showSettings(.general) }
    @objc private func togglePaused() { state.setPaused(!state.paused) }
    @objc private func toggleLaunchAtLogin() { state.setLaunchAtLogin(!state.launchAtLogin) }
    @objc private func openAccessibilitySettings() { state.openAccessibilitySettings() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    private func showSettings(_ tab: SettingsTab) {
        if settings == nil { settings = SettingsWindowController(state: state) }
        settings?.show(tab)
    }

    private func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// The app has no menu bar of its own; these key equivalents serve the Settings window.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit TermPaste", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = appMenu
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        return main
    }

    // MARK: - Launch at Login

    /// On by default, as the user asked on 2026-10-11: set once for an installed copy, then changed from the menu.
    /// Later launches only point an existing agent at this copy. A build inside the repository never touches it.
    private func setUpLaunchAtLogin() {
        guard LoginAgent.isInstalledLocation(Bundle.main.bundlePath, home: FileManager.default.homeDirectoryForCurrentUser) else { return }
        do {
            if UserDefaults.standard.bool(forKey: "launchAtLoginConfigured") { try LoginItem.refreshIfEnabled() }
            else { try LoginItem.enable(); UserDefaults.standard.set(true, forKey: "launchAtLoginConfigured") }
        } catch { NSLog("TermPaste: Launch at Login not set: %@", error.localizedDescription) }
    }
}
