import SwiftUI
import PhotosUI

// MARK: - Models

struct WindowPhoto: Identifiable {
    let id = UUID()
    var imageData: Data
    var note: String = ""
    var image: UIImage? { UIImage(data: imageData) }
}

struct WallEntry: Identifiable {
    let id = UUID()
    var area: String
    var notes: String
    var overviewImageData: Data? = nil
    var windowPhotos: [WindowPhoto] = []
    var overviewImage: UIImage? { overviewImageData.flatMap { UIImage(data: $0) } }
}

// MARK: - Root Walls View

struct WallsView: View {
    let booking: Booking
    var onComplete: (([WallEntry]) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var timerMgr: TimerManager

    @State private var walls: [WallEntry] = []
    @State private var showAddSheet = false
    @State private var pendingWall: WallEntry? = nil
    @State private var showWindowPhotos = false
    @State private var showSummary = false

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.82).ignoresSafeArea())

            VStack(spacing: 0) {
                header
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
                            addMoreButton.padding(.top, 4)
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showAddSheet, onDismiss: {
            // Only present after the sheet is fully gone
            if pendingWall != nil { showWindowPhotos = true }
        }) {
            AddWallSheet { entry in
                pendingWall = entry
                // AddWallSheet calls its own dismiss() — onDismiss fires after animation
            }
        }
        .fullScreenCover(isPresented: $showWindowPhotos) {
            if let wall = pendingWall {
                WindowPhotosView(
                    wall: wall,
                    onComplete: { completed, isLast in
                        walls.append(completed)
                        pendingWall = nil
                        showWindowPhotos = false
                        if isLast { showSummary = true }
                    }
                )
                .environmentObject(timerMgr)
            }
        }
        .fullScreenCover(isPresented: $showSummary) {
            WallsSummaryView(booking: booking, walls: walls) {
                onComplete?(walls)
                dismiss()
            }
        }
    }

    private var header: some View {
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
            if walls.isEmpty {
                Color.clear.frame(width: 32)
            } else {
                Button {
                    showSummary = true
                } label: {
                    Text("Summary")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "7ED8EA"))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "0A2A3C").opacity(0.6)).frame(width: 90, height: 90)
                Image(systemName: "square.grid.2x2").font(.system(size: 38))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
            }
            VStack(spacing: 8) {
                Text("Document each wall or area")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                Text("Name the area, then photograph each window on it.\nRepeat for every wall.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            Button { showAddSheet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18))
                    Text("Add First Wall / Area").font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(Color(hex: "04101C"))
                .padding(.horizontal, 28).padding(.vertical, 16)
                .background(LinearGradient(colors: [Color(hex: "7ED8EA"), Color(hex: "3AAAC4")], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var addMoreButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 16))
                    .foregroundColor(Color(hex: "3AAAC4"))
                Text("Add Another Wall / Area").font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "7ED8EA"))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
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
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: "0A2030").opacity(0.8))
                    .frame(width: 64, height: 64)
                if let img = wall.overviewImage {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 22))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.4))
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(wall.area).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                if !wall.notes.isEmpty {
                    Text(wall.notes).font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.45)).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack").font(.system(size: 10))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                    Text("\(wall.windowPhotos.count) window photo\(wall.windowPhotos.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.7))
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.2))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color(hex: "0A1E2C").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
    }
}

// MARK: - Add Wall Sheet (name + optional overview photo)

