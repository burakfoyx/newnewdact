import SwiftUI

@MainActor
class SchedulesViewModel: ObservableObject {
    @Published var schedules: [ScheduleAttributes] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetch(serverId: String) async {
        isLoading = true
        do {
            schedules = try await PterodactylClient.shared.fetchSchedules(serverId: serverId)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct SchedulesView: View {
    @StateObject private var viewModel = SchedulesViewModel()
    
    let serverId: String
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    @State private var showingCreate = false
    
    init(serverId: String, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.serverId = serverId
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Hoisted
                
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                } else if viewModel.schedules.isEmpty {
                    ContentUnavailableView(
                        "No Schedules",
                        systemImage: "clock.badge.exclamationmark",
                        description: Text("Create a schedule to automate server tasks.")
                    )
                    .padding(.top, 40)
                } else {
                                    } else {
                                        Text("Inactive")
                                            .font(.caption2.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.3))
                                            .foregroundColor(.white.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    Label(formatCron(schedule.cron), systemImage: "clock.arrow.circlepath")
                                        .foregroundStyle(.blue.opacity(0.8))
                                    Spacer()
                                    if let lastRun = schedule.lastRunAt {
                                        Text("Last: " + formatDate(lastRun))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .font(.caption)
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .task {
            if viewModel.schedules.isEmpty { await viewModel.fetch(serverId: serverId) }
        }
        .refreshable {
            await viewModel.fetch(serverId: serverId)
        }
    }
    
    func formatCron(_ cron: ScheduleCron) -> String {
        return "\(cron.minute) \(cron.hour) \(cron.dayOfMonth) * \(cron.dayOfWeek)"
    }
    
    func formatDate(_ dateStr: String) -> String {
        return String(dateStr.prefix(10))
    }
}
