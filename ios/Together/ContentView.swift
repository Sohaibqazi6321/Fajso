import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var service = TogetherSupabaseService()
    @StateObject private var locationManager = TogetherLocationManager()
    @State private var email = ""
    @State private var inviteCode = ""
    @State private var developerMiles = ""
    @State private var showingPartnerPhoto = false
    @State private var showingUnpairConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                TogetherPalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        stateContent
                        if !service.statusText.isEmpty {
                            Text(service.statusText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(22)
                }
                .refreshable {
                    await service.refreshPairingState()
                    if service.sessionState.isPaired {
                        locationManager.requestOneUpdate()
                        await service.refreshLatestPartnerPhoto()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .tint(TogetherPalette.accent)
        .sheet(isPresented: $showingPartnerPhoto) {
            NavigationStack {
                PartnerPhotoView(supabaseService: service)
            }
        }
        .confirmationDialog(
            "Unpair from your partner?",
            isPresented: $showingUnpairConfirmation,
            titleVisibility: .visible
        ) {
            Button("Unpair", role: .destructive) {
                Task { await service.unpair() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Together data on this device will be cleared.")
        }
        .onReceive(locationManager.$latestLocation.compactMap { $0 }) { location in
            Task { await service.syncLocationAndDistance(from: location) }
        }
        .onChange(of: service.sessionState.isPaired) { _, isPaired in
            guard isPaired else {
                locationManager.stopUpdates()
                return
            }
            locationManager.requestOneUpdate()
            Task { await service.refreshLatestPartnerPhoto() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, service.sessionState.isPaired else { return }
            locationManager.requestOneUpdate()
            Task {
                await service.refreshPairingState()
                await service.refreshLatestPartnerPhoto()
            }
        }
        .onOpenURL { url in
            guard url.scheme == "together" else { return }
            if url.host == "photo" {
                showingPartnerPhoto = true
            } else if url.host == "home" {
                showingPartnerPhoto = false
            }
        }
        .task {
            if service.sessionState.isPaired {
                locationManager.requestOneUpdate()
                await service.refreshLatestPartnerPhoto()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(TogetherPalette.accent)
                Text("Together")
                    .font(.largeTitle.bold())
            }
            Text("A small place for the two of you.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch service.sessionState {
        case .loading:
            TogetherCard {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading your private space…")
                }
            }
        case .configurationMissing:
            TogetherCard {
                Label("Together needs its Supabase configuration before you can sign in.", systemImage: "exclamationmark.triangle")
            }
        case .signedOut:
            signedOutCard
        case .unpaired:
            unpairedCard
        case let .pending(_, pairing):
            pendingCard(pairing)
        case let .paired(_, pairing):
            pairedHome(pairing)
        }
    }

    private var signedOutCard: some View {
        TogetherCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sign in")
                    .font(.title2.bold())
                Text("We'll email you a secure link—no password needed.")
                    .foregroundStyle(.secondary)
                TextField("Email address", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .padding(12)
                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                Button("Send sign-in link") {
                    Task { await service.sendMagicLink(to: email) }
                }
                .buttonStyle(TogetherPrimaryButtonStyle())
                .disabled(service.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var unpairedCard: some View {
        VStack(spacing: 16) {
            TogetherCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Invite your partner")
                        .font(.title2.bold())
                    Text("Create a private, time-limited code to share with one person.")
                        .foregroundStyle(.secondary)
                    Button("Create invite") {
                        Task { await service.createInvite() }
                    }
                    .buttonStyle(TogetherPrimaryButtonStyle())
                    .disabled(service.isBusy)
                }
            }
            TogetherCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Join your partner")
                        .font(.title2.bold())
                    TextField("Invite code", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    Button("Join invite") {
                        Task { await service.joinInvite(code: inviteCode) }
                    }
                    .buttonStyle(TogetherSecondaryButtonStyle())
                    .disabled(service.isBusy || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            if service.canUseDeveloperMode {
                developerCard
            }
            accountActions
        }
    }

    private func pendingCard(_ pairing: TogetherPairingDetails) -> some View {
        VStack(spacing: 16) {
            TogetherCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Waiting for your partner")
                        .font(.title2.bold())
                    if let code = pairing.inviteCode {
                        Text(code)
                            .font(.system(.title, design: .monospaced, weight: .bold))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(TogetherPalette.lavender.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
                        HStack {
                            Button("Copy") {
                                UIPasteboard.general.string = code
                            }
                            .buttonStyle(TogetherSecondaryButtonStyle())
                            ShareLink(item: "Join me on Together with invite code \(code)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(TogetherSecondaryButtonStyle())
                        }
                        if let expiry = pairing.inviteExpiresAt {
                            Text("Expires \(expiry.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Your previous code is no longer active. Create a new one when you're ready.")
                            .foregroundStyle(.secondary)
                    }
                    Button(pairing.inviteCode == nil ? "Create new code" : "Regenerate code") {
                        Task { await service.createInvite(regenerate: true) }
                    }
                    .buttonStyle(TogetherPrimaryButtonStyle())
                    .disabled(service.isBusy)
                    if pairing.inviteCode != nil {
                        Button("Revoke this code", role: .destructive) {
                            Task { await service.revokeInvite() }
                        }
                        .disabled(service.isBusy)
                    }
                }
            }
            Button("Cancel pairing", role: .destructive) {
                showingUnpairConfirmation = true
            }
            if service.canUseDeveloperMode {
                developerCard
            }
            accountActions
        }
    }

    private func pairedHome(_ pairing: TogetherPairingDetails) -> some View {
        VStack(spacing: 16) {
            TogetherCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(pairing.partnerDisplayName.map { "You + \($0)" } ?? "You + your partner")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(distanceHeadline)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                    Text(distanceStatus)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        locationManager.requestOneUpdate()
                    } label: {
                        Label("Refresh distance", systemImage: "location.fill")
                    }
                    .buttonStyle(TogetherSecondaryButtonStyle())
                }
            }

            Button {
                showingPartnerPhoto = true
            } label: {
                HStack(spacing: 14) {
                    partnerPhotoThumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partner photo")
                            .font(.headline)
                        Text(service.widgetState.partnerPhoto == nil ? "Share the first photo" : "Open and send a photo")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(.plain)

            if service.canUseDeveloperMode {
                developerCard
            }

            TogetherCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label(locationManager.statusText, systemImage: "location.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Unpair", role: .destructive) {
                        showingUnpairConfirmation = true
                    }
                    Button("Sign out") {
                        Task { await service.signOut() }
                    }
                    .disabled(service.isBusy)
                }
            }
        }
    }

    private var developerCard: some View {
        TogetherCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Local developer preview", systemImage: "hammer")
                    .font(.headline)
                Text("Only changes the distance shown on this device. It never uploads a location.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let override = service.widgetState.localDistanceOverride {
                    Label(
                        "Active: \(TogetherDistanceFormatter.text(miles: override.miles))",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TogetherPalette.accent)
                }
                TextField("Miles", text: $developerMiles)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                HStack {
                    Button("Apply") {
                        service.setDeveloperDistanceOverride(miles: Double(developerMiles))
                    }
                    .buttonStyle(TogetherSecondaryButtonStyle())
                    Button("Disable") {
                        developerMiles = ""
                        service.setDeveloperDistanceOverride(miles: nil)
                    }
                    .disabled(service.widgetState.localDistanceOverride == nil)
                }
            }
        }
    }

    private var accountActions: some View {
        Button("Sign out") {
            Task { await service.signOut() }
        }
        .disabled(service.isBusy)
    }

    private var distanceHeadline: String {
        guard let distance = service.widgetState.effectiveDistance else {
            return "Waiting for location"
        }
        return TogetherDistanceFormatter.text(miles: distance.miles)
    }

    private var distanceStatus: String {
        guard let distance = service.widgetState.effectiveDistance else {
            return "Refresh after both of you allow location access."
        }
        if distance.origin == .developerOverride { return "Local test value" }
        switch service.widgetState.distanceFreshness() {
        case .fresh:
            return TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt)
        case .aging:
            return "May be a little out of date · \(TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt))"
        case .stale:
            return "Last known · \(TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt))"
        case .offlineCached:
            return "Offline · last known \(TogetherDistanceFormatter.ageText(since: distance.sourceUpdatedAt).lowercased())"
        case .missing:
            return "Waiting for both locations"
        }
    }

    @ViewBuilder
    private var partnerPhotoThumbnail: some View {
        if
            let data = CoupleWidgetCache.photoData(for: service.widgetState),
            let image = UIImage(data: data)
        {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            Image(systemName: "photo.fill")
                .font(.title2)
                .foregroundStyle(TogetherPalette.accent)
                .frame(width: 58, height: 58)
                .background(TogetherPalette.lavender, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct TogetherCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: TogetherPalette.accent.opacity(0.07), radius: 12, y: 5)
    }
}

private struct TogetherPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(TogetherPalette.accent.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 13))
    }
}

private struct TogetherSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(TogetherPalette.accent)
            .background(TogetherPalette.lavender.opacity(configuration.isPressed ? 0.45 : 0.75), in: RoundedRectangle(cornerRadius: 12))
    }
}

enum TogetherPalette {
    static let background = Color(red: 0.985, green: 0.975, blue: 0.99)
    static let lavender = Color(red: 0.91, green: 0.86, blue: 0.98)
    static let accent = Color(red: 0.44, green: 0.25, blue: 0.67)
}

#Preview {
    ContentView()
}