struct AddWallSheet: View {
    let onAdd: (WallEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var areaName = ""
    @State private var notes = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var imageData: Data? = nil
    @State private var previewImage: UIImage? = nil
    @State private var showCamera = false

    private let suggestions = [
        "Front Exterior", "Back Exterior", "Left Side", "Right Side",
        "Living Room", "Kitchen", "Master Bedroom", "Bathroom",
        "Office", "Garage", "Skylights", "French Doors",
    ]

    var body: some View {
        ZStack {
            Color(hex: "04101C").ignoresSafeArea()
            VStack(spacing: 0) {
                Capsule().fill(Color.white.opacity(0.12)).frame(width: 38, height: 4).padding(.top, 12)

                Text("NAME THIS WALL / AREA")
                    .font(.system(size: 10, weight: .black)).tracking(3)
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.55))
                    .padding(.top, 24).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        fieldSection(label: "AREA NAME") {
                            TextField("e.g. Front Exterior", text: $areaName)
                                .font(.system(size: 16)).foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUICK SELECT")
                                .font(.system(size: 9, weight: .black)).tracking(2)
                                .foregroundColor(Color.white.opacity(0.25))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(suggestions, id: \.self) { s in
                                        Button { areaName = s } label: {
                                            Text(s).font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(areaName == s ? Color(hex: "04101C") : Color(hex: "7ED8EA"))
                                                .padding(.horizontal, 12).padding(.vertical, 7)
                                                .background(areaName == s ? Color(hex: "3AAAC4") : Color(hex: "0A2A3C").opacity(0.7))
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

                        fieldSection(label: "NOTES (optional)") {
                            TextField("Access notes, condition, etc.", text: $notes, axis: .vertical)
                                .font(.system(size: 14)).foregroundColor(.white)
                                .lineLimit(3, reservesSpace: true)
                        }

                        // Overview photo — camera or library
                        VStack(alignment: .leading, spacing: 10) {
                            Text("OVERVIEW PHOTO (optional)")
                                .font(.system(size: 9, weight: .black)).tracking(2)
                                .foregroundColor(Color.white.opacity(0.25))
                                .padding(.horizontal, 24)

                            if let img = previewImage {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(maxWidth: .infinity).frame(height: 140)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .padding(.horizontal, 24)
                                    HStack(spacing: 8) {
                                        Button { showCamera = true } label: {
                                            photoChip("camera.fill", "Retake")
                                        }
                                        PhotosPicker(selection: $selectedItem, matching: .images) {
                                            photoChip("photo.on.rectangle", "Library")
                                        }
                                    }
                                    .padding(.trailing, 32).padding(.bottom, 8)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Button { showCamera = true } label: {
                                        photoSourceButton(icon: "camera.fill", label: "Take Photo")
                                    }
                                    PhotosPicker(selection: $selectedItem, matching: .images) {
                                        photoSourceButton(icon: "photo.on.rectangle", label: "Choose")
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .onChange(of: selectedItem) { _, item in
                            Task {
                                if let data = try? await item?.loadTransferable(type: Data.self) {
                                    imageData = data; previewImage = UIImage(data: data)
                                }
                            }
                        }

                        Spacer(minLength: 16)

                        Button {
                            guard !areaName.isEmpty else { return }
                            onAdd(WallEntry(area: areaName, notes: notes, overviewImageData: imageData))
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(areaName.isEmpty ? "Name this area first" : "Next — Photograph Windows")
                                    .font(.system(size: 16, weight: .bold))
                                if !areaName.isEmpty {
                                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold))
                                }
                            }
                            .foregroundColor(areaName.isEmpty ? Color.white.opacity(0.3) : Color(hex: "04101C"))
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background {
                                if areaName.isEmpty {
                                    Color(hex: "0A2030").opacity(0.7)
                                } else {
                                    LinearGradient(colors: [Color(hex: "7ED8EA"), Color(hex: "3AAAC4")], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(areaName.isEmpty)
                        .padding(.horizontal, 24).padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPickerView { img in
                imageData = img.jpegData(compressionQuality: 0.82)
                previewImage = img
            }
        }
        .presentationDetents([.large])
    }

    private func fieldSection<F: View>(label: String, @ViewBuilder field: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 9, weight: .black)).tracking(2)
                .foregroundColor(Color.white.opacity(0.25))
            field()
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(hex: "0A2030").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3AAAC4").opacity(0.18), lineWidth: 1))
        }
        .padding(.horizontal, 24)
    }

    private func photoSourceButton(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 16))
            Text(label).font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(Color(hex: "7ED8EA").opacity(0.8))
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color(hex: "0A2030").opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundColor(Color(hex: "3AAAC4").opacity(0.25)))
    }

    private func photoChip(_ icon: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11))
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }
}

