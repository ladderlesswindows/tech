import Foundation
import SwiftUI

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

struct Booking: Identifiable, Decodable, Hashable {
    let id: String
    let first_name: String?
    let last_name: String?
    let address: String?
    let service_date: String?
    let service_time: String?
    let window_count: Int?
    let total_price: Double?
    let status: String?

    var displayName: String {
        [first_name, last_name].compactMap { $0 }.joined(separator: " ")
    }

    var formattedDate: String {
        guard let d = service_date else { return "" }
        let iso = DateFormatter(); iso.dateFormat = "yyyy-MM-dd"
        guard let date = iso.date(from: d) else { return d }
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    var isToday: Bool {
        service_date == DateFormatter.isoDate.string(from: Date())
    }
}

struct TechAlert: Identifiable, Decodable {
    let id: String
    let created_at: String
    let customer_name: String?
    let address: String?
    let windows_added: Int
    let interiors_added: Int
    let screens_added: Int
    let technician_name: String?
    var acknowledged: Bool

    var minutesAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = fmt.date(from: created_at) ?? ISO8601DateFormatter().date(from: created_at) else { return "" }
        let mins = Int(-d.timeIntervalSinceNow / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        return "\(mins / 60)h \(mins % 60)m ago"
    }
}

struct BookingsResponse: Decodable { let bookings: [Booking] }
struct AlertsResponse: Decodable { let alerts: [TechAlert] }

extension DateFormatter {
    static let isoDate: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
}
