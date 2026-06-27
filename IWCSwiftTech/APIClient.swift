import Foundation

class APIClient {
    static let base = "https://www.ladderlesswindows.com"

    static func headers(password: String) -> [String: String] {
        ["x-admin-pw": password, "Content-Type": "application/json"]
    }

    static func fetchSchedule(password: String) async throws -> [Booking] {
        var req = URLRequest(url: URL(string: "\(base)/api/admin/bookings")!)
        headers(password: password).forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, _) = try await URLSession.shared.data(for: req)
        let all = try JSONDecoder().decode(BookingsResponse.self, from: data).bookings
        let today = DateFormatter.isoDate.string(from: Date())
        return all.filter { b in
            guard let d = b.service_date else { return false }
            return d >= today && b.status != "prebooked" && b.status != "cancelled"
        }
    }

    static func fetchAlerts(password: String) async throws -> [TechAlert] {
        var req = URLRequest(url: URL(string: "\(base)/api/tech/alerts")!)
        headers(password: password).forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(AlertsResponse.self, from: data).alerts
    }

    static func acknowledgeAlert(id: String, password: String) async throws {
        var req = URLRequest(url: URL(string: "\(base)/api/tech/alerts")!)
        req.httpMethod = "PATCH"
        headers(password: password).forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id": id])
        _ = try await URLSession.shared.data(for: req)
    }

    static func verifyPassword(_ password: String) async -> Bool {
        var req = URLRequest(url: URL(string: "\(base)/api/admin/bookings")!)
        headers(password: password).forEach { req.setValue($1, forHTTPHeaderField: $0) }
        guard let (_, response) = try? await URLSession.shared.data(for: req) else { return false }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
}
