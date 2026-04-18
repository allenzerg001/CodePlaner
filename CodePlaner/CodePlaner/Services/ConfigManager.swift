import Foundation
import Combine
import CryptoKit

class ConfigManager: ObservableObject {
    @Published var providers: [Provider] = []
    @Published var defaultProvider: String = ""
    @Published var fallbackEnabled: Bool = true
    @Published var servicePort: Int = 9800
    @Published var allowLAN: Bool = false
    @Published var localAPIKey: String = "sk-codingplan-local"
    @Published var appLanguage: String = "auto" // "auto", "en", "zh-Hans"

    private let configPath: String
    private static let defaultCryptoKey = "codingplan-dev-key-change-in-prod"
    
    // Cache for decrypted API keys
    private var providerAPIKeys: [String: String] = [:]

    private static let logoAssetNames: [String: String] = [
        "bailian": "bailian",
        "volcengine": "volcengine",
        "zhipu": "zhipu",
        "deepseek": "deepseek",
        "moonshot": "moonshot",
        "minimax": "minimax",
        "xiaomi": "xiaomi",
        "siliconflow": "siliconflow",
        "hunyuan": "hunyuan",
        "openai": "openai",
        "anthropic": "anthropic",
        "openrouter": "openrouter",
        "gemini": "gemini",
        "mistral": "mistral",
        "groq": "groq",
        "cohere": "cohere",
        "together": "together",
    ]

    // MARK: - Preset providers

    static let presetProviders: [Provider] = [
        Provider(name: "bailian",     displayName: nil,      icon: "🔶", enabled: false,
                 baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
                 models: []),
        Provider(name: "volcengine",  displayName: nil,      icon: "🌋", enabled: false,
                 baseURL: "https://ark.cn-beijing.volces.com/api/v3",
                 models: []),
        Provider(name: "zhipu",       displayName: nil,      icon: "🧠", enabled: false,
                 baseURL: "https://open.bigmodel.cn/api/paas/v4",
                 models: []),
        Provider(name: "deepseek",    displayName: nil,      icon: "🐋", enabled: false,
                 baseURL: "https://api.deepseek.com/v1",
                 models: []),
        Provider(name: "moonshot",    displayName: nil,      icon: "🌙", enabled: false,
                 baseURL: "https://api.moonshot.cn/v1",
                 models: []),
        Provider(name: "minimax",     displayName: nil,      icon: "⚡", enabled: false,
                 baseURL: "https://api.minimax.chat/v1",
                 models: []),
        Provider(name: "xiaomi",      displayName: nil, icon: "📱", enabled: false,
                 baseURL: "https://api.xiaomi.com/v1",
                 models: []),
        Provider(name: "siliconflow", displayName: nil,   icon: "💎", enabled: false,
                 baseURL: "https://api.siliconflow.cn/v1",
                 models: []),
        Provider(name: "hunyuan",     displayName: nil,   icon: "🔵", enabled: false,
                 baseURL: "https://api.hunyuan.cloud.tencent.com/v1",
                 models: []),
        Provider(name: "openai", displayName: nil, icon: "🤖", enabled: false,
                 baseURL: "https://api.openai.com/v1",
                 models: []),
        Provider(name: "anthropic", displayName: nil, icon: "🔮", enabled: false,
                 baseURL: "https://api.anthropic.com/v1",
                 models: []),
        Provider(name: "openrouter", displayName: nil, icon: "🔀", enabled: false,
                 baseURL: "https://openrouter.ai/api/v1",
                 models: []),
        Provider(name: "gemini", displayName: nil, icon: "💫", enabled: false,
                 baseURL: "https://generativelanguage.googleapis.com/v1beta/openai",
                 models: []),
        Provider(name: "mistral", displayName: nil, icon: "🌊", enabled: false,
                 baseURL: "https://api.mistral.ai/v1",
                 models: []),
        Provider(name: "groq", displayName: nil, icon: "⚡", enabled: false,
                 baseURL: "https://api.groq.com/openai/v1",
                 models: []),
        Provider(name: "cohere", displayName: nil, icon: "🟣", enabled: false,
                 baseURL: "https://api.cohere.com/v2",
                 models: []),
        Provider(name: "together", displayName: nil, icon: "🤝", enabled: false,
                 baseURL: "https://api.together.xyz/v1",
                 models: []),
    ]

    // MARK: - Init

    init(
        configPath: String? = nil
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if let configPath = configPath {
            self.configPath = configPath
        } else {
            self.configPath = (home as NSString).appendingPathComponent(".codingplan/config.json")
        }
        load()
    }

