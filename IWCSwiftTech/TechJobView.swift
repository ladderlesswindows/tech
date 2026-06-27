import SwiftUI
import PhotosUI

struct TechJobView: View {
    let booking: Booking
    @ObservedObject var timerMgr: TimerManager
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var safetyStage: SafetyStage = .step1
    @State private var safetyCleared = false
    @State private var step1Selections: Set<String> = []
    @State private var step2Checks: Set<String> = []
    @State private var showSafety = true

    // Check-in state
    enum CheckInState { case idle, requested, confirmed, exception }
    @State private var checkInState: CheckInState = .idle
    @State private var checkInId: String? = nil
    @State private var checkInPollingTask: Task<Void, Never>? = nil

    // Walls + job state
    @State private var showWalls = false
    @State private var showQuickWindow = false
    @State private var documentedWalls: [WallEntry] = []
    @State private var jobClosed = false
    @State private var showCloseConfirm = false

    var documentedWindowCount: Int { documentedWalls.reduce(0) { $0 + $1.windowPhotos.count } }
    var bookedWindowCount: Int { booking.window_count ?? 0 }
    var windowDelta: Int { documentedWindowCount - bookedWindowCount }

    enum SafetyStage { case step1, step2 }

    private var driveWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "drive" }) }
    private var onsiteWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "onsite" }) }
    private var windowWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "window" }) }
    private var onsiteRunning: Bool { onsiteWatch?.isRunning ?? false }
    private var password: String { auth.apiPassword }

    var body: some View {
        ZStack {
            // Background
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.78).ignoresSafeArea())

            if safetyCleared {
                jobDetailContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showSafety {
                SafetyOverlay(
                    stage: $safetyStage,
                    step1Selections: $step1Selections,
                    step2Checks: $step2Checks,
                    booking: booking,
                    onClear: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            showSafety = false
                            safetyCleared = true
                        }
                    },
                    onDismiss: { dismiss() }
                )
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showWalls) {
            WallsView(booking: booking, onComplete: { walls in
                documentedWalls.append(contentsOf: walls)
            })
            .environmentObject(timerMgr)
        }
        .sheet(isPresented: $showQuickWindow) {
            QuickWindowSheet { photo in
                var quick = WallEntry(area: "Last Minute", notes: "Quick add")
                quick.windowPhotos = [photo]
                documentedWalls.append(quick)
                showQuickWindow = false
            }
        }
        .confirmationDialog(
            "Close this job?",
            isPresented: $showCloseConfirm,
            titleVisibility: .visible
        ) {
            Button("Close Job + Stop Timers", role: .destructive) {
                if onsiteWatch?.isRunning == true { timerMgr.toggle("onsite") }
                if windowWatch?.isRunning == true { timerMgr.toggle("window") }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    jobClosed = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the On-Site and Window timers and mark the job complete.")
        }
        .onDisappear { checkInPollingTask?.cancel() }
    }

    // MARK: - Check-In Logic

    private func requestCheckIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            checkInState = .requested
        }
        Task {
            if let id = try? await APIClient.requestCheckIn(
                password: password,
                bookingId: booking.id,
                techName: auth.currentEmployee?.name ?? "Tech"
            ) {
                await MainActor.run { checkInId = id }
                startPolling()
            }
        }
    }

    private func startPolling() {
        checkInPollingTask?.cancel()
        checkInPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                if let status = try? await APIClient.pollCheckIn(password: password, bookingId: booking.id) {
                    if status.confirmed != nil {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                checkInState = .confirmed
                            }
                            checkInPollingTask?.cancel()
                        }
                        return
                    }
                }
            }
        }
    }

    // MARK: - Job Detail

    private var jobDetailContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Top bar
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
                    safetyBadge
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Job header card
                jobHeaderCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Timer controls
                timerSection(
                    watch: driveWatch,
                    id: "drive",
                    label: "Drive Timer",
                    emoji: "🚗",
                    subtitle: "Start when leaving for this job"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                timerSection(
                    watch: onsiteWatch,
                    id: "onsite",
                    label: "On-Site Timer",
                    emoji: "📍",
                    subtitle: "Start when you arrive"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Check-in block — appears once on-site timer is running
                if onsiteRunning {
                    checkInBlock
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: onsiteRunning)
                }

                // Window timer only unlocked after check-in
                if checkInState == .confirmed || checkInState == .exception {
                    timerSection(
                        watch: windowWatch,
                        id: "window",
                        label: "Window Timer",
                        emoji: "🪟",
                        subtitle: "Start when cleaning begins"
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    // Pre-documentation: Begin Wall Documentation
                    if documentedWalls.isEmpty {
                        Button { showWalls = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.grid.2x2.fill").font(.system(size: 17))
                                Text("Begin Wall Documentation").font(.system(size: 16, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18).padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "1278A0"), Color(hex: "0D5C85")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        // Post-documentation: Add Last Minute + Close Job
                        VStack(spacing: 10) {
                        Button { showQuickWindow = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.viewfinder").font(.system(size: 17))
                                Text("Add Last Minute Window").font(.system(size: 15, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13))
                            }
                            .foregroundColor(Color(hex: "7ED8EA"))
                            .padding(.horizontal, 18).padding(.vertical, 16)
                            .background(Color(hex: "0A2A3C").opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                        }

                        Button { showCloseConfirm = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 17))
                                Text("Close Job + Stop Gig Timer").font(.system(size: 15, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(jobClosed ? Color(hex: "34D399") : .white)
                            .padding(.horizontal, 18).padding(.vertical, 16)
                            .background {
                                if jobClosed {
                                    Color(hex: "0A1E12").opacity(0.85)
                                } else {
                                    LinearGradient(
                                        colors: [Color(hex: "1C3A50"), Color(hex: "0F2A3A")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                                jobClosed ? Color(hex: "34D399").opacity(0.35) : Color.white.opacity(0.1),
                                lineWidth: 1
                            ))
                        }
                        .disabled(jobClosed)

                        if jobClosed {
                            navigateButton
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    } // end VStack
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: jobClosed)
                    } // end else (post-documentation)
                } // end if checkInState

                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Job Header Card

    private var jobHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    if let addr = booking.address {
                        Text(addr)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
                Spacer()
                if let t = booking.service_time {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(t)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "7ED8EA"))
                        Text("scheduled")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
            }

            Divider().background(Color(hex: "3AAAC4").opacity(0.15))

            // Window count row
            HStack(spacing: 0) {
                // Booked
                windowStatCell(
                    value: "\(bookedWindowCount)",
                    label: "BOOKED",
                    color: "3AAAC4"
                )

                // Divider
                Rectangle()
                    .fill(Color(hex: "3AAAC4").opacity(0.15))
                    .frame(width: 1, height: 36)

                // Documented
                windowStatCell(
                    value: documentedWindowCount > 0 ? "\(documentedWindowCount)" : "—",
                    label: "DOCUMENTED",
                    color: documentedWindowCount > 0 ? "34D399" : "3AAAC4"
                )

                // Difference — only once we have documented windows
                if documentedWindowCount > 0 {
                    Rectangle()
                        .fill(Color(hex: "3AAAC4").opacity(0.15))
                        .frame(width: 1, height: 36)

                    let delta = windowDelta
                    windowStatCell(
                        value: delta == 0 ? "=" : (delta > 0 ? "+\(delta)" : "\(delta)"),
                        label: "DIFFERENCE",
                        color: delta == 0 ? "7ED8EA" : (delta > 0 ? "F59E0B" : "F97316")
                    )
                }

                Spacer()

                // Job status pill
                Text(jobClosed ? "CLOSED" : "ACTIVE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(2)
                    .foregroundColor(jobClosed ? Color(hex: "34D399") : Color(hex: "F59E0B"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(
                        jobClosed
                        ? Color(hex: "34D399").opacity(0.12)
                        : Color(hex: "F59E0B").opacity(0.12)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(18)
        .background(Color(hex: "0A2030").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(
            jobClosed ? Color(hex: "34D399").opacity(0.25) : Color(hex: "3AAAC4").opacity(0.2),
            lineWidth: 1
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: documentedWindowCount)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: jobClosed)
    }

    private func windowStatCell(value: String, label: String, color: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.3))
        }
        .frame(minWidth: 70)
    }

    // MARK: - Navigate

    private var navigateButton: some View {
        Button {
            guard let addr = booking.address,
                  let encoded = addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(encoded)&travelmode=driving")
            else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.system(size: 20))
                Text("Navigate")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Text(booking.address ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Timer Section

    private func timerSection(watch: StopwatchState?, id: String, label: String, emoji: String, subtitle: String) -> some View {
        let running = watch?.isRunning ?? false
        let elapsed = watch?.currentElapsed(at: timerMgr.tick) ?? 0
        let timeStr = watch?.formatTime(elapsed) ?? "00:00"

        return HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(running ? .white : Color.white.opacity(0.55))
                Text(running ? timeStr : subtitle)
                    .font(.system(size: running ? 22 : 11, weight: running ? .light : .regular, design: running ? .monospaced : .default))
                    .foregroundColor(running ? Color(hex: "7ED8EA") : Color.white.opacity(0.3))
                    .animation(.none, value: elapsed)
            }

            Spacer()

            Button { timerMgr.toggle(id) } label: {
                HStack(spacing: 6) {
                    Image(systemName: running ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(running ? "Pause" : "Start")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(running ? Color(hex: "34D399") : Color(hex: "7ED8EA"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    running
                    ? Color(hex: "0F3A25").opacity(0.9)
                    : Color(hex: "0A3D5C").opacity(0.9)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        running ? Color(hex: "34D399").opacity(0.4) : Color(hex: "3AAAC4").opacity(0.4),
                        lineWidth: 1
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: running ? "0C2A3E" : "071520").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(
                running ? Color(hex: "3AAAC4").opacity(0.35) : Color.white.opacity(0.07),
                lineWidth: running ? 1.5 : 1
            )
        )
    }

    // MARK: - Check-In Block

    @ViewBuilder
    private var checkInBlock: some View {
        switch checkInState {
        case .idle:
            Button { requestCheckIn() } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: "3AAAC4").opacity(0.15)).frame(width: 42, height: 42)
                        Image(systemName: "ipad.and.iphone")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "3AAAC4"))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Check In")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Notify the iPad app — customer confirms your arrival")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "0A2A3C").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)

        case .requested:
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(hex: "F59E0B").opacity(0.12)).frame(width: 42, height: 42)
                        ProgressView()
                            .tint(Color(hex: "F59E0B"))
                            .scaleEffect(1.1)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Waiting for check-in confirmation")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Customer needs to tap Confirm on the iPad")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "1A1200").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "F59E0B").opacity(0.35), lineWidth: 1))

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        checkInState = .exception
                        checkInPollingTask?.cancel()
                    }
                } label: {
                    Text("Proceed anyway (exception)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.3))
                        .underline()
                }
            }

        case .confirmed:
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: "34D399").opacity(0.15)).frame(width: 42, height: 42)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "34D399"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Checked In ✓")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "34D399"))
                    Text("Customer confirmed your arrival")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "0A1E12").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "34D399").opacity(0.3), lineWidth: 1))

        case .exception:
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: "F97316").opacity(0.12)).frame(width: 42, height: 42)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "F97316"))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Exception — proceeding without confirmation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "F97316"))
                    Text("Check-in was not confirmed on iPad")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.35))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "1A0A00").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "F97316").opacity(0.25), lineWidth: 1))
        }
    }

    // MARK: - Safety Badge

    private var safetyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "34D399"))
            Text("Safety cleared")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(hex: "34D399").opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "0F3A25").opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: "34D399").opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Quick Window Sheet

