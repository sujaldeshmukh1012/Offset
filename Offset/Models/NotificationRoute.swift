import Foundation

enum NotificationRoute: Equatable, Identifiable, Sendable {
    case project(UUID)
    case program(id: String, projectID: UUID?)

    var id: String {
        switch self {
        case .project(let id): "project-\(id.uuidString)"
        case .program(let id, let projectID): "program-\(id)-\(projectID?.uuidString ?? "none")"
        }
    }

    static func parse(url: URL) -> Self? {
        guard url.scheme?.lowercased() == "offset" else { return nil }
        let identifier = url.pathComponents.dropFirst().first
        switch url.host?.lowercased() {
        case "project":
            guard let identifier, let id = UUID(uuidString: identifier) else { return nil }
            return .project(id)
        case "program":
            guard let identifier, !identifier.isEmpty else { return nil }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let projectID = components?.queryItems?
                .first(where: { $0.name == "project_id" })?
                .value
                .flatMap(UUID.init(uuidString:))
            return .program(id: identifier, projectID: projectID)
        default:
            return nil
        }
    }

    static func parse(additionalData: [AnyHashable: Any]?) -> Self? {
        guard let data = additionalData else { return nil }
        if let deepLink = data["deep_link"] as? String,
           let url = URL(string: deepLink),
           let route = parse(url: url) {
            return route
        }

        let projectID = (data["project_id"] as? String).flatMap(UUID.init(uuidString:))
        if let programID = data["program_id"] as? String, !programID.isEmpty {
            return .program(id: programID, projectID: projectID)
        }
        if let projectID { return .project(projectID) }
        return nil
    }

    var userInfo: [String: String] {
        switch self {
        case .project(let id):
            return ["project_id": id.uuidString, "deep_link": "offset://project/\(id.uuidString)"]
        case .program(let id, let projectID):
            var result = ["program_id": id]
            if let projectID {
                result["project_id"] = projectID.uuidString
                result["deep_link"] = "offset://program/\(id)?project_id=\(projectID.uuidString)"
            } else {
                result["deep_link"] = "offset://program/\(id)"
            }
            return result
        }
    }
}

extension Notification.Name {
    static let offsetNotificationRoute = Notification.Name("offset.notification-route")
    static let offsetForegroundNotificationReceived = Notification.Name("offset.foreground-notification-received")
}
