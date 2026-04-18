import SwiftUI
import Darwin

struct SettingsView: View {
    @ObservedObject var config: ConfigManager
    @ObservedObject private var pythonManager: PythonProcessManager = AppRuntime.shared.pythonManager

    @State private var portDraft: Int = 0
    @State private var apiKeyDraft: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isApplying = false

    var body: some View {
        Form {
            // MARK: - Network Section
            Section {
                Toggle(NSLocalizedString("settings_allow_lan", comment: ""), isOn: Binding(
                    get: { config.allowLAN },
                    set: { newValue in
                        config.setAllowLAN(newValue)
                        if pythonManager.isRunning {
                            pythonManager.restart()
                        }
                    }
                ))

                if config.allowLAN {
                    let lanURL = pythonManager.lanServiceURL
                    HStack {
                        Text(NSLocalizedString("settings_lan_address", comment: ""))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lanURL)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(NSLocalizedString("settings_network_header", comment: ""))
            }

            // MARK: - Appearance & Language Section
            Section {
                Picker(NSLocalizedString("settings_language", comment: ""), selection: Binding(
                    get: { config.appLanguage },
                    set: { config.setLanguage($0) }
                )) {
                    Text(NSLocalizedString("settings_language_auto", comment: "")).tag("auto")
                    Text(NSLocalizedString("settings_language_en", comment: "")).tag("en")
                    Text(NSLocalizedString("settings_language_zh", comment: "")).tag("zh-Hans")
                }
            } header: {
                Text(NSLocalizedString("settings_appearance_header", comment: ""))
            } footer: {
                Text(NSLocalizedString("settings_language_restart_notice", comment: ""))
            }

            // MARK: - Service Configuration Section
            Section {
                HStack {
                    Text(NSLocalizedString("settings_service_port", comment: ""))
                    Spacer()
                    TextField("", value: $portDraft, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                HStack {
                    Text(NSLocalizedString("settings_local_api_key", comment: ""))
                    Spacer()
                    TextField("", text: $apiKeyDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                HStack {
                    Spacer()
                    if isApplying {
                        ProgressView().controlSize(.small)
                            .padding(.trailing, 8)
                    }
                    Button(NSLocalizedString("settings_apply", comment: "Apply")) {
                        handleApply()
                    }
                    .disabled(isApplying || !hasChanges)
                }
                .padding(.top, 4)
            } header: {
                Text(NSLocalizedString("settings_service_header", comment: ""))
            } footer: {
                Text(NSLocalizedString("settings_apply_footer", comment: ""))
            }
        }
        .formStyle(.grouped)
        .navigationTitle(NSLocalizedString("settings_title", comment: ""))
        .onAppear {
            portDraft = config.servicePort
            apiKeyDraft = config.localAPIKey
        }
        .alert(NSLocalizedString("settings_update_alert_title", comment: ""), isPresented: $showAlert) {
            Button(NSLocalizedString("common_ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var hasChanges: Bool {
        portDraft != config.servicePort || apiKeyDraft != config.localAPIKey
    }

    private func handleApply() {
        // 1. Port Validation
        guard portDraft >= 1024 && portDraft <= 65535 else {
            alertMessage = NSLocalizedString("settings_error_invalid_port", comment: "")
            showAlert = true
            return
        }

        // 2. Conflict Detection
        let isAvailable = pythonManager.isPortAvailable(portDraft)
        let isOurCurrentPort = pythonManager.isRunning && pythonManager.servicePort == portDraft

        if !isAvailable && !isOurCurrentPort {
            alertMessage = String(format: NSLocalizedString("settings_error_port_conflict", comment: ""), portDraft)
            showAlert = true
            return
        }

        // 3. Apply changes
        isApplying = true
        
        // Update Config
        if portDraft != config.servicePort {
            config.setServicePort(portDraft)
        }
        if apiKeyDraft != config.localAPIKey {
            config.setLocalAPIKey(apiKeyDraft)
        }

        // 4. Restart Service
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if pythonManager.isRunning {
                pythonManager.restart()
            } else {
                pythonManager.start()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isApplying = false
            }
        }
    }
}
