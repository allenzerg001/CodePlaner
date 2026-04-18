import Cocoa
import Combine
import SwiftUI

protocol StatusBarProvider {
    func statusItem(withLength length: CGFloat) -> NSStatusItem
}

class SystemStatusBarProvider: StatusBarProvider {
    func statusItem(withLength length: CGFloat) -> NSStatusItem {
        NSStatusBar.system.statusItem(withLength: length)
    }
}

final class StatusBarController: NSObject, NSMenuDelegate {
    struct ServiceActionConfiguration {
        let titleKey: String
        let action: Selector
        let symbolName: String
        let color: NSColor
    }

    private let statusItem: NSStatusItem
    private let pythonManager: PythonProcessManager
    private let configManager: ConfigManager
    private let usageService: UsageStatsService
    private var cancellables = Set<AnyCancellable>()

    init(
        pythonManager: PythonProcessManager,
        configManager: ConfigManager,
        usageService: UsageStatsService,
        statusBarProvider: StatusBarProvider = SystemStatusBarProvider()
    ) {
        self.pythonManager = pythonManager
        self.configManager = configManager
        self.usageService = usageService
        self.statusItem = statusBarProvider.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupDropdown()
        observeStatus()
    }

    private func setupDropdown() {
        updateStatusBarIcon()
        let menu = buildDropdown()
        menu.delegate = self
        statusItem.menu = menu
    }

