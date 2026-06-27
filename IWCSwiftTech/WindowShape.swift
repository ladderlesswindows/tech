import SwiftUI

struct WindowPane: View {
    var tint: Color = Color(hex: "7EC8E3")
    var label: String? = nil
    var width: CGFloat = 54
    var height: CGFloat = 72

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Frame
                RoundedRectangle(cornerRadius: 3)
                    .stroke(tint.opacity(0.7), lineWidth: 2)
                    .frame(width: width, height: height)

                // Glass fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(0.07))
                    .frame(width: width - 4, height: height - 4)

                // Center vertical divider (makes it a double-hung window)
                Rectangle()
                    .fill(tint.opacity(0.5))
                    .frame(width: 1.5, height: height - 4)

                // Center horizontal rail
                Rectangle()
                    .fill(tint.opacity(0.5))
                    .frame(width: width - 4, height: 1.5)

                // Glass glint
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .frame(width: width - 4, height: height - 4)

                // Latch (small rectangle at center)
                RoundedRectangle(cornerRadius: 1)
                    .fill(tint.opacity(0.6))
                    .frame(width: 6, height: 10)
                    .offset(y: -1)
            }

            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(tint.opacity(0.6))
                    .lineLimit(1)
            }
        }
    }
}

struct SlidingWindowRow: View {
    let baseWindows: Int
    let freeWindows: Int

    @State private var revealed = false

    var total: Int { baseWindows + freeWindows }
    private var useDeck: Bool { total > 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if useDeck {
                DeckWindowView(
                    baseWindows: baseWindows,
                    freeWindows: freeWindows,
                    revealed: revealed
                )
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<total, id: \.self) { i in
                        let isFree = i >= baseWindows
                        WindowPane(
                            tint: isFree ? Color(hex: "34d399") : Color(hex: "7EC8E3"),
                            label: isFree ? "free" : nil
                        )
                        .opacity(revealed ? 1 : 0)
                        .offset(x: revealed ? 0 : 80)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.72)
                            .delay(Double(i) * 0.18),
                            value: revealed
                        )
                    }
                    Spacer()
                }
            }

            HStack(spacing: 6) {
                Text("You purchased \(plural(baseWindows, "window"))")
                    .foregroundColor(.white.opacity(0.7))
                if freeWindows > 0 {
                    Text("·")
                        .foregroundColor(.white.opacity(0.3))
                    Text("\(plural(freeWindows, "free window")) included")
                        .foregroundColor(Color(hex: "34d399").opacity(0.85))
                }
            }
            .font(.system(size: 14, weight: .medium))
            .opacity(revealed ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(useDeck ? 0.5 : Double(total) * 0.18 + 0.1), value: revealed)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                revealed = true
            }
        }
    }

    private func plural(_ n: Int, _ word: String) -> String {
        "\(n) \(word)\(n != 1 ? "s" : "")"
    }
}

// Deck-of-cards view for large window counts
struct DeckWindowView: View {
    let baseWindows: Int
    let freeWindows: Int
    let revealed: Bool

    private var deckCount: Int { min(baseWindows, 8) }
    private var hasFree: Bool { freeWindows > 0 }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Purchased deck
            ZStack(alignment: .bottomLeading) {
                ForEach(0..<deckCount, id: \.self) { i in
                    let spread = CGFloat(i) * 4.0
                    let tilt = Double(i) * 1.5 - Double(deckCount) * 0.75
                    WindowPane(tint: Color(hex: "7EC8E3"), width: 48, height: 64)
                        .rotationEffect(.degrees(tilt))
                        .offset(x: revealed ? spread : CGFloat(deckCount) * 4 + 60, y: -spread * 0.3)
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.7)
                            .delay(Double(i) * 0.04),
                            value: revealed
                        )
                }
            }
            .frame(width: CGFloat(deckCount) * 4 + 52, height: 90, alignment: .bottomLeading)

            // Count badge
            VStack(spacing: 2) {
                Text("\(baseWindows)")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                Text("windows")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .opacity(revealed ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.4), value: revealed)
            .padding(.leading, 16)

            if hasFree {
                Spacer().frame(width: 24)

                // Free window(s)
                ZStack(alignment: .bottomLeading) {
                    ForEach(0..<freeWindows, id: \.self) { i in
                        WindowPane(tint: Color(hex: "34d399"), label: "free", width: 48, height: 64)
                            .offset(x: revealed ? CGFloat(i) * 4 : 60, y: 0)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.7)
                                .delay(0.3 + Double(i) * 0.1),
                                value: revealed
                            )
                    }
                }
                .frame(width: CGFloat(freeWindows) * 4 + 52, height: 90, alignment: .bottomLeading)
            }

            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "06050f").ignoresSafeArea()
        SlidingWindowRow(baseWindows: 2, freeWindows: 1)
            .padding(40)
    }
}
