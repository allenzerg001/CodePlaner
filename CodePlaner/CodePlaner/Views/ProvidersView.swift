import SwiftUI
import AppKit

struct ProvidersView: View {
    @ObservedObject var config: ConfigManager
    @State private var showingAddProvider = false
    @State private var editingProvider: Provider? = nil

    @State private var newName = ""
    @State private var newBaseURL = ""
    @State private var newModels = ""

    // MARK: - Model fetch state
    @State private var fetchedModels: [String: [String]] = [:]
    @State private var loadingModels: Set<String> = []

    // MARK: - Copy toast
    @State private var copyToast: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // MARK: - Active Providers
                let active = config.activeProviders()
                if !active.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("providers_active_section", comment: ""))
                                .font(.headline)
                            Spacer()
                            Text("\(active.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 16, alignment: .top)],
                            spacing: 16
                        ) {
                            ForEach(active) { provider in
                                ProviderCardView(
                                    provider: provider,
                                    isDefault: provider.name == config.defaultProvider,
                                    hasKey: config.hasConfiguredAPIKey(for: provider),
                                    maskedKey: maskedKey(for: provider),
                                    models: fetchedModels[provider.name] ?? [],
                                    isLoadingModels: loadingModels.contains(provider.name),
                                    onEdit: { editingProvider = provider },
                                    onSetDefault: { config.setDefaultProvider(provider.name) },
                                    onCopyModel: { copyModel($0) }
                                )
                            }
                        }
                    }
                } else {
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text(NSLocalizedString("providers_active_empty", comment: ""))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }

                // MARK: - Inactive Providers
                let inactive = config.inactiveProviders()
                if !inactive.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("providers_inactive_section", comment: ""))
                                .font(.headline)
                            Spacer()
                            Text("\(inactive.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 16, alignment: .top)],
                            spacing: 16
                        ) {
                            ForEach(inactive) { provider in
                                ProviderCardView(
                                    provider: provider,
                                    isDefault: false,
                                    hasKey: false,
                                    maskedKey: "",
                                    models: [],
                                    isLoadingModels: false,
                                    onEdit: { editingProvider = provider },
                                    onSetDefault: {},
                                    onCopyModel: { _ in }
                                )
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        // MARK: - Copy toast overlay
        .overlay(alignment: .bottom) {
            if let message = copyToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.78))
                )
                .padding(.bottom, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: copyToast)
        .navigationTitle(NSLocalizedString("providers_title", comment: ""))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProvider = true
                } label: {
                    Label(NSLocalizedString("provider_add_button", comment: ""), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            addProviderSheet
        }
        .sheet(item: $editingProvider) { provider in
            EditProviderSheet(
                provider: provider,
                config: config,
                isDefault: provider.name == config.defaultProvider,
                onSetDefault: { config.setDefaultProvider(provider.name) }
            )
        }
        .onAppear {
            ensureSingleConfiguredProviderIsDefault()
            refreshModels()
        }
        .onReceive(config.$providers) { _ in
            ensureSingleConfiguredProviderIsDefault()
            refreshModels()
        }
    }

    // MARK: - Model Fetching

    private func refreshModels() {
        for provider in config.activeProviders() {
            if fetchedModels[provider.name] == nil {
                fetchModels(for: provider)
            }
        }
    }

    private func fetchModels(for provider: Provider) {
        guard !loadingModels.contains(provider.name),
              let apiKey = config.getAPIKey(provider: provider.name),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let base = provider.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !base.isEmpty, let url = URL(string: "\(base)/models") else { return }

        loadingModels.insert(provider.name)

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                         forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                loadingModels.remove(provider.name)

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = json["data"] as? [[String: Any]] else { return }

                let ids = list
                    .compactMap { $0["id"] as? String }
                    .filter { !$0.isEmpty }
                    .sorted()

                if !ids.isEmpty {
                    fetchedModels[provider.name] = ids
                    // Save back to config so backend can see them in /v1/models
                    config.updateProviderModels(name: provider.name, models: ids)
                }
            }
        }.resume()
    }

    // MARK: - Copy with toast

    private func copyModel(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copyToast = "已复制 \(text)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            copyToast = nil
        }
    }

    // MARK: - Helpers

    private func maskedKey(for provider: Provider) -> String {
        guard let key = config.getAPIKey(provider: provider.name),
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(trimmed.prefix(5))••••••••••••••••"
    }

    private func ensureSingleConfiguredProviderIsDefault() {
        let configured = config.activeProviders()
        guard configured.count == 1, let sole = configured.first else { return }
        if config.defaultProvider != sole.name {
            config.setDefaultProvider(sole.name)
        }
    }

    // MARK: - Add Provider Sheet

    private var addProviderSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NSLocalizedString("provider_add_title", comment: ""))
                        .font(.headline)
                    Text(NSLocalizedString("providers_subtitle", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showingAddProvider = false
                    newName = ""; newBaseURL = ""; newModels = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                TextField(NSLocalizedString("provider_add_name_placeholder", comment: ""), text: $newName)
                    .textFieldStyle(.roundedBorder)
                TextField(NSLocalizedString("settings_base_url_placeholder", comment: ""), text: $newBaseURL)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            Divider()

            HStack {
                Button(NSLocalizedString("common_cancel", comment: "")) {
                    showingAddProvider = false
                    newName = ""; newBaseURL = ""
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(NSLocalizedString("provider_add_button", comment: "")) {
                    config.addProvider(name: newName, baseURL: newBaseURL, models: [])
                    showingAddProvider = false
                    newName = ""; newBaseURL = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || newBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 440)
    }
}
