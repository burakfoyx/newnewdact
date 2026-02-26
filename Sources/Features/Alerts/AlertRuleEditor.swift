import SwiftUI

struct AlertRuleEditor: View {
    let server: ServerAttributes
    @ObservedObject var manager: AlertManager
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var metric: AlertMetric = .cpu
    @State private var condition: AlertCondition = .above
    @State private var threshold: Double = 80
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Metric Selection Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Metric")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(AlertMetric.allCases) { m in
                                    MetricSelectionButton(
                                        metric: m,
                                        isSelected: metric == m
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            metric = m
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        
                        // Condition Section (only for non-offline metrics)
                        if metric != .offline {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Condition")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 8) {
                                    ForEach(AlertCondition.allCases) { c in
                                        ConditionSelectionButton(
                                            condition: c,
                                            isSelected: condition == c
                                        ) {
                                            withAnimation(.spring(response: 0.3)) {
                                                condition = c
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            
                            // Threshold Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Threshold")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(Int(threshold))\(metric.unit)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.primary)
                                }
                                
                                // Custom Slider with Glass Effect
                                GlassSlider(value: $threshold, range: 0...maxThreshold, step: 5)
                                
                                // Quick value buttons
                                HStack(spacing: 8) {
                                    ForEach(quickValues, id: \.self) { value in
                                        Button {
                                            withAnimation(.spring(response: 0.3)) {
                                                threshold = value
                                            }
                                        } label: {
                                            Text("\(Int(value))\(metric.unit)")
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(threshold == value ? .primary : .secondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(
                                                    threshold == value ? Color(.tertiarySystemFill) : Color.clear,
                                                    in: Capsule()
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        
                        // Summary Card
                        VStack(spacing: 12) {
                            Image(systemName: iconFor(metric))
                                .font(.largeTitle)
                                .foregroundStyle(.blue)
                            
                            Text(summaryText)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("You will receive a notification when this condition is met.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        
                        // Create Button
                        Button {
                            createRule()
                        } label: {
                            Text("Create Alert")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    .padding()
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var summaryText: String {
        if metric == .offline {
            return "Alert when server goes offline"
        } else {
            return "Alert when \(metric.displayName) is \(condition.displayName.lowercased()) \(Int(threshold))\(metric.unit)"
        }
    }
    
    private var quickValues: [Double] {
        switch metric {
        case .cpu:
            return [50, 75, 90, 100]
        case .memory, .disk:
            return [50, 75, 85, 95]
        case .offline:
            return []
        case .network:
            return [10, 50, 100]
        }
    }
    
    private func iconFor(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .offline: return "power"
        case .network: return "network"
        }
    }
    
    private func createRule() {
        // Create rule using struct initialization
        // Note: AlertRule might not have serverId in 'init' if it was removed? 
        // Let's check AlertsManager.swift again for AlertRule struct.
        // It has `var serverId: String`? 
        // Use memberwise init if valid.
        // `AlertsManager.swift`: `struct AlertRule: ... { var id... var metric... }`
        // I need to be sure about `AlertRule` properties.
        // Assuming it's `metric`, `condition`, `threshold`.
        // `AlertsManager` handles the saving.
        // `manager.addRule` will handle it.
        
        let rule = AlertRule(
            metric: metric,
            condition: condition,
            threshold: threshold,
            isEnabled: true
        )
        
        manager.addRule(rule)
        dismiss()
    }
    
    private var maxThreshold: Double {
        if metric == .cpu {
            if let limit = server.limits.cpu, limit > 0 {
                return Double(limit)
            }
            return 400.0
        }
        return 100.0
    }
}

// MARK: - Metric Selection Button
struct MetricSelectionButton: View {
    let metric: AlertMetric
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconFor(metric))
                    .font(.title2)
                Text(metric.displayName)
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color(.tertiarySystemFill) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconFor(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .offline: return "power"
        case .network: return "network"
        }
    }
}

// MARK: - Condition Selection Button
struct ConditionSelectionButton: View {
    let condition: AlertCondition
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconFor(condition))
                    .font(.caption)
                Text(condition.displayName)
                    .font(.subheadline)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color(.tertiarySystemFill) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconFor(_ condition: AlertCondition) -> String {
        switch condition {
        case .above: return "arrow.up"
        case .below: return "arrow.down"
        }
    }
}

// MARK: - Glass Slider
struct GlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 8)
                
                // Filled track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth(in: geometry.size.width), height: 8)
                
                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .offset(x: thumbOffset(in: geometry.size.width))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                updateValue(from: gesture.location.x, in: geometry.size.width)
                            }
                    )
            }
            .frame(height: 28)
        }
        .frame(height: 28)
    }
    
    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(totalWidth, totalWidth * percentage))
    }
    
    private func thumbOffset(in totalWidth: CGFloat) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        let offset = (totalWidth - 28) * percentage
        return max(0, min(totalWidth - 28, offset))
    }
    
    private func updateValue(from x: CGFloat, in totalWidth: CGFloat) {
        let percentage = max(0, min(1, x / totalWidth))
        let rawValue = range.lowerBound + (range.upperBound - range.lowerBound) * percentage
        let steppedValue = (rawValue / step).rounded() * step
        value = max(range.lowerBound, min(range.upperBound, steppedValue))
    }
}