// MARK: - Window Photos View

struct WindowPhotosView: View {
    var wall: WallEntry
    let onComplete: (WallEntry, _ isLast: Bool) -> Void

    @EnvironmentObject private var timerMgr: TimerManager
    @State private var photos: [WindowPhoto] = []
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem? = nil

    private var windowWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "window" }) }

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.82).ignoresSafeArea())

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    Text("WINDOW PHOTOS")
                        .font(.system(size: 10, weight: .black)).tracking(3)
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.55))
                    Text(wall.area)
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    if !wall.notes.isEmpty {
                        Text(wall.notes).font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                }

                // Window timer strip
                windowTimerStrip
                .padding(.top, 60).padding(.bottom, 24)

                if photos.isEmpty {
                    firstPhotoPrompt
                } else {
                    photosGrid
                }

                Spacer()

                // Action buttons
                VStack(spacing: 10) {
                    if !photos.isEmpty {
                        addAnotherRow
                    }
                    completeButtons
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showCamera) {
            CameraPickerView { img in
                if let data = img.jpegData(compressionQuality: 0.82) {
                    photos.append(WindowPhoto(imageData: data))
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    photos.append(WindowPhoto(imageData: data))
                }
                selectedItem = nil
            }
        }
    }

    private var windowTimerStrip: some View {
        let watch = windowWatch
        let running = watch?.isRunning ?? false
        let elapsed = watch?.currentElapsed(at: timerMgr.tick) ?? 0

        return Button { timerMgr.toggle("window") } label: {
            HStack(spacing: 10) {
                Text("🪟").font(.system(size: 15))
                Text("Window Timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(running ? Color(hex: "7ED8EA") : Color.white.opacity(0.4))
                Spacer()
                Text(watch?.formatTime(elapsed) ?? "00:00")
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundColor(running ? .white : Color.white.opacity(0.25))
                    .animation(.none, value: elapsed)
                Image(systemName: running ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(running ? Color(hex: "34D399") : Color(hex: "3AAAC4").opacity(0.6))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(running ? Color(hex: "0A2A1A").opacity(0.85) : Color(hex: "0A1E2C").opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                running ? Color(hex: "34D399").opacity(0.35) : Color(hex: "3AAAC4").opacity(0.15),
                lineWidth: running ? 1.5 : 1
            ))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var firstPhotoPrompt: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(Color(hex: "0A2A3C").opacity(0.6)).frame(width: 80, height: 80)
                Image(systemName: "camera.viewfinder").font(.system(size: 34))
                    .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
            }
            Text("Photograph each window on this wall")
                .font(.system(size: 15)).foregroundColor(Color.white.opacity(0.45))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
    }

    private var photosGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { i, photo in
                    ZStack(alignment: .topTrailing) {
                        if let img = photo.image {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        // Window number badge
                        Text("\(i + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color(hex: "3AAAC4").opacity(0.85))
                            .clipShape(Circle())
                            .padding(5)
                        // Delete
                        Button { photos.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 18))
                                .foregroundColor(Color.black.opacity(0.6))
                                .background(Color.white.clipShape(Circle()))
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var addAnotherRow: some View {
        HStack(spacing: 10) {
            Button { showCamera = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill").font(.system(size: 14))
                    Text("Camera").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(hex: "7ED8EA"))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(hex: "0A2A3C").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle").font(.system(size: 14))
                    Text("Library").font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(hex: "7ED8EA"))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color(hex: "0A2A3C").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
            }
        }
    }

    private var completeButtons: some View {
        VStack(spacing: 10) {
            if photos.isEmpty {
                // No photos yet — show camera and library side by side
                HStack(spacing: 10) {
                    Button { showCamera = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill").font(.system(size: 16))
                            Text("Take Photo").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle").font(.system(size: 16))
                            Text("Library").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "7ED8EA"))
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Color(hex: "0A2A3C").opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                    }
                }
            }

            // "Last of this wall" / "Last wall" button — always visible
            Button {
                var completed = wall
                completed.windowPhotos = photos
                onComplete(completed, true)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: photos.isEmpty ? "arrow.right.circle" : "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text(photos.isEmpty
                         ? "Skip — No Windows to Photograph"
                         : "Last Window · Go to Summary")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(photos.isEmpty ? Color.white.opacity(0.4) : Color(hex: "04101C"))
                .frame(maxWidth: .infinity).padding(.vertical, 18)
                .background {
                    if photos.isEmpty {
                        Color(hex: "0A1A28").opacity(0.7)
                    } else {
                        LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(photos.isEmpty ? Color.white.opacity(0.08) : Color.clear, lineWidth: 1)
                )
            }

            // "Add another wall" — only when photos exist
            if !photos.isEmpty {
                Button {
                    var completed = wall
                    completed.windowPhotos = photos
                    onComplete(completed, false)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.rectangle.on.rectangle").font(.system(size: 14))
                        Text("Done with this wall — add another")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "7ED8EA").opacity(0.7))
                }
            }
        }
    }

}

