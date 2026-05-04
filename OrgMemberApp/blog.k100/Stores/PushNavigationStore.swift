import Foundation
import Combine

@MainActor
final class PushNavigationStore: ObservableObject {
    @Published var shouldOpenMessageDetail = false
    @Published var targetMessageId: String?
    @Published var targetOrganizationId: String?

    func openMessage(messageId: String, organizationId: String) {
        targetMessageId = messageId
        targetOrganizationId = organizationId
        shouldOpenMessageDetail = true

        print("🔔 通知タップで開く messageId:", messageId)
        print("🔔 organizationId:", organizationId)
    }

    func reset() {
        shouldOpenMessageDetail = false
        targetMessageId = nil
        targetOrganizationId = nil
    }
}
