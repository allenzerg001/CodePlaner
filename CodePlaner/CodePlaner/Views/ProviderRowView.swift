import SwiftUI
import AppKit

// MARK: - ProviderCardView

struct ProviderCardView: View {
    let provider: Provider
    let isDefault: Bool
    let hasKey: Bool
    let maskedKey: String
    var models: [String]
    var isLoadingModels: Bool
    var onEdit: () -> Void
    var onSetDefault: () -> Void
    var onCopyModel: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: Logo + Name + Badges
            HStack(spacing: 12) {
                // Logo
                ProviderLogoView(
                    assetName: provider.name,
                    displayName: provider.displayName,
                    size: 32
                )

                // Name + system identifier
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(provider.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Badges
                HStack(spacing: 6) {
                    if isDefault {
                        ProviderBadge(text: NSLocalizedString("provider_default_badge", comment: ""), tint: .orange)
                    }
                    ProviderBadge(
                        text: hasKey
                            ? NSLocalizedString("provider_status_active", comment: "")
                            : NSLocalizedString("provider_status_inactive", comment: ""),
                        tint: hasKey ? .green : Color(NSColor.tertiaryLabelColor)
                    )
                }
            }
            .padding(12)

            Divider()

            // API Key row + Edit Button (If active)
            if hasKey {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(maskedKey)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .help(NSLocalizedString("provider_edit_button", comment: ""))
                }
                .padding(12)

                Divider()
            }

