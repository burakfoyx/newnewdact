import SwiftUI
import SwiftData

struct AlertsListView: View {
    let server: ServerAttributes
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    @Environment(\.modelContext) private var modelContext
    @Query private var rules: [AlertRule]
    @State private var showEditor = false
    
    init(server: ServerAttributes, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.server = server
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
        
        let id = server.identifier
        _rules = Query(filter: #Predicate<AlertRule> { rule in
            rule.serverId == id
        })
    }
    
    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var showSettings = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Header Hoisted
                    
                    if rules.isEmpty {
                        ContentUnavailableView(
                            "No Alerts",
                            systemImage: "bell.slash",
                            description: Text(limitDescription)
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(rules) { rule in
                            AlertRuleRow(rule: rule)
                                .opacity(rule.isEnabled ? 1.0 : 0.6)
                                .contextMenu {
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
                                }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20) // Tab bar clearance
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
        .navigationTitle("Alerts") // Kept for semantics, hidden elsewhere
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
            AlertSettingsView(server: server)
        }
        .onAppear {
            NotificationService.shared.requestPermissions()
        }
    }
    
    var limitDescription: String {
        guard let limit = FeatureFlags.shared.limit(for: .customAlerts) else {
            return "Create custom alert rules."
        }
        
        if limit == 0 {
            return "Upgrade to Pro to create alert rules."
        } else if limit == .max {
            return "Create unlimited alert rules."
        } else {
            return "Create up to \(limit) alert rules."
        }
    }
    
    var canCreateRule: Bool {
        guard let limit = FeatureFlags.shared.limit(for: .customAlerts) else { return true }
        return rules.count < limit
    }
}

struct AlertRuleRow: View {
    let rule: AlertRule
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconFor(rule.metric))
                .foregroundStyle(rule.isEnabled ? .blue : .gray)
                .font(.title)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.metric.displayName)
                    .font(.headline)
                
                if rule.metric == .offline {
                    Text("When server is offline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(rule.condition.displayName) \(Int(rule.threshold))\(rule.metric.unit)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !rule.isEnabled {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(.gray)
                    .font(.title3)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .liquidGlass(variant: .clear, cornerRadius: 20)
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
