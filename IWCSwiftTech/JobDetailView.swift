import SwiftUI

struct JobDetailView: View {
    let booking: Booking
    @ObservedObject var timerMgr: TimerManager
    @Environment(\.dismiss) private var dismiss

    @State private var showTechJob = false
    @State private var showMapPicker = false

    private var shiftWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "shift" }) }

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.78).ignoresSafeArea())

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("JOB DETAIL")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if timerMgr.windowsCleanedToday > 0 { statsCard }
                        jobInfoCard
                        propertyCard
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }

            VStack {
                Spacer()
                startNavigateButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .confirmationDialog("Open directions in...", isPresented: $showMapPicker, titleVisibility: .visible) {
            Button("Apple Maps") {
                openMaps(scheme: "maps://?daddr=", suffix: "&dirflg=d")
                showTechJob = true
            }
            Button("Google Maps") {
                let opened = openMaps(scheme: "comgooglemaps://?daddr=", suffix: "&directionsmode=driving")
                if !opened { openMaps(scheme: "maps://?daddr=", suffix: "&dirflg=d") }
                showTechJob = true
            }
            Button("Skip Navigation") { showTechJob = true }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showTechJob, onDismiss: { dismiss() }) {
            TechJobView(booking: booking, timerMgr: timerMgr)
                .environmentObject(timerMgr)
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        let perHr = timerMgr.windowsPerHour(at: timerMgr.tick)
        return HStack(spacing: 0) {
            statCell(emoji: "🪟", value: "\(timerMgr.windowsCleanedToday)", label: "TODAY", color: "34D399")
            if perHr > 0 {
                Rectangle().fill(Color(hex: "3AAAC4").opacity(0.15)).frame(width: 1, height: 32)
                statCell(emoji: "⚡️", value: String(format: "%.1f", perHr), label: "PER HR", color: "7ED8EA")
            }
            Rectangle().fill(Color(hex: "3AAAC4").opacity(0.15)).frame(width: 1, height: 32)
            statCell(emoji: "📅", value: "\(timerMgr.windowsCleanedThisWeek)", label: "THIS WK", color: "3AAAC4")
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(Color(hex: "0A2030").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
    }

    private func statCell(emoji: String, value: String, label: String, color: String) -> some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: color))
                Text(label)
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(Color.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Job Info

    private var jobInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Big date + time hero
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let t = booking.service_time {
                    Text(t)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "7ED8EA"))
                }
                Spacer()
                Text(booking.formattedDate)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.bottom, 4)

            Divider().background(Color(hex: "3AAAC4").opacity(0.15))

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                if let addr = booking.address {
                    Text(addr)
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }

            Divider().background(Color(hex: "3AAAC4").opacity(0.15))

            Label("\(booking.window_count ?? 0) windows", systemImage: "window.casement")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "7ED8EA"))
        }
        .padding(18)
        .background(Color(hex: "0A2030").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "3AAAC4").opacity(0.2), lineWidth: 1))
    }

    // MARK: - Property Placeholder

    private var propertyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROPERTY DATA")
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(Color(hex: "3AAAC4").opacity(0.35))

            HStack(spacing: 0) {
                propCell(icon: "ruler", value: "—", label: "SQ FT")
                Rectangle().fill(Color(hex: "3AAAC4").opacity(0.1)).frame(width: 1, height: 28)
                propCell(icon: "building.2", value: "—", label: "STORIES")
                Rectangle().fill(Color(hex: "3AAAC4").opacity(0.1)).frame(width: 1, height: 28)
                propCell(icon: "calendar.badge.clock", value: "—", label: "BUILT")
                Spacer()
            }
        }
        .padding(16)
        .background(Color(hex: "070F18").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }

    private func propCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.2))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.white.opacity(0.2))
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(1)
                .foregroundColor(Color.white.opacity(0.18))
        }
        .frame(minWidth: 72)
    }

    // MARK: - Start & Navigate

    private var startNavigateButton: some View {
        Button { startAndNavigate() } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 46, height: 46)
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start & Navigate")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(booking.address ?? "Tap to begin job")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color(hex: "1278A0").opacity(0.45), radius: 18, y: 8)
        }
    }

    private func startAndNavigate() {
        timerMgr.cancelShiftEnd()
        if timerMgr.watches.first(where: { $0.id == "shift" })?.isRunning == false {
            timerMgr.toggle("shift")
        }
        if timerMgr.watches.first(where: { $0.id == "drive" })?.isRunning == false {
            timerMgr.toggle("drive")
        }
        showMapPicker = true
    }

    @discardableResult
    private func openMaps(scheme: String, suffix: String) -> Bool {
        guard let addr = booking.address,
              let encoded = addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(scheme)\(encoded)\(suffix)"),
              UIApplication.shared.canOpenURL(url)
        else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