struct QuickWindowSheet: View {
    let onSave: (WindowPhoto) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var capturedPhoto: WindowPhoto? = nil
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        ZStack {
            Color(hex: "04101C").ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 6) {
                    Text("Last Minute Window")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Document and clean one complimentary window")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Photo preview or picker buttons
                if let photo = capturedPhoto, let img = photo.image {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 24)

                        Button { capturedPhoto = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        }
                        .offset(x: -28, y: 8)
                    }
                } else {
                    HStack(spacing: 14) {
                        Button { showCamera = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill").font(.system(size: 24))
                                Text("Camera").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "7ED8EA"))
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                            .background(Color(hex: "0A2A3C").opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                        }
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle").font(.system(size: 24))
                                Text("Library").font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "7ED8EA"))
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                            .background(Color(hex: "0A2A3C").opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Save button
                Button {
                    if let photo = capturedPhoto {
                        onSave(photo)
                    } else {
                        // Save without photo (documented but no image)
                        if let placeholder = UIImage(systemName: "window.casement")?.withTintColor(.white, renderingMode: .alwaysOriginal),
                           let data = placeholder.pngData() {
                            onSave(WindowPhoto(imageData: data))
                        }
                    }
                } label: {
                    Text(capturedPhoto != nil ? "Save Window" : "Document Without Photo")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "1278A0"), Color(hex: "0D5C85")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { img in
                if let data = img.jpegData(compressionQuality: 0.82) {
                    capturedPhoto = WindowPhoto(imageData: data)
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    capturedPhoto = WindowPhoto(imageData: data)
                }
                selectedItem = nil
            }
        }
    }
}

