import Foundation
import SwiftUI
import Combine

struct StopwatchState: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let color: String
    var isRunning: Bool = false
    var elapsed: TimeInterval = 0
    var startedAt: Date? = nil

    func currentElapsed(at now: Date = Date()) -> TimeInterval {
        guard isRunning, let start = startedAt else { return elapsed }
        return elapsed + now.timeIntervalSince(start)
    }

    var formattedTime: String {
        formatTime(currentElapsed())
    }

    func formatTime(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

class TimerManager: ObservableObject {
    @Published var watches: [StopwatchState] = [
        .init(id: "shift",    label: "Shift Clock",  emoji: "🌅", color: "7ED8EA"),
        .init(id: "drive",    label: "Drive In",     emoji: "🚗", color: "3AAAC4"),
        .init(id: "onsite",   label: "On-Site",      emoji: "📍", color: "1278A0"),
        .init(id: "window",   label: "Window Time",  emoji: "🪟", color: "34D399"),
        .init(id: "interior", label: "Interior",     emoji: "🏠", color: "059669"),
        .init(id: "screen",   label: "Screen Work",  emoji: "🪞", color: "F59E0B"),
        .init(id: "between",  label: "Between Jobs", emoji: "↔️", color: "6366F1"),
        .init(id: "break",    label: "Break",        emoji: "☕", color: "A78BFA"),
        .init(id: "packup",   label: "Pack Up",      emoji: "📦", color: "F97316"),
        .init(id: "admin",    label: "Admin",        emoji: "📋", color: "94A3B8"),
    ]

    @Published var tick = Date()
    @Published var windowsCleanedToday: Int = 0
    @Published var windowsCleanedThisWeek: Int = 0
    @Published var shiftEndTime: Date? = nil

    var shiftEndCountdown: TimeInterval? {
        guard let end = shiftEndTime else { return nil }
        let remaining = end.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    private var timer: AnyCancellable?
    private var shiftEndTask: Task<Void, Never>? = nil

    init() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.tick = now }
        loadPersistedCounts()
    }

    func scheduleShiftEnd(after seconds: TimeInterval = 300) {
        shiftEndTask?.cancel()
        shiftEndTime = Date().addingTimeInterval(seconds)
        shiftEndTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.clockOut()
                self.shiftEndTime = nil
            }
        }
    }

    func cancelShiftEnd() {
        shiftEndTask?.cancel()
        shiftEndTask = nil
        shiftEndTime = nil
    }

    // MARK: - Persistence

    private func loadPersistedCounts() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let defaults = UserDefaults.standard

        // Daily reset
        if let lastDay = defaults.object(forKey: "iwc_windows_last_date") as? Date,
           cal.isDate(lastDay, inSameDayAs: today) {
            windowsCleanedToday = defaults.integer(forKey: "iwc_windows_today")
        } else {
            windowsCleanedToday = 0
            defaults.set(today, forKey: "iwc_windows_last_date")
            defaults.set(0, forKey: "iwc_windows_today")
        }

        // Weekly reset (Sun–Sat)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? today
        if let lastWeekStart = defaults.object(forKey: "iwc_windows_week_start") as? Date,
           cal.isDate(lastWeekStart, inSameDayAs: weekStart) {
            windowsCleanedThisWeek = defaults.integer(forKey: "iwc_windows_week")
        } else {
            windowsCleanedThisWeek = 0
            defaults.set(weekStart, forKey: "iwc_windows_week_start")
            defaults.set(0, forKey: "iwc_windows_week")
        }
    }

    func addWindowsCleaned(_ count: Int) {
        windowsCleanedToday += count
        windowsCleanedThisWeek += count
        UserDefaults.standard.set(windowsCleanedToday, forKey: "iwc_windows_today")
        UserDefaults.standard.set(windowsCleanedThisWeek, forKey: "iwc_windows_week")
    }

    // MARK: - Per-Hour Rate

    func windowsPerHour(at now: Date) -> Double {
        guard let shift = watches.first(where: { $0.id == "shift" }) else { return 0 }
        let elapsed = shift.currentElapsed(at: now)
        guard elapsed >= 1800, windowsCleanedToday > 0 else { return 0 }
        return Double(windowsCleanedToday) / (elapsed / 3600.0)
    }

    // MARK: - Timers

    var totalShiftTime: TimeInterval {
        watches.first(where: { $0.id == "shift" })?.currentElapsed() ?? 0
    }

    var anyRunning: Bool { watches.contains { $0.isRunning } }

    func toggle(_ id: String) {
        guard let idx = watches.firstIndex(where: { $0.id == id }) else { return }
        var w = watches[idx]
        if w.isRunning {
            w.elapsed = w.currentElapsed()
            w.startedAt = nil
            w.isRunning = false
        } else {
            w.startedAt = Date()
            w.isRunning = true
        }
        watches[idx] = w
    }

    func reset(_ id: String) {
        guard let idx = watches.firstIndex(where: { $0.id == id }) else { return }
        watches[idx].isRunning = false
        watches[idx].elapsed = 0
        watches[idx].startedAt = nil
    }

    func resetAll() {
        for i in watches.indices {
            watches[i].isRunning = false
            watches[i].elapsed = 0
            watches[i].startedAt = nil
        }
    }

    func clockIn() {
        let shiftIdx = watches.firstIndex(where: { $0.id == "shift" })!
        if !watches[shiftIdx].isRunning { toggle("shift") }
    }

    func clockOut() {
        for w in watches where w.isRunning { toggle(w.id) }
    }
}
