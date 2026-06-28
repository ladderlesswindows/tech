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
                    // Overlay stops 230pt from bottom so shift card + tab bar show full beach
                    VStack(spacing: 0) {
                        Color(hex: "04101C")
                            .opacity(selectedTab == 0 && !homeExpanded ? 0.0 : 0.72)
                            .animation(.easeInOut(duration: 0.4), value: homeExpanded)
                            .animation(.easeInOut(duration: 0.25), value: selectedTab)
                        Color.clear.frame(height: 230)
                    }
                    .ignoresSafeArea()
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
                    if let jobs = try? await APIClient.fetchSchedule(password: auth.apiPassword) {
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
    }

    private func tabItem(icon: String, label: String, index: Int, badge: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index }
        } label: {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: selectedTab == index ? .bold : .semibold))
                    .foregroundColor(selectedTab == index ? Color(hex: "7ED8EA") : Color.white.opacity(0.75))
                    .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 1)
                if badge > 0 {
                    Text("\(min(badge, 9))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color(hex: "F97316"))
                        .clipShape(Circle())
                        .offset(x: 12, y: -10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.bottom, 20)
        }
    }

    private var vanTab: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedTab = 3 }
        } label: {
            Image(systemName: "car.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(hex: "34D399"))
                .shadow(color: Color(hex: "34D399").opacity(0.6), radius: 6, x: 0, y: 0)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.bottom, 20)
        }
    }
}
