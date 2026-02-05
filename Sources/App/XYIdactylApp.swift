import SwiftUI
import SwiftData

@main
struct XYIdactylApp: App {
    init() {
        ResourceCollector.registerBackgroundTasks()
        triggerNetworkPermissionIfNeeded()
    }
    
    private func triggerNetworkPermissionIfNeeded() {
        let hasLaunchedKey = "hasLaunchedBefore"
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedKey)
        
        if !hasLaunched {
            // First launch - trigger Local Network permission popup
            // by making a dummy request to a private IP range
            let urls = [
                "http://192.168.0.1",
                "http://192.168.1.1", 
                "http://10.0.0.1"
            ]
            
            for urlString in urls {
                if let url = URL(string: urlString) {
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 0.5
                    URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
                }
            }
            
            // Mark as launched
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Liquid Glass looks best in dark mode
                .onAppear {
                    ResourceCollector.shared.startPolling()
                    
                    // Register background tasks
                    ResourceCollector.scheduleBackgroundTask() 
                }
        }
        .modelContainer(for: [ResourceSnapshotEntity.self, AlertRule.self, AlertEvent.self])
    }
}
