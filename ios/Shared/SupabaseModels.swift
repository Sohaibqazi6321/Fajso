import Foundation

struct TogetherLocationRecord: Codable, Sendable {
    let coupleId: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double?
    let capturedAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case userId = "user_id"
        case latitude
        case longitude
        case accuracyMeters = "accuracy_meters"
        case capturedAt = "captured_at"
        case updatedAt = "updated_at"
    }
}

struct TogetherLocationUpsert: Encodable {
    let coupleId: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double?
    let capturedAt: String

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case userId = "user_id"
        case latitude
        case longitude
        case accuracyMeters = "accuracy_meters"
        case capturedAt = "captured_at"
    }
}

struct TogetherPairingRPCResult: Codable, Sendable {
    let status: String
    let coupleId: UUID?
    let createdBy: UUID?
    let memberCount: Int
    let partnerDisplayName: String?
    let inviteCode: String?
    let inviteExpiresAt: String?

    enum CodingKeys: String, CodingKey {
        case status = "result_status"
        case coupleId = "result_couple_id"
        case createdBy = "result_created_by"
        case memberCount = "result_member_count"
        case partnerDisplayName = "result_partner_display_name"
        case inviteCode = "result_invite_code"
        case inviteExpiresAt = "result_invite_expires_at"
    }
}

struct TogetherInviteRPCResult: Codable, Sendable {
    let status: String
    let coupleId: UUID?
    let inviteCode: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case status = "result_status"
        case coupleId = "result_couple_id"
        case inviteCode = "result_invite_code"
        case expiresAt = "result_expires_at"
    }
}

struct TogetherStatusRPCResult: Codable, Sendable {
    let status: String

    enum CodingKeys: String, CodingKey {
        case status = "result_status"
    }
}

struct TogetherPublishPhotoRPCResult: Codable, Sendable {
    let status: String
    let previousStoragePath: String?

    enum CodingKeys: String, CodingKey {
        case status = "result_status"
        case previousStoragePath = "result_previous_storage_path"
    }
}

struct TogetherCurrentPartnerPhotoRecord: Codable, Sendable {
    let coupleId: UUID
    let senderUserId: UUID
    let photoId: UUID
    let storagePath: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case coupleId = "couple_id"
        case senderUserId = "sender_user_id"
        case photoId = "photo_id"
        case storagePath = "storage_path"
        case updatedAt = "updated_at"
    }
}
