import DesignSystem
import SwiftUI

public struct AppManual: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let detail: String
    public let externalURL: String?

    public init(
        id: String,
        title: String,
        description: String,
        detail: String,
        externalURL: String? = nil,
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.detail = detail
        self.externalURL = externalURL
    }
}

public struct ManualListView: View {
    @State private var selectedManual: AppManual?

    public init() {}

    public var body: some View {
        NavigationStack {
            if let selectedManual {
                ManualDetailView(manual: selectedManual) {
                    self.selectedManual = nil
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        Text("使い方マニュアル")
                            .font(.title3.bold())
                        Text("ログイン、コミュニティ参加、主要機能の使い方をまとめています。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(availableManuals) { manual in
                            Button {
                                selectedManual = manual
                            } label: {
                                FeatureCard(
                                    manual.title,
                                    subtitle: manual.description,
                                    systemImage: "book"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .navigationTitle("使い方マニュアル")
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
}

public struct ManualDetailView: View {
    private let manual: AppManual
    private let onClose: () -> Void
    @Environment(\.openURL) private var openURL

    fileprivate init(manual: AppManual, onClose: @escaping () -> Void) {
        self.manual = manual
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(manual.title)
                        .font(.title3.bold())
                    Text(manual.detail)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let externalURL = manual.externalURL, let url = URL(string: externalURL) {
                        Button {
                            openURL(url)
                        } label: {
                            FeatureCard(
                                "外部参照を開く",
                                subtitle: externalURL,
                                systemImage: "arrow.up.right.square"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(manual.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる", action: onClose)
                }
            }
        }
    }
}

private let availableManuals: [AppManual] = [
    AppManual(
        id: "quick-start",
        title: "1. アカウントと開始の流れ",
        description: "Guestで始めて、会員登録するまで。",
        detail:
        """
        1) アプリを開くとホームと便利機能が表示されます。  
        2) 会員登録はマイページからメールアドレスで行います。  
        3) コミュニティへ参加するには、コミュニティコードまたはQRコードを使います。  
        4) 承認後、コミュニティ機能（投稿・お知らせなど）が利用できます。
        """,
        externalURL: nil
    ),
    AppManual(
        id: "tools-start",
        title: "2. 便利機能の使い方",
        description: "予定、日記、金種計算、会議録音など。",
        detail:
        """
        ホーム・便利タブから各機能画面を開けます。  
        - 予定: 今日の予定を入力し、繰り返しやリマインダーを設定します。  
        - 日記・写真日記: 写真付きで自分用の記録を残します。  
        - 金種計算: 配布金額を入力して、必要な紙幣・硬貨を整理できます。  
        - 会議録音: 文章化は端末内で保存し、後で確認できるようにします。
        """,
        externalURL: nil
    ),
    AppManual(
        id: "sns-favorites",
        title: "3. SNS補助・お気に入りの使い方",
        description: "投稿補助やリンク保存の流れを確認。",
        detail:
        """
        SNS投稿補助では、文章を1タップで外部SNSへコピーできます。  
        お気に入りは、タイトル・URL・メモを保存し、アプリ削除前にバックアップも可能です。  
        共有URLは同じ機能内でワンタップで開けるため、後から見返しやすいです。
        """,
        externalURL: nil
    ),
    AppManual(
        id: "troubleshoot",
        title: "4. よくあるトラブル",
        description: "音声・写真・同期で困ったときの確認ポイント。",
        detail:
        """
        - 録音が再生されない: 権限（マイク）と保存先の空き容量を確認します。  
        - カメラや写真が保存されない: 端末内保存の許可、またはアプリ更新後の再起動で解消する場合があります。  
        - ログインできない: メールアドレスとパスワード、再度パスワードリセットを確認します。  
        - コミュニティ参加できない: 正しいコミュニティコードか、承認待ち状態かを確認します。
        """,
        externalURL: nil
    ),
]
