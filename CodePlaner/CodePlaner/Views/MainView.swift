import SwiftUI

struct MainView: View {
    @ObservedObject var config: ConfigManager
    @ObservedObject var usageService: UsageStatsService
    @State private var selection: NavItem? = .usage

    enum NavItem: Hashable {
        case usage, providers, clients, settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label(NSLocalizedString("sidebar_usage", comment: ""), systemImage: "chart.bar.fill")
                    .tag(NavItem.usage)

                Label(NSLocalizedString("sidebar_providers", comment: ""), systemImage: "cpu")
                    .tag(NavItem.providers)

                Label(NSLocalizedString("sidebar_clients", comment: ""), systemImage: "desktopcomputer")
                    .tag(NavItem.clients)

                Label("Settings", systemImage: "gear")
                    .tag(NavItem.settings)
            }
            .listStyle(.sidebar)
            .navigationTitle("CodingPlan")
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .usage {
        case .usage:
            UsageDashboardView(usageService: usageService)
        case .providers:
            ProvidersView(config: config)
        case .clients:
            ClientsView(config: config, usageService: usageService)
        case .settings:
            SettingsView(config: config)
        }
    }
}
