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
    var watchWindowCount: Int = 0           // > 0 means watch mode
    var watchWindowTimes: [TimeInterval] = []
    var isWatchMode: Bool { watchWindowCount > 0 }
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
    @State private var showWatchMode = false
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
            guard let wall = pendingWall else { return }
            if wall.isWatchMode { showWatchMode = true }
            else { showWindowPhotos = true }
        }) {
            AddWallSheet { entry in
                pendingWall = entry
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
        .fullScreenCover(isPresented: $showWatchMode) {
            if let wall = pendingWall {
                WatchModeSessionView(
                    wall: wall,
                    onComplete: { completed, isLast in
                        walls.append(completed)
                        pendingWall = nil
                        showWatchMode = false
                        if isLast { showSummary = true }
                        else { showAddSheet = true }
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
                if wall.isWatchMode {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch").font(.system(size: 10))
                            .foregroundColor(Color(hex: "7ED8EA").opacity(0.6))
                        let done = wall.watchWindowTimes.count
                        let total = wall.watchWindowCount
                        Text("\(done)/\(total) windows · Watch Mode")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "7ED8EA").opacity(0.7))
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.stack").font(.system(size: 10))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.6))
                        Text("\(wall.windowPhotos.count) window photo\(wall.windowPhotos.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.7))
                    }
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
    @State private var watchMode = false
    @State private var watchWindowCount = 6

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
                        // Mode toggle
                        HStack(spacing: 8) {
                            modeButton(
                                icon: "camera.fill",
                                label: "Camera Mode",
                                subtitle: "Photo each window",
                                selected: !watchMode
                            ) { watchMode = false }

                            modeButton(
                                icon: "applewatch",
                                label: "Watch Mode",
                                subtitle: "Timer per window",
                                selected: watchMode
                            ) { watchMode = true }
                        }
                        .padding(.horizontal, 24)

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

                        // Watch mode: window count picker
                        if watchMode {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("WINDOWS ON THIS WALL")
                                    .font(.system(size: 9, weight: .black)).tracking(2)
                                    .foregroundColor(Color.white.opacity(0.25))
                                    .padding(.horizontal, 24)

                                HStack(spacing: 0) {
                                    Button {
                                        if watchWindowCount > 1 { watchWindowCount -= 1 }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(hex: "7ED8EA"))
                                            .frame(width: 56, height: 56)
                                            .background(Color(hex: "0A2A3C").opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    Spacer()
                                    VStack(spacing: 2) {
                                        Text("\(watchWindowCount)")
                                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white)
                                        Text("windows")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.white.opacity(0.3))
                                    }
                                    Spacer()
                                    Button {
                                        if watchWindowCount < 40 { watchWindowCount += 1 }
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(Color(hex: "7ED8EA"))
                                            .frame(width: 56, height: 56)
                                            .background(Color(hex: "0A2A3C").opacity(0.8))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }

                        Spacer(minLength: 16)

                        Button {
                            guard !areaName.isEmpty else { return }
                            var entry = WallEntry(area: areaName, notes: notes, overviewImageData: imageData)
                            if watchMode { entry.watchWindowCount = watchWindowCount }
                            onAdd(entry)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                let label: String = {
                                    if areaName.isEmpty { return "Name this area first" }
                                    return watchMode ? "Hand Off to Watch" : "Next — Photograph Windows"
                                }()
                                Text(label).font(.system(size: 16, weight: .bold))
                                if !areaName.isEmpty {
                                    Image(systemName: watchMode ? "applewatch" : "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .foregroundColor(areaName.isEmpty ? Color.white.opacity(0.3) : Color(hex: "04101C"))
                            .frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background {
                                if areaName.isEmpty {
                                    Color(hex: "0A2030").opacity(0.7)
                                } else if watchMode {
                                    LinearGradient(colors: [Color(hex: "3AAAC4"), Color(hex: "1278A0")], startPoint: .leading, endPoint: .trailing)
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

    private func modeButton(icon: String, label: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selected ? Color(hex: "04101C") : Color(hex: "7ED8EA").opacity(0.6))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(selected ? Color(hex: "04101C") : Color.white.opacity(0.5))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(selected ? Color(hex: "04101C").opacity(0.6) : Color.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background {
                if selected {
                    LinearGradient(colors: [Color(hex: "7ED8EA"), Color(hex: "3AAAC4")], startPoint: .leading, endPoint: .trailing)
                } else {
                    Color(hex: "0A2030").opacity(0.7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(
                selected ? Color.clear : Color(hex: "3AAAC4").opacity(0.2), lineWidth: 1
            ))
        }
        .buttonStyle(.plain)
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

    enum WindowStage { case waitingForPhoto, timing }

    @State private var stage: WindowStage = .waitingForPhoto
    @State private var currentImage: UIImage? = nil
    @State private var windowTimerStart: Date? = nil
    @State private var completedWindows: [(UIImage, TimeInterval)] = []
    @State private var showCamera = false
    @State private var selectedItem: PhotosPickerItem? = nil

    private var totalWindowTime: TimeInterval { completedWindows.reduce(0) { $0 + $1.1 } }
    private var currentElapsed: TimeInterval {
        guard let start = windowTimerStart else { return 0 }
        return timerMgr.tick.timeIntervalSince(start)
    }
    private var windowWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "window" }) }
    private let photoHeight: CGFloat = UIScreen.main.bounds.height * 0.42

    var body: some View {
        ZStack {
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(Color(hex: "04101C").opacity(0.82).ignoresSafeArea())

            VStack(spacing: 0) {
                header
                    .padding(.top, 60)
                    .padding(.bottom, 20)

                if stage == .waitingForPhoto {
                    waitingView
                } else if let img = currentImage {
                    activePhotoView(img: img)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showCamera, onDismiss: {
            // Photo landing = timer auto-starts
            if let img = currentImage, stage == .waitingForPhoto {
                currentImage = img
                startCurrentWindow()
            }
        }) {
            CameraPickerView { img in currentImage = img }
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        currentImage = img
                        startCurrentWindow()
                    }
                }
                selectedItem = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("WINDOW BY WINDOW")
                .font(.system(size: 10, weight: .black)).tracking(3)
                .foregroundColor(Color(hex: "3AAAC4").opacity(0.55))
            Text(wall.area)
                .font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            if !wall.notes.isEmpty {
                Text(wall.notes).font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Waiting for Photo

    @ViewBuilder
    private var waitingView: some View {
        VStack(spacing: 0) {
            if completedWindows.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color(hex: "0A2A3C").opacity(0.6)).frame(width: 80, height: 80)
                        Image(systemName: "camera.viewfinder").font(.system(size: 34))
                            .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
                    }
                    Text("Photograph each window on this wall")
                        .font(.system(size: 15)).foregroundColor(Color.white.opacity(0.45))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                Spacer()
            } else {
                // Total time bar
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "34D399").opacity(0.7))
                    Text(formatTime(totalWindowTime))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "34D399"))
                    Text("total window time")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.35))
                    Spacer()
                    Text("\(completedWindows.count) done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "7ED8EA").opacity(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(hex: "071520").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "34D399").opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Thumbnail strip with per-window times
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(completedWindows.enumerated()), id: \.offset) { i, item in
                            VStack(spacing: 4) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: item.0)
                                        .resizable().scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text("\(i + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color(hex: "3AAAC4"))
                                        .clipShape(Circle())
                                        .padding(3)
                                }
                                Text(formatTime(item.1))
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)

                Spacer()
            }

            // Bottom actions
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button { showCamera = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill").font(.system(size: 17))
                            Text(completedWindows.isEmpty ? "Take First Photo" : "Next Window")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(LinearGradient(colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "7ED8EA"))
                            .frame(width: 60, height: 60)
                            .background(Color(hex: "0A2A3C").opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "3AAAC4").opacity(0.3), lineWidth: 1))
                    }
                }

                if !completedWindows.isEmpty {
                    Button { finish(isLast: true) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 16))
                            Text("Last Window · Go to Summary")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "04101C"))
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button { finish(isLast: false) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.rectangle.on.rectangle").font(.system(size: 14))
                            Text("Done with wall — add another")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "7ED8EA").opacity(0.7))
                    }
                } else {
                    Button { onComplete(wall, true) } label: {
                        Text("Skip — No Windows to Photograph")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 44)
        }
    }

    // MARK: - Active Photo View (always timing — photo landing starts the clock)

    @ViewBuilder
    private func activePhotoView(img: UIImage) -> some View {
        VStack(spacing: 0) {
            // Large photo with window number badge
            ZStack(alignment: .topLeading) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: photoHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)

                Text("Window \(completedWindows.count + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(hex: "DC2626").opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.leading, 30).padding(.top, 10)
            }

            // Live timer
            Text(formatTime(currentElapsed))
                .font(.system(size: 52, weight: .ultraLight, design: .monospaced))
                .foregroundColor(Color(hex: "FF6B6B"))
                .padding(.top, 10)
                .animation(.none, value: currentElapsed)

            Spacer()

            // Compact completed strip
            if !completedWindows.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(completedWindows.enumerated()), id: \.offset) { i, item in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: item.0)
                                    .resizable().scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                Text("\(i + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color(hex: "3AAAC4"))
                                    .clipShape(Circle())
                                    .padding(2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
            }

            // Done button — this is what the watch will trigger
            VStack(spacing: 10) {
                Button { stopCurrentWindow(img: img) } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "stop.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Done · Next Window")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.vertical, 22)
                    .background(
                        LinearGradient(colors: [Color(hex: "DC2626"), Color(hex: "991B1B")], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color(hex: "DC2626").opacity(0.45), radius: 16, y: 8)
                }

                Button {
                    // Discard current window and go back (timer reset)
                    windowTimerStart = nil
                    currentImage = nil
                    withAnimation { stage = .waitingForPhoto }
                } label: {
                    Text("Discard this window")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 44)
        }
    }

    // MARK: - Actions

    private func startCurrentWindow() {
        windowTimerStart = Date()
        stage = .timing
        if windowWatch?.isRunning == false { timerMgr.toggle("window") }
    }

    private func stopCurrentWindow(img: UIImage) {
        let elapsed = timerMgr.tick.timeIntervalSince(windowTimerStart ?? timerMgr.tick)
        completedWindows.append((img, elapsed))
        currentImage = nil
        windowTimerStart = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { stage = .waitingForPhoto }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showCamera = true }
    }

    private func finish(isLast: Bool) {
        var completed = wall
        completed.windowPhotos = completedWindows.map { img, _ in
            WindowPhoto(imageData: img.jpegData(compressionQuality: 0.82) ?? Data())
        }
        onComplete(completed, isLast)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Watch Mode Session View

struct WatchModeSessionView: View {
    var wall: WallEntry
    let onComplete: (WallEntry, _ isLast: Bool) -> Void

    @EnvironmentObject private var timerMgr: TimerManager

    @State private var completedTimes: [TimeInterval] = []
    @State private var windowTimerStart: Date? = nil
    @State private var pausedElapsed: TimeInterval = 0
    @State private var isPaused = false
    @State private var isComplete = false

    private var currentWindow: Int { completedTimes.count + 1 }
    private var totalWindows: Int { wall.watchWindowCount }
    private var isIdle: Bool { windowTimerStart == nil && !isPaused && completedTimes.isEmpty }

    private var liveElapsed: TimeInterval {
        pausedElapsed + (windowTimerStart.map { timerMgr.tick.timeIntervalSince($0) } ?? 0)
    }
    private var totalElapsed: TimeInterval {
        completedTimes.reduce(0, +) + (isComplete ? 0 : liveElapsed)
    }
    private var windowWatch: StopwatchState? { timerMgr.watches.first(where: { $0.id == "window" }) }

    var body: some View {
        ZStack {
            Color(hex: "010A12").ignoresSafeArea()

            VStack(spacing: 0) {
                // Wall name + progress
                VStack(spacing: 4) {
                    Text(wall.area.uppercased())
                        .font(.system(size: 11, weight: .black)).tracking(3)
                        .foregroundColor(Color(hex: "3AAAC4").opacity(0.5))
                    if isComplete {
                        Text("Wall Complete")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(hex: "34D399"))
                    } else {
                        Text("Window \(currentWindow) of \(totalWindows)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.top, 70)

                Spacer()

                if isComplete {
                    wallCompleteContent
                } else {
                    timingContent
                }

                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear { beginFirstWindow() }
        .onDisappear { WatchConnectivityManager.shared.sendIdle() }
        .onReceive(NotificationCenter.default.publisher(for: .wxwWatchAction)) { note in
            guard let action = note.userInfo?["action"] as? String else { return }
            if action == "next" { tapNext() }
            else if action == "pause" { tapPause() }
        }
    }

    // MARK: - Timing Content

    @ViewBuilder
    private var timingContent: some View {
        VStack(spacing: 0) {
            // Live timer — huge
            Text(formatTime(liveElapsed))
                .font(.system(size: isPaused ? 64 : 80, weight: .ultraLight, design: .monospaced))
                .foregroundColor(isPaused ? Color.white.opacity(0.4) : Color(hex: "FF6B6B"))
                .animation(.none, value: liveElapsed)
                .padding(.bottom, isPaused ? 8 : 0)

            if isPaused {
                Text("PAUSED")
                    .font(.system(size: 13, weight: .black)).tracking(4)
                    .foregroundColor(Color.white.opacity(0.3))
            }

            Spacer().frame(height: 40)

            // NEXT button — the big one the watch will trigger
            Button { tapNext() } label: {
                VStack(spacing: 6) {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 30, weight: .bold))
                    Text(isPaused ? "RESUME + NEXT" : "NEXT")
                        .font(.system(size: 22, weight: .black)).tracking(2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    LinearGradient(
                        colors: isPaused
                            ? [Color(hex: "059669"), Color(hex: "047857")]
                            : [Color(hex: "1278A0"), Color(hex: "0A5C85")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: Color(hex: "1278A0").opacity(0.4), radius: 20, y: 10)
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // PAUSE / END WALL row
            HStack(spacing: 12) {
                Button { tapPause() } label: {
                    VStack(spacing: 5) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text(isPaused ? "RESUME" : "PAUSE")
                            .font(.system(size: 12, weight: .black)).tracking(1.5)
                    }
                    .foregroundColor(isPaused ? Color(hex: "34D399") : Color.white.opacity(0.6))
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .background(Color(hex: "0A1E2C").opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                        isPaused ? Color(hex: "34D399").opacity(0.4) : Color.white.opacity(0.08),
                        lineWidth: 1.5
                    ))
                }

                Button { finishWall(isLast: true) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("DONE WALL")
                            .font(.system(size: 12, weight: .black)).tracking(1.5)
                    }
                    .foregroundColor(Color(hex: "34D399").opacity(0.8))
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .background(Color(hex: "0A1E12").opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "34D399").opacity(0.2), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)

            // Completed count
            if !completedTimes.isEmpty {
                Text("\(completedTimes.count) done · \(formatTime(completedTimes.reduce(0, +))) total so far")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.25))
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 50)
    }

    // MARK: - Wall Complete Content

    @ViewBuilder
    private var wallCompleteContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "34D399"))

            VStack(spacing: 8) {
                Text(formatTime(totalElapsed))
                    .font(.system(size: 52, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(Color(hex: "34D399"))
                Text("\(completedTimes.count) windows completed")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.4))
            }

            // Per-window breakdown (compact)
            if completedTimes.count > 1 {
                HStack(spacing: 6) {
                    ForEach(Array(completedTimes.enumerated()), id: \.offset) { i, t in
                        VStack(spacing: 2) {
                            Text("\(i + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: "3AAAC4"))
                            Text(formatTime(t))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.35))
                        }
                        .frame(minWidth: 32)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                Button { finishWall(isLast: false) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.rectangle.fill").font(.system(size: 18))
                        Text("Next Wall").font(.system(size: 18, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 72)
                    .background(LinearGradient(colors: [Color(hex: "1278A0"), Color(hex: "0A5C85")], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                Button { finishWall(isLast: true) } label: {
                    Text("Last Wall · Go to Summary")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "04101C"))
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(LinearGradient(colors: [Color(hex: "34D399"), Color(hex: "059669")], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 50)
    }

    // MARK: - Actions

    private func beginFirstWindow() {
        windowTimerStart = Date()
        if windowWatch?.isRunning == false { timerMgr.toggle("window") }
        syncWatch()
    }

    private func tapNext() {
        let elapsed = liveElapsed
        completedTimes.append(elapsed)
        pausedElapsed = 0
        isPaused = false

        if completedTimes.count >= totalWindows {
            windowTimerStart = nil
            isComplete = true
            WatchConnectivityManager.shared.sendIdle()
        } else {
            windowTimerStart = Date()
            syncWatch()
        }
    }

    private func tapPause() {
        if isPaused {
            windowTimerStart = Date()
            isPaused = false
        } else {
            pausedElapsed = liveElapsed
            windowTimerStart = nil
            isPaused = true
        }
        syncWatch()
    }

    private func syncWatch() {
        WatchConnectivityManager.shared.sendWallState(
            wall: wall.area,
            window: currentWindow,
            total: totalWindows,
            elapsed: liveElapsed,
            paused: isPaused,
            active: true
        )
    }

    private func finishWall(isLast: Bool) {
        if !isComplete && liveElapsed > 0 { completedTimes.append(liveElapsed) }
        windowTimerStart = nil
        WatchConnectivityManager.shared.sendIdle()

        var completed = wall
        completed.watchWindowTimes = completedTimes
        onComplete(completed, isLast)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
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

    private func watchFormatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60; let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
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
            if wall.isWatchMode {
                // Watch mode: show per-window times grid
                let times = wall.watchWindowTimes
                if !times.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                        ForEach(Array(times.enumerated()), id: \.offset) { i, t in
                            VStack(spacing: 2) {
                                Text("\(i + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(hex: "3AAAC4"))
                                Text(watchFormatTime(t))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(hex: "071520").opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    HStack {
                        Image(systemName: "clock").font(.system(size: 11))
                            .foregroundColor(Color(hex: "34D399").opacity(0.6))
                        Text("Total: \(watchFormatTime(times.reduce(0, +)))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "34D399").opacity(0.8))
                        Spacer()
                        Text("\(times.count)/\(wall.watchWindowCount) windows")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
            } else if !wall.windowPhotos.isEmpty {
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
