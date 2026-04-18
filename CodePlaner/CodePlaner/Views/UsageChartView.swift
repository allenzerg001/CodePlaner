import SwiftUI
import Charts

struct UsageChartView: View {
    let stats: [String: Any]

    struct ChartItem: Identifiable {
        let id = UUID()
        let provider: String
        let tokens: Int
    }

    var chartData: [ChartItem] {
        guard let byProvider = stats["by_provider"] as? [String: [String: Any]] else {
            return []
        }
        return byProvider.map { name, data in
            ChartItem(provider: name, tokens: data["tokens"] as? Int ?? 0)
        }.sorted { $0.tokens > $1.tokens }
    }

    var body: some View {
        if chartData.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .font(.largeTitle)
                    .foregroundStyle(.quaternary)
                Text(NSLocalizedString("usage_no_data", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Chart(chartData) { item in
                    BarMark(
                        x: .value(NSLocalizedString("usage_chart_label_tokens", comment: ""), item.tokens),
                        y: .value(NSLocalizedString("usage_chart_label_provider", comment: ""), item.provider)
                    )
                    .foregroundStyle(by: .value(NSLocalizedString("usage_chart_label_provider", comment: ""), item.provider))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let providerName = value.as(String.self) {
                                HStack(spacing: 4) {
                                    ProviderLogoView(
                                        assetName: providerName,
                                        displayName: providerName,
                                        size: 16
                                    )
                                    Text(providerName)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
                .frame(height: max(120, CGFloat(chartData.count) * 36))
            }
        }
    }
}