    func buildDropdown() -> NSMenu {
        let menu = NSMenu()

        let serviceKey = pythonManager.isRunning ? "dropdown_service_running" : "dropdown_service_stopped"
        let serviceItem = NSMenuItem(title: localizedMenuString(serviceKey), action: nil, keyEquivalent: "")
        serviceItem.image = symbolImage(
            pythonManager.isRunning ? "checkmark.circle.fill" : "xmark.circle.fill",
            color: pythonManager.isRunning ? .systemGreen : .systemRed
        )
        menu.addItem(serviceItem)

        let serviceAction = Self.serviceActionConfiguration(isRunning: pythonManager.isRunning)
        let serviceActionItem = NSMenuItem(
            title: localizedMenuString(serviceAction.titleKey),
            action: serviceAction.action,
            keyEquivalent: ""
        )
        serviceActionItem.target = self
        serviceActionItem.image = symbolImage(serviceAction.symbolName, color: serviceAction.color)
        menu.addItem(serviceActionItem)

        menu.addItem(.separator())

        let providerHeader = NSMenuItem(title: localizedMenuString("dropdown_providers"), action: nil, keyEquivalent: "")
        providerHeader.isEnabled = false
        menu.addItem(providerHeader)
        let providers = configuredProvidersWithKeys()

        if providers.isEmpty {
            let emptyItem = NSMenuItem(title: localizedMenuString("dropdown_no_configured_providers"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for provider in providers {
                let item = NSMenuItem(title: providerLabel(for: provider), action: #selector(switchProvider(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = provider.name
                item.state = provider.name == configManager.defaultProvider ? .on : .off
                item.image = providerLogoImage(for: provider)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let clientsHeader = NSMenuItem(title: localizedMenuString("dropdown_top_clients"), action: nil, keyEquivalent: "")
        clientsHeader.isEnabled = false
        menu.addItem(clientsHeader)
        let topClients = topClientsByRequestCount()

        if topClients.isEmpty {
            let emptyItem = NSMenuItem(title: localizedMenuString("dropdown_no_clients"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for client in topClients {
                let title = String(format: localizedMenuString("dropdown_client_requests"), client.name, client.requests)
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let serviceHeader = NSMenuItem(title: localizedMenuString("dropdown_service_details"), action: nil, keyEquivalent: "")
        serviceHeader.isEnabled = false
        menu.addItem(serviceHeader)

        let serviceURLItem = copyableValueItem(
            title: String(format: localizedMenuString("dropdown_service_url"), pythonManager.serviceURL),
            value: pythonManager.serviceURL,
            symbolName: "link"
        )
        menu.addItem(serviceURLItem)

        let apiKeyValue = pythonManager.localAPIKey
        let apiKeyItem = copyableValueItem(
            title: String(format: localizedMenuString("dropdown_api_key"), apiKeyValue),
            value: apiKeyValue,
            symbolName: "key"
        )
        menu.addItem(apiKeyItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: NSLocalizedString("settings_title", comment: ""), action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let openMainItem = NSMenuItem(title: NSLocalizedString("dropdown_open_usage", comment: ""), action: #selector(openMainWindow), keyEquivalent: "")
        openMainItem.target = self
        menu.addItem(openMainItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: NSLocalizedString("dropdown_quit", comment: ""), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    static func serviceActionConfiguration(isRunning: Bool) -> ServiceActionConfiguration {
        if isRunning {
            return ServiceActionConfiguration(
                titleKey: "dropdown_stop_service",
                action: #selector(stopService),
                symbolName: "stop.circle.fill",
                color: .systemRed
            )
        }

        return ServiceActionConfiguration(
            titleKey: "dropdown_start_service",
            action: #selector(startService),
            symbolName: "play.circle.fill",
            color: .systemGreen
        )
    }

    private func localizedMenuString(_ key: String) -> String {
        let localized = NSLocalizedString(key, comment: "")
        guard localized == key else {
            return localized
        }

        let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") == true
        let zhFallbacks: [String: String] = [
            "dropdown_service_running": "服务: 运行中",
            "dropdown_service_stopped": "服务: 已停止",
            "dropdown_default_tag": "默认",
            "dropdown_start_service": "启动服务",
            "dropdown_stop_service": "停止服务",
            "dropdown_service_details": "本地服务",
            "dropdown_service_url": "服务地址: %@",
            "dropdown_api_key": "API Key: %@",
            "dropdown_providers": "厂商",
            "dropdown_no_configured_providers": "未配置 App Key",
            "dropdown_top_clients": "客户端",
            "dropdown_no_clients": "暂无客户端",
            "dropdown_client_requests": "%@ · %d 次请求",
            "dropdown_open_usage": "打开用量面板...",
            "dropdown_quit": "退出",
            "settings_none": "无"
        ]
        let enFallbacks: [String: String] = [
            "dropdown_service_running": "Service: Running",
            "dropdown_service_stopped": "Service: Stopped",
            "dropdown_default_tag": "Default",
            "dropdown_start_service": "Start Service",
            "dropdown_stop_service": "Stop Service",
            "dropdown_service_details": "Local Service",
            "dropdown_service_url": "URL: %@",
            "dropdown_api_key": "API Key: %@",
            "dropdown_providers": "Providers",
            "dropdown_no_configured_providers": "No configured API keys",
            "dropdown_top_clients": "Clients",
            "dropdown_no_clients": "No clients yet",
            "dropdown_client_requests": "%@ · %d requests",
            "dropdown_open_usage": "Open Usage Dashboard...",
            "dropdown_quit": "Quit",
            "settings_none": "None"
        ]

        return (prefersChinese ? zhFallbacks[key] : enFallbacks[key]) ?? key.replacingOccurrences(of: "dropdown_", with: "")
    }

    private func observeStatus() {
        Publishers.MergeMany(
            pythonManager.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            pythonManager.$servicePort.map { _ in () }.eraseToAnyPublisher(),
            pythonManager.$lastError.map { _ in () }.eraseToAnyPublisher(),
            configManager.$defaultProvider.map { _ in () }.eraseToAnyPublisher(),
            configManager.$providers.map { _ in () }.eraseToAnyPublisher(),
            usageService.$todayStats.map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.setupDropdown()
        }
        .store(in: &cancellables)
    }

    func menuWillOpen(_ menu: NSMenu) {
        setupDropdown()
    }

    @objc private func openMainWindow() {
        NotificationCenter.default.post(name: .codingPlanOpenMainWindow, object: nil)
    }

    @objc private func openSettingsWindow() {
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(#selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: nil, from: nil)
        }
    }

    @objc private func startService() {
        pythonManager.start()
    }

    @objc private func stopService() {
        pythonManager.stop()
    }

    @objc private func switchProvider(_ sender: NSMenuItem) {
        guard let providerName = sender.representedObject as? String else {
            return
        }
        configManager.setDefaultProvider(providerName)
    }

    @objc private func quit() {
        pythonManager.stop(waitUntilStopped: true)
        NSApp.terminate(nil)
    }

    private func defaultProviderLabel() -> String {
        guard !configManager.defaultProvider.isEmpty else {
            return localizedMenuString("settings_none")
        }
        guard let provider = configManager.providers.first(where: { $0.name == configManager.defaultProvider }) else {
            return displayName(for: configManager.defaultProvider)
        }
        return provider.displayName.isEmpty ? provider.name : provider.displayName
    }

    private func defaultProviderImage() -> NSImage? {
        guard let provider = configManager.providers.first(where: { $0.name == configManager.defaultProvider }) else {
            return symbolImage("star.fill", color: .systemYellow)
        }
        return providerLogoImage(for: provider) ?? symbolImage("star.fill", color: .systemYellow)
    }

    private func configuredProvidersWithKeys() -> [Provider] {
        configManager.configuredProviders()
            .sorted { $0.name < $1.name }
    }

    private func providerLabel(for provider: Provider) -> String {
        let label = displayName(for: provider.name)
        if provider.name == configManager.defaultProvider {
            return "\(label) • \(localizedMenuString("dropdown_default_tag"))"
        }
        return label
    }

    private func displayName(for providerName: String) -> String {
        guard let provider = configManager.providers.first(where: { $0.name == providerName }) else {
            return providerName
        }
        return provider.displayName.isEmpty ? provider.name : provider.displayName
    }

    private func topClientsByRequestCount() -> [(name: String, requests: Int)] {
        guard let byClient = usageService.todayStats["by_client"] as? [String: [String: Any]] else {
            return []
        }

        return byClient
            .map { key, value in
                (
                    name: key,
                    requests: integerValue(value["requests"])
                )
            }
            .sorted {
                if $0.requests == $1.requests {
                    return $0.name < $1.name
                }
                return $0.requests > $1.requests
            }
            .prefix(3)
            .map { $0 }
    }

    private func integerValue(_ value: Any?) -> Int {
        switch value {
        case let number as Int:
            return number
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string) ?? 0
        default:
            return 0
        }
    }

    private func symbolImage(_ name: String, color: NSColor) -> NSImage? {
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        let image = base.withSymbolConfiguration(config)
        image?.size = NSSize(width: 13, height: 13)
        return image
    }

    private func copyableValueItem(title: String, value: String, symbolName: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(copyValue(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = value
        item.image = symbolImage(symbolName, color: .secondaryLabelColor)
        item.isEnabled = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return item
    }

    @objc private func copyValue(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func providerLogoImage(for provider: Provider) -> NSImage? {
        guard let image = NSImage(named: configManager.providerLogoAssetName(for: provider.name)) else {
            return nil
        }
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }
        button.image = makeAppIconImage(isRunning: pythonManager.isRunning)
        button.imagePosition = .imageOnly
        button.toolTip = pythonManager.isRunning
            ? localizedMenuString("dropdown_service_running")
            : localizedMenuString("dropdown_service_stopped")
    }

    private func makeAppIconImage(isRunning: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let bounds = NSRect(origin: .zero, size: size)
        let rounded = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.0, dy: 1.0), xRadius: 4, yRadius: 4)

        NSColor.controlBackgroundColor.setFill()
        rounded.fill()

        NSColor.labelColor.setStroke()
        rounded.lineWidth = 1.1
        rounded.stroke()

        NSColor.systemTeal.setFill()
        let topBar = NSBezierPath(roundedRect: NSRect(x: 4.2, y: 10.4, width: 9.0, height: 2.0), xRadius: 1.0, yRadius: 1.0)
        topBar.fill()

        NSColor.systemOrange.setFill()
        let bottomBar = NSBezierPath(roundedRect: NSRect(x: 4.2, y: 5.8, width: 6.0, height: 2.0), xRadius: 1.0, yRadius: 1.0)
        bottomBar.fill()

        NSColor.labelColor.setFill()
        let node = NSBezierPath(ovalIn: NSRect(x: 12.1, y: 5.9, width: 2.6, height: 2.6))
        node.fill()

        let statusColor = isRunning ? NSColor.systemGreen : NSColor.systemRed
        statusColor.setFill()
        let statusDot = NSBezierPath(ovalIn: NSRect(x: 12.5, y: 12.2, width: 4.8, height: 4.8))
        statusDot.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
