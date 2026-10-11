import AppKit
import Observation
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general, apps, diagnostics

    var title: String {
        switch self {
        case .general: "General"
        case .apps: "Apps"
        case .diagnostics: "Diagnostics"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .apps: "square.grid.2x2"
        case .diagnostics: "waveform.path.ecg"
        }
    }

    var identifier: NSToolbarItem.Identifier { NSToolbarItem.Identifier(rawValue) }
}

@Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
}

/// A plain window with preference-style toolbar tabs around the SwiftUI panes, as macOS settings
/// windows look. The window is kept and shown again rather than rebuilt.
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
    private let navigation = SettingsNavigation()

    init(state: AppState) {
        let host = NSHostingController(rootView: SettingsView(state: state, navigation: navigation))
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .preference
        super.init(window: window)
        let toolbar = NSToolbar(identifier: "TermPasteSettings")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.center()
        select(.general)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ tab: SettingsTab) {
        select(tab)
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    private func select(_ tab: SettingsTab) {
        navigation.tab = tab
        window?.toolbar?.selectedItemIdentifier = tab.identifier
        window?.title = tab.title
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { SettingsTab.allCases.map(\.identifier) }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { SettingsTab.allCases.map(\.identifier) }
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { SettingsTab.allCases.map(\.identifier) }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: identifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(selectTab(_:))
        return item
    }

    @objc private func selectTab(_ sender: NSToolbarItem) {
        if let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) { select(tab) }
    }
}
