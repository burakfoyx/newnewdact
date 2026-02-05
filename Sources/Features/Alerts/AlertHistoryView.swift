import SwiftUI
import SwiftData

struct AlertHistoryView: View {
    let serverId: String
    
    @Query(sort: \AlertEvent.timestamp, order: .reverse) private var events: [AlertEvent]
    @Environment(\.dismiss) private var dismiss
    
    init(serverId: String) {
        self.serverId = serverId
        _events = Query(
            filter: #Predicate<AlertEvent> { event in
                event.serverId == serverId
            },
            sort: \AlertEvent.timestamp,
            order: .reverse
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Alerts triggered for this server will appear here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.message)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(event.timestamp.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Alert History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
