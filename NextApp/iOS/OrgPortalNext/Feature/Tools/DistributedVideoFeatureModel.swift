import Foundation
import DataLayer
import Model
import Session

@MainActor
public final class DistributedVideoFeatureModel: ObservableObject {
    @Published public private(set) var videos: [DistributedVideo] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let repository: any CommunityRepository
    private let session: AppSession
    private let canViewMembersOnlyVideo: (String) -> Bool

    public init(
        repository: any CommunityRepository,
        session: AppSession,
        canViewMembersOnlyVideo: @escaping (String) -> Bool
    ) {
        self.repository = repository
        self.session = session
        self.canViewMembersOnlyVideo = canViewMembersOnlyVideo
    }

    public func load() async {
        guard let communityId = session.selectedCommunityId,
              let token = session.authenticationToken else {
            videos = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let allowed = canViewMembersOnlyVideo(communityId)
            videos = filterDistributedVideos(
                try await repository.communityVideos(
                    communityId: communityId,
                    idToken: token
                ),
                canViewMembersOnlyVideo: allowed,
            )
        } catch {
            errorMessage = "動画を取得できませんでした。"
        }
        isLoading = false
    }

    public func clearError() {
        errorMessage = nil
    }
}

internal func filterDistributedVideos(
    _ videos: [DistributedVideo],
    canViewMembersOnlyVideo: Bool,
) -> [DistributedVideo] {
    videos
        .filter { video in
            !video.isPremium && (!video.isMembersOnly || canViewMembersOnlyVideo)
        }
        .sorted {
            $0.sortOrder == $1.sortOrder
                ? $0.title < $1.title
                : $0.sortOrder < $1.sortOrder
        }
}
