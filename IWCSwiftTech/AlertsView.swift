import SwiftUI

struct AlertsView: View {
    @ObservedObject var alertsMgr: AlertsManager
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOTIFY TECH")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.3))
                    HStack(spacing: 8) {
                        Text("Alerts")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        if alertsMgr.unreadCount > 0 {
                            Text("\(alertsMgr.unreadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(Color(hex: "F97316"))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                SoundToggle()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            if alertsMgr.alerts.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(alertsMgr.alerts) { alert in
                            AlertCard(alert: alert) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                                    alertsMgr.acknowledge(alert)
                                }
                            }
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color(hex: "0A2A3C").opacity(0.6))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash")
                    .font(.system(size: 34))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
            }
            Text("No alerts in the last 24 hours")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.3))
            Text("When a customer taps Notify Tech, it appears here instantly.")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }
}

struct AlertCard: View {
    let alert: TechAlert
    let onAcknowledge: () -> Void

    var windowSummary: String {
        var parts: [String] = []
        if alert.windows_added > 0 { parts.append("\(alert.windows_added) ext windows") }
        if alert.interiors_added > 0 { parts.append("\(alert.interiors_added) interior") }
        if alert.screens_added > 0 { parts.append("\(alert.screens_added) screens") }
        return parts.isEmpty ? "Details pending" : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Unread indicator
            Rectangle()
                .fill(alert.acknowledged ? Color.clear : Color(hex: "F97316"))
                .frame(width: 3)
                .clipShape(Capsule())
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Customer name + time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.customer_name ?? "Customer")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(alert.acknowledged ? Color.white.opacity(0.5) : .white)
                        Text(alert.minutesAgo)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                    Spacer()
                    if !alert.acknowledged {
                        Button(action: onAcknowledge) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "34D399"))
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.15))
                    }
                }

                // Window breakdown
                HStack(spacing: 8) {
                    if alert.windows_added > 0 {
                        statChip(value: "\(alert.windows_added)", label: "EXT", color: "3AAAC4")
                    }
                    if alert.interiors_added > 0 {
                        statChip(value: "\(alert.interiors_added)", label: "INT", color: "34D399")
                    }
                    if alert.screens_added > 0 {
                        statChip(value: "\(alert.screens_added)", label: "SCR", color: "F59E0B")
                    }
                    Spacer()
                }

                if let addr = alert.address, !addr.isEmpty {
                    Label(addr, systemImage: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(alert.acknowledged ? 0.2 : 0.38))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(
            alert.acknowledged
            ? Color(hex: "07151E").opacity(0.6)
            : Color(hex: "0C2030").opacity(0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    alert.acknowledged
                    ? Color.white.opacity(0.05)
                    : Color(hex: "F97316").opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    private func statChip(value: String, label: String, color: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(Color(hex: color).opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(hex: color).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: color).opacity(0.3), lineWidth: 1))
    }
}
