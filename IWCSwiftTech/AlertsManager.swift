import Foundation
import Combine

@MainActor
class AlertsManager: ObservableObject {
    @Published var alerts: [TechAlert] = []
    @Published var incomingAlert: TechAlert? = nil

    private var pollingTimer: AnyCancellable?
    private var lastAlertIds: Set<String> = []

    var unreadCount: Int { alerts.filter { !$0.acknowledged }.count }

    func startPolling() {
        poll()
        pollingTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchAlerts() }
            }
    }

    func stopPolling() { pollingTimer = nil }

    private func poll() {
        Task { await fetchAlerts() }
    }

    private func fetchAlerts() async {
        guard let pw = UserDefaults.standard.string(forKey: "worker_password") else { return }
        guard let fresh = try? await APIClient.fetchAlerts(password: pw) else { return }
        let newIds = Set(fresh.map { $0.id })
        let brandNew = fresh.filter { !lastAlertIds.contains($0.id) && !$0.acknowledged }
        lastAlertIds = newIds
        alerts = fresh
        if let first = brandNew.first {
            incomingAlert = first
        }
    }

    func acknowledge(_ alert: TechAlert) {
        guard let pw = UserDefaults.standard.string(forKey: "worker_password") else { return }
        if let idx = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[idx].acknowledged = true
        }
        if incomingAlert?.id == alert.id { incomingAlert = nil }
        Task { try? await APIClient.acknowledgeAlert(id: alert.id, password: pw) }
    }
}
