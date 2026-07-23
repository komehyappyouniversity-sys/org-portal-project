# 開発・Pull Request運用

## ブランチ

- `main`への直接pushは禁止します。
- 作業は目的別ブランチで行います。
- Codexの実装ブランチは`codex/<task-name>`形式とします。
- 1つのPull Requestには、検証可能な1つの目的だけを含めます。

## コミットメッセージ

次の接頭辞を使用します。

- `feat:` 新機能
- `fix:` 不具合修正
- `docs:` 文書のみの変更
- `test:` テストのみの変更
- `chore:` CI、ビルド、保守作業
- `refactor:` 挙動を変えない構造改善

## Pull Request

- 1名以上のレビュー承認を必要とします。
- Android CIとiPhone CIの成功を必要とします。
- Firebase関連テストはEmulator Suiteまたは専用の開発Firebaseだけを使用します。
- 本番Firebaseの設定ファイル、秘密鍵、APIキーを含めません。
- iPhone・Android共通機能では、両OSの実装・テスト状況を説明します。
- 設計資料にない仕様判断が必要な場合は実装を止め、根津さんへ確認します。

## マージ

- 原則としてSquash mergeを使用します。
- マージ後のコミットメッセージも上記の接頭辞に従います。
