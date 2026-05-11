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
            errorMessage = "organizationId が空です"
            print("❌ AdminFeatureStore organizationId empty")
            return
        }

        print("🔍 AdminFeatureStore listen start")
        print("🔍 organizationId:", organizationId)

        isLoading = true

        listener = db
            .collection("organizations")
            .document(organizationId)
            .collection("settings")
            .document("adminFeatures")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        print("❌ adminFeatures read error")
                        print(error.localizedDescription)

                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                        return
                    }

                    guard let data = snapshot?.data() else {
                        print("⚠️ adminFeatures not found")
                        print("⚠️ using default settings")

                        self.settings = .default
                        self.isLoading = false
                        return
                    }

                    print("✅ adminFeatures loaded")
                    print(data)

                    self.settings = AdminFeatureSettings(data: data)
                    self.isLoading = false
                }
            }
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
