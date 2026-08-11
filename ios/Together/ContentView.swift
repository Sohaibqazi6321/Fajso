import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var cacheStatus = "Not tested yet"
    @StateObject private var supabaseService = TogetherSupabaseService()
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Together")
                        .font(.largeTitle.bold())

                    Text("Private sideloading proof of concept for Sohaib and Fajr.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(TogetherDemo.distanceText, systemImage: "heart.fill")
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

                    Text(supabaseService.statusText)
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

                Spacer()
            }
            .padding(24)
        }
    }

    private var supabaseStatusText: String {
        TogetherSupabaseConfig.isConfigured ? "Supabase configured" : "Supabase not configured yet"
    }
}

#Preview {
    ContentView()
}
