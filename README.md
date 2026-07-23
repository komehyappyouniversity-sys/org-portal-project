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
