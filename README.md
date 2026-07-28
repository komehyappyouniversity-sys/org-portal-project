# Org Portal Project

コミュニティ会員アプリと運営機能を管理するリポジトリです。

## 次期会員アプリ

次期会員アプリは、現行アプリから独立した新規プロジェクトとして
`NextApp/` 配下で開発します。

```text
NextApp/
├── iOS/       SwiftUI / SwiftData
├── Android/   Jetpack Compose / Room
└── firebase/  開発・CI用Firebase Emulator設定
```

正式な仕様は
[docs/次期会員アプリ_設計資料_v1.md](docs/次期会員アプリ_設計資料_v1.md)
を参照してください。

## 重要な安全方針

- 現行アプリは参照用として維持し、次期版へ旧画面や巨大なRepositoryをコピーしません。
- Debugビルドは本番Firebaseへ接続しません。
- 本番Firebaseの秘密情報を通常のCIへ渡しません。
- iPhone・Androidの両方で実装とテストが揃うまで、機能を完了扱いにしません。

## 開発

ブランチ、コミット、Pull Requestの運用は
[CONTRIBUTING.md](CONTRIBUTING.md)を参照してください。

### ローカル検証

Android:

```sh
cd NextApp/Android
./gradlew :app:assembleDebug test lintDebug
```

iPhone:

```sh
xcodebuild \
  -project NextApp/iOS/OrgPortalNext/OrgPortalNext.xcodeproj \
  -scheme OrgPortalNext \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test
```

Firebase Emulator:

```sh
cd NextApp/firebase
firebase emulators:exec \
  --project demo-org-portal-next \
  --only auth,firestore,storage \
  'node -e "process.exit(0)"'
```

`demo-`で始まるプロジェクトIDだけを使うため、この検証から本番Firebaseへ接続することはありません。

### 開発Firebaseのコミュニティ初期データ

実機でコミュニティコードによる参加申請を確認するには、開発Firebase
`kome-org-portal-next-dev` の `organizations` に公開コミュニティ設定が必要です。
本番の会員・管理者・申請・投稿データは複製せず、公開中かつ参加受付中の
組織設定だけを次の手順で投入します。

```sh
# 対象確認（書き込みなし）
node scripts/seed_development_communities.js

# 開発Firebaseへ新規文書だけを投入
node scripts/seed_development_communities.js --apply
```

スクリプトはコピー元・コピー先を固定し、許可リストに含まれる公開フィールド
だけを扱います。コピー先に同じ組織文書がある場合は上書きせずスキップします。
