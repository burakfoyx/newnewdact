import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AlertEvent.triggeredAt, order: .reverse) private var events: [AlertEvent]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                if events.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !events.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Clear All", role: .destructive) {
                            clearAll()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.4))
            
            Text("No Notifications")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("Alert notifications will appear here")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(events) { event in
                    NotificationCard(event: event) {
                        withAnimation {
                            modelContext.delete(event)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func clearAll() {
        for event in events {
            modelContext.delete(event)
        }
    }
}

struct NotificationCard: View {
    let event: AlertEvent
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconFor(event.metric))
                .font(.title2)
                .foregroundStyle(colorFor(event.metric))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.serverName)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(event.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                
                Text(event.triggeredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func iconFor(_ metric: AlertMetric) -> String {
        switch metric {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .offline: return "power"
        }
    }
    
    private func colorFor(_ metric: AlertMetric) -> Color {
        switch metric {
        case .cpu: return .orange
        case .memory: return .purple
        case .disk: return .blue
        case .offline: return .red
        }
    }
}

// MARK: - Notification Bell Button (for toolbar)

struct NotificationBellButton: View {
    @Query(sort: \AlertEvent.triggeredAt, order: .reverse) private var events: [AlertEvent]
    @State private var showNotifications = false
    
    // Count unread (events from last 24 hours as "new")
    private var unreadCount: Int {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        return events.filter { $0.triggeredAt > oneDayAgo }.count
    }
    
    init() {}
    
    var body: some View {
        Button {
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                
                if unreadCount > 0 {
                    Text(unreadCount > 9 ? "9+" : "\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 8, y: -8)
                }
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }
}
