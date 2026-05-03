import Foundation
import Combine

enum AppUserRole {
    case loading
    case guest
    case member
}

@MainActor
final class AppBootstrapStore: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var appUserRole: AppUserRole = .loading
    @Published var errorMessage: String?

    func resolve(
        authUid: String?,
        memberProfile: MemberProfile?
    ) {
        if memberProfile != nil {
            appUserRole = .member
        } else if authUid != nil {
            appUserRole = .guest
        } else {
            appUserRole = .guest
        }

        isLoading = false
    }
}