// MARK: - Summary View

struct WallsSummaryView: View {
    let booking: Booking
    let walls: [WallEntry]
    let onDone: () -> Void

    var totalWindowPhotos: Int { walls.reduce(0) { $0 + $1.windowPhotos.count } }

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.82).ignoresSafeArea())

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundColor(Color(hex: "34D399"))
                    Text("DOCUMENTATION COMPLETE")
                        .font(.system(size: 11, weight: .black)).tracking(3)
                        .foregroundColor(Color(hex: "34D399").opacity(0.6))
                    Text(booking.displayName)
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                }
                .padding(.top, 60).padding(.bottom, 28)

                // Stats row
                HStack(spacing: 0) {
                    summaryStatPill("\(walls.count)", "WALLS")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                    summaryStatPill("\(totalWindowPhotos)", "PHOTOS")
                    Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                    summaryStatPill(booking.window_count.map { "\($0)" } ?? "--", "BOOKED W")
                }
                .padding(.vertical, 14)
                .background(Color(hex: "071520").opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3AAAC4").opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(walls) { wall in
                            summaryWallRow(wall)
                        }
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }

                Button(action: onDone) {
                    Text("Complete Job")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "04101C"))
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
    }

    private func summaryStatPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 9, weight: .black)).tracking(1.5)
                .foregroundColor(Color.white.opacity(0.3))
            Text(value).font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(hex: "7ED8EA"))
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryWallRow(_ wall: WallEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(wall.area).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(wall.windowPhotos.count) photo\(wall.windowPhotos.count == 1 ? "" : "s")")
                    .font(.system(size: 12)).foregroundColor(Color(hex: "3AAAC4").opacity(0.7))
            }
            if !wall.windowPhotos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let overview = wall.overviewImage {
                            ZStack(alignment: .bottomLeading) {
                                Image(uiImage: overview).resizable().scaledToFill()
                                    .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                                Text("overview").font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white).padding(.horizontal, 5).padding(.vertical, 2)
                                    .background(Color.black.opacity(0.5)).clipShape(Capsule())
                                    .padding(4)
                            }
                        }
                        ForEach(Array(wall.windowPhotos.enumerated()), id: \.element.id) { i, photo in
                            if let img = photo.image {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                        .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text("\(i + 1)").font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white).frame(width: 18, height: 18)
                                        .background(Color(hex: "3AAAC4")).clipShape(Circle())
                                        .padding(3)
                                }
                            }
                        }
                    }
                }
            } else if let overview = wall.overviewImage {
                Image(uiImage: overview).resizable().scaledToFill()
                    .frame(height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color(hex: "0A1E2C").opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "3AAAC4").opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
