import SwiftUI
import Charts

struct UsageDashboardView: View {
    @ObservedObject var usageService: UsageStatsService
    private let pythonManager = AppRuntime.shared.pythonManager
    @State private var serviceRunning = AppRuntime.shared.pythonManager.isRunning
    @State private var serviceURL = AppRuntime.shared.pythonManager.serviceURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: - Service Status
                GroupBox {
                    HStack(spacing: 16) {
                        // Status indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(serviceRunning ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                                .shadow(color: serviceRunning ? .green.opacity(0.6) : .red.opacity(0.4),
                                        radius: serviceRunning ? 4 : 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(serviceRunning
                                     ? NSLocalizedString("usage_service_running", comment: "")
                                     : NSLocalizedString("usage_service_stopped", comment: ""))
                                    .font(.subheadline.weight(.medium))

                                Text(serviceURL)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            Button(NSLocalizedString("usage_start_service", comment: "")) {
                                pythonManager.start()
                            }
                            .disabled(serviceRunning)

                            Button(NSLocalizedString("usage_stop_service", comment: "")) {
                                pythonManager.stop()
                            }
                            .disabled(!serviceRunning)
                            .tint(.red)
                        }
                        .controlSize(.regular)
                    }
                    .padding(4)
                } label: {
                    Label(NSLocalizedString("usage_service_status", comment: ""),
                          systemImage: "server.rack")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // MARK: - Stat Cards
                HStack(spacing: 14) {
                    StatCard(
                        title: NSLocalizedString("usage_stat_requests", comment: ""),
                        value: "\(usageService.todayStats["total_requests"] as? Int ?? 0)",
                        icon: "arrow.up.right.circle.fill",
                        tint: .blue
                    )
                    StatCard(
                        title: NSLocalizedString("usage_stat_total_tokens", comment: ""),
                        value: "\(usageService.todayStats["total_tokens"] as? Int ?? 0)",
                        icon: "sparkles",
                        tint: .purple
                    )
                    StatCard(
                        title: NSLocalizedString("usage_cost", comment: ""),
                        value: "¥\(String(format: "%.2f", usageService.todayStats["total_cost"] as? Double ?? 0.0))",
                        icon: "yensign.circle.fill",
                        tint: .orange
                    )
                }

                Divider()

                // MARK: - Charts
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(NSLocalizedString("usage_by_provider", comment: ""),
                              systemImage: "cpu")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        UsageChartView(stats: usageService.todayStats)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        Label(NSLocalizedString("usage_by_client", comment: ""),
                              systemImage: "desktopcomputer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        ClientUsageChartView(stats: usageService.todayStats)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(28)
        }
        .navigationTitle(NSLocalizedString("sidebar_usage", comment: ""))
        .onAppear {
            usageService.fetchUsage()
            serviceRunning = pythonManager.isRunning
            serviceURL = pythonManager.serviceURL
        }
        .onReceive(pythonManager.$isRunning) { serviceRunning = $0 }
        .onReceive(pythonManager.$servicePort) { _ in serviceURL = pythonManager.serviceURL }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    var tint: Color = .blue

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}

// MARK: - ClientUsageChartView

struct ClientUsageChartView: View {
    let stats: [String: Any]

    var chartData: [(client: String, tokens: Int)] {
        guard let byClient = stats["by_client"] as? [String: [String: Any]] else {
            return []
        }
        return byClient.map { (client: $0.key, tokens: $0.value["tokens"] as? Int ?? 0) }
            .sorted { $0.tokens > $1.tokens }
    }

    var body: some View {
        if chartData.isEmpty {
            emptyState
        } else {
            Chart(chartData, id: \.client) { item in
                BarMark(
                    x: .value("Tokens", item.tokens),
                    y: .value("Client", item.client)
                )
                .foregroundStyle(by: .value("Client", item.client))
                .cornerRadius(4)
            }
            .chartLegend(.hidden)
            .frame(height: max(120, CGFloat(chartData.count) * 36))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text(NSLocalizedString("usage_no_data", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}
