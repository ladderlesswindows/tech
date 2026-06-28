import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var timerMgr: TimerManager
    @ObservedObject var alertsMgr: AlertsManager
    @Binding var selectedTab: Int

    @State private var upcomingJobs: [Booking] = []
    @State private var isLoadingJobs = false
    @State private var activeJob: Booking? = nil
    @State private var showProfile = false
    @State private var avatarImage: UIImage? = nil

    private var avatarKey: String { "avatar_\(auth.currentEmployee?.id ?? "unknown")" }

    private var shiftState: StopwatchState? { timerMgr.watches.first(where: { $0.id == "shift" }) }
    private var shiftRunning: Bool { shiftState?.isRunning ?? false }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, 60)
                    .padding(.bottom, 24)

                // Windows cleaned tally — appears once first job is closed
                if timerMgr.windowsCleanedToday > 0 {
                    let perHr = timerMgr.windowsPerHour(at: timerMgr.tick)
                    HStack(spacing: 0) {
                        tallyCell(value: "\(timerMgr.windowsCleanedToday)", label: "TODAY", color: "34D399")
                        if perHr > 0 {
                            Rectangle().fill(Color(hex: "34D399").opacity(0.15)).frame(width: 1, height: 32)
                            tallyCell(value: String(format: "%.1f", perHr), label: "PER HR", color: "7ED8EA")
                        }
                        Rectangle().fill(Color(hex: "34D399").opacity(0.15)).frame(width: 1, height: 32)
                        tallyCell(value: "\(timerMgr.windowsCleanedThisWeek)", label: "THIS WK", color: "3AAAC4")
                        Spacer()
                        Text("🪟").font(.system(size: 22)).padding(.trailing, 16)
                    }
                    .padding(.horizontal, 4).padding(.vertical, 14)
                    .background(Color(hex: "0A1E12").opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "34D399").opacity(0.25), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: timerMgr.windowsCleanedToday)
                }

                // Shift auto-end countdown
                if let countdown = timerMgr.shiftEndCountdown {
                    let mins = Int(countdown) / 60
                    let secs = Int(countdown) % 60
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text("Shift ends in \(mins):\(String(format: "%02d", secs)) — start another job to continue")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "F59E0B").opacity(0.85))
                        Spacer()
                        Button {
                            timerMgr.cancelShiftEnd()
                        } label: {
                            Text("Keep open")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color(hex: "F59E0B").opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color(hex: "1A1000").opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "F59E0B").opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: timerMgr.shiftEndTime)
                }

                // Shift control card
                shiftCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Incoming alert banner
                if let alert = alertsMgr.incomingAlert {
                    incomingAlertBanner(alert: alert)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: alertsMgr.incomingAlert?.id)
                }

                // Quick nav pills
                quickNavRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Upcoming jobs — shown once clocked in
                if shiftRunning && !upcomingJobs.isEmpty {
                    let todayJobs = upcomingJobs.filter { $0.isToday }
                    let futureJobs = upcomingJobs.filter { !$0.isToday }

                    if !todayJobs.isEmpty {
                        sectionHeader("TODAY · \(todayJobs.count) JOB\(todayJobs.count == 1 ? "" : "S")")
                            .padding(.horizontal, 20).padding(.bottom, 10)
                        VStack(spacing: 8) {
                            ForEach(todayJobs) { job in
                                JobRowCard(booking: job, shiftRunning: shiftRunning) { activeJob = job }
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 16)
                    }

                    if !futureJobs.isEmpty {
                        sectionHeader("UPCOMING")
                            .padding(.horizontal, 20).padding(.bottom, 10)
                        VStack(spacing: 8) {
                            ForEach(futureJobs) { job in
                                JobRowCard(booking: job, shiftRunning: shiftRunning) { activeJob = job }
                            }
                        }
                        .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                }

                // Running timers summary
                if timerMgr.watches.filter({ $0.isRunning }).count > 1 {
                    runningTimersSummary
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }

                Spacer(minLength: 120)
            }
        }
        .task { await loadJobs() }
        .fullScreenCover(item: $activeJob) { job in
            JobDetailView(booking: job, timerMgr: timerMgr)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { showProfile = true } label: {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0A3D5C").opacity(0.8))
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color(hex: "3AAAC4").opacity(0.4), lineWidth: 1.5))
                    if let img = avatarImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())
                    } else {
                        Text(String(auth.currentEmployee?.name.prefix(1) ?? "?"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "7ED8EA"))
                    }
                }
            }
            .buttonStyle(.plain)

            Button { showProfile = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.currentEmployee?.name ?? "Technician")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text(shiftRunning ? "Shift active" : "Off clock")
                        .font(.system(size: 12))
                        .foregroundColor(shiftRunning ? Color(hex: "34D399") : Color.white.opacity(0.4))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            SoundToggle()
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showProfile, onDismiss: {
            if let data = UserDefaults.standard.data(forKey: avatarKey) {
                avatarImage = UIImage(data: data)
            }
        }) {
            WorkerProfileView(timerMgr: timerMgr)
        }
        .onAppear {
            if let data = UserDefaults.standard.data(forKey: avatarKey) {
                avatarImage = UIImage(data: data)
            }
        }
    }

    // MARK: - Shift Card

    private var shiftCard: some View {
        let sw = shiftState
        let elapsed = sw?.currentElapsed(at: timerMgr.tick) ?? 0

        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: shiftRunning
                                    ? [Color(hex: "34D399").opacity(0.6), Color(hex: "3AAAC4").opacity(0.25)]
                                    : [Color.white.opacity(0.12), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SHIFT CLOCK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(2)
                        .foregroundColor(Color.white.opacity(0.35))

                    Text(shiftRunning ? (sw?.formatTime(elapsed) ?? "00:00") : "Ready")
                        .font(.system(size: 38, weight: .light, design: .monospaced))
                        .foregroundColor(shiftRunning ? Color(hex: "7ED8EA") : Color.white.opacity(0.25))
                        .animation(.none, value: elapsed)
                }
                .padding(.leading, 22)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if shiftRunning { timerMgr.clockOut() }
                        else { timerMgr.clockIn() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                shiftRunning
                                ? Color(hex: "0F4A30").opacity(0.9)
                                : Color(hex: "1278A0").opacity(0.9)
                            )
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(
                                shiftRunning ? Color(hex: "34D399").opacity(0.6) : Color(hex: "3AAAC4").opacity(0.6),
                                lineWidth: 1.5
                            ))
                        Image(systemName: shiftRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing, 18)
            }
            .padding(.vertical, 22)
        }
        .frame(height: 100)
    }

    // MARK: - Quick Nav

    private var quickNavRow: some View {
        HStack(spacing: 10) {
            quickNavPill(icon: "timer", label: "Clocks", tab: 1)
            quickNavPill(icon: "calendar", label: "Schedule", tab: 2)
            quickNavPill(icon: "bell.fill", label: "Alerts\(alertsMgr.unreadCount > 0 ? " (\(alertsMgr.unreadCount))" : "")", tab: 3)
            quickNavPill(icon: "map.fill", label: "Miles", tab: 4)
        }
    }

    private func quickNavPill(icon: String, label: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "7ED8EA").opacity(0.85))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "0A2D42").opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        }
    }

    // MARK: - Incoming Alert Banner

    private func incomingAlertBanner(alert: TechAlert) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color(hex: "F97316").opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "F97316"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("NOTIFY TECH")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(Color(hex: "F97316").opacity(0.8))
                Text("\(alert.customer_name ?? "Customer") added \(alert.windows_added)w\(alert.screens_added > 0 ? " + \(alert.screens_added) screens" : "")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(alert.address ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.4))
                    .lineLimit(1)
            }
            Spacer()
            Button { withAnimation { alertsMgr.acknowledge(alert) } } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "34D399"))
            }
        }
        .padding(16)
        .background(Color(hex: "1A1200").opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "F97316").opacity(0.4), lineWidth: 1))
    }

    // MARK: - Running Timers Summary

    private var runningTimersSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("ACTIVE TIMERS")
            VStack(spacing: 6) {
                ForEach(timerMgr.watches.filter { $0.isRunning }) { w in
                    HStack {
                        Text(w.emoji)
                            .font(.system(size: 14))
                        Text(w.label)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.7))
                        Spacer()
                        Text(w.formatTime(w.currentElapsed(at: timerMgr.tick)))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: w.color))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "0A2A3A").opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func tallyCell(value: String, label: String, color: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.3))
        }
        .frame(minWidth: 72)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black))
            .tracking(2)
            .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
    }

    private func loadJobs() async {
        guard let pw = UserDefaults.standard.string(forKey: "worker_password") else { return }
        isLoadingJobs = true
        if let jobs = try? await APIClient.fetchSchedule(password: pw) {
            upcomingJobs = jobs
        }
        isLoadingJobs = false
    }
}

struct JobRowCard: View {
    let booking: Booking
    var shiftRunning: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            if shiftRunning { onTap?() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "3AAAC4").opacity(shiftRunning ? 0.25 : 0.1))
                        .frame(width: 38, height: 38)
                    Image(systemName: shiftRunning ? "window.casement" : "house.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(shiftRunning ? Color(hex: "7ED8EA") : Color.white.opacity(0.25))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(booking.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(shiftRunning ? .white : Color.white.opacity(0.4))
                    if let addr = booking.address {
                        Text(addr)
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.35))
                            .lineLimit(1)
                    }
                    if !shiftRunning {
                        Text("Start shift to begin")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let t = booking.service_time {
                        Text(t)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(shiftRunning ? Color(hex: "7ED8EA") : Color.white.opacity(0.25))
                    }
                    if let w = booking.window_count {
                        Text("\(w)w")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(shiftRunning ? Color(hex: "3AAAC4").opacity(0.5) : Color.white.opacity(0.1))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(hex: shiftRunning ? "0A2A3C" : "071520").opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        shiftRunning ? Color(hex: "3AAAC4").opacity(0.3) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
