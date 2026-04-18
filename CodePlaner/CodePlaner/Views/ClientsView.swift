import SwiftUI

struct ClientsView: View {
    @ObservedObject var config: ConfigManager
    @ObservedObject var usageService: UsageStatsService
    @State private var sortOrder = [KeyPathComparator(\ClientRow.tokens, order: .reverse)]
    @State private var rows: [ClientRow] = []
    
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    struct ClientRow: Identifiable {
        let id = UUID()
        let name: String
        let tokens: Int
        let requests: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - OpenCode Integration Card
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    // Logo
                    Image("opencode")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OpenCode Integration")
                            .font(.headline)
                        Text("Automatically write codingplan configuration to OpenCode.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        do {
                            try config.writeToOpenCode()
                            showingSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingSuccess = false
                            }
                        } catch {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    } label: {
                        HStack {
                            if showingSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Success")
                            } else {
                                Image(systemName: "square.and.pencil")
                                Text("Write Config")
                            }
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(20)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(28)
            
            Divider()

            // MARK: - Clients Table
            Group {
                if rows.isEmpty {
                    emptyState
                } else {
                    Table(rows, sortOrder: $sortOrder) {
                        TableColumn(NSLocalizedString("sidebar_clients", comment: ""), value: \.name) { row in
                            HStack(spacing: 8) {
                                ClientIconView(name: row.name, size: 18)
                                Text(row.name)
                                    .font(.body)
                            }
                        }

                        TableColumn("Requests", value: \.requests) { row in
                            Text("\(row.requests)")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 90, ideal: 110)

                        TableColumn("Tokens", value: \.tokens) { row in
                            Text("\(row.tokens)")
                                .font(.body.monospacedDigit().weight(.medium))
                        }
                        .width(min: 90, ideal: 120)
                    }
                    .onChange(of: sortOrder) { _, newOrder in
                        rows = rows.sorted(using: newOrder)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("sidebar_clients", comment: ""))
        .alert("Error Writing Config", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            usageService.fetchUsage()
            loadRows()
        }
        .onReceive(usageService.$todayStats) { _ in
            loadRows()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "desktopcomputer.slash")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)

            VStack(spacing: 4) {
                Text("No Clients Yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Applications identified via User-Agent header will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadRows() {
        guard let byClient = usageService.todayStats["by_client"] as? [String: [String: Any]] else {
            rows = []
            return
        }
        let loaded = byClient.map { key, val in
            ClientRow(
                name: key,
                tokens: val["tokens"] as? Int ?? 0,
                requests: val["requests"] as? Int ?? 0
            )
        }
        rows = loaded.sorted(using: sortOrder)
    }
}

// MARK: - ClientIconView

struct ClientIconView: View {
    let name: String
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = NSImage(named: iconName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                Image(systemName: "desktopcomputer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.9, height: size * 0.9)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private var iconName: String {
        let n = name.lowercased()
        if n.contains("opencode") { return "opencode" }
        if n.contains("cursor") { return "cursor" }
        if n.contains("continue") { return "continue" }
        if n.contains("claude") { return "claude-code" }
        if n.contains("roo") { return "roo-code" }
        return "unknown"
    }
}

