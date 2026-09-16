import Foundation

struct AppStateSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var profile: UserProfile?
    var savedProjects: [SavedProject]
    var completedClaimSteps: Set<ClaimStepID>
    var notificationPreferences: NotificationPreferences
    var hasCompletedOnboarding: Bool

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        profile: UserProfile? = nil,
        savedProjects: [SavedProject] = [],
        completedClaimSteps: Set<ClaimStepID> = [],
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        hasCompletedOnboarding: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.profile = profile
        self.savedProjects = savedProjects
        self.completedClaimSteps = completedClaimSteps
        self.notificationPreferences = notificationPreferences
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profile
        case savedProjects
        case completedClaimSteps
        case notificationPreferences
        case hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        profile = try container.decodeIfPresent(UserProfile.self, forKey: .profile)
        savedProjects = try container.decodeIfPresent([SavedProject].self, forKey: .savedProjects) ?? []
        completedClaimSteps = try container.decodeIfPresent(Set<ClaimStepID>.self, forKey: .completedClaimSteps) ?? []
        notificationPreferences = try container.decodeIfPresent(NotificationPreferences.self, forKey: .notificationPreferences) ?? NotificationPreferences()
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}

protocol AppStateStoring {
    func load() throws -> AppStateSnapshot?
    func save(_ snapshot: AppStateSnapshot) throws
}

struct UserDefaultsAppStateStore: AppStateStoring {
    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "offset.app-state.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func load() throws -> AppStateSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try Self.decoder.decode(AppStateSnapshot.self, from: data)
    }

    func save(_ snapshot: AppStateSnapshot) throws {
        defaults.set(try Self.encoder.encode(snapshot), forKey: storageKey)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
