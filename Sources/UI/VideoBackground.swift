import SwiftUI
import AVKit

// MARK: - Video Background Player
struct VideoBackgroundView: UIViewRepresentable {
    let videoName: String
    @Binding var isVideoReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Try multiple ways to find the video
        var videoURL: URL?
        
        // Method 1: Direct bundle URL
        if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            videoURL = url
        }
        // Method 2: Path-based lookup
        else if let path = Bundle.main.path(forResource: videoName, ofType: "mp4") {
            videoURL = URL(fileURLWithPath: path)
        }
        
        guard let url = videoURL else {
            print("❌ Video not found: \(videoName).mp4")
            return containerView
        }
        
        print("✅ Video found at: \(url)")
        
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds
        
        containerView.layer.addSublayer(playerLayer)
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        // Observe when video is ready to play
        player.currentItem?.addObserver(context.coordinator, forKeyPath: "status", options: [.new], context: nil)
        
        player.play()
        
        // Store player in coordinator to keep it alive
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        context.coordinator.isVideoReady = $isVideoReady
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var isVideoReady: Binding<Bool>?
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "status", let item = object as? AVPlayerItem {
                if item.status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.isVideoReady?.wrappedValue = true
                    }
                }
            }
        }
        
        deinit {
            player?.currentItem?.removeObserver(self, forKeyPath: "status")
        }
    }
}
