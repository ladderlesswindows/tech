import SwiftUI

struct TechMainView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var timerMgr = TimerManager()
    @StateObject private var alertsMgr = AlertsManager()
    @State private var selectedTab = 0
    @State private var homeExpanded = false
    @State private var nextGig: Booking? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Persistent beach video behind all tabs
            VideoBackground(player: VideoPlayerController.shared.player)
                .ignoresSafeArea()
                .overlay(
                    Color(hex: "04101C")
                        .opacity(selectedTab == 0 && !homeExpanded ? 0.0 : 0.72)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.4), value: homeExpanded)
                        .animation(.easeInOut(duration: 0.25), value: selectedTab)
                )

            // Tab content
            ZStack {
                switch selectedTab {
                case 0: DashboardView(timerMgr: timerMgr, alertsMgr: alertsMgr, selectedTab: $selectedTab, isExpanded: $homeExpanded)
                case 1: ScheduleView()
                case 2: AlertsView(alertsMgr: alertsMgr)
                default: Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Tab bar hidden on home screen until expanded
            if selectedTab != 0 || homeExpanded {
                TechTabBar(selectedTab: $selectedTab, unreadAlerts: alertsMgr.unreadCount)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(timerMgr)
        .environmentObject(alertsMgr)
        .onAppear { alertsMgr.startPolling() }
        .onDisappear { alertsMgr.stopPolling() }
        .onChange(of: selectedTab) { tab in
            if tab != 0 { homeExpanded = false }
            if tab == 3 {
                selectedTab = 0
                Task {
                    guard let pw = UserDefaults.standard.string(forKey: "worker_password") else { return }
                    if let jobs = try? await APIClient.fetchSchedule(password: pw) {
                        nextGig = jobs.first
                    }
                }
            }
        }
        .fullScreenCover(item: $nextGig) { job in
            JobDetailView(booking: job, timerMgr: timerMgr)
        }
    }
}

struct TechTabBar: View {
    @Binding var selectedTab: Int
    let unreadAlerts: Int

    var body: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house.fill", label: "Home", index: 0)
            tabItem(icon: "calendar", label: "Schedule", index: 1)
            tabItem(icon: "bell.fill", label: "Alerts", index: 2, badge: unreadAlerts)
            vanTab
        }
        .background(
            Color(hex: "07151E").opacity(0.92)
                .overlay(
                    LinearGradient(
                        colors: [Color(hex: "0D2D44").opacity(0.6), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(hex: "3AAAC4").opacity(0.22)),
            alignment: .top
        )
    }

    private func tabItem(icon: String, label: String, index: Int, badge: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: selectedTab == index ? .bold : .regular))
                        .foregroundColor(selectedTab == index ? Color(hex: "7ED8EA") : Color.white.opacity(0.32))
                    if badge > 0 {
                        Text("\(min(badge, 9))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color(hex: "F97316"))
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(selectedTab == index ? Color(hex: "7ED8EA") : Color.white.opacity(0.28))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    private var vanTab: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = 3 }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "van.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color(hex: "34D399").opacity(0.9))
                Text("Next Gig")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "34D399").opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }
}
