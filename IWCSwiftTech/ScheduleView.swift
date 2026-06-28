import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var timerMgr: TimerManager
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var selectedBooking: Booking? = nil

    private var grouped: [(key: String, values: [Booking])] {
        let sorted = bookings.sorted { ($0.service_date ?? "") < ($1.service_date ?? "") }
        var dict: [(key: String, values: [Booking])] = []
        for booking in sorted {
            let key = sectionTitle(for: booking.service_date ?? "")
            if let idx = dict.firstIndex(where: { $0.key == key }) {
                dict[idx].values.append(booking)
            } else {
                dict.append((key: key, values: [booking]))
            }
        }
        return dict
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SCHEDULE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("Upcoming Jobs")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "3AAAC4"))
                } else {
                    Button { Task { await loadSchedule() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            if bookings.isEmpty && !isLoading {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(grouped, id: \.key) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.key)
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(2)
                                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
                                    .padding(.leading, 4)

                                VStack(spacing: 8) {
                                    ForEach(group.values) { booking in
                                        Button { selectedBooking = booking } label: {
                                            ScheduleJobCard(booking: booking)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.bottom, 20)
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .task { await loadSchedule() }
        .fullScreenCover(item: $selectedBooking) { booking in
            JobDetailView(booking: booking, timerMgr: timerMgr)
        }
    }

    private func loadSchedule() async {
        guard let pw = UserDefaults.standard.string(forKey: "worker_password") else { return }
        isLoading = true
        errorMsg = nil
        do {
            bookings = try await APIClient.fetchSchedule(password: pw)
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func sectionTitle(for dateStr: String) -> String {
        let iso = DateFormatter(); iso.dateFormat = "yyyy-MM-dd"
        guard let date = iso.date(from: dateStr) else { return dateStr }
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: date)
        let diff = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
        switch diff {
        case 0: return "TODAY"
        case 1: return "TOMORROW"
        default:
            let fmt = DateFormatter(); fmt.dateFormat = "EEEE · MMM d"
            return fmt.string(from: date).uppercased()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "0A2A3C").opacity(0.6))
                    .frame(width: 80, height: 80)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 34))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
            }
            Text("No upcoming jobs")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.3))
            Spacer()
            Spacer()
        }
    }
}

struct ScheduleJobCard: View {
    let booking: Booking

    var statusColor: Color {
        switch booking.status {
        case "confirmed": return Color(hex: "34D399")
        case "pending": return Color(hex: "F59E0B")
        default: return Color(hex: "3AAAC4")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Time column
            VStack(spacing: 2) {
                Text(booking.service_time?.replacingOccurrences(of: ":00", with: "") ?? "--")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "7ED8EA"))
                    .multilineTextAlignment(.center)
            }
            .frame(width: 52)
            .padding(.leading, 4)

            Divider()
                .background(Color(hex: "3AAAC4").opacity(0.2))
                .frame(height: 44)
                .padding(.horizontal, 10)

            // Job info
            VStack(alignment: .leading, spacing: 3) {
                Text(booking.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                if let addr = booking.address {
                    Text(addr)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.38))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Window count + price
            VStack(alignment: .trailing, spacing: 3) {
                if let w = booking.window_count {
                    Text("\(w)w")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "3AAAC4"))
                }
                if let p = booking.total_price, p > 0 {
                    Text("$\(Int(p))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
            .padding(.trailing, 4)

            // Status dot
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.leading, 10)
                .padding(.trailing, 6)
        }
        .padding(.vertical, 12)
        .background(Color(hex: "0A2030").opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.12), lineWidth: 1))
    }
}
