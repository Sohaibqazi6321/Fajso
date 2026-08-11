import Combine
import Foundation
import Supabase
import CoreLocation
import Photos
import UIKit

@MainActor
final class TogetherSupabaseService: ObservableObject {
    @Published private(set) var isConfigured = TogetherSupabaseConfig.isConfigured
    @Published private(set) var statusText = TogetherSupabaseConfig.isConfigured ? "Supabase ready" : "Supabase not configured"
    @Published private(set) var photoStatusText = "Photo sync ready."

    private let client: SupabaseClient?
    private let photoCleanupDelay: TimeInterval = 24 * 60 * 60

    init(client: SupabaseClient? = TogetherSupabaseConfig.makeClient()) {
        self.client = client
    }

    func setPhotoStatus(_ text: String) {
        photoStatusText = text
    }

    func sendMagicLink(to email: String) async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            try await client.auth.signInWithOTP(
                email: email,
                redirectTo: TogetherSupabaseConfig.authRedirectURL
            )
            statusText = "Magic link sent to \(email)."
        } catch {
            statusText = "Magic link failed: \(error.localizedDescription)"
        }
    }

    func refreshSessionStatus() async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            let session = try await client.auth.session
            statusText = "Signed in as \(session.user.email ?? "Supabase user")."
        } catch {
            statusText = "Not signed in yet."
        }
    }

    func setupMember(role: TogetherRole, pairCode: String) async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        let displayName = role == .sohaib ? "Sohaib" : "Fajr"

        do {
            let memberships: [TogetherSetupMemberResult] = try await client
                .rpc(
                    "setup_together_member",
                    params: [
                        "selected_role": role.rawValue,
                        "selected_display_name": displayName,
                        "selected_pair_code": pairCode
                    ]
                )
                .execute()
                .value

            if let membership = memberships.first {
                statusText = "\(displayName) paired in \(membership.role.rawValue) slot."
            } else {
                statusText = "\(displayName) paired."
            }
        } catch {
            statusText = "Pair setup failed: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        guard let client else {
            statusText = "Supabase keys are missing."
            return
        }

        do {
            try await client.auth.signOut()
            statusText = "Signed out."
        } catch {
            statusText = "Sign out failed: \(error.localizedDescription)"
        }
    }

    func syncLocationAndDistance(from location: CLLocation) async -> TogetherDistanceSnapshot? {
        guard let client else {
            statusText = "Supabase keys are missing."
            return nil
        }

        do {
            let session = try await client.auth.session
            let userId = session.user.id
            let memberships: [TogetherMembershipRecord] = try await client
                .from("couple_members")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            guard let membership = memberships.first else {
                statusText = "Sign-in works, but this user is not paired yet."
                return nil
            }

            let payload = TogetherLocationRecord(
                coupleId: membership.coupleId,
                userId: userId,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )

            try await client
                .from("locations")
                .upsert(payload)
                .execute()

            let locations: [TogetherLocationRecord] = try await client
                .from("locations")
                .select()
                .eq("couple_id", value: membership.coupleId.uuidString)
                .execute()
                .value

            guard locations.count >= 2 else {
                statusText = "Your location synced. Waiting for partner location."
                return nil
            }

            let sortedLocations = locations.sorted { $0.updatedAt > $1.updatedAt }
            guard
                let mine = sortedLocations.first(where: { $0.userId == userId }),
                let partner = sortedLocations.first(where: { $0.userId != userId })
            else {
                statusText = "Location rows synced, but partner location is missing."
                return nil
            }

            let miles = Self.distanceMiles(
                from: CLLocation(latitude: mine.latitude, longitude: mine.longitude),
                to: CLLocation(latitude: partner.latitude, longitude: partner.longitude)
            )
            let distanceText = TogetherDemo.formattedDistance(miles: miles)
            let updatedAt = Date()
            _ = TogetherDemo.writeLiveDistance(distanceText: distanceText, miles: miles, updatedAt: updatedAt)
            statusText = "Live distance synced: \(distanceText)"

            return TogetherDistanceSnapshot(text: distanceText, miles: miles, updatedAt: updatedAt, isLive: true)
        } catch {
            statusText = "Location sync failed: \(error.localizedDescription)"
            return nil
        }
    }

    func uploadPartnerPhoto(image: UIImage) async -> UUID? {
        guard let client else {
            photoStatusText = "Supabase keys are missing."
            return nil
        }

        do {
            let membership = try await currentMembership(using: client)
            let photoId = UUID()
            let storagePath = "\(membership.coupleId.uuidString)/\(membership.userId.uuidString)/\(photoId.uuidString).jpg"

            guard let jpegData = image.togetherCompressedJPEGData() else {
                photoStatusText = "Could not compress that photo."
                return nil
            }

            try await client.storage
                .from("partner-photos")
                .upload(
                    path: storagePath,
                    file: jpegData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

            let photo = TogetherPhotoInsert(
                id: photoId,
                coupleId: membership.coupleId,
                senderUserId: membership.userId,
                storagePath: storagePath
            )

            try await client
                .from("photos")
                .insert(photo)
                .execute()

            photoStatusText = "Photo uploaded. Your partner can refresh now."
            await cleanupExpiredTransferredPhotos(client: client, coupleId: membership.coupleId)
            return photoId
        } catch {
            photoStatusText = "Photo upload failed: \(error.localizedDescription)"
            return nil
        }
    }

    func refreshLatestPartnerPhoto() async -> TogetherPartnerPhotoSnapshot? {
        guard let client else {
            photoStatusText = "Supabase keys are missing."
            return nil
        }

        do {
            let membership = try await currentMembership(using: client)
            await cleanupExpiredTransferredPhotos(client: client, coupleId: membership.coupleId)

            let photos: [TogetherPhotoRecord] = try await client
                .from("photos")
                .select()
                .eq("couple_id", value: membership.coupleId.uuidString)
                .execute()
                .value

            let latest = photos
                .filter { $0.senderUserId != membership.userId && $0.storageDeletedAt == nil }
                .sorted { $0.createdAt > $1.createdAt }
                .first

            guard let latest else {
                photoStatusText = "No partner photo yet."
                return nil
            }

            let cached = TogetherDemo.partnerPhoto()
            if cached.photoId == latest.id, cached.data != nil {
                if
                    TogetherDemo.lastSavedPartnerPhotoId() != latest.id,
                    let data = cached.data,
                    await saveReceivedPhotoToLibraryIfNeeded(data: data, photoId: latest.id)
                {
                    try await markPhotoSaved(client: client, photoId: latest.id)
                }

                photoStatusText = "Latest partner photo is already cached."
                return cached
            }

            let data = try await client.storage
                .from("partner-photos")
                .download(path: latest.storagePath)

            let now = Date()
            _ = TogetherDemo.writePartnerPhoto(
                data: data,
                photoId: latest.id,
                senderUserId: latest.senderUserId,
                updatedAt: now
            )

            if
                TogetherDemo.lastSavedPartnerPhotoId() != latest.id,
                await saveReceivedPhotoToLibraryIfNeeded(data: data, photoId: latest.id)
            {
                try await markPhotoSaved(client: client, photoId: latest.id)
            }

            photoStatusText = "Latest partner photo synced."
            return TogetherPartnerPhotoSnapshot(
                data: data,
                photoId: latest.id,
                senderUserId: latest.senderUserId,
                updatedAt: now
            )
        } catch {
            photoStatusText = "Photo refresh failed: \(error.localizedDescription)"
            return nil
        }
    }

    private static func distanceMiles(from start: CLLocation, to end: CLLocation) -> Double {
        start.distance(from: end) / 1609.344
    }

    private func currentMembership(using client: SupabaseClient) async throws -> TogetherMembershipRecord {
        let session = try await client.auth.session
        let userId = session.user.id
        let memberships: [TogetherMembershipRecord] = try await client
            .from("couple_members")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        guard let membership = memberships.first else {
            throw TogetherSyncError.notPaired
        }

        return membership
    }

    private func saveReceivedPhotoToLibraryIfNeeded(data: Data, photoId: UUID) async -> Bool {
        guard TogetherDemo.lastSavedPartnerPhotoId() != photoId else {
            return true
        }

        let status = await requestPhotoAddPermission()
        guard status == .authorized || status == .limited else {
            photoStatusText = "Partner photo cached, but Photos save permission was denied."
            return false
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            _ = TogetherDemo.markPartnerPhotoSavedToPhotos(photoId: photoId)
            return true
        } catch {
            photoStatusText = "Partner photo cached, but saving to Photos failed: \(error.localizedDescription)"
            return false
        }
    }

    private func requestPhotoAddPermission() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func markPhotoSaved(client: SupabaseClient, photoId: UUID) async throws {
        try await client
            .from("photos")
            .update(["receiver_saved_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: photoId.uuidString)
            .execute()
    }

    private func cleanupExpiredTransferredPhotos(client: SupabaseClient, coupleId: UUID) async {
        do {
            let photos: [TogetherPhotoRecord] = try await client
                .from("photos")
                .select()
                .eq("couple_id", value: coupleId.uuidString)
                .execute()
                .value

            let cutoff = Date().addingTimeInterval(-photoCleanupDelay)
            let expired = photos.filter { photo in
                guard
                    photo.storageDeletedAt == nil,
                    let savedAt = Self.isoDate(from: photo.receiverSavedAt)
                else {
                    return false
                }

                return savedAt <= cutoff
            }

            for photo in expired {
                try await client.storage
                    .from("partner-photos")
                    .remove(paths: [photo.storagePath])

                try await client
                    .from("photos")
                    .update(["storage_deleted_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: photo.id.uuidString)
                    .execute()
            }
        } catch {
            photoStatusText = "Photo cleanup skipped: \(error.localizedDescription)"
        }
    }

    private static func isoDate(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        return ISO8601DateFormatter().date(from: value)
    }
}

enum TogetherSyncError: LocalizedError {
    case notPaired

    var errorDescription: String? {
        switch self {
        case .notPaired:
            return "Sign in and choose Sohaib or Fajr before syncing."
        }
    }
}

private extension UIImage {
    func togetherCompressedJPEGData(maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        let size = normalizedSize(maxDimension: maxDimension)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return rendered.jpegData(compressionQuality: quality)
    }

    private func normalizedSize(maxDimension: CGFloat) -> CGSize {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else {
            return size
        }

        let scale = maxDimension / longestSide
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
