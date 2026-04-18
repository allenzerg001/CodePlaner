import Foundation

struct Provider: Codable, Identifiable {
    var id: String { name }
    let name: String
    var displayName: String
    var icon: String
    var enabled: Bool
    var baseURL: String
    var models: [String]
    var enabledModels: [String]

    enum CodingKeys: String, CodingKey {
        case name, enabled, models
        case displayName = "display_name"
        case baseURL = "base_url"
        case enabledModels = "enabled_models"
    }

    // Custom decoder: display_name and icon are optional in JSON; fall back to preset table
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name          = try c.decode(String.self, forKey: .name)
        enabled       = try c.decode(Bool.self,   forKey: .enabled)
        baseURL       = (try? c.decode(String.self, forKey: .baseURL)) ?? ""
        models        = (try? c.decode([String].self, forKey: .models)) ?? []
        enabledModels = (try? c.decode([String].self, forKey: .enabledModels)) ?? Array(models.prefix(3))
        displayName   = (try? c.decode(String.self, forKey: .displayName))
                      ?? Provider.displayName(for: name)
        icon          = Provider.icon(for: name)
    }

    // Memberwise init used inside the app (ConfigManager, etc.)
    init(name: String,
         displayName: String? = nil,
         icon: String? = nil,
         enabled: Bool,
         baseURL: String,
         models: [String],
         enabledModels: [String]? = nil) {
        self.name          = name
        self.enabled       = enabled
        self.baseURL       = baseURL
        self.models        = models
        self.enabledModels = enabledModels ?? Array(models.prefix(3))
        self.displayName   = displayName ?? Provider.displayName(for: name)
        self.icon          = icon        ?? Provider.icon(for: name)
    }

    // MARK: - Preset lookup tables

    private static let displayNames: [String: String] = [
        "bailian":     NSLocalizedString("provider_name_bailian", comment: ""),
        "volcengine":  NSLocalizedString("provider_name_volcengine", comment: ""),
        "zhipu":       NSLocalizedString("provider_name_zhipu", comment: ""),
        "deepseek":    NSLocalizedString("provider_name_deepseek", comment: ""),
        "moonshot":    NSLocalizedString("provider_name_moonshot", comment: ""),
        "minimax":     NSLocalizedString("provider_name_minimax", comment: ""),
        "xiaomi":      NSLocalizedString("provider_name_xiaomi", comment: ""),
        "siliconflow": NSLocalizedString("provider_name_siliconflow", comment: ""),
        "hunyuan":     NSLocalizedString("provider_name_hunyuan", comment: ""),
        "openai":      NSLocalizedString("provider_name_openai", comment: ""),
        "anthropic":   NSLocalizedString("provider_name_anthropic", comment: ""),
        "openrouter":  NSLocalizedString("provider_name_openrouter", comment: ""),
        "gemini":      NSLocalizedString("provider_name_gemini", comment: ""),
        "mistral":     NSLocalizedString("provider_name_mistral", comment: ""),
        "groq":        NSLocalizedString("provider_name_groq", comment: ""),
        "cohere":      NSLocalizedString("provider_name_cohere", comment: ""),
        "together":    NSLocalizedString("provider_name_together", comment: ""),
    ]

    private static let icons: [String: String] = [
        "bailian":     "bailian",
        "volcengine":  "volcengine",
        "zhipu":       "zhipu",
        "deepseek":    "deepseek",
        "moonshot":    "moonshot",
        "minimax":     "minimax",
        "siliconflow": "siliconflow",
        "hunyuan":     "hunyuan",
    ]

    static func displayName(for providerName: String) -> String {
        return displayNames[providerName] ?? providerName
    }

    static func icon(for providerName: String) -> String {
        return icons[providerName] ?? "🔌"
    }
}
