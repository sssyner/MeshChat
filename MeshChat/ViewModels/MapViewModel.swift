import Foundation
import MapKit

@Observable
final class MapViewModel {
    var messages: [MeshMessage] = []
    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private let messageStore: MessageStore
    private let locationService: LocationService
    private let cloudSync: CloudSyncService

    init(messageStore: MessageStore, locationService: LocationService, cloudSync: CloudSyncService) {
        self.messageStore = messageStore
        self.locationService = locationService
        self.cloudSync = cloudSync
    }

    func loadMessages() {
        // Insert demo data on first launch
        insertDemoDataIfNeeded()

        do {
            messages = try messageStore.unexpiredMessages()
            let allCount = try messageStore.allMessages().count
            // debugInfo += " unexpired=\(messages.count) all=\(allCount)"

            // 期限切れデモデータの自動復旧
            if messages.isEmpty {
                if allCount > 0 {
                    try messageStore.deleteExpiredMessages()
                }
                UserDefaults.standard.removeObject(forKey: "meshchat_demo_data_inserted")
                insertDemoDataIfNeeded()
                messages = try messageStore.unexpiredMessages()
                // debugInfo += " retry=\(messages.count)"
            }

            if let location = locationService.currentLocation {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        } catch {
            // debugInfo += " ERR=\(error.localizedDescription)"
            MeshLogger.general.error("MapVM: Failed to load messages: \(error.localizedDescription)")
        }

        Task {
            await fetchFromCloud()
        }
    }

    func fetchFromCloud() async {
        let cloudMessages = await cloudSync.fetchGlobalMessages()

        for msg in cloudMessages {
            do {
                if !(try messageStore.messageExists(id: msg.id)) {
                    try messageStore.insert(msg)
                }
            } catch {
                MeshLogger.general.error("MapVM: Failed to store cloud message: \(error.localizedDescription)")
            }
        }

        do {
            messages = try messageStore.unexpiredMessages()
        } catch {
            MeshLogger.general.error("MapVM: Failed to reload: \(error.localizedDescription)")
        }
    }

    private func insertDemoDataIfNeeded() {
        let key = "meshchat_demo_data_inserted"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let demoMessages: [(String, String, DangerType?, Double, Double, String)] = [
            ("渋谷駅前で火災発生。消防車出動中。周辺の方は注意してください。", "田中太郎", .fire, 35.6580, 139.7016, "demo-1"),
            ("新宿区で断水情報あり。給水車が区役所前に来ています。", "佐藤花子", .info, 35.6896, 139.6921, "demo-2"),
            ("品川駅周辺、電車運転見合わせ中。振替輸送を利用してください。", "鈴木一郎", .info, 35.6284, 139.7387, "demo-3"),
            ("目黒川が増水中。河川敷には近づかないでください。", "高橋美咲", .flood, 35.6441, 139.6980, "demo-4"),
            ("代々木公園が避難場所として開放されています。毛布の配布あり。", "山本健二", .help, 35.6715, 139.6949, "demo-5"),
            ("池袋駅東口、建物からの落下物に注意。迂回をお勧めします。", "中村優子", .earthquake, 35.7295, 139.7109, "demo-6"),
            ("六本木ヒルズ付近、停電発生。復旧は未定。", "小林大輔", .info, 35.6605, 139.7292, "demo-7"),
            ("上野公園で炊き出し実施中。どなたでも利用可能です。", "伊藤真理", .help, 35.7146, 139.7732, "demo-8"),
            ("秋葉原周辺で余震を感知。建物内では机の下へ。", "渡辺拓也", .earthquake, 35.6984, 139.7731, "demo-9"),
            ("東京タワー付近、道路の亀裂を確認。車両通行注意。", "松本さくら", .earthquake, 35.6586, 139.7454, "demo-10"),
            ("お台場海浜公園で津波注意報。高台に避難してください。", "木村翔太", .flood, 35.6292, 139.7753, "demo-11"),
            ("中野区の避難所に食料が不足しています。支援お願いします。", "加藤由美", .help, 35.7078, 139.6638, "demo-12"),
        ]

        let now = Date()
        for (i, demo) in demoMessages.enumerated() {
            let (text, sender, dangerType, lat, lon, id) = demo
            let createdAt = now.addingTimeInterval(Double(-i * 300)) // 5分間隔
            let msg = MeshMessage(
                id: id,
                senderID: "demo-user-\(i)",
                senderName: sender,
                message: text,
                dangerType: dangerType,
                latitude: lat,
                longitude: lon,
                createdAt: createdAt,
                expiresAt: now.addingTimeInterval(24 * 60 * 60),
                hopCount: Int.random(in: 0...4),
                maxHops: 7,
                signature: "demo-sig-\(id)",
                isSynced: i % 3 == 0,
                receivedAt: createdAt
            )
            do {
                try messageStore.insert(msg)
            } catch {
                MeshLogger.general.error("Failed to insert demo message: \(error.localizedDescription)")
            }
        }
    }
}
