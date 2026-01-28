import SwiftUI

@main
struct XYIdactylApp: App {
    init() {
        // Attempt to trigger Local Network permission early if the user is going to use a local IP
        // by making a dummy outgoing request to a private IP range.
        let url = URL(string: "http://192.168.0.1")!
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 1)
        URLSession.shared.dataTask(with: request).resume()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark) // Liquid Glass looks best in dark mode
        }
    }
}
