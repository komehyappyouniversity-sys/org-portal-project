import DataLayer
import DesignSystem
import Model
import SwiftUI

@MainActor
public final class ManualFeatureModel: ObservableObject {
    @Published public private(set) var manuals: [Manual] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var hasLoaded = false
    @Published public private(set) var errorMessage: String?

    private let repository: any ManualRepository
    private var communityId: String?
    private var idToken: String?
    private var requestID = UUID()

    public init(repository: any ManualRepository) {
        self.repository = repository
    }

    public func load(communityId: String?, idToken: String?) async {
        self.communityId = communityId
        self.idToken = idToken
        let currentRequestID = UUID()
        requestID = currentRequestID
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await repository.manuals(
                communityId: communityId,
                idToken: idToken
            )
            guard requestID == currentRequestID else { return }
            manuals = loaded
            hasLoaded = true
            isLoading = false
        } catch is CancellationError {
            guard requestID == currentRequestID else { return }
            isLoading = false
        } catch {
            guard requestID == currentRequestID else { return }
            manuals = []
            hasLoaded = true
            isLoading = false
            errorMessage = "マニュアルを読み込めませんでした。"
        }
    }

    public func retry() async {
        await load(communityId: communityId, idToken: idToken)
    }
}

public struct ManualListView: View {
    @ObservedObject private var model: ManualFeatureModel
    @State private var selectedManual: Manual?

    public init(model: ManualFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            if let selectedManual {
                ManualDetailView(manual: selectedManual) {
                    self.selectedManual = nil
                }
            } else {
                Group {
                    if model.isLoading && !model.hasLoaded {
                        VStack(spacing: 12) {
                            LoadingState()
                            Text("読み込み中")
                        }
                    } else if let errorMessage = model.errorMessage {
                        ErrorState(message: errorMessage) {
                            Task { await model.retry() }
                        }
                    } else if model.manuals.isEmpty {
                        EmptyState(
                            "表示可能なマニュアルがありません。",
                            description: "公開中のマニュアルが追加されると、ここに表示されます。",
                            systemImage: "book.closed"
                        )
                    } else {
                        manualList
                    }
                }
                .navigationTitle("使い方マニュアル")
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onChange(of: model.manuals) { _, manuals in
            guard let selectedManual else { return }
            if !manuals.contains(where: { $0.listIdentity == selectedManual.listIdentity }) {
                self.selectedManual = nil
            }
        }
    }

    private var manualList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("使い方マニュアル")
                    .font(.title3.bold())
                Text("アプリ共通と、選択中のコミュニティ専用マニュアルを表示します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(model.manuals, id: \.listIdentity) { manual in
                    Button {
                        selectedManual = manual
                    } label: {
                        FeatureCard(
                            LocalizedStringKey(manual.title),
                            subtitle: LocalizedStringKey(
                                manual.communityId == nil
                                    ? "アプリ共通マニュアル"
                                    : "コミュニティ専用マニュアル"
                            ),
                            systemImage: "book"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

public struct ManualDetailView: View {
    private struct SelectedImage: Identifiable {
        let id = UUID()
        let url: URL
    }

    private let manual: Manual
    private let onClose: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var selectedImage: SelectedImage?

    fileprivate init(manual: Manual, onClose: @escaping () -> Void) {
        self.manual = manual
        self.onClose = onClose
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(manual.title)
                    .font(.title3.bold())
                Text(manual.body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(Array(manual.imageUrls.enumerated()), id: \.offset) { index, value in
                    if let url = URL(string: value) {
                        Button {
                            selectedImage = SelectedImage(url: url)
                        } label: {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                case .failure:
                                    Label("画像を読み込めませんでした。", systemImage: "photo")
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                default:
                                    ProgressView()
                                        .frame(maxWidth: .infinity, minHeight: 120)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("画像 \(index + 1) を拡大")
                    }
                }

                if let pdfUrl = validURL(manual.pdfUrl) {
                    linkButton(title: "PDFを開く", url: pdfUrl, systemImage: "doc.richtext")
                }
                if let externalUrl = validURL(manual.externalUrl) {
                    linkButton(
                        title: "外部リンクを開く",
                        url: externalUrl,
                        systemImage: "arrow.up.right.square"
                    )
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
        .sheet(item: $selectedImage) { image in
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    AsyncImage(url: image.url) { phase in
                        if let loadedImage = phase.image {
                            loadedImage
                                .resizable()
                                .scaledToFit()
                        } else if phase.error != nil {
                            Text("画像を読み込めませんでした。")
                                .foregroundStyle(.white)
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("閉じる") { selectedImage = nil }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func validURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }

    private func linkButton(title: String, url: URL, systemImage: String) -> some View {
        Button {
            openURL(url)
        } label: {
            FeatureCard(
                LocalizedStringKey(title),
                subtitle: LocalizedStringKey(url.absoluteString),
                systemImage: systemImage
            )
        }
        .buttonStyle(.plain)
    }
}
