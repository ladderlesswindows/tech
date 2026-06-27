import SwiftUI
import PhotosUI

struct WallEntry: Identifiable {
    let id = UUID()
    var area: String
    var notes: String
    var imageData: Data? = nil
    var image: UIImage? { imageData.flatMap { UIImage(data: $0) } }
}

struct WallsView: View {
    let booking: Booking
    @Environment(\.dismiss) private var dismiss

    @State private var walls: [WallEntry] = []
    @State private var showAddSheet = false
    @State private var showDoneConfirm = false

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.82).ignoresSafeArea())

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("WALL DOCUMENTATION")
                            .font(.system(size: 10, weight: .black))
                            .tracking(2.5)
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.55))
                        Text(booking.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        if walls.isEmpty { dismiss() }
                        else { showDoneConfirm = true }
                    } label: {
                        Text("Done")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(walls.isEmpty ? Color.white.opacity(0.3) : Color(hex: "34D399"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)

                if walls.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(walls) { wall in
                                WallCard(wall: wall) {
                                    walls.removeAll { $0.id == wall.id }
                                }
                            }
                            addMoreButton
                                .padding(.top, 4)
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showAddSheet) {
            AddWallSheet { entry in
                walls.append(entry)
                showAddSheet = false
            }
        }
        .confirmationDialog(
            "Complete documentation for \(booking.displayName)?",
            isPresented: $showDoneConfirm,
            titleVisibility: .visible
        ) {
            Button("Complete Job Documentation") { dismiss() }
            Button("Keep Adding Walls") {}
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "0A2A3C").opacity(0.6))
                    .frame(width: 90, height: 90)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 38))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
            }

            VStack(spacing: 8) {
                Text("Document each wall or area")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                Text("Add a photo and notes for every section of\nthis job before starting.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }

            Button { showAddSheet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Add First Wall / Area")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color(hex: "04101C"))
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "7ED8EA"), Color(hex: "3AAAC4")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var addMoreButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "3AAAC4"))
                Text("Add Another Wall / Area")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "7ED8EA"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "0A2030").opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - Wall Card

struct WallCard: View {
    let wall: WallEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "0A2030").opacity(0.8))
                    .frame(width: 64, height: 64)
                if let img = wall.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(wall.area)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                if !wall.notes.isEmpty {
                    Text(wall.notes)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.45))
                        .lineLimit(2)
                }
                if wall.image != nil {
                    Label("Photo attached", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "34D399").opacity(0.7))
                } else {
                    Label("No photo", systemImage: "camera.slash")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.25))
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "0A1E2C").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Add Wall Sheet

struct AddWallSheet: View {
    let onAdd: (WallEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var areaName = ""
    @State private var notes = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var previewImage: UIImage? = nil

    private let suggestions = [
        "Front Exterior", "Back Exterior", "Left Side", "Right Side",
        "Living Room", "Kitchen", "Master Bedroom", "Bathroom",
        "Office", "Garage", "Skylights", "French Doors",
    ]

    var body: some View {
        ZStack {
            Color(hex: "04101C").ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)

                Text("ADD WALL / AREA")
                    .font(.system(size: 10, weight: .black))
                    .tracking(3)
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.55))
                    .padding(.top, 24)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // Area name
                        fieldSection(label: "AREA NAME") {
                            TextField("e.g. Front Exterior", text: $areaName)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }

                        // Quick-select area
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUICK SELECT")
                                .font(.system(size: 9, weight: .black))
                                .tracking(2)
                                .foregroundColor(Color.white.opacity(0.25))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button { areaName = s } label: {
                                            Text(s)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(
                                                    areaName == s ? Color(hex: "04101C") : Color(hex: "7ED8EA")
                                                )
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(
                                                    areaName == s
                                                    ? Color(hex: "3AAAC4")
                                                    : Color(hex: "0A2A3C").opacity(0.7)
                                                )
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                            .padding(.horizontal, -24)
                        }
                        .padding(.horizontal, 24)

                        // Notes
                        fieldSection(label: "NOTES (optional)") {
                            TextField("Condition, access notes, etc.", text: $notes, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .lineLimit(3, reservesSpace: true)
                        }

                        // Photo
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PHOTO")
                                .font(.system(size: 9, weight: .black))
                                .tracking(2)
                                .foregroundColor(Color.white.opacity(0.25))
                                .padding(.horizontal, 24)

                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                if let img = previewImage {
                                    ZStack(alignment: .bottomTrailing) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))

                                        Text("Change")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.black.opacity(0.55))
                                            .clipShape(Capsule())
                                            .padding(10)
                                    }
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                                        Text("Attach Photo")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "7ED8EA").opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 80)
                                    .background(Color(hex: "0A2030").opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.25))
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .onChange(of: selectedItem) { _, item in
                                Task {
                                    if let data = try? await item?.loadTransferable(type: Data.self) {
                                        imageData = data
                                        previewImage = UIImage(data: data)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 16)

                        Button {
                            guard !areaName.isEmpty else { return }
                            onAdd(WallEntry(area: areaName, notes: notes, imageData: imageData))
                        } label: {
                            Text("Add Wall")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(areaName.isEmpty ? Color.white.opacity(0.3) : Color(hex: "04101C"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background {
                                    if areaName.isEmpty {
                                        Color(hex: "0A2030").opacity(0.7)
                                    } else {
                                        LinearGradient(
                                            colors: [Color(hex: "7ED8EA"), Color(hex: "3AAAC4")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(areaName.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func fieldSection<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundColor(Color.white.opacity(0.25))
            field()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "0A2030").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3AAAC4").opacity(0.18), lineWidth: 1))
        }
        .padding(.horizontal, 24)
    }
}
