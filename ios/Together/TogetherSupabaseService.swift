import Combine
import CoreLocation
import Foundation
import Supabase
import UIKit
import WidgetKit

struct TogetherAccountIdentity: Equatable, Sendable {
    let id: UUID
    let email: String?
}

struct TogetherPairingDetails: Equatable, Sendable {
    let status: String
    let coupleId: UUID
    let createdBy: UUID?
    let memberCount: Int
    let partnerDisplayName: String?
    let inviteCode: String?
    let inviteExpiresAt: Date?

    var isPaired: Bool {
        memberCount >= 2 || ["active", "paired"].contains(status.lowercased())
    }
}

enum TogetherSessionState: Equatable, Sendable {
    case loading
    case configurationMissing
    case signedOut
    case unpaired(TogetherAccountIdentity)
    case pending(TogetherAccountIdentity, TogetherPairingDetails)
    case paired(TogetherAccountIdentity, TogetherPairingDetails)

    var account: TogetherAccountIdentity? {
        switch self {
        case let .unpaired(account), let .pending(account, _), let .paired(account, _):
            return account
        case .loading, .configurationMissing, .signedOut:
            return nil
        }
    }

    var pairing: TogetherPairingDetails? {
        switch self {
        case let .pending(_, pairing), let .paired(_, pairing):
            return pairing
        case .loading, .configurationMissing, .signedOut, .unpaired:
            return nil
        }
    }

    var isPaired: Bool {
        if case .paired = self { return true }
        return false
    }
}

@MainActor
final class TogetherSupabaseService: ObservableObject {
    @Published private(set) var sessionState: TogetherSessionState
    @Published private(set) var widgetState: CoupleWidgetState
    @Published private(set) var statusText = ""
    @Published private(set) var photoStatusText = ""
    @Published private(set) var isBusy = false

    private let client: SupabaseClient?
    private var authTask: Task<Void, Never>?
    private var sessionGeneration = 0
    private var observedAccountId: UUID?
    private var pairingRequestGeneration = 0
    private var photoRequestGeneration = 0
    private var locationRequestGeneration = 0

    init(client: SupabaseClient? = TogetherSupabaseConfig.makeClient()) {
        self.client = client
        self.widgetState = CoupleWidgetCache.load() ?? .signedOut
        if client == nil {
            sessionState = .configurationMissing
            statusText = "Together isn't connected yet."
        } else {
            sessionState = .loading
            statusText = "Restoring your session…"
            observeAuthState(using: client!)
        }
    }

    var canUseDeveloperMode: Bool {
        guard let accountId = sessionState.account?.id else { return false }
        return accountId == TogetherSupabaseConfig.developerUserId
    }

    func setPhotoStatus(_ text: String) {
        photoStatusText = text
    }

    func sendMagicLink(to email: String) async {
        guard let client else {
            statusText = "Together isn't connected yet."
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            statusText = "Enter a valid email address."
            return
        }

        await withBusyState {
            do {
                try await client.auth.signInWithOTP(
                    email: trimmedEmail,
                    redirectTo: TogetherSupabaseConfig.authRedirectURL
                )
                statusText = "Check your email for a secure sign-in link."
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't send the sign-in link. Try again shortly.")
            }
        }
    }

    func refreshPairingState() async {
        guard let client, let account = sessionState.account else { return }
        await withBusyState {
            await loadPairingState(for: account, using: client)
        }
    }

    func createInvite(regenerate: Bool = false) async {
        guard let client, sessionState.account != nil else { return }
        await withBusyState {
            do {
                let results: [TogetherInviteRPCResult] = try await client
                    .rpc("create_pair_invite", params: ["p_regenerate": regenerate])
                    .execute()
                    .value
                guard let result = results.first else {
                    statusText = "The invite couldn't be created. Please try again."
                    return
                }
                guard result.status.togetherIsSuccess else {
                    statusText = TogetherRPCMessage.message(for: result.status)
                    return
                }
                statusText = regenerate ? "A new invite code is ready." : "Your invite code is ready."
                if let account = sessionState.account {
                    await loadPairingState(for: account, using: client)
                }
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't create an invite. Try again shortly.")
            }
        }
    }

