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
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case userId = "user_id"
        case latitude
        case longitude
        case accuracyMeters = "accuracy_meters"
        case updatedAt = "updated_at"
    }
}

struct TogetherMembershipRecord: Codable, Sendable {
    let coupleId: UUID
    let userId: UUID
    let role: TogetherRole

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case userId = "user_id"
        case role
    }
}

struct TogetherSetupMemberResult: Codable, Sendable {
    let coupleId: UUID
    let userId: UUID
    let role: TogetherRole

    enum CodingKeys: String, CodingKey {
        case coupleId = "result_couple_id"
        case userId = "result_user_id"
        case role = "result_role"
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
    let receiverSavedAt: String?
    let storageDeletedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case senderUserId = "sender_user_id"
        case storagePath = "storage_path"
        case receiverSavedAt = "receiver_saved_at"
        case storageDeletedAt = "storage_deleted_at"
        case createdAt = "created_at"
    }
}

struct TogetherPhotoInsert: Encodable {
    let id: UUID
    let coupleId: UUID
    let senderUserId: UUID
    let storagePath: String

    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case senderUserId = "sender_user_id"
        case storagePath = "storage_path"
    }
}
