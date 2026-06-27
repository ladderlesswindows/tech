import SwiftUI

struct TimeclockView: View {
    @ObservedObject var timerMgr: TimerManager
    @State private var showResetConfirm = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STOPWATCHES")
                            .font(.system(size: 11, weight: .black))
                            .tracking(3)
                            .foregroundColor(Color.white.opacity(0.3))
                        Text("\(timerMgr.watches.filter { $0.isRunning }.count) running")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("Reset All", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "0A2A3C").opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                // Clock grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach($timerMgr.watches) { $watch in
                        TimerCard(
                            watch: watch,
                            now: timerMgr.tick,
                            onTap: { timerMgr.toggle(watch.id) },
                            onReset: { timerMgr.reset(watch.id) }
                        )
                    }
                }
                .padding(.horizontal, 16)

                // Total summary
                totalBar
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                Spacer(minLength: 120)
            }
        }
        .confirmationDialog("Reset all timers to zero?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset All", role: .destructive) { timerMgr.resetAll() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var totalBar: some View {
        let shift = timerMgr.watches.first(where: { $0.id == "shift" })
        let shiftTime = shift?.formatTime(shift?.currentElapsed(at: timerMgr.tick) ?? 0) ?? "00:00"

        return HStack(spacing: 0) {
            statPill(label: "SHIFT", value: shiftTime, color: "7ED8EA")
            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
            let cleanTime = ["window", "interior", "screen"]
                .compactMap { id in timerMgr.watches.first(where: { $0.id == id }) }
                .reduce(0.0) { $0 + $1.currentElapsed(at: timerMgr.tick) }
            let cleanWatch = timerMgr.watches.first!
            statPill(label: "CLEAN", value: cleanWatch.formatTime(cleanTime), color: "34D399")
            Divider().background(Color.white.opacity(0.1)).frame(height: 36)
            let driveTime = timerMgr.watches
                .filter { $0.id == "drive" || $0.id == "between" }
                .reduce(0.0) { $0 + $1.currentElapsed(at: timerMgr.tick) }
            statPill(label: "DRIVE", value: cleanWatch.formatTime(driveTime), color: "F59E0B")
        }
        .padding(.vertical, 14)
        .background(Color(hex: "071520").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
    }

    private func statPill(label: String, value: String, color: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(Color.white.opacity(0.3))
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: color))
        }
        .frame(maxWidth: .infinity)
    }
}

struct TimerCard: View {
    let watch: StopwatchState
    let now: Date
    let onTap: () -> Void
    let onReset: () -> Void

    @State private var pressing = false

    private var elapsed: TimeInterval { watch.currentElapsed(at: now) }
    private var isZero: Bool { elapsed < 0.5 }

    var body: some View {
        ZStack {
            // Background glow when running
            if watch.isRunning {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: watch.color).opacity(0.07))
                    .blur(radius: 2)
            }

            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: watch.isRunning ? "0C2A3E" : "07151E").opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            watch.isRunning
                            ? Color(hex: watch.color).opacity(0.55)
                            : Color.white.opacity(0.06),
                            lineWidth: watch.isRunning ? 1.5 : 1
                        )
                )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(watch.emoji)
                        .font(.system(size: 18))
                    Spacer()
                    if !isZero {
                        Button { onReset() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.2))
                        }
                    }
                }
                .padding(.bottom, 8)

                Text(watch.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(
                        watch.isRunning
                        ? Color(hex: watch.color).opacity(0.9)
                        : Color.white.opacity(0.4)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 6)

                Text(watch.formatTime(elapsed))
                    .font(.system(size: 26, weight: .light, design: .monospaced))
                    .foregroundColor(
                        watch.isRunning
                        ? .white
                        : (isZero ? Color.white.opacity(0.18) : Color.white.opacity(0.5))
                    )
                    .animation(.none, value: elapsed)

                Spacer(minLength: 10)

                // Start/Stop button
                HStack {
                    Spacer()
                    ZStack {
                        Capsule()
                            .fill(
                                watch.isRunning
                                ? Color(hex: watch.color).opacity(0.2)
                                : Color(hex: "1278A0").opacity(0.3)
                            )
                            .frame(width: 72, height: 28)
                        HStack(spacing: 5) {
                            Image(systemName: watch.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(watch.isRunning ? "Pause" : "Start")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(
                            watch.isRunning
                            ? Color(hex: watch.color)
                            : Color(hex: "7ED8EA")
                        )
                    }
                }
            }
            .padding(16)
        }
        .frame(height: 160)
        .scaleEffect(pressing ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pressing)
        .onTapGesture { onTap() }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in pressing = false }
        )
    }
}