    func joinInvite(code: String) async {
        guard let client, sessionState.account != nil else { return }
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else {
            statusText = "Enter your partner's invite code."
            return
        }

        await withBusyState {
            do {
                let results: [TogetherStatusRPCResult] = try await client
                    .rpc("join_pair_invite", params: ["p_invite_code": normalizedCode])
                    .execute()
                    .value
                guard let result = results.first else {
                    statusText = "That invite couldn't be joined. Please try again."
                    return
                }
                guard result.status.togetherIsSuccess else {
                    statusText = TogetherRPCMessage.message(for: result.status)
                    return
                }
                statusText = "You're paired!"
                if let account = sessionState.account {
                    await loadPairingState(for: account, using: client)
                }
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't join that invite. Try again shortly.")
            }
        }
    }

    func revokeInvite() async {
        guard let client, sessionState.account != nil else { return }
        await withBusyState {
            do {
                let results: [TogetherStatusRPCResult] = try await client
                    .rpc("revoke_pair_invite")
                    .execute()
                    .value
                guard let result = results.first, result.status.togetherIsSuccess else {
                    statusText = TogetherRPCMessage.message(for: results.first?.status ?? "unknown")
                    return
                }
                statusText = "Invite revoked. You can make a new one anytime."
                if let account = sessionState.account {
                    await loadPairingState(for: account, using: client)
                }
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't revoke the invite. Try again shortly.")
            }
        }
    }

    func unpair() async {
        guard let client, let account = sessionState.account else { return }
        await withBusyState {
            do {
                let results: [TogetherStatusRPCResult] = try await client
                    .rpc("unpair_current_couple")
                    .execute()
                    .value
                guard let result = results.first, result.status.togetherIsSuccess else {
                    statusText = TogetherRPCMessage.message(for: results.first?.status ?? "unknown")
                    return
                }
                guard sessionState.account?.id == account.id else { return }
                sessionGeneration += 1
                clearPrivateCache(replacement: unpairedCache(for: account.id, preserveDeveloperOverride: false))
                sessionState = .unpaired(account)
                statusText = "You're no longer paired."
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't unpair right now. Try again shortly.")
            }
        }
    }

    func signOut() async {
        guard let client else { return }
        await withBusyState {
            do {
                try await client.auth.signOut()
                transitionToSignedOut()
                statusText = "Signed out."
            } catch {
                statusText = friendlyMessage(for: error, fallback: "We couldn't sign out. Try again shortly.")
            }
        }
    }

    func syncLocationAndDistance(from location: CLLocation) async {
        guard
            let client,
            case let .paired(account, pairing) = sessionState,
            Self.isValid(location: location)
        else {
            if sessionState.isPaired {
                statusText = "That location reading was too old or inaccurate. Try refreshing again."
            }
            return
        }
        let generation = sessionGeneration
        locationRequestGeneration += 1
        let locationGeneration = locationRequestGeneration

        do {
            let payload = TogetherLocationUpsert(
                coupleId: pairing.coupleId,
                userId: account.id,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyMeters: location.horizontalAccuracy,
                capturedAt: Self.isoString(from: location.timestamp)
            )
            try await client.from("locations").upsert(payload).execute()
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  locationRequestGeneration == locationGeneration else { return }

            let locations: [TogetherLocationRecord] = try await client
                .from("locations")
                .select()
                .eq("couple_id", value: pairing.coupleId.uuidString)
                .execute()
                .value
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  locationRequestGeneration == locationGeneration else { return }
            guard
                let mine = locations.first(where: { $0.userId == account.id }),
                let partner = locations.first(where: { $0.userId != account.id }),
                let mineDate = Self.isoDate(from: mine.capturedAt),
                let partnerDate = Self.isoDate(from: partner.capturedAt),
                Self.isValid(sourceDate: mineDate),
                Self.isValid(sourceDate: partnerDate),
                Self.isValid(record: mine),
                Self.isValid(record: partner)
            else {
                updateConnectionStatus(isOffline: false)
                statusText = "Your location is synced. Waiting for your partner's location."
                return
            }

            let miles = CLLocation(
                latitude: mine.latitude,
                longitude: mine.longitude
            ).distance(from: CLLocation(latitude: partner.latitude, longitude: partner.longitude)) / 1609.344
            let now = Date()
            var state = pairedCache(for: account, pairing: pairing)
            state.distance = TogetherDistancePresentation(
                miles: miles,
                sourceUpdatedAt: min(mineDate, partnerDate),
                cachedAt: now,
                origin: .live
            )
            state.lastSuccessfulSync = now
            state.isOffline = false
            publish(state)
            statusText = "Distance updated."
        } catch {
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  locationRequestGeneration == locationGeneration else { return }
            updateConnectionStatus(isOffline: true)
            statusText = friendlyMessage(for: error, fallback: "You're offline. Showing the last known distance.")
        }
    }

