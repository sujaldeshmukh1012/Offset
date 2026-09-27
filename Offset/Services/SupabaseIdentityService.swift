import Foundation
import Security

enum SupabaseIdentityError: LocalizedError, Equatable {
    case notConfigured
    case invalidResponse
    case httpStatus(Int)
    case invalidUserID

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Secure catalog access is not configured for this build."
        case .invalidResponse:
            "Supabase returned an invalid authentication response."
        case .httpStatus(let status):
            "Supabase authentication returned HTTP \(status)."
        case .invalidUserID:
            "Supabase returned an invalid user identifier."
        }
    }
}

struct SupabaseAuthenticatedSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let userID: UUID
    let expiresAt: Date

    var needsRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 60
    }
}

actor SupabaseIdentityService {
    private struct AuthResponse: Decodable {
        struct User: Decodable { let id: String }

        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let expiresAt: Double?
        let user: User
    }

    private struct RefreshBody: Encodable {
        let refreshToken: String
    }

    private let configuration: AppConfiguration
    private let session: URLSession
    private let credentialStore: SupabaseCredentialStore
    private var cachedSession: SupabaseAuthenticatedSession?

    init(
        configuration: AppConfiguration,
        session: URLSession = .shared,
        credentialStore: SupabaseCredentialStore = KeychainSupabaseCredentialStore()
    ) {
        self.configuration = configuration
        self.session = session
        self.credentialStore = credentialStore
    }

    func authenticatedSession() async throws -> SupabaseAuthenticatedSession {
        if let cachedSession, !cachedSession.needsRefresh {
            return cachedSession
        }

        if cachedSession == nil,
           let stored = try? credentialStore.load(),
           !stored.needsRefresh {
            cachedSession = stored
            return stored
        }

        if let existing = cachedSession ?? (try? credentialStore.load()) {
            do {
                let refreshed = try await refresh(existing)
                try credentialStore.save(refreshed)
                cachedSession = refreshed
                return refreshed
            } catch {
                try? credentialStore.remove()
                cachedSession = nil
            }
        }

        let created = try await createAnonymousUser()
        try credentialStore.save(created)
        cachedSession = created
        return created
    }

    private func createAnonymousUser() async throws -> SupabaseAuthenticatedSession {
        var request = try request(path: "auth/v1/signup")
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        return try await authenticate(request)
    }

    private func refresh(_ existing: SupabaseAuthenticatedSession) async throws -> SupabaseAuthenticatedSession {
        var request = try request(path: "auth/v1/token", queryItems: [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ])
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: existing.refreshToken))
        return try await authenticate(request)
    }

    private func authenticate(_ request: URLRequest) async throws -> SupabaseAuthenticatedSession {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SupabaseIdentityError.invalidResponse
        }
        guard response.statusCode == 200 else {
            throw SupabaseIdentityError.httpStatus(response.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let auth = try decoder.decode(AuthResponse.self, from: data)
        guard let userID = UUID(uuidString: auth.user.id) else {
            throw SupabaseIdentityError.invalidUserID
        }
        let expiration = auth.expiresAt.map(Date.init(timeIntervalSince1970:))
            ?? Date().addingTimeInterval(TimeInterval(auth.expiresIn))
        return SupabaseAuthenticatedSession(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            userID: userID,
            expiresAt: expiration
        )
    }

    private func request(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard let baseURL = configuration.supabaseURL,
              let publishableKey = configuration.supabasePublishableKey else {
            throw SupabaseIdentityError.notConfigured
        }
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw SupabaseIdentityError.notConfigured
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw SupabaseIdentityError.notConfigured }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

protocol SupabaseCredentialStore: Sendable {
    func load() throws -> SupabaseAuthenticatedSession?
    func save(_ session: SupabaseAuthenticatedSession) throws
    func remove() throws
}

struct KeychainSupabaseCredentialStore: SupabaseCredentialStore {
    private let service = "com.sujal.Offset.supabase-auth"
    private let account = "anonymous-session-v1"

    func load() throws -> SupabaseAuthenticatedSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CocoaError(.fileReadUnknown)
        }
        return try JSONDecoder().decode(SupabaseAuthenticatedSession.self, from: data)
    }

    func save(_ session: SupabaseAuthenticatedSession) throws {
        let data = try JSONEncoder().encode(session)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
                throw CocoaError(.fileWriteUnknown)
            }
        } else if status != errSecSuccess {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    func remove() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