            // Models row (Only if active)
            if hasKey {
                VStack(alignment: .leading, spacing: 6) {
                    if isLoadingModels {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(NSLocalizedString("provider_loading_models", comment: ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Filter models to show only enabled ones
                        let activeModels = provider.models.filter { provider.enabledModels.contains($0) }
                        
                        if !activeModels.isEmpty {
                            ModelsListView(
                                providerName: provider.name,
                                models: activeModels,
                                onCopy: onCopyModel
                            )
                        } else if !provider.models.isEmpty {
                            Text(NSLocalizedString("provider_no_models_enabled", comment: ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(NSLocalizedString("provider_no_models_available", comment: ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                
                Spacer(minLength: 0)

                if !isDefault {
                    Divider()
                    HStack {
                        Button(NSLocalizedString("provider_set_default", comment: "")) {
                            onSetDefault()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(12)
                }
            } else {
                // Inactive provider view - Reduced Height
                Spacer(minLength: 8)
                HStack {
                    Spacer()
                    Button(NSLocalizedString("provider_activate_button", comment: "")) {
                        onEdit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ModelsListView

struct ModelsListView: View {
    let providerName: String
    let models: [String]
    let onCopy: (String) -> Void
    @State private var showingAllModels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let displayedModels = Array(models.prefix(3))
            
            ForEach(displayedModels, id: \.self) { model in
                Button {
                    onCopy("\(providerName)/\(model)")
                } label: {
                    Text(model)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .help("点击复制: \(providerName)/\(model)")
            }
            
            if models.count > 3 {
                Button {
                    showingAllModels = true
                } label: {
                    Text(String(format: NSLocalizedString("provider_more_models", comment: ""), models.count))
                        .font(.system(size: 10))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingAllModels) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: NSLocalizedString("provider_all_models", comment: ""), models.count))
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            ForEach(models, id: \.self) { model in
                                Button {
                                    onCopy("\(providerName)/\(model)")
                                    showingAllModels = false
                                } label: {
                                    Text(model)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                    }
                    .frame(width: 240, height: 300)
                }
            }
        }
    }
}

// MARK: - EditProviderSheet

struct EditProviderSheet: View {
    let provider: Provider
    let config: ConfigManager
    let isDefault: Bool
    let onSetDefault: () -> Void

    @State private var baseURLDraft: String
    @State private var apiKeyDraft: String
    @State private var selectedModels: Set<String>
    @State private var searchText: String = ""
    @State private var manualModelName: String = ""
    @Environment(\.dismiss) private var dismiss

    init(provider: Provider, config: ConfigManager, isDefault: Bool, onSetDefault: @escaping () -> Void) {
        self.provider = provider
        self.config = config
        self.isDefault = isDefault
        self.onSetDefault = onSetDefault
        _baseURLDraft = State(initialValue: provider.baseURL)
        _apiKeyDraft = State(initialValue: config.getAPIKey(provider: provider.name) ?? "")
        _selectedModels = State(initialValue: Set(provider.enabledModels))
    }

    var filteredModels: [String] {
        if searchText.isEmpty {
            return provider.models
        } else {
            return provider.models.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ProviderLogoView(
                    assetName: provider.name,
                    displayName: provider.displayName,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.displayName)
                        .font(.headline)
                    Text(provider.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("", text: $baseURLDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 380)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        SecureField("", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 380)
                    }
                    
                    // Manual Model Entry
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("provider_add_model_manual", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            TextField(NSLocalizedString("provider_model_name_placeholder", comment: ""), text: $manualModelName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                            
                            Button(NSLocalizedString("provider_add_and_select", comment: "")) {
                                let trimmed = manualModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    selectedModels.insert(trimmed)
                                    manualModelName = ""
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(manualModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    // Model List Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("provider_enabled_models_label", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            
                            // Search bar
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField(NSLocalizedString("provider_search_models_placeholder", comment: ""), text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .frame(width: 180)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // First show extra models that are selected but not in provider.models
                            let extraModels = selectedModels.subtracting(Set(provider.models)).sorted()
                            
                            if !extraModels.isEmpty {
                                ForEach(extraModels, id: \.self) { model in
                                    Toggle(isOn: Binding(
                                        get: { selectedModels.contains(model) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedModels.insert(model)
                                            } else {
                                                selectedModels.remove(model)
                                            }
                                        }
                                    )) {
                                        HStack {
                                            Text(model)
                                                .font(.system(.body, design: .monospaced))
                                            Text(NSLocalizedString("provider_manual_tag", comment: ""))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                                Divider().padding(.vertical, 4)
                            }

                            if filteredModels.isEmpty && extraModels.isEmpty {
                                Text(NSLocalizedString("provider_no_models_found", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(filteredModels, id: \.self) { model in
                                    Toggle(isOn: Binding(
                                        get: { selectedModels.contains(model) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedModels.insert(model)
                                            } else {
                                                selectedModels.remove(model)
                                            }
                                        }
                                    )) {
                                        Text(model)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    if config.hasConfiguredAPIKey(for: provider) {
                        Button(role: .destructive) {
                            config.setAPIKey(provider: provider.name, key: "")
                            dismiss()
                        } label: {
                            Label(NSLocalizedString("provider_deactivate_button", comment: ""), systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .padding(.top, 4)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: 400, alignment: .leading)

            Divider()

            // Footer actions
            HStack {
                if !isDefault && config.hasConfiguredAPIKey(for: provider) {
                    Button(NSLocalizedString("provider_set_default", comment: "")) {
                        onSetDefault()
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button(NSLocalizedString("common_cancel", comment: "")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(NSLocalizedString("settings_save", comment: "")) {
                    // Clean URL and Key: trim and take first line only
                    let cleanURL = baseURLDraft.split(separator: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let cleanKey = apiKeyDraft.split(separator: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    config.updateProvider(name: provider.name, baseURL: cleanURL)
                    config.setAPIKey(provider: provider.name, key: cleanKey)
                    
                    // Merge existing models with manually added ones
                    var allModelsSet = Set(provider.models)
                    for m in selectedModels {
                        allModelsSet.insert(m)
                    }
                    
                    config.updateProviderModels(name: provider.name, models: Array(allModelsSet).sorted())
                    config.updateProviderEnabledModels(name: provider.name, enabledModels: Array(selectedModels))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500)
    }
}

// MARK: - ProviderLogoView

struct ProviderLogoView: View {
    let assetName: String
    let displayName: String
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let image = NSImage(named: assetName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(width: size, height: size)
            }
        }
    }

    private var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(2)).isEmpty ? "AI" : String(trimmed.prefix(2))
    }
}

// MARK: - ProviderBadge

struct ProviderBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.1))
            )
    }
}
