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
        ScrollView {
                VStack(spacing: 20) {
                    // Collection Status
                    VStack(spacing: 4) {
                        if collector.snapshotCount > 0 {
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                        .font(.caption)
                                    Text("\(collector.snapshotCount) snapshots")
                                        .font(.caption)
                                }
                                
                                if let lastCollected = collector.lastCollectionTime {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                        Text(lastCollected.formatted(.relative(presentation: .named)))
                                            .font(.caption)
                                    }
                                }
                            }
                            .foregroundStyle(.green.opacity(0.8))
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                Text("No data yet - View Console to start collecting")
                                    .font(.caption)
                            }
                            .foregroundStyle(.yellow.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glassEffect(.clear, in: Capsule())
                    
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
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onChange(of: selectedTimeRange) { oldValue, newValue in
            Task { 
                isLoading = true
                await loadData() 
            }
        }
        .onChange(of: selectedMetric) { oldValue, newValue in
            isLoading = true
            loadChartData()
            isLoading = false
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
        VStack(spacing: 12) {
            // Uptime Wide Card
            SummaryCard(
                title: String(format: "%.1f%% Reliability", summary.uptimeAvailability),
                value: formatUptime(summary.currentUptimeMs),
                trend: nil,
                icon: "clock.arrow.circlepath"
            )
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                // Row 1: CPU
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
                
                // Row 2: Memory
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
                    icon: "memorychip.fill"
                )
            }
        }
    }
    
    private func formatUptime(_ ms: Int64) -> String {
        let seconds = ms / 1000
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
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
                
                // Show data range info
                if !chartData.isEmpty {
                    Text("\(chartData.count) points")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            
            if isLoading {
                ProgressView()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else if chartData.isEmpty {
                noDataView
            } else {
                // Calculate the actual data time range
                let dataStartDate = chartData.first?.timestamp ?? selectedTimeRange.startDate
                let dataEndDate = chartData.last?.timestamp ?? Date()
                
                // Use data range if it spans less than 50% of selected time range
                // Otherwise use the full time range
                let selectedDuration = Date().timeIntervalSince(selectedTimeRange.startDate)
                let dataDuration = dataEndDate.timeIntervalSince(dataStartDate)
                let useDataRange = dataDuration < (selectedDuration * 0.5) && dataDuration > 0
                
                let xDomainStart = useDataRange ? dataStartDate.addingTimeInterval(-dataDuration * 0.1) : selectedTimeRange.startDate
                let xDomainEnd = useDataRange ? dataEndDate.addingTimeInterval(dataDuration * 0.1) : Date()
                
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
                    .interpolationMethod(.monotone)
                    
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value(selectedMetric.rawValue, point.value)
                    )
                    .foregroundStyle(metricColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
                    
                    // Show individual points when data is sparse
                    if chartData.count < 20 {
                        PointMark(
                            x: .value("Time", point.timestamp),
                            y: .value(selectedMetric.rawValue, point.value)
                        )
                        .foregroundStyle(metricColor)
                        .symbolSize(30)
                    }
                }
                .chartXScale(domain: xDomainStart...xDomainEnd)
                .chartYScale(domain: 0...(chartData.map(\.value).max() ?? 100) * 1.1)
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
                // Force re-render when time range or metric changes
                .id("\(selectedTimeRange.rawValue)-\(selectedMetric.rawValue)-\(chartData.count)")
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
                
                if summary.idleHoursPerDay > 4 {
                    InsightRow(
                        icon: "moon.zzz.fill",
                        iconColor: .purple,
                        title: "Idle Server",
                        description: "This server is idle for ~\(Int(summary.idleHoursPerDay)) hours/day. Consider stopping it when not in use."
                    )
                }
                
                if summary.isDiskCritical {
                    InsightRow(
                        icon: "internaldrive.fill",
                        iconColor: .red,
                        title: "Critical Disk Space",
                        description: "Disk usage averages >90%. Risk of data corruption or write failures."
                    )
                }
                
                if summary.isSaturated {
                    InsightRow(
                        icon: "flame.fill",
                        iconColor: .red,
                        title: "Severe Saturation",
                        description: "Average load is consistently high (>80%). Performance is likely degraded."
                    )
                }
                
                if summary.isOverallocated {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange,
                        title: "Peak Usage Warning",
                        description: "This server frequently hits resource limits during peaks. Consider upgrading."
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
                
                if !summary.isUnderutilized && !summary.isOverallocated && !summary.isSaturated && !summary.isDiskCritical && summary.cpuTrend != .increasing {
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
        case .uptime: return .pink
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
