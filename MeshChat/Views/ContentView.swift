import SwiftUI

struct ContentView: View {
    let chatViewModel: ChatViewModel
    let mapViewModel: MapViewModel
    let statsViewModel: StatsViewModel
    let bleService: BLEService
    let cloudSync: CloudSyncService
    let authService: AuthService
    let moderationService: ModerationService
    let onSignOut: () -> Void

    @State private var selectedTab = 0
    @State private var showProfile = false

    var body: some View {
        TabView(selection: $selectedTab) {
            MeshMapView(viewModel: mapViewModel, bleService: bleService, chatViewModel: chatViewModel, cloudSync: cloudSync)
                .tabItem {
                    Label("マップ", systemImage: "map")
                }
                .tag(0)

            StatsView(viewModel: statsViewModel, bleService: bleService, cloudSync: cloudSync)
                .tabItem {
                    Label("診断", systemImage: "chart.bar")
                }
                .tag(1)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showProfile = true
            } label: {
                Image(systemName: "person.circle")
                    .font(.title3)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.trailing, 8)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authService: authService, onSignOut: onSignOut)
        }
    }
}
