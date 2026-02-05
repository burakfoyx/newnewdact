import SwiftUI

struct AlertRuleEditor: View {
    let server: ServerAttributes
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var metric: AlertMetric = .cpu
    @State private var condition: AlertCondition = .above
    @State private var threshold: Double = 80
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                Form {
                    Section("Trigger") {
                        Picker("Metric", selection: $metric) {
                            ForEach(AlertMetric.allCases) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if metric != .offline {
                            Picker("Condition", selection: $condition) {
                                ForEach(AlertCondition.allCases) { c in
                                    Text(c.displayName).tag(c)
                                }
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Threshold")
                                    Spacer()
                                    Text("\(Int(threshold))\(metric.unit)")
                                        .foregroundStyle(.secondary)
                                }
                                Slider(value: $threshold, in: 0...maxThreshold, step: 5)
                            }
                        }
                    }
                    
                    Section {
                        Button("Create Alert Rule") {
                            createRule()
                        }
                        .frame(maxWidth: .infinity)
                        .bold()
                    }
                    
                    Section {
                        Text("You will receive a local notification when this rule is triggered while the app is running.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
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
    
    private func createRule() {
        let rule = AlertRule(
            serverId: server.identifier,
            serverName: server.name,
            metric: metric,
            condition: condition,
            threshold: threshold
        )
        
        modelContext.insert(rule)
        try? modelContext.save() // Explicit save
        dismiss()
    }
    
    private var maxThreshold: Double {
        if metric == .cpu {
            // If explicit limit exists and > 0, use it. Otherwise, assume up to 400% (4 cores) as reasonable default for unlimited/unset
            if let limit = server.limits.cpu, limit > 0 {
                return Double(limit)
            }
            return 400.0
        }
        // Memory/Disk are usually handled as % of limit in AlertEngine logic, so 100% is max
        return 100.0
    }
}
