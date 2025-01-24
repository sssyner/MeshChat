# MeshChat (iOS)

インターネットなしで使える災害時メッシュ通信アプリ。
BLEで端末同士を直接つないで、圏外でも近くの人とメッセージをやりとりできる。

Android版は [MeshChat-Android](https://github.com/sssyner/MeshChat-Android)。

## どう動くか

各端末がBLE Central + Peripheralの両方として動作する。
メッセージは最大7ホップまで中継され、直接つながっていない端末にも届く。

```
端末A → BLE → 端末B → リレー → 端末C → ...
```

- ローカルDB（GRDB/SQLite）に保存、ネット復旧でFirestore同期
- 24時間で自動消滅（災害時の古い情報が残り続けないように）
- 重複排除キャッシュ（1000件、5分TTL）

## BLEプロトコル

独自のバイナリプロトコルを実装した。

- ヘッダー: 14バイト（version, type, TTL, timestamp, flags, payload length）
- MTU 512バイト超のメッセージはフラグメント分割して送信
- パケットタイプ: message, ack, fragment, peerDiscovery, heartbeat

フラグメントの再組み立て（`FragmentAssembler`）はNSLockでスレッドセーフにしてある。

## 技術構成

- SwiftUI (iOS 17+) + Swift 5.9
- CoreBluetooth
- GRDB (SQLiteラッパー)
- Firebase Auth / Firestore
- MapKit

## 機能

- 地図上にメッセージ位置をピン表示
- 危険種別: 火災/洪水/地震/救助要請/情報共有
- BLE診断画面（接続数、リレー統計）
- ユーザーブロック・通報

## セットアップ

Xcode 15+で`MeshChat.xcodeproj`を開いて、`GoogleService-Info.plist`を追加してビルド。
BLEの動作確認には実機が2台以上必要。
