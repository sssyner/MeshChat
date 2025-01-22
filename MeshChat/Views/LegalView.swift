import SwiftUI

struct TermsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("最終更新日: 2026年3月14日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LegalSection(title: "第1条（適用）", content: "本規約は、MeshChat（以下「本アプリ」）の利用に関する条件を定めるものです。ユーザーは本アプリを利用することにより、本規約に同意したものとみなします。")

                    LegalSection(title: "第2条（サービス内容）", content: "本アプリは、Bluetooth Low Energy（BLE）メッシュネットワークを利用した近距離メッセージ通信サービスを提供します。インターネット接続が利用可能な場合、クラウド同期機能も利用できます。")

                    LegalSection(title: "第3条（利用条件）", content: "1. ユーザーは本アプリを災害時の通信手段として、また日常のローカルコミュニケーションツールとして利用できます。\n2. ユーザーはBluetooth及び位置情報の許可を付与する必要があります。\n3. 本アプリの利用にあたり、ユーザーは法令及び公序良俗に反する行為を行ってはなりません。")

                    LegalSection(title: "第4条（禁止事項）", content: "1. 虚偽の災害情報の発信\n2. 他のユーザーへの嫌がらせ、誹謗中傷\n3. スパムメッセージの送信\n4. 本アプリの不正利用、リバースエンジニアリング\n5. 公序良俗に反するメッセージの送信")

                    LegalSection(title: "第5条（メッセージの取り扱い）", content: "1. メッセージはBLEメッシュネットワークを通じて近隣デバイスにリレーされます。\n2. メッセージには位置情報とタイムスタンプが付加されます。\n3. メッセージは一定期間（24時間）経過後に自動削除されます。\n4. クラウド同期されたメッセージは運営が管理するサーバーに保存されます。")

                    LegalSection(title: "第6条（免責事項）", content: "1. 本アプリはBLE通信の特性上、メッセージの配達を保証するものではありません。\n2. 災害時における通信の確実性を保証するものではありません。\n3. 本アプリの利用により生じた損害について、運営は一切の責任を負いません。\n4. 本アプリは現状有姿で提供されます。")

                    LegalSection(title: "第7条（アカウント）", content: "1. ユーザーは匿名またはGoogle・Appleアカウントで利用できます。\n2. アカウント削除時、ユーザーのデータは完全に削除されます。")

                    LegalSection(title: "第8条（コンテンツの通報）", content: "1. ユーザーは不適切なメッセージを通報することができます。\n2. ユーザーは特定のユーザーをブロックし、そのユーザーからのメッセージを非表示にすることができます。\n3. 運営は通報されたコンテンツを確認し、必要に応じて適切な措置を講じます。")

                    LegalSection(title: "第9条（規約の変更）", content: "運営は必要に応じて本規約を変更できるものとします。変更後の規約はアプリ内に掲示した時点で効力を生じます。")

                    LegalSection(title: "第10条（準拠法）", content: "本規約は日本法に準拠し、解釈されるものとします。")
                }
                .padding()
            }
            .navigationTitle("利用規約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct PrivacyPolicySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("最終更新日: 2026年3月14日")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LegalSection(title: "1. 収集する情報", content: "本アプリは以下の情報を収集します：\n\n・表示名（ユーザーが設定）\n・位置情報（メッセージ送信時のGPS座標）\n・メッセージ内容\n・デバイス識別情報（匿名ID）\n・Google/Appleアカウント情報（連携時のみ）")

                    LegalSection(title: "2. 位置情報の利用", content: "位置情報はメッセージに付加し、マップ上に表示する目的で使用します。位置情報はメッセージ送信時にのみ取得され、常時追跡は行いません。")

                    LegalSection(title: "3. Bluetooth通信", content: "BLE（Bluetooth Low Energy）を使用して近隣デバイスとメッセージを交換します。通信範囲内のデバイスがメッセージをリレーすることで、メッシュネットワークを構成します。BLEスキャンにより、近隣デバイスのBluetooth識別情報を一時的に処理しますが、永続的に保存しません。")

                    LegalSection(title: "4. データの保存", content: "・ローカルデータ: メッセージはデバイス内のデータベースに保存され、24時間後に自動削除されます。\n・クラウドデータ: インターネット接続時、メッセージはFirebase Cloud Firestoreに同期されます。クラウドデータは災害情報の共有と永続化を目的としています。")

                    LegalSection(title: "5. Firebase サービス", content: "本アプリはGoogle Firebaseの以下のサービスを使用します：\n\n・Firebase Authentication（認証）\n・Cloud Firestore（データ同期）\n\nこれらのサービスのプライバシーについては、Googleのプライバシーポリシーが適用されます。")

                    LegalSection(title: "6. 第三者への提供", content: "ユーザーの個人情報を第三者に販売、貸与することはありません。ただし、以下の場合を除きます：\n\n・法令に基づく開示要求があった場合\n・ユーザーの同意がある場合\n・BLEメッシュネットワークを通じた近隣デバイスへのメッセージリレー（本アプリの主要機能）")

                    LegalSection(title: "7. データの削除", content: "ユーザーはアプリ内の「アカウントを削除」機能を使用して、アカウントと関連データを削除できます。ローカルデータはアプリのアンインストールにより削除されます。")

                    LegalSection(title: "8. 子どものプライバシー", content: "本アプリは13歳未満の子どもを対象としていません。13歳未満の方は保護者の同意のもとで利用してください。")

                    LegalSection(title: "9. ポリシーの変更", content: "本ポリシーは必要に応じて更新されます。重要な変更がある場合はアプリ内で通知します。")

                    LegalSection(title: "10. お問い合わせ", content: "プライバシーに関するお問い合わせは以下までご連絡ください：\nsynergy.effect.jp@gmail.com")
                }
                .padding()
            }
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct LegalSection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}
