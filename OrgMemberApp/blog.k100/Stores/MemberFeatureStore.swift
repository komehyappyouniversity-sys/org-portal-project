import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class MemberFeatureStore: ObservableObject {
    @Published var settings: MemberFeatureSettings = .default
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        listener?.remove()
    }

    func startListening(organizationId: String) {
        listener?.remove()
        errorMessage = ""

        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            errorMessage = "organizationId が空です"
            print("❌ MemberFeatureStore organizationId empty")
            return
        }

        print("🔍 MemberFeatureStore listen start")
        print("🔍 organizationId:", orgId)

        isLoading = true

        listener = db
            .collection("organizations")
            .document(orgId)
            .collection("settings")
            .document("adminFeatures")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.settings = .default
                        print("❌ member adminFeatures read error:", error.localizedDescription)
                        return
                    }

                    guard let data = snapshot?.data() else {
                        self.settings = .default
                        print("⚠️ settings/adminFeatures not found. using default settings")
                        return
                    }

                    self.settings = MemberFeatureSettings(data: data)

                    print("✅ member adminFeatures loaded from settings/adminFeatures:", data)
                    print("🎛 bookingEnabled:", self.settings.bookingEnabled)
                    print("🎛 videoEnabled:", self.settings.videoEnabled)
                    print("🎛 paidVideoEnabled:", self.settings.paidVideoEnabled)
                    print("🎛 announcementEnabled:", self.settings.announcementEnabled)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    var bookingEnabled: Bool {
        settings.bookingEnabled
    }

    var videoEnabled: Bool {
        settings.videoEnabled
    }

    var paidVideoEnabled: Bool {
        settings.paidVideoEnabled
    }

    var announcementEnabled: Bool {
        settings.announcementEnabled
    }
}
