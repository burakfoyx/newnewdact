import SwiftUI

struct SchedulesView: View {
    let serverId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
                .padding()
                .glassEffect(.regular, in: Circle())
            
            Text("Schedules")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("Scheduled tasks functionality is coming soon.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                // Placeholder action
            }
            .buttonStyle(LiquidButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
