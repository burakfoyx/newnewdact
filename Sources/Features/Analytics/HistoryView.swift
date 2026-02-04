import SwiftUI
import Charts

// MARK: - History View (Analytics Dashboard)
struct HistoryView: View {
    let server: ServerAttributes
    
    @StateObject private var store = ResourceStore.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var collector = ResourceCollector.shared
    @State private var selectedTimeRange: AnalyticsTimeRange = .hour24
    @State private var selectedMetric: AnalyticsMetric = .cpu
    @State private var chartData: [ChartDataPoint] = []
    @State private var summary: ServerAnalyticsSummary?
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var showPaywall = false
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Collection Status
                    if let lastCollected = collector.lastCollectionTime {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.caption)
                            Text("Last collected: \(lastCollected.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, -8)
                    }
                    
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Summary Cards
                    if let summary = summary {
                        summaryCards(summary)
                    }
                    
                    // Main Chart
                    chartSection
                    
                    // Metric Selector
                    metricSelector
                    
                    // Insights
                    if let summary = summary {
                        insightsSection(summary)
                    }
                    
                    // Collection hint
                    if chartData.isEmpty {
                        collectionHint
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .refreshable {
                await refreshData()
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await loadData()
        }
        .onChange(of: selectedTimeRange) {
            Task { await loadData() }
        }
        .onChange(of: selectedMetric) {
            loadChartData()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: .historicalAnalytics)
        }
    }
    
    // MARK: - Collection Hint
    private var collectionHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text("How Analytics Work")
                .font(.headline)
                .foregroundStyle(.white)
            
            Text("Analytics data is collected while viewing the Console tab. Open the Console to start collecting real-time stats, then return here to see your charts.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Text("Pull down to refresh")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Refresh Data
    private func refreshData() async {
        isRefreshing = true
        
        // Small delay for visual feedback
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Reload data from store
        await loadData()
        
        isRefreshing = false
    }
    
    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsTimeRange.allCases) { range in
                    TimeRangeButton(
                        range: range,
                        isSelected: selectedTimeRange == range,
                        isLocked: !canAccessRange(range)
                    ) {
                        if canAccessRange(range) {
                            selectedTimeRange = range
                        } else {
                            showPaywall = true
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Summary Cards
    private func summaryCards(_ summary: ServerAnalyticsSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            SummaryCard(
                title: "Avg CPU",
                value: String(format: "%.1f%%", summary.avgCPU),
                trend: summary.cpuTrend,
                icon: "cpu"
            )
            
            SummaryCard(
                title: "Peak CPU",
                value: String(format: "%.1f%%", summary.peakCPU),
                trend: nil,
                icon: "arrow.up.circle"
            )
            
            SummaryCard(
                title: "Avg Memory",
                value: String(format: "%.1f%%", summary.avgMemoryPercent),
                trend: summary.memoryTrend,
                icon: "memorychip"
            )
            
            SummaryCard(
                title: "Peak Memory",
                value: String(format: "%.1f%%", summary.peakMemoryPercent),
                trend: nil,
                icon: "arrow.up.circle"
            )
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: selectedMetric.icon)
                    .foregroundStyle(.yellow)
                Text(selectedMetric.rawValue)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            if isLoading {
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else if chartData.isEmpty {
                noDataView
            } else {
                Chart(chartData) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [metricColor.opacity(0.5), metricColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(metricColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel(format: xAxisFormat)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))\(selectedMetric.unit)")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(.white.opacity(0.1))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
            
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Data collection will begin automatically")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Metric Selector
    private var metricSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsMetric.allCases) { metric in
                    MetricButton(
                        metric: metric,
                        isSelected: selectedMetric == metric
                    ) {
                        selectedMetric = metric
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Insights Section
    private func insightsSection(_ summary: ServerAnalyticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
                .foregroundStyle(.white)
            
            VStack(spacing: 8) {
                if summary.isUnderutilized {
                    InsightRow(
                        icon: "leaf.fill",
                        iconColor: .green,
                        title: "Underutilized Server",
                        description: "This server has low average usage. Consider downsizing to save resources."
                    )
                }
                
                if summary.isOverallocated {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "High Resource Usage",
                        description: "This server frequently hits resource limits. Consider upgrading."
                    )
                }
                
                if summary.cpuTrend == .increasing {
                    InsightRow(
                        icon: "arrow.up.right",
                        iconColor: .red,
                        title: "CPU Usage Increasing",
                        description: "CPU usage has been trending upward over this period."
                    )
                }
                
                if !summary.isUnderutilized && !summary.isOverallocated && summary.cpuTrend != .increasing {
                    InsightRow(
                        icon: "checkmark.circle.fill",
                        iconColor: .green,
                        title: "Healthy Usage",
                        description: "Resource usage looks normal for this server."
                    )
                }
            }
            .padding()
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
    
    // MARK: - Helpers
    private var metricColor: Color {
        switch selectedMetric {
        case .cpu: return .blue
        case .memory: return .purple
        case .disk: return .orange
        case .networkRx: return .green
        case .networkTx: return .teal
        }
    }
    
    private var xAxisFormat: Date.FormatStyle {
        switch selectedTimeRange {
        case .hour1, .hour6:
            return .dateTime.hour().minute()
        case .hour24:
            return .dateTime.hour()
        case .days7, .days30:
            return .dateTime.month().day()
        }
    }
    
    private func canAccessRange(_ range: AnalyticsTimeRange) -> Bool {
        subscriptionManager.currentTier >= range.requiredTier
    }
    
    private func loadData() async {
        isLoading = true
        
        summary = store.calculateSummary(
            serverId: server.identifier,
            serverName: server.name,
            timeRange: selectedTimeRange
        )
        
        loadChartData()
        isLoading = false
    }
    
    private func loadChartData() {
        chartData = store.getChartData(
            serverId: server.identifier,
            metric: selectedMetric,
            timeRange: selectedTimeRange
        )
    }
}

// MARK: - Time Range Button
struct TimeRangeButton: View {
    let range: AnalyticsTimeRange
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(range.rawValue)
                    .font(.subheadline.weight(isSelected ? .bold : .regular))
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected ?
                    AnyShapeStyle(LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )) :
                    AnyShapeStyle(Color.clear)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isSelected ? 0.3 : 0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Metric Button
struct MetricButton: View {
    let metric: AnalyticsMetric
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: metric.icon)
                    .font(.caption)
                Text(metric.rawValue)
                    .font(.subheadline)
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(
                isSelected ? .clear.interactive() : .clear,
                in: Capsule()
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let title: String
    let value: String
    let trend: UsageTrend?
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Spacer()
                if let trend = trend {
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundStyle(trendColor(trend))
                }
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func trendColor(_ trend: UsageTrend) -> Color {
        switch trend {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable: return .blue
        case .volatile: return .orange
        }
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
