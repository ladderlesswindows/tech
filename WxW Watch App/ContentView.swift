import SwiftUI
import WatchConnectivity
import Combine

// MARK: - Watch Session

class WxWSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WxWSession()

    @Published var isActive = false
    @Published var wallName = ""
    @Published var currentWindow = 0
    @Published var totalWindows = 0
    @Published var baseElapsed: TimeInterval = 0
    @Published var isPaused = false

    // Local timer to count up from baseElapsed
    private var receivedAt = Date()
    @Published var liveElapsed: TimeInterval = 0
    private var timerCancellable: AnyCancellable?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        startLocalTimer()
        // Pick up any state that was sent while the watch app wasn't running
        let ctx = WCSession.default.receivedApplicationContext
        if !ctx.isEmpty { apply(ctx) }
    }

    private func startLocalTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isActive, !self.isPaused else { return }
                self.liveElapsed = self.baseElapsed + Date().timeIntervalSince(self.receivedAt)
            }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    private func apply(_ message: [String: Any]) {
        DispatchQueue.main.async {
            let active = message["active"] as? Bool ?? false
            self.isActive = active
            guard active else { return }
            self.wallName = message["wall"] as? String ?? ""
            self.currentWindow = message["window"] as? Int ?? 0
            self.totalWindows = message["total"] as? Int ?? 0
            self.baseElapsed = message["elapsed"] as? TimeInterval ?? 0
            self.isPaused = message["paused"] as? Bool ?? false
            self.receivedAt = Date()
            self.liveElapsed = self.baseElapsed
        }
    }

    func sendAction(_ action: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": action], replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}

// MARK: - Watch UI

struct ContentView: View {
    @StateObject private var session = WxWSession.shared

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        if session.isActive {
            activeView
        } else {
            idleView
        }
    }

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "window.casement")
                .font(.system(size: 28))
                .foregroundColor(.blue.opacity(0.5))
            Text("WxW")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.white.opacity(0.4))
            Text("Waiting for wall")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }

    private var activeView: some View {
        VStack(spacing: 4) {
            // Wall name
            Text(session.wallName.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.blue.opacity(0.7))
                .lineLimit(1)

            // Window counter
            Text("\(session.currentWindow) of \(session.totalWindows)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            // Timer
            Text(formatTime(session.isPaused ? session.baseElapsed : session.liveElapsed))
                .font(.system(size: 30, weight: .ultraLight, design: .monospaced))
                .foregroundColor(session.isPaused ? .white.opacity(0.4) : Color(red: 1.0, green: 0.42, blue: 0.42))
                .animation(.none, value: session.liveElapsed)

            if session.isPaused {
                Text("PAUSED")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer().frame(height: 4)

            // NEXT button
            Button {
                session.sendAction("next")
            } label: {
                Label("NEXT", systemImage: "forward.end.fill")
                    .font(.system(size: 14, weight: .black))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // PAUSE button
            Button {
                session.sendAction("pause")
            } label: {
                Text(session.isPaused ? "RESUME" : "PAUSE")
                    .font(.system(size: 12, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(session.isPaused ? Color.green.opacity(0.7) : Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ContentView()
}
