import SwiftUI
import AVKit

// MARK: - Video Player Manager (Singleton)
class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    let player: AVPlayer
    private var isInitialized = false
    
    private init() {
        self.player = AVPlayer()
        self.player.isMuted = true
        self.player.actionAtItemEnd = .none // Loop managed by observer
    }
    
    func setup(videoName: String) {
        if isInitialized { return }
        
        var videoURL: URL?
        if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            videoURL = url
        } else if let path = Bundle.main.path(forResource: videoName, ofType: "mp4") {
            videoURL = URL(fileURLWithPath: path)
        }
        
        guard let url = videoURL else {
            print("❌ Shared Video not found: \(videoName).mp4")
            return
        }
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        // Setup Loop
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        
        player.play()
        isInitialized = true
    }
}

// MARK: - Smart Video Background (Handles Attach/Detach)
struct VideoBackgroundView: View {
    let videoName: String
    @Binding var isVideoReady: Bool
    
    var body: some View {
        VideoBackgroundRepresentable(videoName: videoName, isVideoReady: $isVideoReady)
            .onAppear {
                // When appearing, we ensure the shared player is setup
                VideoPlayerManager.shared.setup(videoName: videoName)
            }
    }
}

// MARK: - Internal Representable
private struct VideoBackgroundRepresentable: UIViewRepresentable {
    let videoName: String
    @Binding var isVideoReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create Layer but DO NOT attach player yet (wait for update or appear logic if possible, 
        // but simple "always attach" is fine for init, as onDisappear isn't called yet)
        let playerLayer = AVPlayerLayer(player: VideoPlayerManager.shared.player)
        playerLayer.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer
        
        // Initial Ready Check
        checkReadyState(context: context)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
        
        // Crucial: Update player attachment based on view hierarchy presence
        // But updateUIView is called on init and layout changes.
        // We really need 'onDisappear' equivalent in Representable. 
        // SwiftUI 'dismantleUIView' is for *destruction*, not hiding.
        // Tab switching usually *hides* views, doesn't always destroy them immediately?
        // Actually, TabView usually keeps state but might dismantle UIViews? 
        // If it dismantles, we are good (layer destroyed).
        // If it keeps them, we need to manually detach.
        
        // Optimization: Use the context.environment to detect visibility?
        // Simpler: Just ensure player is attached here.
        if context.coordinator.playerLayer?.player == nil {
             context.coordinator.playerLayer?.player = VideoPlayerManager.shared.player
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        // DETACH PLAYER ON DESTRUCTION
        // This stops the GPU work for this specific layer/tab when it is removed from hierarchy
        coordinator.playerLayer?.player = nil
    }
    
    func checkReadyState(context: Context) {
        let player = VideoPlayerManager.shared.player
        if let item = player.currentItem, item.status == .readyToPlay {
            DispatchQueue.main.async { isVideoReady = true }
        } else if let item = player.currentItem {
            // Observe status
            item.addObserver(context.coordinator, forKeyPath: "status", options: [.new], context: nil)
            context.coordinator.observedItem = item
            context.coordinator.isVideoReadyBinding = $isVideoReady // Store binding to update later
        }
        
        if player.timeControlStatus != .playing {
            player.play()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var playerLayer: AVPlayerLayer?
        var observedItem: AVPlayerItem?
        var isVideoReadyBinding: Binding<Bool>?
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "status", let item = object as? AVPlayerItem {
                if item.status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.isVideoReadyBinding?.wrappedValue = true
                    }
                    item.removeObserver(self, forKeyPath: "status")
                    self.observedItem = nil
                }
            }
        }
        
        deinit {
            if let item = observedItem {
                item.removeObserver(self, forKeyPath: "status")
            }
        }
    }
}
