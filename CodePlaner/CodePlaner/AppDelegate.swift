import Cocoa
import AppKit
import Combine

extension Notification.Name {
    static let codingPlanOpenMainWindow = Notification.Name("codingPlanOpenMainWindow")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let runtime = AppRuntime.shared
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initial state: hide Dock icon if no windows are shown at startup (standard for menu bar apps)
        // But here we might want to show it if MainView is shown by default.
        // SwiftUI shows the first WindowGroup by default.
        NSApp.setActivationPolicy(.regular)
        
        // Manual fallback for app icon if needed
        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }

        DispatchQueue.main.async {
            self.runtime.pythonManager.start()

            self.statusBarController = StatusBarController(
                pythonManager: self.runtime.pythonManager,
                configManager: self.runtime.configManager,
                usageService: self.runtime.usageService
            )
            
            // Start observing window status after a short delay to let SwiftUI initialize
            self.setupWindowObservers()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openMainWindow),
            name: .codingPlanOpenMainWindow,
            object: nil
        )

        // Auto-open main window during UI tests
        if CommandLine.arguments.contains("--uitesting") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openMainWindow()
            }
        }
    }

    private func setupWindowObservers() {
        // Observe key window changes and visibility
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            self.updateActivationPolicy()
        }
        
        // Specifically catch window close and order out events
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            self.schedulePolicyUpdate()
        }
        
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { _ in
            self.schedulePolicyUpdate()
        }
    }

    private func schedulePolicyUpdate() {
        // Delay update to let SwiftUI finish its window closing cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        // Filter windows: must be visible, not a panel/menu, and have a non-empty title or be a standard SwiftUI window
        let visibleWindows = NSApp.windows.filter { window in
            guard window.isVisible else { return false }
            
            // Ignore status bar items, panels, and internal SwiftUI windows
            let className = String(describing: type(of: window))
            if className.contains("NSStatusBarWindow") || window.isKind(of: NSPanel.self) {
                return false
            }
            
            // Standard windows usually have a title or are certain classes
            return window.canBecomeMain || window.canBecomeKey
        }
        
        print("[AppDelegate] Visible windows count: \(visibleWindows.count)")
        for w in visibleWindows {
            print("  - Window: \(w.title) (Class: \(type(of: w)))")
        }

        if visibleWindows.isEmpty {
            if NSApp.activationPolicy() != .accessory {
                print("[AppDelegate] No visible windows, switching to .accessory mode")
                NSApp.setActivationPolicy(.accessory)
            }
        } else {
            if NSApp.activationPolicy() != .regular {
                print("[AppDelegate] Windows detected, switching to .regular mode")
                NSApp.setActivationPolicy(.regular)
                // If we are opening a window, we usually want focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        self.runtime.pythonManager.stop(waitUntilStopped: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.runtime.pythonManager.stop(waitUntilStopped: true)
        return .terminateNow
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    @objc func openMainWindow() {
        DispatchQueue.main.async {
            // 1. Show Dock icon and force regular mode
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
            }
            
            // 2. Aggressively bring app to front of ALL other apps
            NSApp.activate(ignoringOtherApps: true)

            // 3. Try to find an existing window
            let mainWindows = NSApp.windows.filter { 
                !$0.isKind(of: NSPanel.self) && 
                String(describing: type(of: $0)).contains("Window") &&
                !String(describing: type(of: $0)).contains("NSStatusBarWindow")
            }
            
            if let window = mainWindows.first {
                if window.isMiniaturized { window.deminiaturize(nil) }
                
                // Ensure visibility and layer priority
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                
                // Extra insurance to get focus
                NSApp.activate(ignoringOtherApps: true)
                
                print("[AppDelegate] Main window aggressively brought to front")
            } else {
                // 4. If no window, trigger creation
                print("[AppDelegate] No window found, triggering creation and focus")
                _ = self.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
                
                // Second pass to catch the newly created window and bring it to front
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.orderFrontRegardless()
                }
            }
        }
    }
}

