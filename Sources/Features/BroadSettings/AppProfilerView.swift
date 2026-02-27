import SwiftUI

struct AppProfilerView: View {
    @StateObject private var profiler = AppProfiler.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total App CPU")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1f%%", profiler.totalAppCPUUsage))
                            .font(.system(.title3, design: .monospaced).bold())
                            .foregroundColor(profiler.totalAppCPUUsage > 80 ? .red : (profiler.totalAppCPUUsage > 40 ? .orange : .green))
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Overview")
                } footer: {
                    Text("This shows the combined CPU usage across all threads belonging to the app.")
                }
                
                Section {
                    ForEach(profiler.threadUsages) { thread in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Thread \(thread.id)")
                                    .font(.subheadline.bold())
                            }
                            Spacer()
                            Text(String(format: "%.1f%%", thread.cpuUsage))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(thread.cpuUsage > 50 ? .red : .primary)
                        }
                    }
                } header: {
                    Text("Active Threads (\(profiler.threadUsages.count))")
                } footer: {
                    Text("Take a screenshot of this list if you see a thread consistently stuck at high CPU usage.")
                }
            }
            .navigationTitle("CPU Profiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                profiler.startProfiling()
            }
            .onDisappear {
                profiler.stopProfiling()
            }
        }
    }
}

#Preview {
    AppProfilerView()
}
