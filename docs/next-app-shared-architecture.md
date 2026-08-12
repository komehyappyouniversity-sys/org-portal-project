# Next App 共通設計

## 目的

Next App は、iPhone と Android で同じ利用者状態、権限、データ形式、エラー方針を共有する新規アプリです。開発版は本番版と別のアプリ ID を利用し、開発中に本番 Firebase へ書き込まないことを前提にします。

## レイヤーと依存関係

共通の論理構成は `Core`、`Feature`、`App` の三層です。

- `Core` は Model、DesignSystem、Navigation、Session、Data、Notifications、Testing を提供します。
- `Feature` は Tools、Account、Community、Messages、Content、Posts、Creator、CommunityAdmin、Billing を必要な Core にだけ依存して実装します。
- `App` は Core と Feature を組み合わせます。Feature 同士は直接依存しません。

Firebase 実装は Data 層に限定し、画面は Firestore の `DocumentSnapshot` や辞書を直接扱いません。既存 Firebase のフィールド名や欠損値は Legacy Adapter で Domain Model へ変換します。

## 利用者状態と権限

利用者状態は Guest、申請中、会員、Creator、Owner、Manager を共通の Session と権限モデルで扱います。

- Guest は端末内の便利機能と公開コンテンツを利用できます。
- 会員は選択中コミュニティのお知らせ、投稿、動画、ラジオ、イベント予約を利用できます。
- Creator、Owner、Manager は必要な範囲だけ運営機能を利用できます。
- UI の表示権限と Firebase Security Rules は同じ権限方針に従います。

## データ方針

- 端末内データは各 OS のローカル永続化層で保存します。
- Firebase の読書きは Repository を経由します。
- 予約など同時更新が起きる操作はサーバー側で整合性を確保します。
- 通知トークンは UID、アプリ種別、環境、更新日時とともに保存します。

## UI 方針

基本ナビゲーションは「ホーム・便利・つながる・マイページ」を維持し、利用者状態に応じてホームカードとマイページの入口を追加します。重要操作には確認と結果表示を用意し、状態は色だけで表現しません。

アクセシビリティでは、十分なタップ領域、文字サイズ変更、ダークモード、高コントラストを考慮します。iPhone と Android は情報構造と文言をそろえ、各 OS の標準操作に合わせます。

## 開発版と本番版

開発版は `org.nagaoka.blog.k100.member.next` と `jp.komehyappyo.member.next` を利用します。本番配信では現行アプリと同じ正式 ID と署名を利用し、既存会員データを維持した更新として提供します。
