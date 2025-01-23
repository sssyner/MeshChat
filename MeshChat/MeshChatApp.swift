import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct MeshChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var messageStore: MessageStore?
    @State private var bleService: BLEService?
    @State private var chatViewModel: ChatViewModel?
    @State private var mapViewModel: MapViewModel?
    @State private var statsViewModel: StatsViewModel?
    @State private var authService = AuthService()
    @State private var locationService = LocationService()
    @State private var cloudSync = CloudSyncService()
    @State private var moderationService = ModerationService()
    @State private var initError: String?
    @State private var servicesStarted = false
    @State private var showMain = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = initError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("初期化エラー")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if messageStore == nil {
                    ProgressView("初期化中...")
                } else if !showMain {
                    LoginView(authService: authService) {
                        if !authService.isSignedIn {
                            authService.setLocalFallback()
                        }
                        startServices()
                        showMain = true
                    }
                } else if let chatVM = chatViewModel,
                          let mapVM = mapViewModel,
                          let statsVM = statsViewModel,
                          let ble = bleService {
                    ContentView(
                        chatViewModel: chatVM,
                        mapViewModel: mapVM,
                        statsViewModel: statsVM,
                        bleService: ble,
                        cloudSync: cloudSync,
                        authService: authService,
                        moderationService: moderationService,
                        onSignOut: {
                            do {
                                try authService.signOut()
                                servicesStarted = false
                                bleService = nil
                                chatViewModel = nil
                                mapViewModel = nil
                                statsViewModel = nil
                                showMain = false
                            } catch {
                                MeshLogger.general.error("Sign out failed: \(error.localizedDescription)")
                            }
                        }
                    )
                } else {
                    ProgressView("サービス起動中...")
                }
            }
            .task {
                await initialize()
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    private func initialize() async {
        do {
            let store = try MessageStore()
            cloudSync.configure(store: store)
            authService.restoreSession()
            self.messageStore = store

            if authService.isSignedIn && !authService.isAnonymous {
                startServices()
                showMain = true
            }

            MeshLogger.general.info("App initialized successfully")
        } catch {
            initError = error.localizedDescription
            MeshLogger.general.error("Init failed: \(error.localizedDescription)")
        }
    }

    private func startServices() {
        guard !servicesStarted, let store = messageStore else { return }
        servicesStarted = true

        let router = MeshRouter()
        let ble = BLEService(router: router)
        self.bleService = ble

        self.chatViewModel = ChatViewModel(
            messageStore: store,
            bleService: ble,
            authService: authService,
            locationService: locationService,
            cloudSync: cloudSync,
            moderationService: moderationService
        )
        self.mapViewModel = MapViewModel(
            messageStore: store,
            locationService: locationService,
            cloudSync: cloudSync
        )
        self.statsViewModel = StatsViewModel(
            messageStore: store,
            bleService: ble,
            cloudSync: cloudSync
        )

        locationService.requestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ble.start()
        }
    }
}