// MARK: - Safety Overlay

struct SafetyOverlay: View {
    @Binding var stage: TechJobView.SafetyStage
    @Binding var step1Selections: Set<String>
    @Binding var step2Checks: Set<String>
    let booking: Booking
    let onClear: () -> Void
    let onDismiss: () -> Void

    private let step1Options = [
        ("⌚", "Smartwatch online"),
        ("👤", "Client nearby"),
        ("🤝", "Assistant on site"),
    ]

    private let step2Checks_items = [
        "Power lines near work zone",
        "Flower pots or rail hazards on balconies",
        "Crowded public in work zone",
    ]

    private var step2AllChecked: Bool {
        step2Checks_items.allSatisfy { step2Checks.contains($0) }
    }

    var body: some View {
        ZStack {
            Color(hex: "02080F").opacity(0.88).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { onDismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                    Text("SAFETY CHECK")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                    Spacer()
                    // stage indicator
                    Text(stage == .step1 ? "1 of 2" : "2 of 2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.3))
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 8)

                // Job name
                Text(booking.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 4)
                Text(booking.address ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
                    .lineLimit(1)
                    .padding(.bottom, 32)

                if stage == .step1 {
                    step1View
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    step2View
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer()
            }
        }
    }

    // MARK: Step 1 — Situation awareness

    private var step1View: some View {
        VStack(spacing: 0) {
            Text("Who's with you today?")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                ForEach(step1Options, id: \.1) { emoji, label in
                    let selected = step1Selections.contains(label)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selected { step1Selections.remove(label) }
                            else { step1Selections.insert(label) }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Text(emoji).font(.system(size: 22))
                            Text(label)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(selected ? .white : Color.white.opacity(0.55))
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(selected ? Color(hex: "3AAAC4") : Color.clear)
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(
                                        selected ? Color(hex: "3AAAC4") : Color.white.opacity(0.25),
                                        lineWidth: 1.5
                                    ))
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(
                            selected
                            ? Color(hex: "0A3D5C").opacity(0.85)
                            : Color(hex: "0A1A28").opacity(0.7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(
                                selected ? Color(hex: "3AAAC4").opacity(0.5) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Text("Select all that apply, or none to continue solo.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 32)

            Spacer(minLength: 32)

            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    stage = .step2
                }
            } label: {
                Text("Continue →")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    // MARK: Step 2 — Pre-check hazards

    private var step2View: some View {
        VStack(spacing: 0) {
            Text("Confirm your pre-check")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.6))
                .padding(.bottom, 6)
            Text("Check all that you've assessed before starting.")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                ForEach(step2Checks_items, id: \.self) { item in
                    let checked = step2Checks.contains(item)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if checked { step2Checks.remove(item) }
                            else { step2Checks.insert(item) }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(checked ? Color(hex: "34D399") : Color.clear)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6).stroke(
                                            checked ? Color(hex: "34D399") : Color.white.opacity(0.25),
                                            lineWidth: 1.5
                                        )
                                    )
                                if checked {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color(hex: "061A10"))
                                }
                            }
                            Text("I checked for \(item.lowercased())")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(checked ? .white : Color.white.opacity(0.5))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            checked
                            ? Color(hex: "0F3A25").opacity(0.8)
                            : Color(hex: "0A1A28").opacity(0.7)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(
                                checked ? Color(hex: "34D399").opacity(0.4) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 32)

            Button {
                if step2AllChecked { onClear() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: step2AllChecked ? "checkmark.shield.fill" : "shield")
                        .font(.system(size: 17))
                    Text(step2AllChecked ? "All clear — Open Job" : "Check all items to continue")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(step2AllChecked ? Color(hex: "061A10") : Color.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    step2AllChecked
                    ? LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color(hex: "0A1A28"), Color(hex: "0A1A28")], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(
                        step2AllChecked ? Color.clear : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
                )
            }
            .disabled(!step2AllChecked)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
