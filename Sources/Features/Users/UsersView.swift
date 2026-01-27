import SwiftUI

struct UsersView: View {
    let serverId: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.3))
                .padding()
                .glassEffect(.regular, in: Circle())
            
            Text("Subusers")
                .font(.title2.bold())
                .foregroundStyle(.white)
            
            Text("User management is coming soon.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