    // MARK: - Load / Save

    func load() {
        var loaded: [Provider] = []
        let presetBaseURLs = Dictionary(uniqueKeysWithValues: ConfigManager.presetProviders.map { ($0.name, $0.baseURL) })

        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            defaultProvider = json["default_provider"] as? String ?? ""
            fallbackEnabled = json["fallback_enabled"] as? Bool ?? true
            localAPIKey = json["local_api_key"] as? String ?? "sk-codingplan-local"
            appLanguage = json["language"] as? String ?? "auto"
            if let server = json["server"] as? [String: Any] {
                servicePort = server["port"] as? Int ?? 9800
                allowLAN = server["allow_lan"] as? Bool ?? false
            } else {
                servicePort = 9800
                allowLAN = false
            }

            if let providersDict = json["providers"] as? [String: [String: Any]] {
                loaded = providersDict.map { name, cfg in
                    let loadedBaseURL = cfg["base_url"] as? String ?? ""
                    
                    // Extract and decrypt API key
                    if let encryptedKey = cfg["api_key_encrypted"] as? String, !encryptedKey.isEmpty {
                        providerAPIKeys[name] = decryptAPIKey(encryptedKey)
                    }
                    
                    return Provider(
                        name: name,
                        enabled: cfg["enabled"] as? Bool ?? false,
                        baseURL: loadedBaseURL.isEmpty ? (presetBaseURLs[name] ?? "") : loadedBaseURL,
                        models: cfg["models"] as? [String] ?? [],
                        enabledModels: cfg["enabled_models"] as? [String]
                    )
                }
            }
        }

