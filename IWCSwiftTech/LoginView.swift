import SwiftUI

// MARK: - Login (root screen, video background)

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var selected: Employee? = nil
    @State private var pin = ""
    @State private var shaking = false
    @State private var errorFlash = false

    private var canSubmit: Bool { selected != nil && pin.count == 4 }

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.45).ignoresSafeArea())

            VStack(spacing: 0) {
                Spacer()

                Image("icon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
                    .padding(.bottom, 28)

                Text("SIMPLE WINDOW CLEANING")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.bottom, 6)

                Text("Who's working today?")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.bottom, 36)

                // Employee scroll
                if auth.loadingEmployees {
                    ProgressView().tint(.white).padding(.bottom, 32)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(auth.employees) { emp in
                                EmployeeCard(
                                    name: emp.name,
                                    photoUrl: emp.photoUrl,
                                    isSelected: selected?.id == emp.id
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selected = emp
                                        pin = ""
                                        errorFlash = false
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 32)
                }

                // PIN dots
                HStack(spacing: 18) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i < pin.count
                                  ? (errorFlash ? Color(hex: "f87171") : Color(hex: "3AAAC4"))
                                  : Color.white.opacity(0.15))
                            .frame(width: 14, height: 14)
                            .animation(.spring(response: 0.2), value: pin.count)
                            .animation(.spring(response: 0.2), value: errorFlash)
                    }
                }
                .offset(x: shaking ? -8 : 0)
                .padding(.bottom, 28)

                // Numpad
                PINPad(pin: $pin, onComplete: attemptLogin)
                    .frame(maxWidth: 300)
                    .opacity(selected == nil ? 0.35 : 1)
                    .allowsHitTesting(selected != nil)
                    .padding(.bottom, 40)

                Spacer()

                Text("Simple Window Cleaning · Santa Cruz, CA")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.1))
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 40)
        }
        .ignoresSafeArea()
        .task { await auth.loadEmployees() }
    }

    private func attemptLogin() {
        guard let emp = selected else { return }
        Task {
            let ok = await auth.login(employee: emp, pin: pin)
            if ok {
                // success — root switches away from this view
            } else {
                withAnimation(.default) { errorFlash = true }
                withAnimation(.spring(response: 0.1, dampingFraction: 0.3).repeatCount(4, autoreverses: true)) {
                    shaking = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    shaking = false
                    errorFlash = false
                    pin = ""
                }
            }
        }
    }
}

// MARK: - Employee name card

private struct EmployeeCard: View {
    let name: String
    let photoUrl: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? LinearGradient(colors: [Color(hex: "1278A0"), Color(hex: "0A3D5C")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)

                    if let urlStr = photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                initialsView
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                    } else {
                        initialsView
                    }

                    Circle()
                        .stroke(isSelected ? Color(hex: "3AAAC4") : Color.white.opacity(0.12), lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                }

                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.45))
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color(hex: "1278A0").opacity(0.2) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color(hex: "3AAAC4").opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var initialsView: some View {
        let initials = name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
        return Text(initials)
            .font(.system(size: 22, weight: .heavy))
            .foregroundColor(isSelected ? .white : .white.opacity(0.55))
    }
}

// MARK: - 4-digit PIN numpad

private struct PINPad: View {
    @Binding var pin: String
    let onComplete: () -> Void

    private let keys: [[String]] = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["","0","⌫"],
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        PINKey(label: key) {
                            handleKey(key)
                        }
                        .opacity(key.isEmpty ? 0 : 1)
                        .allowsHitTesting(!key.isEmpty)
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
        } else if pin.count < 4 {
            pin += key
            if pin.count == 4 { onComplete() }
        }
    }
}

private struct PINKey: View {
    let label: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: label == "⌫" ? 20 : 26, weight: .semibold))
                .foregroundColor(.white.opacity(pressed ? 0.5 : 0.9))
                .frame(width: 76, height: 56)
                .background(Color.white.opacity(pressed ? 0.18 : 0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded   { _ in pressed = false }
        )
    }
}

// MARK: - One-time API password setup (shown before LoginView if not configured)

struct SetupView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var input = ""
    @State private var loading = false
    @State private var error = false

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.55).ignoresSafeArea())

            VStack(spacing: 24) {
                Text("Admin Setup")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                Text("Enter the API access code once to configure this device.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)

                SecureField("Access code", text: $input)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(error ? Color(hex: "f87171") : Color.white.opacity(0.1)))
                    .onChange(of: input) { error = false }

                if error {
                    Text("Incorrect — try again.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "f87171"))
                }

                Button {
                    Task { await verify() }
                } label: {
                    Text(loading ? "Verifying…" : "Save & Continue")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(input.isEmpty ? Color(hex: "1278A0").opacity(0.3) : Color(hex: "1278A0"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(input.isEmpty || loading)
            }
            .frame(maxWidth: 400)
            .padding(40)
        }
    }

    private func verify() async {
        loading = true
        let ok = await APIClient.verifyPassword(input)
        await MainActor.run {
            if ok {
                auth.saveAPIPassword(input)
            } else {
                error = true
            }
            loading = false
        }
    }
}
