import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        if !auth.isConfigured {
            SetupView()
        } else if auth.currentEmployee == nil {
            LoginView()
        } else {
            TechMainView()
        }
    }
}
