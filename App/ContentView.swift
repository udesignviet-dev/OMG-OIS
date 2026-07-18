import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if authStore.isLoggedIn {
                MapScreen()
            } else {
                LoginView()
            }
        }
    }
}
