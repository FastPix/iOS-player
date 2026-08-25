import SwiftUI
import AVKit
import FastPixPlayerSDK

// MARK: - Configuration
// Replace these placeholders with your own values before running.
enum FastPixConfig {
    /// Your FastPix workspace key. Find it in the FastPix dashboard under
    /// Workspaces (https://dashboard.fastpix.io). A placeholder key still
    /// wires the analytics pipeline — the backend just rejects its beacons.
    static let workspaceKey = "WORKSPACE_KEY"

    /// The playback ID of the video to play, from your FastPix dashboard.
    /// Defaults to a public FastPix demo asset so the example runs as-is.
    static let playbackID = "7c8d5087-edf7-462f-a1b3-e2fbd30747fa"
}

// MARK: - Player + SDK owner
// SwiftUI View structs are recreated on every render, so the player and the
// FastPix Data SDK attached to it must live in an ObservableObject that
// survives re-renders (held as @StateObject by the View).
final class PlayerModel: ObservableObject {
    let controller = AVPlayerViewController()

    init() {
        // Attach FastPix analytics before preparing playback.
        controller.enableAnalytics(metadata: [
            "workspace_id": FastPixConfig.workspaceKey,
            "video_title": "FastPix SwiftUI Example",
            "viewer_id": "swiftui-demo-user",
            "video_stream_type": "on-demand",
        ])
        controller.prepare(
            playbackID: FastPixConfig.playbackID,
            playbackOptions: PlaybackOptions(streamType: "on-demand")
        )
    }

    func play() { controller.play() }
    func pause() { controller.pause() }

    deinit {
        // Releasing the controller tears down the player and detaches the SDK.
        controller.pause()
    }
}

// MARK: - SwiftUI bridge for AVPlayerViewController
struct FastPixPlayerView: UIViewControllerRepresentable {
    let controller: AVPlayerViewController
    func makeUIViewController(context: Context) -> AVPlayerViewController { controller }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

struct ContentView: View {
    @StateObject private var model = PlayerModel()

    var body: some View {
        FastPixPlayerView(controller: model.controller)
            .ignoresSafeArea()
            .onAppear { model.play() }
            .onDisappear { model.pause() } // teardown on disappear
    }
}
