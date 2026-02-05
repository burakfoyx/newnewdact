import SwiftUI
import SwiftData

struct AlertsListView: View {
    let server: ServerAttributes
    
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [AlertRule]
    @State private var showEditor = false
    
    init(server: ServerAttributes) {
        self.server = server
        let id = server.identifier
        _rules = Query(filter: #Predicate<AlertRule> { rule in
            rule.serverId == id
        }, sort: \.metric.rawValue)
    }
    
    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var showSettings = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        ZStack {
            List {
                if rules.isEmpty {
                    ContentUnavailableView(
                        "No Alerts",
                        systemImage: "bell.slash",
                        description: Text(limitDescription)
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(rules) { rule in
                        AlertRuleRow(rule: rule)
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(rule)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    rule.isEnabled.toggle()
                                } label: {
                                    Label(rule.isEnabled ? "Mute" : "Enable", systemImage: rule.isEnabled ? "bell.slash" : "bell")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if canCreateRule {
                            showEditor = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .glassEffect(.clear.interactive(), in: Circle())
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Alerts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showHistory = true
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Label("Quiet Hours", systemImage: "moon.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            AlertRuleEditor(server: server)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(highlightedFeature: .customAlerts)
        }
        .sheet(isPresented: $showHistory) {
            AlertHistoryView(serverId: server.identifier)
        }
        .sheet(isPresented: $showSettings) {
            AlertSettingsView()
        }
        .onAppear {
            NotificationService.shared.requestPermissions()
        }
    }
    
    var limitDescription: String {
        switch subscriptionManager.currentTier {
        case .free: return "Upgrade to Pro to create alert rules."
        case .pro: return "Create up to 5 alert rules."
        case .host: return "Create unlimited alert rules."
        }
    }
    
    var canCreateRule: Bool {
        let count = rules.count
        switch subscriptionManager.currentTier {
        case .free: return false
        case .pro: return count < 5
        case .host: return true
        }
    }
}

struct AlertRuleRow: View {
    let rule: AlertRule
    
    var body: some View {
        HStack {
            Image(systemName: iconFor(rule.metric))
                .foregroundStyle(rule.isEnabled ? .blue : .gray)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(rule.metric.displayName)
                    .font(.headline)
                
                if rule.metric == .offline {
                    Text("When server is offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(rule.condition.displayName) \(Int(rule.threshold))\(rule.metric.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !rule.isEnabled {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.gray)
            }
        }
        .opacity(rule.isEnabled ? 1.0 : 0.6)
    }
    
    func iconFor(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .offline: return "power"
        }
    }
}