    func uploadPartnerPhoto(image: UIImage) async -> UUID? {
        guard
            let client,
            case let .paired(account, pairing) = sessionState
        else {
            photoStatusText = "Pair with your partner before sharing a photo."
            return nil
        }

        guard let jpegData = image.togetherCompressedJPEGData(), jpegData.count <= 5_000_000 else {
            photoStatusText = "That photo is too large to share. Choose a smaller image."
            return nil
        }
        let photoId = UUID()
        let storagePath = "\(pairing.coupleId.uuidString)/\(account.id.uuidString)/\(photoId.uuidString).jpg"

        do {
            try await client.storage
                .from("partner-photos")
                .upload(
                    path: storagePath,
                    file: jpegData,
                    options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: false)
                )

            let results: [TogetherPublishPhotoRPCResult] = try await client
                .rpc(
                    "publish_current_partner_photo",
                    params: [
                        "p_photo_id": photoId.uuidString,
                        "p_storage_path": storagePath
                    ]
                )
                .execute()
                .value
            guard let result = results.first, result.status.togetherIsSuccess else {
                try? await client.storage.from("partner-photos").remove(paths: [storagePath])
                photoStatusText = TogetherRPCMessage.message(for: results.first?.status ?? "unknown")
                return nil
            }
            if let previousPath = result.previousStoragePath, previousPath != storagePath {
                try? await client.storage.from("partner-photos").remove(paths: [previousPath])
            }
            photoStatusText = "Photo shared with your partner."
            return photoId
        } catch {
            try? await client.storage.from("partner-photos").remove(paths: [storagePath])
            photoStatusText = friendlyMessage(for: error, fallback: "We couldn't share that photo. Try again shortly.")
            return nil
        }
    }

    func refreshLatestPartnerPhoto() async {
        guard
            let client,
            case let .paired(account, pairing) = sessionState
        else {
            return
        }
        let generation = sessionGeneration
        photoRequestGeneration += 1
        let photoGeneration = photoRequestGeneration

        do {
            let records: [TogetherCurrentPartnerPhotoRecord] = try await client
                .from("current_partner_photos")
                .select()
                .eq("couple_id", value: pairing.coupleId.uuidString)
                .execute()
                .value
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  photoRequestGeneration == photoGeneration else { return }
            guard let current = records.first(where: { $0.senderUserId != account.id }) else {
                widgetState = CoupleWidgetCache.clearPartnerPhoto(in: pairedCache(for: account, pairing: pairing))
                WidgetCenter.shared.reloadTimelines(ofKind: "TogetherPartnerPhotoWidget")
                photoStatusText = "Waiting for your partner's first photo."
                return
            }
            if widgetState.partnerPhoto?.photoId == current.photoId,
               CoupleWidgetCache.photoData(for: widgetState) != nil {
                photoStatusText = "Partner photo is up to date."
                return
            }

            let data = try await client.storage
                .from("partner-photos")
                .download(path: current.storagePath)
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  photoRequestGeneration == photoGeneration else { return }
            guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
                photoStatusText = "The new photo couldn't be verified. Keeping the last one."
                return
            }
            guard let updatedAt = Self.isoDate(from: current.updatedAt), Self.isValid(sourceDate: updatedAt) else {
                photoStatusText = "The new photo has invalid timing information. Keeping the last one."
                return
            }
            if let cachedUpdatedAt = widgetState.partnerPhoto?.updatedAt,
               updatedAt < cachedUpdatedAt {
                photoStatusText = "Partner photo is up to date."
                return
            }
            guard let state = CoupleWidgetCache.replacePartnerPhoto(
                data: data,
                photoId: current.photoId,
                updatedAt: updatedAt,
                in: pairedCache(for: account, pairing: pairing)
            ) else {
                photoStatusText = "The new photo couldn't be saved. Keeping the last one."
                return
            }
            widgetState = state
            WidgetCenter.shared.reloadTimelines(ofKind: "TogetherPartnerPhotoWidget")
            photoStatusText = "Partner photo updated."
        } catch {
            guard isCurrentPairing(account.id, pairing.coupleId, generation: generation),
                  photoRequestGeneration == photoGeneration else { return }
            photoStatusText = friendlyMessage(for: error, fallback: "You're offline. Keeping the last partner photo.")
        }
    }

    func setDeveloperDistanceOverride(miles: Double?) {
        guard canUseDeveloperMode, let account = sessionState.account else { return }

        var state: CoupleWidgetState
        switch sessionState {
        case let .paired(_, pairing):
            state = pairedCache(for: account, pairing: pairing)
        case let .pending(_, pairing):
            state = pendingCache(for: account.id, coupleId: pairing.coupleId)
        case .unpaired:
            state = unpairedCache(for: account.id)
        case .loading, .configurationMissing, .signedOut:
            return
        }
        if let miles {
            guard miles.isFinite, miles > 0, miles <= 25_000 else {
                statusText = "Enter a distance between 0 and 25,000 miles."
                return
            }
            let now = Date()
            state.localDistanceOverride = TogetherDistancePresentation(
                miles: miles,
                sourceUpdatedAt: now,
                cachedAt: now,
                origin: .developerOverride
            )
            state.pairingStatus = .paired
            state.partnerDisplayName = state.partnerDisplayName ?? "Fajr"
            statusText = "Local test distance enabled on this device."
        } else {
            state.localDistanceOverride = nil
            switch sessionState {
            case .paired:
                state.pairingStatus = .paired
            case .pending:
                state.pairingStatus = .pending
                state.partnerDisplayName = nil
                state.distance = nil
                state.partnerPhoto = nil
            case .unpaired:
                state = unpairedCache(for: account.id, preserveDeveloperOverride: false)
            case .loading, .configurationMissing, .signedOut:
                return
            }
            statusText = "Local test distance disabled."
        }
        publish(state)
    }

    private func observeAuthState(using client: SupabaseClient) {
        authTask = Task { [weak self] in
            for await (_, session) in await client.auth.authStateChanges {
                guard let self else { return }
                await self.consume(session: session, using: client)
            }
        }
    }

    private func consume(session: Session?, using client: SupabaseClient) async {
        guard let session else {
            transitionToSignedOut()
            return
        }
        let account = TogetherAccountIdentity(id: session.user.id, email: session.user.email)
        if observedAccountId != account.id {
            sessionGeneration += 1
            observedAccountId = account.id
        }
        let generation = sessionGeneration
        if let cachedAccount = widgetState.accountId, cachedAccount != account.id {
            CoupleWidgetCache.clear()
            widgetState = .signedOut
        }
        await loadPairingState(for: account, using: client, generation: generation)
    }

    private func loadPairingState(
        for account: TogetherAccountIdentity,
        using client: SupabaseClient,
        generation expectedGeneration: Int? = nil
    ) async {
        let generation = expectedGeneration ?? sessionGeneration
        pairingRequestGeneration += 1
        let pairingGeneration = pairingRequestGeneration
        do {
            let results: [TogetherPairingRPCResult] = try await client
                .rpc("get_pairing_state")
                .execute()
                .value
            guard isCurrentAccount(account.id, generation: generation),
                  pairingRequestGeneration == pairingGeneration else { return }
            guard let result = results.first, let coupleId = result.coupleId else {
                let preserveDeveloperOverride = !sessionState.isPaired
                sessionState = .unpaired(account)
                clearPrivateCache(
                    replacement: unpairedCache(
                        for: account.id,
                        preserveDeveloperOverride: preserveDeveloperOverride
                    )
                )
                statusText = "Invite your partner or join their invite."
                return
            }
            let pairing = TogetherPairingDetails(
                status: result.status,
                coupleId: coupleId,
                createdBy: result.createdBy,
                memberCount: result.memberCount,
                partnerDisplayName: result.partnerDisplayName,
                inviteCode: result.inviteCode,
                inviteExpiresAt: Self.isoDate(from: result.inviteExpiresAt)
            )
            if pairing.isPaired {
                sessionState = .paired(account, pairing)
                var state = pairedCache(for: account, pairing: pairing)
                state.isOffline = false
                state.lastSuccessfulSync = Date()
                publish(state)
                statusText = "Connected with \(pairing.partnerDisplayName ?? "your partner")."
                await refreshLatestPartnerPhoto()
            } else {
                sessionState = .pending(account, pairing)
                publish(pendingCache(for: account.id, coupleId: coupleId))
                statusText = pairing.inviteCode == nil
                    ? "Create a new invite when you're ready."
                    : "Share this invite code with your partner."
            }
        } catch {
            guard isCurrentAccount(account.id, generation: generation),
                  pairingRequestGeneration == pairingGeneration else { return }
            if widgetState.accountId == account.id,
               widgetState.pairingStatus == .paired,
               let coupleId = widgetState.coupleId,
               widgetState.lastSuccessfulSync != nil {
                let cachedPairing = TogetherPairingDetails(
                    status: "paired",
                    coupleId: coupleId,
                    createdBy: nil,
                    memberCount: 2,
                    partnerDisplayName: widgetState.partnerDisplayName,
                    inviteCode: nil,
                    inviteExpiresAt: nil
                )
                sessionState = .paired(account, cachedPairing)
                var cached = widgetState
                cached.isOffline = true
                publish(cached)
                statusText = "You're offline. Showing your last saved Together state."
            } else if widgetState.accountId == account.id,
                      widgetState.localDistanceOverride != nil,
                      let coupleId = widgetState.coupleId {
                sessionState = .pending(
                    account,
                    TogetherPairingDetails(
                        status: "pending",
                        coupleId: coupleId,
                        createdBy: account.id,
                        memberCount: 1,
                        partnerDisplayName: nil,
                        inviteCode: nil,
                        inviteExpiresAt: nil
                    )
                )
                statusText = "You're offline. Your local test distance is still active."
            } else {
                sessionState = .unpaired(account)
                statusText = friendlyMessage(for: error, fallback: "We couldn't load your pairing yet. Pull to retry.")
            }
        }
    }

    private func transitionToSignedOut() {
        sessionGeneration += 1
        observedAccountId = nil
        sessionState = .signedOut
        clearPrivateCache(replacement: .signedOut)
    }

    private func isCurrentAccount(_ accountId: UUID, generation: Int) -> Bool {
        sessionGeneration == generation && observedAccountId == accountId
    }

    private func isCurrentPairing(_ accountId: UUID, _ coupleId: UUID, generation: Int) -> Bool {
        guard sessionGeneration == generation else { return false }
        guard case let .paired(account, pairing) = sessionState else { return false }
        return account.id == accountId && pairing.coupleId == coupleId
    }

    private func clearPrivateCache(replacement: CoupleWidgetState) {
        CoupleWidgetCache.clear()
        widgetState = replacement
        _ = CoupleWidgetCache.write(replacement)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func publish(_ state: CoupleWidgetState) {
        guard CoupleWidgetCache.write(state) else {
            statusText = "Together couldn't update its widget cache. Check App Group signing."
            return
        }
        widgetState = state
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func pairedCache(
        for account: TogetherAccountIdentity,
        pairing: TogetherPairingDetails
    ) -> CoupleWidgetState {
        var state: CoupleWidgetState
        if widgetState.accountId == account.id, widgetState.coupleId == pairing.coupleId {
            state = widgetState
        } else {
            CoupleWidgetCache.clear()
            state = CoupleWidgetState.signedOut
        }
        state.accountId = account.id
        state.coupleId = pairing.coupleId
        state.pairingStatus = .paired
        state.partnerDisplayName = pairing.partnerDisplayName
        return state
    }

    private func pendingCache(for accountId: UUID, coupleId: UUID) -> CoupleWidgetState {
        let developerOverride = accountId == TogetherSupabaseConfig.developerUserId
            && widgetState.accountId == accountId
            ? widgetState.localDistanceOverride
            : nil
        if widgetState.accountId == accountId, widgetState.coupleId == coupleId {
            var state = widgetState
            state.pairingStatus = developerOverride == nil ? .pending : .paired
            state.distance = nil
            state.localDistanceOverride = developerOverride
            state.partnerPhoto = nil
            if developerOverride != nil { state.partnerDisplayName = "Fajr" }
            state.isOffline = false
            return state
        }
        return CoupleWidgetState(
            schemaVersion: CoupleWidgetState.currentSchemaVersion,
            accountId: accountId,
            coupleId: coupleId,
            pairingStatus: developerOverride == nil ? .pending : .paired,
            partnerDisplayName: developerOverride == nil ? nil : "Fajr",
            distance: nil,
            localDistanceOverride: developerOverride,
            partnerPhoto: nil,
            lastSuccessfulSync: nil,
            isOffline: false
        )
    }

    private func unpairedCache(
        for accountId: UUID?,
        preserveDeveloperOverride: Bool = true
    ) -> CoupleWidgetState {
        let developerOverride = preserveDeveloperOverride
            && accountId == TogetherSupabaseConfig.developerUserId
            && widgetState.accountId == accountId
            ? widgetState.localDistanceOverride
            : nil
        return CoupleWidgetState(
            schemaVersion: CoupleWidgetState.currentSchemaVersion,
            accountId: accountId,
            coupleId: nil,
            pairingStatus: developerOverride == nil ? .unpaired : .paired,
            partnerDisplayName: developerOverride == nil ? nil : "Fajr",
            distance: nil,
            localDistanceOverride: developerOverride,
            partnerPhoto: nil,
            lastSuccessfulSync: nil,
            isOffline: false
        )
    }

    private func updateConnectionStatus(isOffline: Bool) {
        guard widgetState.pairingStatus == .paired else { return }
        var state = widgetState
        state.isOffline = isOffline
        if !isOffline { state.lastSuccessfulSync = Date() }
        publish(state)
    }

    private func withBusyState(_ operation: () async -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        await operation()
    }

    private func friendlyMessage(for error: Error, fallback: String) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("offline") || message.contains("internet") || message.contains("timed out") {
            return "You're offline. Try again when you have a connection."
        }
        if message.contains("session") || message.contains("jwt") || message.contains("auth") {
            return "Your session expired. Sign in again to continue."
        }
        return fallback
    }

    private static func isValid(location: CLLocation, now: Date = Date()) -> Bool {
        CLLocationCoordinate2DIsValid(location.coordinate)
            && location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= 20_000
            && location.timestamp <= now.addingTimeInterval(60)
            && location.timestamp >= now.addingTimeInterval(-5 * 60)
    }

    private static func isValid(record: TogetherLocationRecord) -> Bool {
        let coordinateIsValid = CLLocationCoordinate2DIsValid(
            CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
        )
        let accuracyIsValid = record.accuracyMeters.map { $0.isFinite && $0 >= 0 && $0 <= 20_000 } ?? true
        return coordinateIsValid && accuracyIsValid
    }

    private static func isValid(sourceDate: Date, now: Date = Date()) -> Bool {
        sourceDate <= now.addingTimeInterval(5 * 60)
    }

    private static func isoString(from date: Date) -> String {
        fractionalISOFormatter.string(from: date)
    }

    private static func isoDate(from value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalISOFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private enum TogetherRPCMessage {
    static func message(for status: String) -> String {
        switch status.lowercased() {
        case "invalid_invite", "not_found":
            return "That invite code isn't valid. Check it and try again."
        case "expired_invite":
            return "That invite expired. Ask your partner for a new one."
        case "used_invite":
            return "That invite has already been used."
        case "already_paired":
            return "This account is already paired."
        case "invite_full", "couple_full":
            return "That couple already has two people."
        case "not_paired":
            return "This account isn't paired yet."
        case "not_creator", "forbidden":
            return "Only the invite creator can do that."
        case "own_invite":
            return "That code is yours. Share it with your partner instead."
        case "invalid_photo_path", "missing_upload":
            return "The photo upload couldn't be verified. Please try again."
        case "relationship_changed":
            return "Your pairing changed. Refresh and try again."
        default:
            return "Together couldn't complete that request. Please try again."
        }
    }
}

private extension String {
    var togetherIsSuccess: Bool {
        [
            "success", "ok", "created", "invite_created", "invite_ready", "joined", "paired",
            "revoked", "invite_revoked", "no_pending_invite", "unpaired", "not_paired", "published"
        ].contains(lowercased())
    }
}

private extension UIImage {
    func togetherCompressedJPEGData(maxDimension: CGFloat = 1600, quality: CGFloat = 0.82) -> Data? {
        guard size.width > 0, size.height > 0 else { return nil }
        let longestSide = max(size.width, size.height)
        let scale = min(1, maxDimension / longestSide)
        let renderSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: renderSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
