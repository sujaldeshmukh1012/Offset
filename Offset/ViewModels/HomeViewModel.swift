import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var snapshot: OpportunityDiscoverySnapshot = .empty
    private var cachedProfile: UserProfile?

    func refresh(profile: UserProfile?, force: Bool = false) {
        guard let profile else {
            cachedProfile = nil
            snapshot = .empty
            return
        }
        guard force || profile != cachedProfile else { return }
        cachedProfile = profile
        snapshot = OpportunityDiscoveryService.currentSnapshot(for: profile)
    }
}
