import SwiftUI
import AVFoundation

@main
struct IWCSwiftTechApp: App {
    @StateObject private var auth = AuthManager.shared

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        _ = VideoPlayerController.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
