# Codex実装指示書（タスク1〜3）

出典設計資料: `次期会員アプリ_設計資料_v1.md`

## 全タスク共通の制約

1. Android・iPhoneの機能・挙動・データ・検証を共通化する。
2. AppがCoreとFeatureを組み合わせ、Feature同士を直接依存させない。
3. Firebase SDKの実装はData層へ限定し、UIへFirestore生データを渡さない。
4. 端末内保存はiPhoneがSwiftData、AndroidがRoomで、Local Repositoryを経由する。
5. 開発・自動テストはFirebase Emulator Suite、実機結合試験は本番と別の開発Firebaseを使用する。
6. Debugビルドが本番Firebaseを参照していた場合は起動を停止する。
7. 開発用IDはiPhone `org.nagaoka.blog.k100.member.next`、Android `jp.komehyappyo.member.next`とする。
8. 秘密情報をアプリへ直接記載しない。
9. 両OSの実装・テストが揃うまで機能を完了扱いにしない。
10. 設計資料にない仕様判断は独断で行わず、根津さんへ確認する。

## タスク1: リポジトリ整備とCI

- 設計資料を`docs/`へ配置する。
- Pull RequestごとにAndroidのビルド・単体テスト・Lintを実行する。
- Pull RequestごとにiPhone Simulatorのビルド・単体テストを実行する（Apple Developer証明書や本番署名情報は使わない）。
- CIからFirebase Emulator Suiteを起動できるようにする。
- 通常CIへ本番Firebase秘密情報を渡さない。
- macOSとXcodeを固定する。

## タスク2: Core基盤モジュール

両OSへ次の論理モジュールを実装する。

- Model
- DesignSystem
- Navigation
- Session
- Data
- Notifications
- Testing

下部タブは「ホーム・便利・つながる・マイページ」の4つとする。

## タスク3: 予定

- `Schedule`、`RecurrenceRule`、`ReminderSetting`、`ScheduleCategory`
- 時間帯は「終日・午前・午後・夕方・時間指定」
- G02 予定一覧、G03 登録編集、G04 詳細、G05 今日の予定
- SwiftData／Roomによる端末内保存
- CSV共有、端末カレンダーへの追加
- EmptyState、ErrorState/Retry
- Domain Modelと保存・取得処理の単体テスト

Firebase移行処理と予定以外の便利機能は、このタスクの対象外とする。
