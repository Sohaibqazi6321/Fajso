import Foundation

struct TogetherProfile: Codable, Identifiable, Sendable {
    let id: UUID
    let displayName: String
    let role: TogetherRole

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case role
    }
}

enum TogetherRole: String, Codable, Sendable {
    case sohaib
    case fajr
}

struct TogetherCouple: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let pairCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case pairCode = "pair_code"
    }
}

struct TogetherLocationRecord: Codable, Sendable {
    let coupleId: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case userId = "user_id"
        case latitude
        case longitude
        case accuracyMeters = "accuracy_meters"
        case updatedAt = "updated_at"
    }
}

struct TogetherMessageRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let coupleId: UUID
    let senderUserId: UUID
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case senderUserId = "sender_user_id"
        case text
        case createdAt = "created_at"
    }
}

struct TogetherPhotoRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let coupleId: UUID
    let senderUserId: UUID
    let storagePath: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case senderUserId = "sender_user_id"
        case storagePath = "storage_path"
        case createdAt = "created_at"
    }
}
