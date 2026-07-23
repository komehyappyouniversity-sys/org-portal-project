import Foundation
import Model

@MainActor
public final class AppSession: ObservableObject {
    @Published public private(set) var userStage: UserStage
    @Published public var selectedCommunityId: String?
    @Published public private(set) var previousCommunityId: String?

    public init(
        userStage: UserStage = .guest,
        selectedCommunityId: String? = nil
    ) {
        self.userStage = userStage
        self.selectedCommunityId = selectedCommunityId
    }

    public func updateUserStage(_ stage: UserStage) {
        userStage = stage
    }

    public func selectCommunity(_ id: String?) {
        guard id != selectedCommunityId else { return }
        previousCommunityId = selectedCommunityId
        selectedCommunityId = id
    }

    public func returnToPreviousCommunity() {
        let current = selectedCommunityId
        selectedCommunityId = previousCommunityId
        previousCommunityId = current
    }
}
