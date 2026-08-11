import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var cacheStatus = "Not tested yet"
    @StateObject private var supabaseService = TogetherSupabaseService()
    @StateObject private var locationManager = TogetherLocationManager()
    @State private var email = ""
    @State private var pairCode = "SOHAIB-FAJR-2026"
    @State private var distanceSnapshot = TogetherDemo.liveDistance()
    @State private var photoSnapshot = TogetherDemo.partnerPhoto()
    @State private var showingPartnerPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Together")
                            .font(.largeTitle.bold())

                        Text("Private sideloading proof of concept for Sohaib and Fajr.")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label(distanceSnapshot.text, systemImage: "heart.fill")
                        Label("Distance Widget + Partner Photo Widget", systemImage: "square.grid.2x2")
                        Label("One WidgetKit extension", systemImage: "app.badge")
                        Label(supabaseStatusText, systemImage: TogetherSupabaseConfig.isConfigured ? "checkmark.seal.fill" : "server.rack")
                    }
                    .font(.headline)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Supabase Sync")
                            .font(.headline)

                        TextField("Email for magic link", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Send Link") {
                                Task {
                                    await supabaseService.sendMagicLink(to: email.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button("Check") {
                                Task {
                                    await supabaseService.refreshSessionStatus()
                                }
                            }
                        }

                        TextField("Pair code", text: $pairCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("I am Sohaib") {
                                Task {
                                    await supabaseService.setupMember(role: .sohaib, pairCode: pairCode.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }

                            Button("I am Fajr") {
                                Task {
                                    await supabaseService.setupMember(role: .fajr, pairCode: pairCode.trimmingCharacters(in: .whitespacesAndNewlines))
                                }
                            }
                        }

                        Text(supabaseService.statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Live Distance")
                            .font(.headline)

                        Text(distanceSnapshot.statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Allow Location") {
                                locationManager.requestPermission()
                            }

                            Button("Sync Now") {
                                locationManager.requestOneUpdate()
                            }
                        }

                        Button("Allow Background Location") {
                            locationManager.requestBackgroundPermission()
                        }

                        Button("Battery-Friendly Updates") {
                            locationManager.startEfficientUpdates()
                        }

                        Text(locationManager.statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Partner Photo")
                            .font(.headline)

                        Text(photoSnapshot.statusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Open Photo") {
                                showingPartnerPhoto = true
                            }

                            Button("Refresh Photo") {
                                Task {
                                    await refreshPartnerPhoto()
                                }
                            }
                        }

                        Text(supabaseService.photoStatusText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                    Button {
                        if TogetherDemo.writeDemoCache() {
                            cacheStatus = "Shared App Group cache wrote successfully."
                            WidgetCenter.shared.reloadAllTimelines()
                        } else {
                            cacheStatus = "Shared App Group cache failed. App Groups may not be enabled for this signing profile."
                        }
                    } label: {
                        Label("Write Demo Cache", systemImage: "externaldrive.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(cacheStatus)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .onReceive(locationManager.$latestLocation.compactMap { $0 }) { location in
                Task {
                    if let snapshot = await supabaseService.syncLocationAndDistance(from: location) {
                        distanceSnapshot = snapshot
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
            }
            .sheet(isPresented: $showingPartnerPhoto) {
                NavigationStack {
                    PartnerPhotoView(supabaseService: supabaseService)
                }
            }
            .onOpenURL { url in
                if url.scheme == "together", url.host == "photo" {
                    showingPartnerPhoto = true
                }
            }
            .task {
                await refreshPartnerPhoto()
            }
        }
    }

    private var supabaseStatusText: String {
        TogetherSupabaseConfig.isConfigured ? "Supabase configured" : "Supabase not configured yet"
    }

    private func refreshPartnerPhoto() async {
        if let snapshot = await supabaseService.refreshLatestPartnerPhoto() {
            photoSnapshot = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: "TogetherPartnerPhotoWidget")
        } else {
            photoSnapshot = TogetherDemo.partnerPhoto()
        }
    }
}

#Preview {
    ContentView()
}
