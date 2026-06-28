import SwiftUI
import PhotosUI

struct WorkerProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @ObservedObject var timerMgr: TimerManager
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var avatarImage: UIImage? = nil
    @State private var paymentHandle: String = ""
    @State private var editingPayment = false
    @FocusState private var paymentFocused: Bool

    private var shiftWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "shift" }) }
    private var driveWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "drive" }) }
    private var onsiteWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "onsite" }) }
    private var shiftRunning: Bool { shiftWatch?.isRunning ?? false }

    private var avatarKey: String { "avatar_\(auth.currentEmployee?.id ?? "unknown")" }

    var body: some View {
        ZStack {
            Color(hex: "04101C").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Close
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // Avatar + name
                    VStack(spacing: 10) {
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Color(hex: "0A3D5C").opacity(0.8))
                                    .frame(width: 90, height: 90)
                                    .overlay(Circle().stroke(
                                        LinearGradient(colors: [Color(hex: "3AAAC4"), Color(hex: "1278A0")],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: 2
                                    ))
                                if let img = avatarImage {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                } else {
                                    Text(String(auth.currentEmployee?.name.prefix(1) ?? "?"))
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(Color(hex: "7ED8EA"))
                                }
                                // Camera badge
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "1278A0"))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 2, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .onChange(of: pickerItem) { _, item in
                            Task {
                                guard let data = try? await item?.loadTransferable(type: Data.self),
                                      let img = UIImage(data: data),
                                      let compressed = img.jpegData(compressionQuality: 0.75)
                                else { return }
                                await MainActor.run {
                                    avatarImage = UIImage(data: compressed)
                                    UserDefaults.standard.set(compressed, forKey: avatarKey)
                                }
                            }
                        }
                        .onAppear {
                            if let data = UserDefaults.standard.data(forKey: avatarKey) {
                                avatarImage = UIImage(data: data)
                            }
                            let pKey = "payment_\(auth.currentEmployee?.id ?? "unknown")"
                            paymentHandle = UserDefaults.standard.string(forKey: pKey) ?? ""
                        }
                        Text(auth.currentEmployee?.name ?? "Technician")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(shiftRunning ? Color(hex: "34D399") : Color.white.opacity(0.2))
                                .frame(width: 7, height: 7)
                            Text(shiftRunning ? "On Shift" : "Off Clock")
                                .font(.system(size: 13))
                                .foregroundColor(shiftRunning ? Color(hex: "34D399") : Color.white.opacity(0.4))
                        }
                    }
                    .padding(.bottom, 8)

                    // Today stats
                    sectionLabel("TODAY")
                    HStack(spacing: 0) {
                        profileStat(
                            value: "\(timerMgr.windowsCleanedToday)",
                            label: "WINDOWS",
                            color: "34D399",
                            icon: "window.casement"
                        )
                        divider()
                        profileStat(
                            value: formatHours(shiftWatch?.currentElapsed(at: timerMgr.tick) ?? 0),
                            label: "SHIFT TIME",
                            color: "7ED8EA",
                            icon: "clock"
                        )
                        divider()
                        let perHr = timerMgr.windowsPerHour(at: timerMgr.tick)
                        profileStat(
                            value: perHr > 0 ? String(format: "%.1f", perHr) : "—",
                            label: "PER HOUR",
                            color: "3AAAC4",
                            icon: "bolt"
                        )
                    }
                    .padding(.vertical, 18)
                    .background(Color(hex: "0A2030").opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // This week stats
                    sectionLabel("THIS WEEK")
                    HStack(spacing: 0) {
                        profileStat(
                            value: "\(timerMgr.windowsCleanedThisWeek)",
                            label: "WINDOWS",
                            color: "34D399",
                            icon: "window.casement"
                        )
                        divider()
                        profileStat(
                            value: timerMgr.windowsCleanedThisWeek > 0 && timerMgr.windowsCleanedToday > 0
                                ? "\(Int(round(Double(timerMgr.windowsCleanedThisWeek) / max(1, Double(timerMgr.windowsCleanedToday)))))"
                                : "—",
                            label: "DAYS ACTIVE",
                            color: "7ED8EA",
                            icon: "calendar"
                        )
                        divider()
                        profileStat(
                            value: "—",
                            label: "BEST DAY",
                            color: "F59E0B",
                            icon: "star"
                        )
                    }
                    .padding(.vertical, 18)
                    .background(Color(hex: "0A2030").opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // Payment account
                    sectionLabel("PAYMENT")
                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "34D399").opacity(0.7))
                        if editingPayment {
                            TextField("Venmo @handle or PayPal email", text: $paymentHandle)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($paymentFocused)
                        } else {
                            Text(paymentHandle.isEmpty ? "Add Venmo or PayPal" : paymentHandle)
                                .font(.system(size: 14))
                                .foregroundColor(paymentHandle.isEmpty ? Color.white.opacity(0.25) : .white)
                        }
                        Spacer()
                        Button {
                            if editingPayment {
                                let key = "payment_\(auth.currentEmployee?.id ?? "unknown")"
                                UserDefaults.standard.set(paymentHandle, forKey: key)
                                paymentFocused = false
                            }
                            editingPayment.toggle()
                            if editingPayment { paymentFocused = true }
                        } label: {
                            Text(editingPayment ? "Save" : "Edit")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "7ED8EA"))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color(hex: "0A3D5C").opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Color(hex: "0A2030").opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "34D399").opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // Active timers
                    let running = timerMgr.watches.filter { $0.isRunning }
                    if !running.isEmpty {
                        sectionLabel("ACTIVE TIMERS")
                        VStack(spacing: 8) {
                            ForEach(running) { w in
                                HStack {
                                    Text(w.emoji).font(.system(size: 16))
                                    Text(w.label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.7))
                                    Spacer()
                                    Text(w.formatTime(w.currentElapsed(at: timerMgr.tick)))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Color(hex: w.color))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                .background(Color(hex: "0A2030").opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 60)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func profileStat(value: String, label: String, color: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: color).opacity(0.6))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 8, weight: .black))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color(hex: "3AAAC4").opacity(0.12))
            .frame(width: 1, height: 48)
    }

    private func formatHours(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
