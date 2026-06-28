import SwiftUI

struct MileageView: View {
    @State private var tripEntries: [TripEntry] = []
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MILEAGE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.3))
                    Text("Today's Trips")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "3AAAC4"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // Total card
            HStack(spacing: 0) {
                milesStat(value: String(format: "%.1f", tripTotal), label: "TOTAL MI", color: "7ED8EA")
                Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                milesStat(value: "$\(String(format: "%.2f", tripTotal * 0.70))", label: "EST. REIMBURSEMENT", color: "34D399")
                Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                milesStat(value: "\(tripEntries.count)", label: "TRIPS", color: "F59E0B")
            }
            .padding(.vertical, 16)
            .background(Color(hex: "071520").opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            if tripEntries.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(tripEntries) { entry in
                            MileageRow(entry: entry) {
                                tripEntries.removeAll { $0.id == entry.id }
                            }
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTripSheet { entry in
                tripEntries.insert(entry, at: 0)
                showAddSheet = false
            }
        }
    }

    private var tripTotal: Double { tripEntries.reduce(0) { $0 + $1.miles } }

    private func milesStat(value: String, label: String, color: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: color))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "0A2A3C").opacity(0.6)).frame(width: 80, height: 80)
                Image(systemName: "car.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
            }
            Text("No trips logged today")
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.3))
            Button { showAddSheet = true } label: {
                Label("Add First Trip", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "7ED8EA"))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Color(hex: "0A3D5C").opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Spacer()
            Spacer()
        }
    }
}

struct TripEntry: Identifiable {
    let id = UUID()
    var miles: Double
    var note: String
    var time: Date
}

struct MileageRow: View {
    let entry: TripEntry
    let onDelete: () -> Void
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: "0A3D5C").opacity(0.5)).frame(width: 38, height: 38)
                Image(systemName: "car.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "3AAAC4"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.note.isEmpty ? "Trip" : entry.note)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(timeFmt.string(from: entry.time))
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            Spacer()
            Text(String(format: "%.1f mi", entry.miles))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "7ED8EA"))
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "0A2030").opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }
}

struct AddTripSheet: View {
    let onAdd: (TripEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var miles = ""
    @State private var note = ""

    var body: some View {
        ZStack {
            Color(hex: "04101C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)

                Text("LOG TRIP")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                    .padding(.top, 24)
                    .padding(.bottom, 32)

                VStack(spacing: 16) {
                    fieldRow(label: "MILES DRIVEN") {
                        TextField("0.0", text: $miles)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.trailing)
                    }
                    fieldRow(label: "NOTE (optional)") {
                        TextField("Home → Job 1, Job 1 → 2, etc.", text: $note)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    guard let m = Double(miles), m > 0 else { return }
                    onAdd(TripEntry(miles: m, note: note, time: Date()))
                } label: {
                    Text("Add Trip")
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
                .disabled(Double(miles) == nil || (Double(miles) ?? 0) <= 0)
                .opacity((Double(miles) ?? 0) > 0 ? 1 : 0.4)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
    }

    private func fieldRow<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(Color.white.opacity(0.3))
            HStack {
                field()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(hex: "0A2030").opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3AAAC4").opacity(0.2), lineWidth: 1))
        }
    }
}
