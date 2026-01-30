import SwiftUI
import AVKit

// MARK: - Video Player Manager (Singleton)
class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    let player: AVPlayer
    private var isInitialized = false
    
    // Store loop observer to prevent duplicates if specific logic needed, 
    // but NotificationCenter handles multiple observers fine (we only add one in setup).
    private var loopObserver: NSObjectProtocol?
    
    private init() {
        self.player = AVPlayer()
        self.player.isMuted = true
        self.player.actionAtItemEnd = .none
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
        
        print("✅ Initialize Shared Video: \(url)")
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        // Setup Loop (Only once)
        loopObserver = NotificationCenter.default.addObserver(
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

// MARK: - Video Background Player
struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    @Binding var isVideoReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Setup shared player
        VideoPlayerManager.shared.setup(videoName: videoName)
        let player = VideoPlayerManager.shared.player
        
        // Create Layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(playerLayer)
        
        context.coordinator.playerLayer = playerLayer
        
        // Check Ready State
        if let item = player.currentItem, item.status == .readyToPlay {
            // Already ready
            DispatchQueue.main.async {
                isVideoReady = true
            }
        } else if let item = player.currentItem {
            // Observe
            item.addObserver(context.coordinator, forKeyPath: "status", options: [.new], context: nil)
            context.coordinator.observedItem = item
            context.coordinator.isVideoReady = $isVideoReady
        }
        
        // Ensure playing
        if player.timeControlStatus != .playing {
            player.play()
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var playerLayer: AVPlayerLayer?
        var isVideoReady: Binding<Bool>?
        weak var observedItem: AVPlayerItem?
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "status", let item = object as? AVPlayerItem {
                if item.status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.isVideoReady?.wrappedValue = true
                    }
                    // Remove observer once ready to avoid redundant calls or crash
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
