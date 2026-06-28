import SwiftUI

struct TechMainView: View {
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var timerMgr = TimerManager()
    @StateObject private var alertsMgr = AlertsManager()
    @State private var selectedTab = 0
    @State private var homeExpanded = false

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
                case 1: TimeclockView(timerMgr: timerMgr)
                case 2: AlertsView(alertsMgr: alertsMgr)
                default: MileageView()
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
        }
    }
}

struct TechTabBar: View {
    @Binding var selectedTab: Int
    let unreadAlerts: Int

    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("timer", "Clocks"),
        ("bell.fill", "Alerts"),
        ("map.fill", "Miles"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { i, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedTab = i }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20, weight: selectedTab == i ? .bold : .regular))
                                .foregroundColor(
                                    selectedTab == i
                                    ? Color(hex: "7ED8EA")
                                    : Color.white.opacity(0.32)
                                )
                            if i == 2 && unreadAlerts > 0 {
                                Text("\(min(unreadAlerts, 9))")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color(hex: "F97316"))
                                    .clipShape(Circle())
                                    .offset(x: 10, y: -10)
                            }
                        }
                        Text(tab.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(
                                selectedTab == i
                                ? Color(hex: "7ED8EA")
                                : Color.white.opacity(0.28)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
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
}
