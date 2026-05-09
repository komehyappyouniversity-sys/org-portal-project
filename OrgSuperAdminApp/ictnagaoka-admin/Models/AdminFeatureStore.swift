import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class AdminFeatureStore: ObservableObject {
    @Published var settings: AdminFeatureSettings = .default
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

        guard !organizationId.isEmpty else {
            settings = .default
            errorMessage = "organizationId が空です。"
            print("❌ AdminFeatureStore: organizationId is empty")
            return
        }

        isLoading = true

        let ref = db
            .collection("organizations")
            .document(organizationId)
            .collection("settings")
            .document("adminFeatures")

        print("👂 AdminFeatureStore listening:")
        print("organizations/\(organizationId)/settings/adminFeatures")

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.settings = .default
                    self.errorMessage = error.localizedDescription
                    print("❌ AdminFeatureStore listen error: \(error.localizedDescription)")
                    return
                }

                guard let data = snapshot?.data() else {
                    self.settings = .default
                    self.errorMessage = ""
                    print("⚠️ AdminFeatureStore: adminFeatures document not found. All features disabled.")
                    return
                }

                self.settings = AdminFeatureSettings(data: data)
                self.errorMessage = ""

                print("✅ AdminFeatureStore updated:")
                print(data)
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        print("🛑 AdminFeatureStore stopped listening")
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

    var messageEnabled: Bool {
        settings.messageEnabled
    }

    var announcementEnabled: Bool {
        settings.announcementEnabled
    }

    var memberPostEnabled: Bool {
        settings.memberPostEnabled
    }

    var categoryEnabled: Bool {
        settings.categoryEnabled
    }

    var scheduleEnabled: Bool {
        settings.scheduleEnabled
    }
}
