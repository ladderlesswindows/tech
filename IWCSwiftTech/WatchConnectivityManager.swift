import Foundation
import WatchConnectivity

extension Notification.Name {
    static let wxwWatchAction = Notification.Name("WxWWatchAction")
}

class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendWallState(wall: String, window: Int, total: Int, elapsed: TimeInterval, paused: Bool, active: Bool) {
        let payload: [String: Any] = [
            "wall": wall, "window": window, "total": total,
            "elapsed": elapsed, "paused": paused, "active": active
        ]
        // updateApplicationContext delivers even if watch app isn't open yet
        try? WCSession.default.updateApplicationContext(payload)
        // sendMessage delivers immediately if watch app is already running
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    func sendIdle() {
        let payload: [String: Any] = ["active": false]
        try? WCSession.default.updateApplicationContext(payload)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    // Watch → Phone: action buttons
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .wxwWatchAction, object: nil, userInfo: ["action": action])
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