        // Merge presets: insert any preset that isn't already in the loaded list
        let loadedNames = Set(loaded.map { $0.name })
        let missing = ConfigManager.presetProviders.filter { !loadedNames.contains($0.name) }
        providers = (loaded + missing).sorted { $0.name < $1.name }
    }

    func updateProvider(name: String, enabled: Bool) {
        if let index = providers.firstIndex(where: { $0.name == name }) {
            providers[index].enabled = enabled
            save()
        }
    }

    func updateProvider(name: String, baseURL: String) {
        if let index = providers.firstIndex(where: { $0.name == name }) {
            providers[index].baseURL = baseURL
            save()
        }
    }

    func updateProviderModels(name: String, models: [String]) {
        if let index = providers.firstIndex(where: { $0.name == name }) {
            // Only update and save if models actually changed to avoid excessive reloads
            if providers[index].models != models {
                providers[index].models = models
                // If enabledModels is empty, set default (first 3)
                if providers[index].enabledModels.isEmpty {
                    providers[index].enabledModels = Array(models.prefix(3))
                }
                save()
            }
        }
    }

    func updateProviderEnabledModels(name: String, enabledModels: [String]) {
        if let index = providers.firstIndex(where: { $0.name == name }) {
            providers[index].enabledModels = enabledModels
            save()
        }
    }

    func setDefaultProvider(_ name: String) {
        defaultProvider = name
        save()
    }

    func setFallbackEnabled(_ enabled: Bool) {
        fallbackEnabled = enabled
        save()
    }

    func setServicePort(_ port: Int) {
        guard port > 0 else { return }
        servicePort = port
        save()
    }

    func setAllowLAN(_ enabled: Bool) {
        allowLAN = enabled
        save()
    }

    func setLocalAPIKey(_ key: String) {
        localAPIKey = key
        save()
    }

    func setLanguage(_ language: String) {
        appLanguage = language
        save()
        
        // Update system preference for next launch
        if language == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    func addProvider(name: String, baseURL: String, models: [String]) {
        let newProvider = Provider(name: name, enabled: false, baseURL: baseURL, models: models, enabledModels: Array(models.prefix(3)))
        providers.append(newProvider)
        providers.sort { $0.name < $1.name }
        save()
    }

    func removeProvider(name: String) {
        providers.removeAll { $0.name == name }
        if defaultProvider == name {
            defaultProvider = ""
        }
        save()
    }

    func save() {
        var providersDict: [String: [String: Any]] = [:]
        for p in providers {
            let apiKey = providerAPIKeys[p.name] ?? ""
            providersDict[p.name] = [
                "enabled": p.enabled,
                "base_url": p.baseURL,
                "api_key_encrypted": encryptAPIKey(apiKey),
                "models": p.models,
                "enabled_models": p.enabledModels
            ]
        }

        let json: [String: Any] = [
            "default_provider": defaultProvider,
            "fallback_enabled": fallbackEnabled,
            "local_api_key": localAPIKey,
            "language": appLanguage,
            "providers": providersDict,
            "server": ["host": allowLAN ? "0.0.0.0" : "127.0.0.1", "port": servicePort, "allow_lan": allowLAN]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: configPath))
            reloadServiceConfig()
        }
    }

    func setAPIKey(provider: String, key: String) {
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        providerAPIKeys[provider] = normalizedKey
        
        let hasKey = !normalizedKey.isEmpty
        updateProvider(name: provider, enabled: hasKey)
    }

    func getAPIKey(provider: String) -> String? {
        return providerAPIKeys[provider]
    }

    func configuredProviders() -> [Provider] {
        providers.filter { provider in
            guard let key = providerAPIKeys[provider.name] else { return false }
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func hasConfiguredAPIKey(for provider: Provider) -> Bool {
        guard let key = providerAPIKeys[provider.name] else { return false }
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func providerLogoAssetName(for providerName: String) -> String {
        Self.logoAssetNames[providerName] ?? providerName
    }

    func activeProviders() -> [Provider] {
        sortForManagement(providers.filter { hasConfiguredAPIKey(for: $0) })
    }

    func inactiveProviders() -> [Provider] {
        sortForManagement(providers.filter { !hasConfiguredAPIKey(for: $0) })
    }

    func providersGroupedForManagement() -> (active: [Provider], inactive: [Provider]) {
        (activeProviders(), inactiveProviders())
    }

    private func sortForManagement(_ providers: [Provider]) -> [Provider] {
        providers.sorted { lhs, rhs in
            if lhs.name == defaultProvider { return true }
            if rhs.name == defaultProvider { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    func reload() {
        load()
    }

    func writeToOpenCode() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let opencodeDir = (home as NSString).appendingPathComponent(".config/opencode")
        let opencodePath = (opencodeDir as NSString).appendingPathComponent("opencode.json")

        // 1. Ensure directory exists
        if !FileManager.default.fileExists(atPath: opencodeDir) {
            try FileManager.default.createDirectory(atPath: opencodeDir, withIntermediateDirectories: true)
        }

        // 2. Load existing config
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: opencodePath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = existing
        }

        // 3. Prepare codingplan config
        var modelsDict: [String: [String: String]] = [:]
        for provider in activeProviders() {
            // Only export enabled models
            for model in provider.enabledModels {
                let fullId = "\(provider.name)/\(model)"
                modelsDict[fullId] = ["name": fullId]
            }
        }

        let codingPlanConfig: [String: Any] = [
            "npm": "@ai-sdk/openai-compatible",
            "name": "codingplan",
            "options": [
                "baseURL": "http://127.0.0.1:\(servicePort)/v1"
            ],
            "models": modelsDict
        ]

        // 4. Merge into 'provider' node
        var providerNode = root["provider"] as? [String: Any] ?? [:]
        providerNode["codingplan"] = codingPlanConfig
        root["provider"] = providerNode

        // 5. Save back
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: URL(fileURLWithPath: opencodePath))
    }

    private func encryptAPIKey(_ plainText: String) -> String {
        guard !plainText.isEmpty else { return "" }
        guard let data = plainText.data(using: .utf8) else { return "" }

        let keySource = ProcessInfo.processInfo.environment["CODINGPLAN_CRYPTO_KEY"] ?? Self.defaultCryptoKey
        let keyMaterial = SHA256.hash(data: Data(keySource.utf8))
        let symmetricKey = SymmetricKey(data: Data(keyMaterial))

        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            guard let combined = sealedBox.combined else { return "" }
            return combined.base64EncodedString()
        } catch {
            return ""
        }
    }

    private func decryptAPIKey(_ base64Encoded: String) -> String {
        guard !base64Encoded.isEmpty else { return "" }
        guard let data = Data(base64Encoded: base64Encoded) else { return "" }

        let keySource = ProcessInfo.processInfo.environment["CODINGPLAN_CRYPTO_KEY"] ?? Self.defaultCryptoKey
        let keyMaterial = SHA256.hash(data: Data(keySource.utf8))
        let symmetricKey = SymmetricKey(data: Data(keyMaterial))

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decryptedData, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private func reloadServiceConfig() {
        guard let url = URL(string: "http://127.0.0.1:\(servicePort)/admin/reload-config") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.5

        let task = URLSession.shared.dataTask(with: request)
        task.resume()
    }
}
