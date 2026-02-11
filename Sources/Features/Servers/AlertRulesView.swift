import SwiftUI

struct AlertRulesView: View {
    @ObservedObject var manager: AlertManager
    @Environment(\.dismiss) var dismiss
    @State private var showingAddRule = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Enable Monitoring", isOn: $manager.areAlertsEnabled)
                    Toggle("Server Status Notifications", isOn: $manager.statusAlertsEnabled)
                } header: {
                    Text("General")
                }
                
                Section {
                    if manager.rules.isEmpty {
                        ContentUnavailableView("No Rules", systemImage: "bell.slash", description: Text("Add a rule to get notified."))
                    } else {
                        ForEach($manager.rules) { $rule in
                            RuleRow(rule: $rule)
                        }
                        .onDelete(perform: manager.deleteRule)
                    }
                } header: {
                    HStack {
                        Text("Custom Rules")
                        Spacer()
                        Button {
                            showingAddRule = true
                        } label: {
                            Label("Add Rule", systemImage: "plus")
                                .font(.caption.weight(.bold))
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddRule) {
                AddRuleView(manager: manager)
            }
        }
    }
}

struct RuleRow: View {
    @Binding var rule: AlertRule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(rule.metric.rawValue)
                    .font(.headline)
                Text("\(rule.condition.rawValue) \(Int(rule.threshold))\(rule.metric.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
        }
    }
}

struct AddRuleView: View {
    @ObservedObject var manager: AlertManager
    @Environment(\.dismiss) var dismiss
    
    @State private var metric: AlertMetric = .cpu
    @State private var condition: AlertCondition = .above
    @State private var threshold: Double = 90
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trigger") {
                    Picker("Metric", selection: $metric) {
                        ForEach(AlertMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    
                    Picker("Condition", selection: $condition) {
                        ForEach(AlertCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }
                
                Section("Threshold") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Value")
                            Spacer()
                            Text("\(Int(threshold))\(metric.unit)")
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        
                        Slider(value: $threshold, in: rangeForMetric, step: stepForMetric) {
                            Text("Threshold")
                        } minimumValueLabel: {
                            Text("\(Int(rangeForMetric.lowerBound))")
                        } maximumValueLabel: {
                            Text("\(Int(rangeForMetric.upperBound))")
                        }
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Summary")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Alert when \(metric.rawValue) is \(condition.rawValue.lowercased()) \(Int(threshold))\(metric.unit)")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let rule = AlertRule(metric: metric, condition: condition, threshold: threshold)
                        manager.addRule(rule)
                        dismiss()
                    }
                }
            }
        }
    }
    
    var rangeForMetric: ClosedRange<Double> {
        switch metric {
        case .cpu: return 0...400
        case .memory: return 0...100
        case .disk: return 0...100
        case .network: return 0...1000 // MB/s
        }
    }
    
    var stepForMetric: Double {
        switch metric {
        case .network: return 1
        default: return 5
        }
    }
}
