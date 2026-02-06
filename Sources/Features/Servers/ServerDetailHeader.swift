import SwiftUI

struct ServerDetailHeader: View {
    let title: String
    let statusState: String
    @Binding var selectedTab: ServerTab
    let onBack: () -> Void
    let onPowerAction: (String) -> Void
    
    // Metrics Data
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    var statusColor: Color {
        switch statusState {
        case "running": return .green
        case "starting": return .yellow
        case "restarting": return .yellow
        case "stopping": return .orange
        case "offline": return .gray
        case "installing": return .blue
        case "suspended": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Row 1: Title, Status, Power
                HStack(spacing: 12) {
                     Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(8)
                            .glassEffect(in: Circle())
                    }
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: statusColor.opacity(0.8), radius: 4)
                        Text(statusState.capitalized)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(.clear, in: Capsule())
                    
                    // Power Action
                    Menu {
                        Button(action: { onPowerAction("start") }) { Label("Start", systemImage: "play.fill") }
                        Button(action: { onPowerAction("restart") }) { Label("Restart", systemImage: "arrow.clockwise") }
                        Button(action: { onPowerAction("stop") }) { Label("Stop", systemImage: "stop.fill") }
                        Button(role: .destructive, action: { onPowerAction("kill") }) { Label("Kill", systemImage: "flame.fill") }
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .glassEffect(.clear, in: Circle())
                    }
                }
                
                // Row 2: Compact Metrics (New)
                if let stats = stats, let limits = limits {
                    HStack(spacing: 12) {
                        CompactMetricBar(
                            label: "CPU",
                            value: stats.cpu_absolute,
                            total: Double(limits.cpu ?? 100),
                            color: .blue
                        )
                        
                        CompactMetricBar(
                            label: "RAM",
                            value: Double(stats.memory_bytes) / 1024 / 1024,
                            total: Double(limits.memory ?? 1024),
                            color: .purple
                        )
                        
                        CompactMetricBar(
                            label: "DISK",
                            value: Double(stats.disk_bytes) / 1024 / 1024,
                            total: Double(limits.disk ?? 1024),
                            color: .cyan
                        )
                    }
                }
                
                // Row 3: Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ServerTab.allCases) { tab in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                    Text(tab.rawValue)
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.6))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    selectedTab == tab ? Color.white.opacity(0.2) : Color.clear
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedTab == tab ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                             .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(14)
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }
}

// Compact Metric Bar Component
struct CompactMetricBar: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
    
    var displayValue: String {
        if label == "CPU" {
            return String(format: "%.0f%%", value)
        } else {
            // value is usually MB here
            if total >= 1024 {
                return String(format: "%.1f GB", value / 1024)
            }
            return String(format: "%.0f MB", value)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(displayValue)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
        }
    }
}
