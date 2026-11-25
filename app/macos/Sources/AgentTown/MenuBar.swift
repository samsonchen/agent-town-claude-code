import AppKit
import Combine
import SwiftUI

/// The menu bar icon and its menu (docs/spec.md: The menu bar icon). An AppKit status item, not
/// SwiftUI's MenuBarExtra: on recent macOS the system handles a MenuBarExtra's clicks itself, so
/// the app could not tell a click from a menu opening.
///
/// A click while the office window is hidden shows it; a click while it is showing opens the
/// menu. A right-click or Control-click always opens the menu. The menu is built each time it
/// opens, so its check marks match the window and settings at that moment.
@MainActor
final class MenuBar: NSObject {
    static let shared = MenuBar()

    private var item: NSStatusItem?
    private var subscriptions: Set<AnyCancellable> = []
    /// SwiftUI's openWindow and dismissWindow, handed over by `WindowActions` hosted in the icon.
    var openWindow: ((String) -> Void)?
    var dismissWindow: ((String) -> Void)?

    func start() {
        guard item == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // A SwiftUI view in the button, for SwiftUI's window actions; it draws nothing.
        let host = NSHostingView(rootView: WindowActions())
        host.frame = .zero
        button.addSubview(host)
        updateIcon()
        // With a dot while an update is available (spec: Updates).
        Updater.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &subscriptions)
    }

    private func updateIcon() {
        item?.button?.image = MenuIcon.image(dot: Updater.shared.hasUpdate)
    }

    /// The office window is on screen.
    static var officeShown: Bool {
        NSApp.windows.contains { $0.isVisible && $0.title == "agent-town" }
    }

    @objc private func clicked() {
        let e = NSApp.currentEvent
        let forMenu = e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true
        if !forMenu && !Self.officeShown {
            setOfficeShown(true)
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        guard let item, let button = item.button else { return }
        item.menu = makeMenu()
        button.performClick(nil) // opens the menu under the icon, as a menu bar menu does
        item.menu = nil // so the next click comes back to `clicked`
    }

    /// Show agent-town: shows or hides the office window. Showing it also works while it is hidden
    /// for having no session.
    func setOfficeShown(_ on: Bool) {
        let presence = WindowPresence.shared
        if on {
            presence.showNow()
            openWindow?("town")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            dismissWindow?("town")
        }
        presence.setWanted(on)
    }

    private func open(_ id: String) {
        openWindow?(id)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: The menu

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let updater = Updater.shared
        if let r = updater.appUpdate {
            menu.addItem(action(String(format: Labels.text("agent-town %@ is available…"), r.version)) { Updater.shared.showWindow() })
        }
        if let v = updater.pluginUpdate {
            menu.addItem(action(String(format: Labels.text("town-link %@ is available…"), v)) { Updater.shared.showWindow() })
        }
        if updater.hasUpdate { menu.addItem(.separator()) }
        menu.addItem(action(Labels.text("About agent-town")) { [weak self] in self?.open("about") })
        menu.addItem(.separator())
        // While hidden for having no session, the item is off; choosing it shows the office anyway.
        let presence = WindowPresence.shared
        let shown = presence.wanted && !presence.autoHidden
        menu.addItem(action(Labels.text("Show agent-town"), on: shown) { [weak self] in self?.setOfficeShown(!shown) })
        let d = UserDefaults.standard
        menu.addItem(action(Labels.text("Stay on top"), on: d.bool(forKey: Prefs.stayOnTop)) {
            d.set(!d.bool(forKey: Prefs.stayOnTop), forKey: Prefs.stayOnTop)
        })
        menu.addItem(action(Labels.text("Sound"), on: Prefs.isOn(Prefs.sound)) {
            d.set(!Prefs.isOn(Prefs.sound), forKey: Prefs.sound)
        })
        menu.addItem(.separator())
        menu.addItem(action(Labels.text("Settings…"), key: ",") { [weak self] in self?.open("settings") })
        menu.addItem(.separator())
        menu.addItem(action(Labels.text("Quit agent-town"), key: "q") { NSApp.terminate(nil) })
        return menu
    }

    private func action(_ title: String, on: Bool? = nil, key: String = "", _ run: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = MenuAction(title: title, run: run)
        item.keyEquivalent = key
        if let on { item.state = on ? .on : .off }
        return item
    }
}

/// A menu item that runs a closure.
private final class MenuAction: NSMenuItem {
    private let run: @MainActor () -> Void

    init(title: String, run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { MainActor.assumeIsolated { run() } }
}
